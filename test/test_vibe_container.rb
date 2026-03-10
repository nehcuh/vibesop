# frozen_string_literal: true

require_relative "test_helper"
load File.expand_path("../bin/vibe", __dir__)

class TestVibeContainer < Minitest::Test
  def setup
    @repo_root = File.expand_path("..", __dir__)
    @container = Vibe::Container.new(@repo_root)
  end

  def test_container_provides_utils
    assert_equal Vibe::Utils, @container.utils
  end

  def test_container_provides_yaml_loader
    loader = @container.yaml_loader
    assert loader.respond_to?(:call)
  end

  def test_container_can_register_service
    @container.register(:test_service, "test_value")
    assert_equal "test_value", @container.resolve(:test_service)
  end

  def test_container_raises_error_for_unregistered_service
    assert_raises(Vibe::ConfigurationError) do
      @container.resolve(:nonexistent)
    end
  end

  def test_container_registered_checks_service
    refute @container.registered?(:nonexistent)
    @container.register(:test_service, "test_value")
    assert @container.registered?(:test_service)
  end
end
