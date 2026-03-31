#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require_relative '../lib/vibe/llm_provider/factory'

puts '=== Test 1: OpenCode config + API key ==='
ENV['ANTHROPIC_API_KEY'] = 'sk-test-key'
ENV['LOCAL_MODEL_URL'] = 'http://localhost:8000/v1'

begin
  provider = Vibe::LLMProvider::Factory.create_from_opencode_config
  puts "Provider: #{provider.class}"
  puts "Configured: #{provider.configured?}"
  puts "Base URL: #{provider.base_url}"
rescue => e
  puts "Error: #{e.message}"
end

puts "\n=== Test 2: OpenCode config + NO API key ==="
ENV['ANTHROPIC_API_KEY'] = nil
ENV['LOCAL_MODEL_URL'] = 'http://localhost:8000/v1'

begin
  provider = Vibe::LLMProvider::Factory.create_from_opencode_config
  puts "Provider: #{provider.class}"
  puts "Configured: #{provider.configured?}"
  puts "Should fall back to local model: #{!provider.configured?}"
rescue => e
  puts "Error: #{e.message}"
end
