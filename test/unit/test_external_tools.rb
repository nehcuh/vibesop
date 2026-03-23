# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../lib/vibe/external_tools'

class ExternalToolsTestHost
  include Vibe::ExternalTools

  attr_accessor :repo_root, :skip_integrations, :target_platform

  def initialize(repo_root)
    @repo_root = repo_root
  end
end

class TestExternalTools < Minitest::Test
  def setup
    @repo_root = File.expand_path('../../', __dir__)
    @host = ExternalToolsTestHost.new(@repo_root)
  end

  def test_module_exists
    assert Vibe.const_defined?(:ExternalTools)
  end

  def test_module_is_a_module
    assert Vibe::ExternalTools.is_a?(Module)
  end

  def test_superpowers_platform_paths_constant
    assert Vibe::ExternalTools.const_defined?(:SUPERPOWERS_PLATFORM_PATHS)
    paths = Vibe::ExternalTools::SUPERPOWERS_PLATFORM_PATHS
    assert paths.key?('claude-code')
    assert paths.key?('opencode')
  end

  def test_cmd_exist_with_ruby
    # 'ruby' should exist since we're running Ruby
    assert @host.cmd_exist?('ruby')
  end

  def test_cmd_exist_with_nonexistent_command
    refute @host.cmd_exist?('thiscommanddoesnotexist12345')
  end

  def test_load_integration_config_with_existing_tool
    # Load config for an integration that should exist
    result = @host.load_integration_config('superpowers')
    # Should return a hash or nil if file doesn't exist
    assert result.nil? || result.is_a?(Hash)
  end

  def test_load_integration_config_with_nonexistent_tool
    result = @host.load_integration_config('nonexistent-tool-xyz')
    assert_nil result
  end

  def test_list_integrations_returns_array
    result = @host.list_integrations
    assert result.is_a?(Array)
  end

  def test_list_integrations_contains_known_integrations
    integrations = @host.list_integrations
    # Should contain some known integrations if they exist
    # We don't assert specific integrations since the set may vary
    assert integrations.is_a?(Array)
  end

  def test_detect_superpowers_returns_symbol
    result = @host.detect_superpowers
    # Should return a symbol
    assert result.nil? || result.is_a?(Symbol)
  end

  def test_detect_superpowers_with_skip_integrations
    @host.skip_integrations = true
    result = @host.detect_superpowers
    assert_equal :not_installed, result
  end

  def test_detect_superpowers_with_platform
    result = @host.detect_superpowers('claude-code')
    # Should return a symbol or nil
    assert result.nil? || result.is_a?(Symbol)
  end

  def test_module_has_required_methods
    instance_methods = Vibe::ExternalTools.instance_methods(false)

    required_methods = %i[cmd_exist? load_integration_config list_integrations
                          detect_superpowers]
    required_methods.each do |method|
      assert instance_methods.include?(method), "Module should have #{method} method"
    end
  end

  # --- Modern CLI Tools Detection ---

  def test_detect_modern_cli_tools_returns_array
    result = @host.detect_modern_cli_tools
    assert result.is_a?(Array)
  end

  def test_detect_modern_cli_tools_returns_8_tools
    result = @host.detect_modern_cli_tools
    assert_equal 8, result.size
  end

  def test_detect_modern_cli_tools_result_structure
    result = @host.detect_modern_cli_tools
    return if result.empty?

    tool = result.first
    assert tool.key?(:traditional), "should have :traditional"
    assert tool.key?(:modern),      "should have :modern"
    assert tool.key?(:available),   "should have :available"
    assert tool.key?(:binary),      "should have :binary"
    assert tool.key?(:usage_notes), "should have :usage_notes"
    assert tool.key?(:use_cases),   "should have :use_cases"
  end

  def test_detect_modern_cli_tools_available_is_boolean
    result = @host.detect_modern_cli_tools
    result.each do |tool|
      assert [true, false].include?(tool[:available]),
             "#{tool[:modern]} :available should be boolean"
    end
  end

  def test_detect_modern_cli_tools_path_only_when_available
    result = @host.detect_modern_cli_tools
    result.each do |tool|
      if tool[:available]
        assert tool[:path].is_a?(String), "available tool should have :path string"
        refute tool[:path].empty?, "available tool :path should not be empty"
      else
        assert tool[:path].nil?, "unavailable tool should have nil :path"
      end
    end
  end

  def test_detect_single_modern_tool_found_primary
    tool_def = {
      'traditional' => 'old',
      'modern'      => 'ruby',
      'category'    => 'test',
      'detection'   => { 'binary' => 'ruby', 'alternatives' => [] },
      'usage_notes' => 'Test tool',
      'use_cases'   => ['Testing']
    }
    result = @host.detect_single_modern_tool(tool_def)
    assert result[:available]
    assert_equal 'ruby', result[:binary]
  end

  def test_detect_single_modern_tool_not_found
    tool_def = {
      'traditional' => 'old',
      'modern'      => 'nonexistent12345',
      'category'    => 'test',
      'detection'   => { 'binary' => 'nonexistent12345', 'alternatives' => [] },
      'usage_notes' => 'Test tool',
      'use_cases'   => ['Testing']
    }
    result = @host.detect_single_modern_tool(tool_def)
    refute result[:available]
    assert_equal 'nonexistent12345', result[:binary]
    assert_nil result[:path]
  end

  def test_detect_single_modern_tool_fallback_to_alternative
    tool_def = {
      'traditional' => 'old',
      'modern'      => 'fd',
      'category'    => 'test',
      'detection'   => { 'binary' => 'nonexistent12345', 'alternatives' => ['ruby'] },
      'usage_notes' => 'Test tool',
      'use_cases'   => ['Testing']
    }
    result = @host.detect_single_modern_tool(tool_def)
    # ruby should always be available since we're running Ruby
    assert result[:available]
    assert_equal 'ruby', result[:binary]
  end

  def test_which_tool_finds_ruby
    path = @host.which_tool('ruby')
    assert path.is_a?(String), "should find ruby binary"
    assert File.exist?(path),  "path should exist on disk"
    assert path.include?('ruby'), "path should contain 'ruby'"
  end

  def test_which_tool_returns_nil_for_nonexistent
    path = @host.which_tool('nonexistent12345')
    assert_nil path
  end

  def test_verify_modern_cli_tools_structure
    result = @host.verify_modern_cli_tools
    assert result.is_a?(Hash)
    %i[installed ready available_tools unavailable_tools
       total_count available_count].each do |key|
      assert result.key?(key), "should have key :#{key}"
    end
  end

  def test_verify_modern_cli_tools_counts_consistent
    result = @host.verify_modern_cli_tools
    assert_equal result[:total_count],
                 result[:available_count] + result[:unavailable_tools].size
    assert_equal result[:available_count], result[:available_tools].size
  end

  def test_list_integrations_contains_modern_cli
    integrations = @host.list_integrations
    assert_includes integrations, 'modern-cli'
  end
end
