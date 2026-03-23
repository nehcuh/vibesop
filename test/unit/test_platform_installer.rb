# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../lib/vibe/platform_installer'

class TestPlatformInstaller < Minitest::Test
  def test_module_exists
    assert Vibe.const_defined?(:PlatformInstaller)
  end

  def test_module_is_a_module
    assert Vibe::PlatformInstaller.is_a?(Module)
  end

  def test_module_includes_platform_utils
    assert Vibe::PlatformInstaller.include?(Vibe::PlatformUtils)
  end

  def test_module_includes_user_interaction
    assert Vibe::PlatformInstaller.include?(Vibe::UserInteraction)
  end

  def test_module_includes_hook_installer
    assert Vibe::PlatformInstaller.include?(Vibe::HookInstaller)
  end

  def test_module_has_install_global_config
    assert Vibe::PlatformInstaller.instance_methods(false).include?(:install_global_config)
  end

  def test_module_has_build_and_deploy_target
    assert Vibe::PlatformInstaller.instance_methods(false).include?(:build_and_deploy_target)
  end

  def test_module_dependencies_are_available
    assert Vibe.const_defined?(:PlatformUtils)
    assert Vibe.const_defined?(:UserInteraction)
    assert Vibe.const_defined?(:HookInstaller)
  end

  def test_module_has_core_methods
    instance_methods = Vibe::PlatformInstaller.instance_methods(false)

    core_methods = %i[install_global_config build_and_deploy_target]
    core_methods.each do |method|
      assert instance_methods.include?(method), "Module should have #{method} method"
    end
  end

  # --- Modern CLI Tools Integration ---

  def test_module_includes_external_tools
    assert Vibe::PlatformInstaller.include?(Vibe::ExternalTools)
  end

  def test_module_has_detect_and_enable_modern_cli_tools
    instance_methods = Vibe::PlatformInstaller.instance_methods(false)
    assert instance_methods.include?(:detect_and_enable_modern_cli_tools)
  end

  def test_module_has_enable_modern_cli_tools_for_all
    instance_methods = Vibe::PlatformInstaller.instance_methods(false)
    assert instance_methods.include?(:enable_modern_cli_tools_for_all)
  end

  def test_module_has_disable_modern_cli_tools_for_all
    instance_methods = Vibe::PlatformInstaller.instance_methods(false)
    assert instance_methods.include?(:disable_modern_cli_tools_for_all)
  end

  def test_module_has_refresh_modern_cli_tools_docs
    instance_methods = Vibe::PlatformInstaller.instance_methods(false)
    assert instance_methods.include?(:refresh_modern_cli_tools_docs)
  end

  def test_module_has_show_modern_cli_tools_status
    instance_methods = Vibe::PlatformInstaller.instance_methods(false)
    assert instance_methods.include?(:show_modern_cli_tools_status)
  end
end
