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
    # Verify that all required dependencies are available
    assert Vibe.const_defined?(:PlatformUtils)
    assert Vibe.const_defined?(:UserInteraction)
    assert Vibe.const_defined?(:HookInstaller)
  end

  def test_module_has_core_methods
    # Check that the module has core methods
    instance_methods = Vibe::PlatformInstaller.instance_methods(false)

    # Should have methods related to platform operations
    core_methods = %i[install_global_config build_and_deploy_target]
    core_methods.each do |method|
      assert instance_methods.include?(method), "Module should have #{method} method"
    end
  end
end
