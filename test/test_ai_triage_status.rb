#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/vibe/skill_router'
require_relative '../lib/vibe/skill_router/ai_triage_layer'

# 检查环境
puts '=== Environment Check ==='
puts "File.exist?('opencode.json'): #{File.exist?('opencode.json')}"
puts "ENV['OPENCODE']: #{ENV['OPENCODE'].inspect}"
puts "ENV['CLAUDECODE']: #{ENV['CLAUDECODE'].inspect}"
puts

# 创建 router 并检查 AI Triage 状态
router = Vibe::SkillRouter.new
ai_stats = router.stats[:ai_triage]

puts '=== AI Triage Status ==='
puts "Enabled: #{ai_stats[:enabled]}"
puts "Environment: #{ai_stats[:runtime_environment]}"
puts "Reason: #{ai_stats[:disabled_reason]}"
puts

# 测试路由
puts '=== Test Routing ==='
result = router.route('帮我调试这个 bug')
puts "Result: #{result.inspect}"
