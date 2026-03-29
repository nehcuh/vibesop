#!/usr/bin/env ruby
# frozen_string_literal: true

# Performance Benchmark for AI-Powered Skill Routing
#
# This script benchmarks the 5-layer routing system to measure:
# 1. Cache hit rate
# 2. Response time (P50, P95, P99)
# 3. API call count
# 4. Cost per request

require 'benchmark'
require 'json'
require 'tmpdir'
require_relative '../lib/vibe/semantic_matcher'

# Add lib to load path
$LOAD_PATH.unshift(File.expand_path('../lib', __dir__))

class SkillRouterBenchmark
  def initialize
    @project_root = Dir.mktmpdir
    @router = Vibe::SkillRouter.new(@project_root)

    # Test scenarios
    @scenarios = [
      { input: "调试这个bug", context: { file_type: 'rb' }, name: "Chinese debugging" },
      { input: "Review this code", context: { file_type: 'js' }, name: "English review" },
      { input: "帮我重构这个函数", context: { file_type: 'py' }, name: "Chinese refactoring" },
      { input: "Fix the failing test", context: { error_count: 3 }, name: "English testing" },
      { input: "优化性能", context: { file_type: 'go' }, name: "Chinese optimization" },
      { input: "Add documentation", context: { file_type: 'md' }, name: "English documentation" },
      { input: "安全审查", context: { file_type: 'rb' }, name: "Chinese security" },
      { input: "Deploy to production", context: { urgency: 'high' }, name: "English deployment" }
    ]

    @results = {
      cold_cache: [],
      warm_cache: [],
      api_calls: 0,
      cache_hits: 0,
      cache_misses: 0
    }
  end

  def run_benchmark(iterations: 100)
    puts "🚀 Starting Skill Router Benchmark..."
    puts "=" * 60

    # Warm-up phase
    puts "\n📊 Phase 1: Cold Cache Benchmark (#{iterations} iterations)"
    benchmark_phase(:cold_cache, iterations)

    # Warm-up the cache
    puts "\n🔥 Warming up cache..."
    warm_up_cache

    # Hot cache benchmark
    puts "\n📊 Phase 2: Warm Cache Benchmark (#{iterations} iterations)"
    benchmark_phase(:warm_cache, iterations)

    # Generate report
    generate_report
  end

  private

  def benchmark_phase(phase, iterations)
    times = []

    iterations.times do |i|
      scenario = @scenarios.sample

      time = Benchmark.realtime do
        @router.route(scenario[:input], scenario[:context])
      end

      times << time
      @results[phase] << { scenario: scenario[:name], time: time }

      if i % 10 == 0
        print "."
        $stdout.flush
      end
    end

    puts "\n"
  end

  def warm_up_cache
    @scenarios.each do |scenario|
      3.times { @router.route(scenario[:input], scenario[:context]) }
    end

    # Collect statistics
    stats = @router.stats
    @results[:api_calls] = stats[:llm_client][:call_count] || 0
    @results[:cache_hits] = stats[:cache][:total_hits] || 0
    @results[:cache_misses] = stats[:cache][:total_misses] || 0
  end

  def generate_report
    puts "\n" + "=" * 60
    puts "📈 BENCHMARK RESULTS"
    puts "=" * 60

    # Cold cache statistics
    cold_times = @results[:cold_cache].map { |r| r[:time] }
    puts "\n❄️  Cold Cache Performance:"
    puts "   P50: #{percentile(cold_times, 50)*1000.round(2)}ms"
    puts "   P95: #{percentile(cold_times, 95)*1000.round(2)}ms"
    puts "   P99: #{percentile(cold_times, 99)*1000.round(2)}ms"
    puts "   Mean: #{mean(cold_times)*1000.round(2)}ms"

    # Warm cache statistics
    warm_times = @results[:warm_cache].map { |r| r[:time] }
    puts "\n🔥 Warm Cache Performance:"
    puts "   P50: #{percentile(warm_times, 50)*1000.round(2)}ms"
    puts "   P95: #{percentile(warm_times, 95)*1000.round(2)}ms"
    puts "   P99: #{percentile(warm_times, 99)*1000.round(2)}ms"
    puts "   Mean: #{mean(warm_times)*1000.round(2)}ms"

    # Cache statistics
    total_cache_ops = @results[:cache_hits] + @results[:cache_misses]
    cache_hit_rate = total_cache_ops > 0 ? (@results[:cache_hits].to_f / total_cache_ops * 100).round(2) : 0

    puts "\n💾 Cache Statistics:"
    puts "   Hit Rate: #{cache_hit_rate}%"
    puts "   Hits: #{@results[:cache_hits]}"
    puts "   Misses: #{@results[:cache_misses]}"

    # Performance improvement
    improvement = ((1 - mean(warm_times) / mean(cold_times)) * 100).round(2)
    puts "\n⚡ Performance Improvement:"
    puts "   Cache provides #{improvement}% speedup"

    # Cost estimation
    # Haiku pricing: $0.000125 per 1K tokens (input), $0.0005 per 1K tokens (output)
    # Assume avg 500 tokens per request
    cost_per_request = 0.000125 * 0.5 + 0.0005 * 0.2  # ~$0.000175 per request
    monthly_requests = 10_000  # Assume 10K requests per month
    estimated_monthly_cost = (cost_per_request * monthly_requests * (1 - cache_hit_rate/100)).round(4)

    puts "\n💰 Cost Estimation:"
    puts "   Cost per AI call: $#{cost_per_request.round(6)}"
    puts "   Estimated monthly cost: $#{estimated_monthly_cost}"
    puts "   (Assuming #{monthly_requests} requests/month with #{cache_hit_rate}% cache hit rate)"

    # Verdict
    puts "\n" + "=" * 60
    if cache_hit_rate >= 70 && percentile(warm_times, 95) < 0.3
      puts "✅ BENCHMARK PASSED"
      puts "   System meets performance targets:"
      puts "   - Cache hit rate ≥ 70%: #{cache_hit_rate}%"
      puts "   - P95 latency < 300ms: #{percentile(warm_times, 95)*1000.round(2)}ms"
    else
      puts "⚠️  BENCHMARK NEEDS IMPROVEMENT"
      if cache_hit_rate < 70
        puts "   - Cache hit rate below target (#{cache_hit_rate}% < 70%)"
      end
      if percentile(warm_times, 95) >= 0.3
        puts "   - P95 latency above target (#{percentile(warm_times, 95)*1000.round(2)}ms ≥ 300ms)"
      end
    end
    puts "=" * 60
  end

  def percentile(array, p)
    sorted = array.sort
    index = (p.to_f / 100 * sorted.length).ceil - 1
    sorted[[index, 0].max]
  end

  def mean(array)
    array.sum / array.size.to_f
  end
end

# Run benchmark
if __FILE__ == $0
  begin
    benchmark = SkillRouterBenchmark.new
    benchmark.run_benchmark(iterations: 100)
  rescue => e
    puts "Error: #{e.message}"
    puts e.backtrace.first(5)
    exit 1
  end
end
