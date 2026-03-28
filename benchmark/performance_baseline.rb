#!/usr/bin/env ruby
# frozen_string_literal: true

# VibeSOP Performance Benchmark
# Measures key operations to establish baseline and identify bottlenecks

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'vibe/skill_router'
require 'vibe/skill_discovery'
require 'vibe/skill_manager'
require 'benchmark'
require 'tmpdir'
require 'fileutils'

class PerformanceBenchmark
  def initialize
    @repo_root = Dir.pwd
    @results = {}
  end

  def run_all
    puts "=" * 70
    puts "VibeSOP Performance Benchmark"
    puts "=" * 70
    puts "Ruby version: #{RUBY_VERSION}"
    puts "Date: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
    puts

    benchmark_skill_router
    benchmark_skill_discovery
    benchmark_skill_manager
    benchmark_memory_operations

    print_summary
  end

  private

  def benchmark_skill_router
    puts "\n" + "=" * 70
    puts "SkillRouter Performance"
    puts "=" * 70

    router = Vibe::SkillRouter.new(@repo_root)
    test_inputs = [
      '帮我评审代码',
      '这个 bug 很奇怪',
      '这是一个复杂的重构任务',
      '准备发布新版本',
      '帮我测试网站'
    ]

    # Warm up
    10.times { router.route(test_inputs.sample) }

    times = []
    iterations = 100

    Benchmark.bm(20) do |x|
      x.report("single route:") do
        times = iterations.times.map do
          start = Time.now
          router.route(test_inputs.sample)
          Time.now - start
        end
      end
    end

    avg_time = times.sum / times.size
    min_time = times.min
    max_time = times.max
    p95_time = times.sort[(iterations * 0.95).to_i]

    puts "\n  Statistics (#{iterations} iterations):"
    puts "    Average: #{(avg_time * 1000).round(3)} ms"
    puts "    Min:     #{(min_time * 1000).round(3)} ms"
    puts "    Max:     #{(max_time * 1000).round(3)} ms"
    puts "    P95:     #{(p95_time * 1000).round(3)} ms"
    puts "    Routes/sec: #{(1.0 / avg_time).round(0)}"

    @results[:skill_router] = {
      avg_ms: (avg_time * 1000).round(3),
      p95_ms: (p95_time * 1000).round(3),
      rps: (1.0 / avg_time).round(0)
    }
  end

  def benchmark_skill_discovery
    puts "\n" + "=" * 70
    puts "SkillDiscovery Performance"
    puts "=" * 70

    discovery = Vibe::SkillDiscovery.new(@repo_root, @repo_root)

    Benchmark.bm(20) do |x|
      x.report("discover_all:") do
        10.times { discovery.discover_all }
      end

      x.report("get_skill_info:") do
        1000.times { discovery.get_skill_info('systematic-debugging') }
      end

      x.report("unregistered_skills:") do
        10.times { discovery.unregistered_skills }
      end
    end

    # Measure cache effectiveness
    puts "\n  Cache Effectiveness:"
    start = Time.now
    100.times { discovery.get_skill_info('systematic-debugging') }
    cached_time = (Time.now - start) * 1000

    puts "    100 lookups with caching: #{cached_time.round(3)} ms"
    puts "    Average per lookup: #{(cached_time / 100).round(3)} ms"

    @results[:skill_discovery] = {
      cached_lookup_ms: (cached_time / 100).round(3)
    }
  end

  def benchmark_skill_manager
    puts "\n" + "=" * 70
    puts "SkillManager Performance"
    puts "=" * 70

    Dir.mktmpdir('benchmark') do |test_dir|
      manager = Vibe::SkillManager.new(@repo_root, test_dir)

      Benchmark.bm(20) do |x|
        x.report("list_skills:") do
          100.times { manager.list_skills }
        end

        x.report("skill_info:") do
          1000.times { manager.skill_info('systematic-debugging') }
        end

        x.report("check_and_prompt (dry):") do
          # Dry run - no actual prompt
          10.times { manager.send(:check_skill_changes) }
        end
      end

      start = Time.now
      100.times { manager.skill_info('systematic-debugging') }
      info_time = (Time.now - start) * 1000

      puts "\n  skill_info x100: #{info_time.round(3)} ms"
      puts "    Average: #{(info_time / 100).round(3)} ms"

      @results[:skill_manager] = {
        info_lookup_ms: (info_time / 100).round(3)
      }
    end
  end

  def benchmark_memory_operations
    puts "\n" + "=" * 70
    puts "Memory/File Operations"
    puts "=" * 70

    Dir.mktmpdir('memory-benchmark') do |dir|
      yaml_content = YAML.dump({
        'test' => 'data',
        'array' => (1..100).to_a,
        'nested' => { 'key' => 'value' }
      })

      file_path = File.join(dir, 'test.yaml')

      Benchmark.bm(20) do |x|
        x.report("YAML write:") do
          100.times { File.write(file_path, yaml_content) }
        end

        x.report("YAML read:") do
          100.times { YAML.safe_load(File.read(file_path)) }
        end

        x.report("YAML read/write:") do
          100.times do
            File.write(file_path, yaml_content)
            YAML.safe_load(File.read(file_path))
          end
        end
      end

      # File size impact
      puts "\n  File Size Impact:"
      [10, 100, 1000].each do |count|
        data = { 'items' => (1..count).map { |i| { id: i, name: "item#{i}" } } }
        File.write(file_path, YAML.dump(data))
        size = File.size(file_path)

        start = Time.now
        100.times { YAML.safe_load(File.read(file_path)) }
        read_time = (Time.now - start) * 1000

        puts "    #{count} items (#{size} bytes): #{read_time.round(2)} ms (100x)"
      end
    end
  end

  def print_summary
    puts "\n" + "=" * 70
    puts "Performance Summary"
    puts "=" * 70

    puts "\nSkillRouter:"
    puts "  Average: #{@results[:skill_router][:avg_ms]} ms"
    puts "  P95:     #{@results[:skill_router][:p95_ms]} ms"
    puts "  RPS:     #{@results[:skill_router][:rps]} routes/sec"

    puts "\nSkillDiscovery:"
    puts "  Cached lookup: #{@results[:skill_discovery][:cached_lookup_ms]} ms"

    puts "\nSkillManager:"
    puts "  Info lookup: #{@results[:skill_manager][:info_lookup_ms]} ms"

    puts "\n" + "=" * 70
    puts "Recommendations"
    puts "=" * 70

    if @results[:skill_router][:avg_ms] > 10
      puts "⚠️  SkillRouter average > 10ms - consider caching"
    else
      puts "✅ SkillRouter performance good"
    end

    if @results[:skill_discovery][:cached_lookup_ms] > 1
      puts "⚠️  Skill lookup > 1ms - review caching strategy"
    else
      puts "✅ Skill lookup performance good"
    end

    puts "\nBaseline established. Run after optimizations to compare."
    puts "=" * 70
  end
end

# Run benchmark
PerformanceBenchmark.new.run_all
