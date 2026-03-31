#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../lib/vibe/skill_router'

router = Vibe::SkillRouter.new
ai_stats = router.stats[:ai_triage]

puts '=== AI Triage Status ==='
puts "Enabled: #{ai_stats[:enabled]}"
puts "Environment: #{ai_stats[:runtime_environment]}"
puts "Disabled reason: #{ai_stats[:disabled_reason]}"
puts "Model: #{ai_stats[:model]}"
puts "Provider: #{ai_stats[:provider]}"
puts "Provider configured: #{ai_stats[:provider_configured]}"
puts "Base URL: #{ai_stats[:base_url]}"
puts "Is local model: #{ai_stats[:is_local_model]}"
