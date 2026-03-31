#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require_relative '../lib/vibe/llm_provider/factory'

puts '=== Environment Variables ==='
puts "LOCAL_MODEL_URL: #{ENV.fetch('LOCAL_MODEL_URL', nil).inspect}"
puts "VIBE_LOCAL_MODEL_URL: #{ENV.fetch('VIBE_LOCAL_MODEL_URL', nil).inspect}"
puts "ANTHROPIC_API_KEY: #{ENV.fetch('ANTHROPIC_API_KEY', nil).inspect}"
puts "OPENAI_API_KEY: #{ENV.fetch('OPENAI_API_KEY', nil).inspect}"
puts

puts '=== OpenCode Config ==='
if File.exist?('opencode.json')
  config = JSON.parse(File.read('opencode.json'))
  puts "Models config: #{config['models'].inspect}"
else
  puts 'opencode.json not found'
end
puts

puts '=== Testing Provider Creation ==='
puts "1. create_from_opencode_config:"
begin
  provider = Vibe::LLMProvider::Factory.create_from_opencode_config
  puts "   Provider: #{provider.class}"
  puts "   Configured: #{provider.configured?}"
  puts "   Base URL: #{provider.base_url}"
rescue => e
  puts "   Error: #{e.message}"
end
puts

puts "2. create_from_env('anthropic'):"
begin
  provider = Vibe::LLMProvider::Factory.create_from_env('anthropic')
  puts "   Provider: #{provider.class}"
  puts "   Configured: #{provider.configured?}"
  puts "   Base URL: #{provider.base_url}"
rescue => e
  puts "   Error: #{e.message}"
end
