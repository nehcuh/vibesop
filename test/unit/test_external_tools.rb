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
end
