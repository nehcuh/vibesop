#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'yaml'
require_relative '../../lib/vibe/skill_router'

# AI 路由准确率基准测试

class AI_Routing_Accuracy_Test
  TEST_CASES = [
    { input: "这个 bug 很奇怪", expected: "systematic-debugging" },
    { input: "帮我调试这个错误", expected: "systematic-debugging" },
    { input: "代码不工作了", expected: "systematic-debugging" },
    { input: "帮我评审代码", expected: "gstack/review" },
    { input: "重构这个函数", expected: "superpowers/refactor" },
    { input: "需要详细计划", expected: "planning-with-files" },
    { input: "我要走了", expected: "session-end" },
    { input: "深入审查项目", expected: "riper-workflow" },
    { input: "fix this bug", expected: "systematic-debugging" },
    { input: "review my code", expected: "gstack/review" },
  ]

  def initialize
    @router = Vibe::SkillRouter.new(Dir.pwd)
    @results = { correct: 0, total: 0, times: [], no_match: 0 }
  end

  def run
    puts "=== AI 路由准确率测试 ==="
    puts "测试用例: #{TEST_CASES.size}"
    puts "AI 路由: #{@router.ai_triage_enabled? ? '启用' : '禁用'}"
    puts

    TEST_CASES.each_with_index do |tc, i|
      start = Time.now
      result = @router.route(tc[:input])
      elapsed = (Time.now - start) * 1000

      if result && result[:matched]
        actual = result[:skill]
        expected = tc[:expected]
        # 检查是否匹配（考虑 namespace）
        match = actual == expected || 
                actual.end_with?(expected) ||
                actual.include?(expected.split('/').last)
        
        @results[:correct] += 1 if match
        status = match ? '✓' : '✗'
        puts "[#{i+1}] #{tc[:input][0..25].ljust(28)} => #{actual.ljust(30)} #{status} #{elapsed.round(1)}ms"
      else
        @results[:no_match] += 1
        puts "[#{i+1}] #{tc[:input][0..25].ljust(28)} => (无匹配) #{elapsed.round(1)}ms"
      end
      @results[:total] += 1
      @results[:times] << elapsed
      sleep 0.05
    end

    puts
    puts "=" * 50
    puts "测试结果"
    puts "=" * 50
    
    accuracy = (@results[:correct].to_f / @results[:total] * 100).round(1)
    avg_time = (@results[:times].sum / @results[:times].size).round(1)
    p95_time = @results[:times].sort[(@results[:times].size * 0.95).to_i]&.round(1) || @results[:times].last.round(1)

    puts "准确率: #{accuracy}% (#{@results[:correct]}/#{@results[:total]})"
    puts "无匹配: #{@results[:no_match]}"
    puts "平均响应: #{avg_time}ms"
    puts "P95 延迟: #{p95_time}ms"
    puts
    puts "目标评估:"
    puts "  准确率 95%: #{accuracy >= 95 ? '✅ 达标' : '⚠️  未达标'}"
    puts "  P95 延迟 150ms: #{p95_time <= 150 ? '✅ 达标' : '⚠️  未达标'}"
    puts "=" * 50

    # 保存结果
    save_results(accuracy, avg_time, p95_time)
  end

  def save_results(accuracy, avg_time, p95_time)
    results = {
      timestamp: Time.now.iso8601,
      summary: {
        test_cases: TEST_CASES.size,
        accuracy: accuracy,
        avg_time_ms: avg_time,
        p95_time_ms: p95_time,
        no_match: @results[:no_match]
      },
      target_comparison: {
        accuracy_target: 95,
        accuracy_met: accuracy >= 95,
        p95_target_ms: 150,
        p95_met: p95_time <= 150
      }
    }
    
    results_file = File.join(__dir__, 'ai_routing_accuracy_results.json')
    File.write(results_file, JSON.pretty_generate(results))
    puts "\n结果已保存: #{results_file}"
  end
end

AI_Routing_Accuracy_Test.new.run if __FILE__ == $0
