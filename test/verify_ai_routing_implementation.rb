#!/usr/bin/env ruby
# frozen_string_literal: true

##
# AI Routing Implementation Verification
#
# Verifies that AI routing components are properly implemented
# without requiring API keys or full environment setup.
#

require 'fileutils'
require 'json'

class ImplementationVerification
  def initialize(project_root: Dir.pwd)
    @project_root = project_root
    @results = {}
  end

  def run_all_checks
    puts 'AI Routing Implementation Verification'
    puts '=' * 60
    puts

    check_file_structure
    check_class_definitions
    check_method_signatures
    check_configuration
    print_summary

    @results
  end

  private

  def check_file_structure
    puts '=== File Structure ==='
    puts

    checks = {
      'AI Triage Layer' => 'lib/vibe/skill_router/ai_triage_layer.rb',
      'LLM Provider Base' => 'lib/vibe/llm_provider/base.rb',
      'Anthropic Provider' => 'lib/vibe/llm_provider/anthropic.rb',
      'OpenAI Provider' => 'lib/vibe/llm_provider/openai.rb',
      'Provider Factory' => 'lib/vibe/llm_provider/factory.rb',
      'Cache Manager' => 'lib/vibe/cache_manager.rb',
      'Skill Router' => 'lib/vibe/skill_router.rb'
    }

    @results[:file_structure] = {}

    checks.each do |name, path|
      full_path = File.join(@project_root, path)
      exists = File.exist?(full_path)
      @results[:file_structure][name] = exists

      status = exists ? '✓' : '✗'
      size = exists ? "(#{File.size(full_path)} bytes)" : ''
      puts "#{status} #{name}: #{path} #{size}"
    end

    puts
  end

  def check_class_definitions
    puts '=== Class Definitions ==='
    puts

    checks = {
      'AITriageLayer' => 'lib/vibe/skill_router/ai_triage_layer.rb',
      'LLMProvider::Base' => 'lib/vibe/llm_provider/base.rb',
      'LLMProvider::AnthropicProvider' => 'lib/vibe/llm_provider/anthropic.rb',
      'LLMProvider::OpenAIProvider' => 'lib/vibe/llm_provider/openai.rb',
      'LLMProvider::Factory' => 'lib/vibe/llm_provider/factory.rb'
    }

    @results[:class_definitions] = {}

    checks.each do |class_name, file|
      full_path = File.join(@project_root, file)
      content = File.read(full_path) rescue ''
      defined = content.include?("class #{class_name}") ||
                content.include?("module #{class_name}") ||
                content.include?("#{class_name.split('::').last} < ")

      @results[:class_definitions][class_name] = defined
      status = defined ? '✓' : '✗'
      puts "#{status} #{class_name} in #{file}"
    end

    puts
  end

  def check_method_signatures
    puts '=== Method Signatures ==='
    puts

    @results[:method_signatures] = {}

    # Check AITriageLayer methods
    ai_layer_file = File.join(@project_root, 'lib/vibe/skill_router/ai_triage_layer.rb')
    ai_layer_content = File.read(ai_layer_file) rescue ''

    methods = {
      'AITriageLayer#route' => 'def route(',
      'AITriageLayer#enabled?' => 'def enabled?',
      'AITriageLayer#cache_hit?' => 'def cache_hit?'
    }

    methods.each do |method, signature|
      found = ai_layer_content.include?(signature)
      @results[:method_signatures][method] = found
      status = found ? '✓' : '✗'
      puts "#{status} #{method}"
    end

    # Check LLMProvider::Base methods
    base_file = File.join(@project_root, 'lib/vibe/llm_provider/base.rb')
    base_content = File.read(base_file) rescue ''

    base_methods = {
      'LLMProvider::Base#call' => 'def call(',
      'LLMProvider::Base#configured?' => 'def configured?',
      'LLMProvider::Base#provider_name' => 'def provider_name',
      'LLMProvider::Base#supported_models' => 'def supported_models'
    }

    base_methods.each do |method, signature|
      found = base_content.include?(signature)
      @results[:method_signatures][method] = found
      status = found ? '✓' : '✗'
      puts "#{status} #{method}"
    end

    puts
  end

  def check_configuration
    puts '=== Configuration ==='
    puts

    @results[:configuration] = {}

    # Check for platform configuration
    config_file = File.join(@project_root, 'config/platforms.yaml')
    config_exists = File.exist?(config_file)
    @results[:configuration]['platforms.yaml'] = config_exists
    status = config_exists ? '✓' : '✗'
    puts "#{status} Platform configuration: config/platforms.yaml"

    if config_exists
      config_content = File.read(config_file)
      has_claude_code = config_content.include?('claude-code')
      has_opencode = config_content.include?('opencode')

      @results[:configuration]['claude-code platform'] = has_claude_code
      @results[:configuration]['opencode platform'] = has_opencode

      puts "  ✓ claude-code platform defined" if has_claude_code
      puts "  ✓ opencode platform defined" if has_opencode
    end

    # Check for environment detection
    ai_layer_file = File.join(@project_root, 'lib/vibe/skill_router/ai_triage_layer.rb')
    ai_layer_content = File.read(ai_layer_file) rescue ''

    has_env_detection = ai_layer_content.include?('running_in_claude_code?')
    has_auto_disable = ai_layer_content.include?('VIBE_AI_TRIAGE_ENABLED')

    @results[:configuration]['environment detection'] = has_env_detection
    @results[:configuration]['auto disable'] = has_auto_disable

    puts "#{has_env_detection ? '✓' : '✗'} Environment detection (Claude Code)"
    puts "#{has_auto_disable ? '✓' : '✗'} Auto-disable with VIBE_AI_TRIAGE_ENABLED"

    puts
  end

  def print_summary
    puts '=== Summary ==='
    puts

    total_checks = 0
    passed_checks = 0

    @results.each do |category, checks|
      checks.each do |name, passed|
        total_checks += 1
        passed_checks += 1 if passed
      end
    end

    pass_rate = (passed_checks.to_f / total_checks * 100).round(2)

    puts "Total Checks: #{total_checks}"
    puts "Passed: #{passed_checks} (#{pass_rate}%)"
    puts

    if pass_rate == 100
      puts '✓ All checks passed! AI routing implementation is complete.'
    elsif pass_rate >= 80
      puts '⚠ Most checks passed. Some components may be missing.'
    else
      puts '✗ Many checks failed. Implementation may be incomplete.'
    end

    puts

    # Save results to JSON
    save_results(passed_checks, total_checks, pass_rate)
  end

  def save_results(passed, total, pass_rate)
    results_json = {
      timestamp: Time.now.strftime('%Y-%m-%dT%H:%M:%S%:z'),
      summary: {
        total: total,
        passed: passed,
        pass_rate: pass_rate
      },
      details: @results,
      environment: {
        ruby_version: RUBY_VERSION,
        os: RbConfig::CONFIG['host_os']
      }
    }

    output_file = File.join(@project_root, 'test/ai_routing_verification_results.json')
    FileUtils.mkdir_p(File.dirname(output_file))
    File.write(output_file, JSON.pretty_generate(results_json))

    puts "Results saved to: #{output_file}"
  end
end

# Run verification if executed directly
if __FILE__ == $PROGRAM_NAME
  verification = ImplementationVerification.new

  begin
    verification.run_all_checks
  rescue StandardError => e
    puts "Error: #{e.message}"
    puts e.backtrace
    exit 1
  end
end
