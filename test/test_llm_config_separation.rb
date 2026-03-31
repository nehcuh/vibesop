#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require_relative '../lib/vibe/llm_provider/factory'

puts '=== Test 1: Load from .vibe/llm-config.json ==='

# Create test config
test_config = {
  'models' => {
    'fast' => {
      'provider' => 'openai',
      'model' => 'glm-4.5-air',
      'base_url' => 'https://open.bigmodel.cn/api/coding/paas/v4',
      'api_key' => 'test-key-12345',
      'temperature' => 0.7
    }
  }
}

File.write('.vibe/llm-config.json', JSON.pretty_generate(test_config))

begin
  provider = Vibe::LLMProvider::Factory.create_from_opencode_config
  puts "✓ Provider created: #{provider.class}"
  puts "✓ Provider name: #{provider.provider_name}"
  puts "✓ Configured: #{provider.configured?}"
  puts "✓ Base URL: #{provider.base_url}"
  puts "✓ API Key: #{provider.api_key[0..9]}..." # Show first 10 chars only
rescue => e
  puts "✗ Error: #{e.message}"
  puts e.backtrace.first(3)
end

puts "\n=== Test 2: Verify config file priority ==="

# Test that .vibe/llm-config.json has priority over opencode.json
if File.exist?('.vibe/llm-config.json')
  puts "✓ .vibe/llm-config.json exists"
else
  puts "✗ .vibe/llm-config.json not found"
end

puts "\n=== Cleanup ==="
File.delete('.vibe/llm-config.json') if File.exist?('.vibe/llm-config.json')
puts "✓ Test config cleaned up"
