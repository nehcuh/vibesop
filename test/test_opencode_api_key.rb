#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require_relative '../lib/vibe/llm_provider/factory'

puts '=== Test 1: Anthropic with API key in config ==='
test_config_anthropic = {
  '$schema' => 'https://opencode.ai/config.json',
  'instructions' => ['AGENTS.md'],
  'models' => {
    'fast' => {
      'provider' => 'anthropic',
      'model' => 'claude-haiku-4-20250514',
      'api_key' => 'sk-ant-test-key',
      'temperature' => 0.3
    }
  }
}

File.write('test_opencode_anthropic.json', JSON.pretty_generate(test_config_anthropic))

begin
  provider = Vibe::LLMProvider::Factory.create_from_opencode_config('test_opencode_anthropic.json')
  puts "✓ Provider created: #{provider.class}"
  puts "✓ Provider name: #{provider.provider_name}"
  puts "✓ Configured: #{provider.configured?}"
  puts "✓ Base URL: #{provider.base_url}"
rescue => e
  puts "✗ Error: #{e.message}"
end

puts "\n=== Test 2: OpenAI with API key in config ==="
test_config_openai = {
  '$schema' => 'https://opencode.ai/config.json',
  'instructions' => ['AGENTS.md'],
  'models' => {
    'fast' => {
      'provider' => 'openai',
      'model' => 'gpt-4o-mini',
      'api_key' => 'sk-proj-test-key',
      'temperature' => 0.3
    }
  }
}

File.write('test_opencode_openai.json', JSON.pretty_generate(test_config_openai))

begin
  provider = Vibe::LLMProvider::Factory.create_from_opencode_config('test_opencode_openai.json')
  puts "✓ Provider created: #{provider.class}"
  puts "✓ Provider name: #{provider.provider_name}"
  puts "✓ Configured: #{provider.configured?}"
  puts "✓ Base URL: #{provider.base_url}"
rescue => e
  puts "✗ Error: #{e.message}"
end

puts "\n=== Test 3: OpenAI with custom endpoint ==="
test_config_custom = {
  '$schema' => 'https://opencode.ai/config.json',
  'instructions' => ['AGENTS.md'],
  'models' => {
    'fast' => {
      'provider' => 'openai',
      'model' => 'custom-model',
      'api_key' => 'test-key',
      'base_url' => 'https://custom-endpoint.com/v1',
      'temperature' => 0.3
    }
  }
}

File.write('test_opencode_custom.json', JSON.pretty_generate(test_config_custom))

begin
  provider = Vibe::LLMProvider::Factory.create_from_opencode_config('test_opencode_custom.json')
  puts "✓ Provider created: #{provider.class}"
  puts "✓ Provider name: #{provider.provider_name}"
  puts "✓ Configured: #{provider.configured?}"
  puts "✓ Base URL: #{provider.base_url}"
rescue => e
  puts "✗ Error: #{e.message}"
end

puts "\n=== Test 4: Config without API key (fallback to env) ==="
ENV['ANTHROPIC_API_KEY'] = 'sk-ant-env-key'
test_config_no_key = {
  '$schema' => 'https://opencode.ai/config.json',
  'instructions' => ['AGENTS.md'],
  'models' => {
    'fast' => {
      'provider' => 'anthropic',
      'model' => 'claude-haiku-4-20250514',
      'temperature' => 0.3
    }
  }
}

File.write('test_opencode_no_key.json', JSON.pretty_generate(test_config_no_key))

begin
  provider = Vibe::LLMProvider::Factory.create_from_opencode_config('test_opencode_no_key.json')
  puts "✓ Provider created: #{provider.class}"
  puts "✓ Provider name: #{provider.provider_name}"
  puts "✓ Configured: #{provider.configured?}"
  puts "✓ Using env API key: #{provider.api_key == 'sk-ant-env-key'}"
rescue => e
  puts "✗ Error: #{e.message}"
end

puts "\n=== Cleanup ==="
File.delete('test_opencode_anthropic.json') if File.exist?('test_opencode_anthropic.json')
File.delete('test_opencode_openai.json') if File.exist?('test_opencode_openai.json')
File.delete('test_opencode_custom.json') if File.exist?('test_opencode_custom.json')
File.delete('test_opencode_no_key.json') if File.exist?('test_opencode_no_key.json')
puts "✓ Test files cleaned up"
