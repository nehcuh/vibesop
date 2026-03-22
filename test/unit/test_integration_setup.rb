# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../lib/vibe/integration_setup'

class TestIntegrationSetup < Minitest::Test
  class TestHost
    include Vibe::IntegrationSetup

    attr_accessor :repo_root, :target_platform

    def initialize(repo_root)
      @repo_root = repo_root
      @target_platform = 'claude-code'
    end
  end

  def setup
    @repo_root = File.expand_path('../../', __dir__)
    @host = TestHost.new(@repo_root)
  end

  def test_module_exists
    assert Vibe.const_defined?(:IntegrationSetup)
  end

  def test_module_can_be_included
    assert_includes TestHost.ancestors.map(&:to_s), 'Vibe::IntegrationSetup'
  end

  def test_host_has_repo_root
    assert_equal @repo_root, @host.repo_root
    assert_equal 'claude-code', @host.target_platform
  end

  def test_setup_integrations_method_exists
    assert_respond_to @host, :setup_integrations
  end

  def test_setup_integration_method_exists
    assert_respond_to @host, :setup_integration
  end

  def test_module_includes_required_modules
    # Check that the module includes the required dependencies
    assert Vibe::IntegrationSetup.include?(Vibe::PlatformUtils)
  end
end
