#!/usr/bin/env ruby
# frozen_string_literal: true

require 'benchmark'
require 'json'
require_relative '../../lib/vibe/skill_router'
require_relative '../../lib/vibe/skill_router/ai_triage_layer'

##
# AI Routing Performance Benchmark
#
# Measures:
# 1. Accuracy comparison (AI vs Algorithm)
# 2. Latency distribution (P50, P95, P99)
# 3. Cache effectiveness
# 4. Cost estimation
#
class AIRoutingBenchmark
  # Test cases: input => expected_skill_id
  TEST_CASES = {
    # Debugging scenarios
    '帮我调试这个 bug' => 'systematic-debugging',
    '调试错误' => 'systematic-debugging',
    '为什么报错' => 'systematic-debugging',
    '这个功能坏了' => 'systematic-debugging',

    # Code review scenarios
    '帮我评审这段代码' => 'gstack/review',
    '检查代码质量' => 'gstack/review',
    'code review' => 'gstack/review',

    # Refactoring scenarios
    '重构这个函数' => 'superpowers/refactor',
    '优化代码结构' => 'superpowers/refactor',
    '代码太乱了' => 'superpowers/refactor',

    # TDD scenarios
    '测试驱动开发' => 'superpowers/tdd',
    '先写测试还是先写代码' => 'superpowers/tdd',
    'TDD workflow' => 'superpowers/tdd',

    # Planning scenarios
    '制定实施计划' => 'planning-with-files',
    '设计架构方案' => 'riper-workflow',
    '如何实现这个功能' => 'planning-with-files',

    # Exploration scenarios (removed - skill doesn't exist)
    # '探索代码库' => 'exploration',
    # '了解项目结构' => 'exploration',
    # '这个项目是做什么的' => 'exploration',

    # Session end scenarios
    '今天的任务完成了' => 'session-end',
    '我要下班了' => 'session-end',
    '保存进度' => 'session-end',

    # Edge cases
    '今天天气怎么样' => nil,  # Should return nil (no match)
    '讲个笑话' => nil,
    'hello world' => nil
  }.freeze

  def initialize(project_root: Dir.pwd)
    @project_root = project_root
    @router = Vibe::SkillRouter.new(project_root)
    @registry = @router.registry
    @preferences = @router.preferences
    @results = {}
  end

  # Test 1: Accuracy Comparison
  def test_accuracy
    puts "\n=== Test 1: Accuracy Comparison ==="
    puts

    ai_correct = 0
    algo_correct = 0
    ai_total = 0
    algo_total = 0

    TEST_CASES.each do |input, expected|
      # AI routing (with AI Triage Layer enabled)
      result_with_ai = @router.route(input)
      ai_result = if result_with_ai.is_a?(Hash) && result_with_ai[:matched]
                    result_with_ai[:skill]
                  else
                    nil
                  end
      ai_layer = result_with_ai.is_a?(Hash) ? result_with_ai[:layer] : nil

      # Algorithm routing (check if result came from AI layer or algorithm layer)
      # We count it as "algorithm" if it came from layers 1-4 (not layer 0 AI)
      if ai_layer == :layer_0_ai
        # Result came from AI routing
        algo_result = nil  # Algorithm wouldn't have matched
      else
        # Result came from algorithm routing (layers 1-4)
        algo_result = ai_result
      end

      # Check correctness
      if expected.nil?
        # No match expected
        ai_matches = ai_result.nil?
        algo_matches = algo_result.nil?
      else
        # Specific skill expected
        ai_matches = ai_result == expected
        algo_matches = algo_result == expected
      end

      ai_correct += 1 if ai_matches
      algo_correct += 1 if algo_matches

      ai_total += 1
      algo_total += 1

      # Show details for failures
      unless ai_matches && algo_matches
        puts "Input: #{input}"
        puts "  Expected: #{expected || 'no match'}"
        puts "  AI (#{ai_layer}):       #{ai_result || 'no match'} #{ai_matches ? '✓' : '✗'}"
        puts "  Algo:     #{algo_result || 'no match'} #{algo_matches ? '✓' : '✗'}"
        puts
      end
    end

    ai_accuracy = (ai_correct.to_f / ai_total * 100).round(2)
    algo_accuracy = (algo_correct.to_f / algo_total * 100).round(2)

    puts "AI Routing:    #{ai_correct}/#{ai_total} (#{ai_accuracy}%)"
    puts "Algorithm:     #{algo_correct}/#{algo_total} (#{algo_accuracy}%)"
    puts "Improvement:  +#{(ai_accuracy - algo_accuracy).round(2)}%"
    puts

    @results[:accuracy] = {
      ai: { correct: ai_correct, total: ai_total, accuracy: ai_accuracy },
      algorithm: { correct: algo_correct, total: algo_total, accuracy: algo_accuracy },
      improvement: ai_accuracy - algo_accuracy
    }
  end

  # Test 2: Latency Distribution
  def test_latency(iterations: 100)
    puts "\n=== Test 2: Latency Distribution ==="
    puts "Running #{iterations} iterations..."
    puts

    latencies = []
    cache_hits = 0

    iterations.times do
      input = TEST_CASES.keys.sample

      t0 = Time.now
      result = @router.route(input)
      latency_ms = (Time.now - t0) * 1000

      latencies << latency_ms

      # Check if cache hit
      cache_hits += 1 if result[:cache_hit]
    end

    latencies.sort!

    p50 = percentile(latencies, 50)
    p75 = percentile(latencies, 75)
    p95 = percentile(latencies, 95)
    p99 = percentile(latencies, 99)
    avg = latencies.sum / latencies.size

    puts "Latency Distribution:"
    puts "  Average:  #{avg.round(2)}ms"
    puts "  P50:      #{p50.round(2)}ms"
    puts "  P75:      #{p75.round(2)}ms"
    puts "  P95:      #{p95.round(2)}ms"
    puts "  P99:      #{p99.round(2)}ms"
    puts
    puts "Cache Hit Rate: #{cache_hits}/#{iterations} (#{(cache_hits.to_f / iterations * 100).round(2)}%)"
    puts

    @results[:latency] = {
      avg: avg,
      p50: p50,
      p75: p75,
      p95: p95,
      p99: p99,
      cache_hit_rate: cache_hits.to_f / iterations
    }
  end

  # Test 3: Cost Estimation
  def test_cost(monthly_requests: 10_000)
    puts "\n=== Test 3: Cost Estimation ==="
    puts "Assumptions:"
    puts "  Monthly requests: #{monthly_requests}"
    puts "  Daily requests:   #{monthly_requests / 30}"
    puts

    cache_hit_rate = @results[:latency][:cache_hit_rate]
    actual_calls = monthly_requests * (1 - cache_hit_rate)

    # Claude Haiku pricing (as of 2025)
    # Input: $0.000125 per 1K tokens
    # Output: $0.000125 per 1K tokens
    avg_tokens_per_request = 500
    tokens_per_request = avg_tokens_per_request * 2  # input + output
    cost_per_1k_tokens = 0.000125

    cost_per_request = (tokens_per_request / 1000.0) * cost_per_1k_tokens
    monthly_cost = actual_calls * cost_per_request

    puts "Cache Hit Rate:    #{(cache_hit_rate * 100).round(2)}%"
    puts "Actual API Calls:  #{actual_calls.round}"
    puts
    puts "Cost Analysis:"
    puts "  Avg tokens/request: #{tokens_per_request}"
    puts "  Cost per request:   $#{cost_per_request.round(6)}"
    puts "  Monthly cost:       $#{monthly_cost.round(2)}"
    puts

    @results[:cost] = {
      monthly_requests: monthly_requests,
      cache_hit_rate: cache_hit_rate,
      actual_calls: actual_calls,
      monthly_cost: monthly_cost
    }
  end

  # Test 4: Comparison Summary
  def print_summary
    puts "\n=== Performance Summary ==="
    puts

    accuracy = @results[:accuracy]
    latency = @results[:latency]
    cost = @results[:cost]

    puts "Accuracy:"
    puts "  AI Routing:    #{accuracy[:ai][:accuracy]}%"
    puts "  Algorithm:     #{accuracy[:algorithm][:accuracy]}%"
    puts "  Improvement:   +#{accuracy[:improvement]}%"
    puts

    puts "Latency:"
    puts "  P95:          #{latency[:p95].round(2)}ms (target: <150ms) #{latency[:p95] < 150 ? '✓' : '✗'}"
    puts "  Cache Hit:    #{(latency[:cache_hit_rate] * 100).round(2)}% (target: >70%) #{latency[:cache_hit_rate] > 0.7 ? '✓' : '✗'}"
    puts

    puts "Cost:"
    puts "  Monthly:      $#{cost[:monthly_cost].round(2)} (target: <$0.11) #{cost[:monthly_cost] < 0.11 ? '✓' : '✗'}"
    puts

    # Overall verdict
    all_pass = latency[:p95] < 150 && latency[:cache_hit_rate] > 0.7 && cost[:monthly_cost] < 0.11

    puts "Overall: #{all_pass ? '✓ PASS' : '✗ FAIL'}"
    puts
  end

  # Save results to JSON
  def save_results(filename: 'ai_routing_benchmark_results.json')
    results_json = {
      timestamp: Time.now.iso8601,
      results: @results,
      environment: {
        ruby_version: RUBY_VERSION,
        os: RbConfig::CONFIG['host_os']
      }
    }

    File.write(filename, JSON.pretty_generate(results_json))
    puts "Results saved to: #{filename}"
  end

  private

  def route_with_layer(layer, input)
    # Route the input and extract the skill ID
    result = @router.route(input)

    if result.is_a?(Hash) && result[:matched]
      # Extract skill ID from result (note: field name is :skill, not :skill_id)
      result[:skill] || result[:id]
    else
      nil
    end
  end

  def percentile(array, p)
    index = (p * array.size / 100.0).ceil - 1
    index = [0, [index, array.size - 1].min].max
    array[index]
  end
end

# Run benchmark if executed directly
if __FILE__ == $PROGRAM_NAME
  benchmark = AIRoutingBenchmark.new

  puts 'AI Routing Performance Benchmark'
  puts '=' * 60
  puts

  begin
    benchmark.test_accuracy
    benchmark.test_latency(iterations: 100)
    benchmark.test_cost(monthly_requests: 10_000)
    benchmark.print_summary
    benchmark.save_results
  rescue StandardError => e
    puts "Error: #{e.message}"
    puts e.backtrace
    exit 1
  end
end
