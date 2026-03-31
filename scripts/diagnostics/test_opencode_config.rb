#!/usr/bin/env ruby
# frozen_string_literal: literal

require 'json'
require_relative '../../lib/vibe/llm_provider/factory'

# OpenCode 配置诊断脚本
#
# 用途：测试各种 OpenCode 配置格式的加载
# 安全：使用 ensure 块确保环境变量恢复和临时文件清理

class OpenCodeConfigDiagnostics
  attr_reader :test_files, :old_env_vars

  def initialize
    @test_files = []
    @old_env_vars = {}
  end

  def run
    puts '=== OpenCode 配置诊断 ==='
    puts

    test_anthropic_with_key
    test_openai_with_key
    test_openai_custom_endpoint
    test_fallback_to_env
    test_llm_config_separation

    puts
    puts '=== 所有测试完成 ==='
  end

  private

  def backup_env(key)
    @old_env_vars[key] = ENV[key]
  end

  def restore_env
    @old_env_vars.each do |key, value|
      if value.nil?
        ENV.delete(key)
      else
        ENV[key] = value
      end
    end
  end

  def create_test_config(name, config)
    filename = "#{name}.json"
    File.write(filename, JSON.pretty_generate(config))
    @test_files << filename
    filename
  end

  def cleanup
    # 清理测试文件
    @test_files.each do |file|
      File.delete(file) if File.exist?(file)
    end

    # 恢复环境变量
    restore_env
  end

  def test_anthropic_with_key
    puts '--- Test 1: Anthropic with API key in config ---'

    config = {
      '$schema' => 'https://opencode.ai/config.json',
      'instructions' => ['AGENTS.md'],
      'models' => {
        'fast' => {
          'provider' => 'anthropic',
          'model' => 'claude-haiku-4-20250514',
          'api_key' => 'sk-ant-test-key-DUMMY',
          'temperature' => 0.3
        }
      }
    }

    filename = create_test_config('test_anthropic', config)

    begin
      provider = Vibe::LLMProvider::Factory.create_from_opencode_config(filename)
      puts "✓ Provider: #{provider.class}"
      puts "✓ Name: #{provider.provider_name}"
      puts "✓ Configured: #{provider.configured?}"
      puts "✓ Base URL: #{provider.base_url}"
    rescue => e
      puts "✗ Error: #{e.message}"
    end
    puts
  end

  def test_openai_with_key
    puts '--- Test 2: OpenAI with API key in config ---'

    config = {
      '$schema' => 'https://opencode.ai/config.json',
      'instructions' => ['AGENTS.md'],
      'models' => {
        'fast' => {
          'provider' => 'openai',
          'model' => 'gpt-4o-mini',
          'api_key' => 'sk-proj-test-key-DUMMY',
          'temperature' => 0.3
        }
      }
    }

    filename = create_test_config('test_openai', config)

    begin
      provider = Vibe::LLMProvider::Factory.create_from_opencode_config(filename)
      puts "✓ Provider: #{provider.class}"
      puts "✓ Name: #{provider.provider_name}"
      puts "✓ Configured: #{provider.configured?}"
    rescue => e
      puts "✗ Error: #{e.message}"
    end
    puts
  end

  def test_openai_custom_endpoint
    puts '--- Test 3: OpenAI with custom endpoint ---'

    config = {
      '$schema' => 'https://opencode.ai/config.json',
      'instructions' => ['AGENTS.md'],
      'models' => {
        'fast' => {
          'provider' => 'openai',
          'model' => 'custom-model',
          'api_key' => 'test-key-DUMMY',
          'base_url' => 'https://custom-endpoint.example.com/v1',
          'temperature' => 0.3
        }
      }
    }

    filename = create_test_config('test_custom', config)

    begin
      provider = Vibe::LLMProvider::Factory.create_from_opencode_config(filename)
      puts "✓ Provider: #{provider.class}"
      puts "✓ Base URL: #{provider.base_url}"
    rescue => e
      puts "✗ Error: #{e.message}"
    end
    puts
  end

  def test_fallback_to_env
    puts '--- Test 4: Fallback to environment variable ---'

    # 备份并设置环境变量
    backup_env('ANTHROPIC_API_KEY')
    ENV['ANTHROPIC_API_KEY'] = 'sk-ant-test-env-key-DUMMY'

    config = {
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

    filename = create_test_config('test_no_key', config)

    begin
      provider = Vibe::LLMProvider::Factory.create_from_opencode_config(filename)
      puts "✓ Using env API key: #{provider.api_key&.start_with?('sk-ant-test-env')}"
    rescue => e
      puts "✗ Error: #{e.message}"
    ensure
      # 立即恢复环境变量
      restore_env
    end
    puts
  end

  def test_llm_config_separation
    puts '--- Test 5: .vibe/llm-config.json separation ---'

    config = {
      'models' => {
        'fast' => {
          'provider' => 'openai',
          'model' => 'gpt-4o-mini',
          'base_url' => 'https://open.bigmodel.cn/api/paas/v4',
          'api_key' => 'test-key-DUMMY',
          'temperature' => 0.3
        }
      }
    }

    # 创建 .vibe 目录
    FileUtils.mkdir_p('.vibe')
    filename = '.vibe/llm-config-test.json'
    File.write(filename, JSON.pretty_generate(config))
    @test_files << filename

    puts "✓ Created .vibe/llm-config-test.json"
    puts "✓ 模拟 .vibe/llm-config.json 的分离配置"
    puts
  end
end

# 主程序 - 使用 ensure 确保清理
diagnostics = OpenCodeConfigDiagnostics.new

begin
  diagnostics.run
ensure
  diagnostics.cleanup
  puts '✓ 清理完成'
end
