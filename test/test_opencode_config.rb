#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require_relative '../lib/vibe/llm_provider/factory'

puts '=== Testing OpenCode config detection ==='
config_file = 'opencode.json'
if File.exist?(config_file)
  config = JSON.parse(File.read(config_file))
  puts "Config: #{config.inspect}"
  models_config = config['models'] || {}
  puts "Models config: #{models_config.inspect}"
  model_config = models_config['fast']
  puts "Fast model config: #{model_config.inspect}"
  if model_config
    puts "Provider: #{model_config['provider']}"
    puts "Model: #{model_config['model']}"
  end
else
  puts 'opencode.json not found'
end

puts "\n=== Testing provider creation ==="
begin
  provider = Vibe::LLMProvider::Factory.create_from_opencode_config
  puts "Provider created: #{provider.class}"
  puts "Provider name: #{provider.provider_name}"
  puts "Provider configured: #{provider.configured?}"
rescue => e
  puts "Error: #{e.message}"
  puts e.backtrace.first(5)
end
