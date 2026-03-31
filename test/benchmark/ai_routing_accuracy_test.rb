#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'yaml'
require_relative '../../lib/vibe/skill_router'

# AI 路由准确率基准测试
#
# 严格匹配版本 - 只接受完全匹配或明确的前缀匹配
# 不再使用宽松的 include? 逻辑

class AIRoutingAccuracyTest
  # 测试用例：涵盖常见开发场景
  # expected 必须精确匹配或与返回值完全一致
  TEST_CASES = [
    # 调试场景
    { input: "这个 bug 很奇怪", expected: "systematic-debugging", scenario: "debug" },
    { input: "帮我调试这个错误", expected: "systematic-debugging", scenario: "debug" },
    { input: "代码不工作了", expected: "systematic-debugging", scenario: "debug" },
    { input: "测试失败了，帮我找问题", expected: "systematic-debugging", scenario: "debug" },
    { input: "fix this bug", expected: "systematic-debugging", scenario: "debug" },

    # 代码审查场景 - gstack/review 或 /review
    { input: "帮我评审代码", expected: "gstack/review", scenario: "review" },
    { input: "检查代码质量", expected: "gstack/review", scenario: "review" },
    { input: "review my code", expected: "gstack/review", scenario: "review" },

    # 重构场景
    { input: "重构这个函数", expected: "superpowers/refactor", scenario: "refactor" },
    { input: "代码结构不好", expected: "superpowers/refactor", scenario: "refactor" },

    # 规划场景
    { input: "复杂任务需要详细计划", expected: "planning-with-files", scenario: "planning" },
    { input: "帮我规划实现步骤", expected: "planning-with-files", scenario: "planning" },

    # 会话结束场景
    { input: "我要走了", expected: "session-end", scenario: "session_end" },
    { input: "保存一下进度", expected: "session-end", scenario: "session_end" },
    { input: "今天先到这", expected: "session-end", scenario: "session_end" },

    # RIPER 工作流
    { input: "深入审查项目架构", expected: "riper-workflow", scenario: "review" },
    { input: "全面分析代码库", expected: "riper-workflow", scenario: "review" },

    # 经验学习
    { input: "从这次错误中学习", expected: "experience-evolution", scenario: "learning" },

    # TDD 场景
    { input: "先写测试再写代码", expected: "superpowers/tdd", scenario: "tdd" },

    # 实验场景
    { input: "做个实验优化性能", expected: "autonomous-experiment", scenario: "experiment" },
  ]

  def initialize
    @router = Vibe::SkillRouter.new(Dir.pwd)
    @results = {
      correct: 0,
      incorrect: 0,
      no_match: 0,
      total: 0,
      times: [],
      mismatches: []  # 记录不匹配的详情
    }
  end

  def run
    puts "=" * 60
    puts "AI 路由准确率基准测试 (严格匹配版)"
    puts "=" * 60
    puts "测试用例: #{TEST_CASES.size}"
    puts "AI 路由: #{@router.ai_triage_enabled? ? '启用' : '禁用'}"
    puts "匹配模式: 严格匹配 (exact or /review format)"
    puts

    TEST_CASES.each_with_index do |tc, i|
      run_test_case(tc, i)
      sleep 0.05  # 避免速率限制
    end

    print_results
    save_results
  end

  def run_test_case(test_case, index)
    input = test_case[:input]
    expected = test_case[:expected]
    scenario = test_case[:scenario]

    start_time = Time.now
    result = @router.route(input)
    elapsed = (Time.now - start_time) * 1000  # ms

    @results[:total] += 1
    @results[:times] << elapsed

    if result && result[:matched]
      actual = result[:skill]
      is_match = strict_match?(actual, expected)

      if is_match
        @results[:correct] += 1
        puts "[#{index + 1}/#{TEST_CASES.size}] ✓ #{input[0..30].ljust(32)} => #{actual.ljust(35)} #{elapsed.round(1)}ms"
      else
        @results[:incorrect] += 1
        @results[:mismatches] << {
          input: input,
          expected: expected,
          actual: actual,
          scenario: scenario
        }
        puts "[#{index + 1}/#{TEST_CASES.size}] ✗ #{input[0..30].ljust(32)} => #{actual.ljust(35)} (期望: #{expected}) #{elapsed.round(1)}ms"
      end
    else
      @results[:no_match] += 1
      @results[:mismatches] << {
        input: input,
        expected: expected,
        actual: "(no match)",
        scenario: scenario
      }
      puts "[#{index + 1}/#{TEST_CASES.size}] ? #{input[0..30].ljust(32)} => (无匹配) #{elapsed.round(1)}ms"
    end
  end

  # 严格匹配逻辑
  # 只接受完全匹配，或者 /skill 格式的简化匹配
  def strict_match?(actual, expected)
    # 完全匹配
    return true if actual == expected

    # /review 格式匹配 - 如果 actual 是 /review 且 expected 包含 review
    if actual.start_with?('/') && expected.include?(actual.gsub('/', ''))
      return true
    end

    # expected 是 /review 格式，actual 是完整路径
    if expected.start_with?('/') && actual.end_with?(expected.gsub('/', ''))
      return true
    end

    false
  end

  def print_results
    puts
    puts "=" * 60
    puts "测试结果"
    puts "=" * 60
    puts

    accuracy = (@results[:correct].to_f / @results[:total] * 100).round(1)
    avg_time = @results[:times].empty? ? 0 : (@results[:times].sum / @results[:times].size).round(1)
    sorted_times = @results[:times].sort
    p95_index = (sorted_times.size * 0.95).to_i
    p95_time = sorted_times[p95_index]&.round(1) || sorted_times.last&.round(1) || 0

    puts "准确率: #{accuracy}% (#{@results[:correct]}/#{@results[:total]})"
    puts "  - 正确: #{@results[:correct]}"
    puts "  - 错误: #{@results[:incorrect]}"
    puts "  - 无匹配: #{@results[:no_match]}"
    puts
    puts "性能指标:"
    puts "  - 平均: #{avg_time}ms"
    puts "  - P95: #{p95_time}ms"
    puts "  - P99: #{sorted_times[(sorted_times.size * 0.99).to_i]&.round(1) || p95_time}ms"
    puts
    puts "目标评估:"
    puts "  准确率 95%: #{accuracy >= 95 ? '✅ 达标' : '⚠️  未达标'}"
    puts "  P95 延迟 150ms: #{p95_time <= 150 ? '✅ 达标' : '⚠️  未达标'}"
    puts

    # 显示不匹配详情
    if @results[:mismatches].any?
      puts "=" * 60
      puts "不匹配详情 (#{@results[:mismatches].size})"
      puts "=" * 60
      @results[:mismatches].each do |m|
        puts "  输入: #{m[:input]}"
        puts "    期望: #{m[:expected]}"
        puts "    实际: #{m[:actual]}"
        puts "    场景: #{m[:scenario]}"
        puts
      end
    end

    puts "=" * 60
  end

  def save_results
    accuracy = (@results[:correct].to_f / @results[:total] * 100).round(1)
    avg_time = @results[:times].empty? ? 0 : (@results[:times].sum / @results[:times].size).round(1)
    sorted_times = @results[:times].sort
    p95_time = sorted_times[(sorted_times.size * 0.95).to_i]&.round(1) || 0

    results = {
      timestamp: Time.now.iso8601,
      version: "strict-match-v1",
      summary: {
        test_cases: @results[:total],
        correct: @results[:correct],
        incorrect: @results[:incorrect],
        no_match: @results[:no_match],
        accuracy: accuracy,
        avg_time_ms: avg_time,
        p95_time_ms: p95_time
      },
      target_comparison: {
        accuracy_target: 95,
        accuracy_met: accuracy >= 95,
        p95_target_ms: 150,
        p95_met: p95_time <= 150
      },
      mismatches: @results[:mismatches]
    }

    results_file = File.join(__dir__, 'ai_routing_accuracy_results.json')
    File.write(results_file, JSON.pretty_generate(results))
    puts "\n结果已保存: #{results_file}"
  end
end

# 运行测试
if __FILE__ == $0
  AIRoutingAccuracyTest.new.run
end
