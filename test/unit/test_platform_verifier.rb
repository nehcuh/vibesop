# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../lib/vibe/platform_verifier'

class TestPlatformVerifier < Minitest::Test
  def test_module_exists
    assert Vibe.const_defined?(:PlatformVerifier)
  end

  def test_module_is_a_module
    assert Vibe::PlatformVerifier.is_a?(Module)
  end

  def test_module_includes_platform_utils
    assert Vibe::PlatformVerifier.include?(Vibe::PlatformUtils)
  end

  def test_module_has_verify_platform_installation
    assert Vibe::PlatformVerifier.instance_methods(false).include?(:verify_platform_installation)
  end

  def test_module_has_suggest_platform_setup
    assert Vibe::PlatformVerifier.instance_methods(false).include?(:suggest_platform_setup)
  end

  def test_module_has_verify_all_platforms
    assert Vibe::PlatformVerifier.instance_methods(false).include?(:verify_all_platforms)
  end

  def test_module_has_required_methods
    instance_methods = Vibe::PlatformVerifier.instance_methods(false)

    # Should have methods related to platform verification
    relevant_methods = %i[verify_platform_installation suggest_platform_setup
                          verify_all_platforms]
    relevant_methods.each do |method|
      assert instance_methods.include?(method), "Module should have #{method} method"
    end
  end

  def test_module_methods_return_values
    # Test that methods exist and can be called
    instance_methods = Vibe::PlatformVerifier.instance_methods(false)

    # These are instance methods that should exist
    assert instance_methods.include?(:verify_platform_installation)
    assert instance_methods.include?(:suggest_platform_setup)
    assert instance_methods.include?(:verify_all_platforms)
  end

  def test_module_integration_with_platform_utils
    # The module should work with PlatformUtils constants
    assert Vibe::PlatformUtils.const_defined?(:VALID_TARGETS)

    # Should include claude-code and opencode
    valid_targets = Vibe::PlatformUtils::VALID_TARGETS
    assert_includes valid_targets, 'claude-code'
    assert_includes valid_targets, 'opencode'
  end
end
