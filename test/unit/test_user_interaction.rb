# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../lib/vibe/user_interaction'

class UserInteractionTestHost
  include Vibe::UserInteraction
end

class TestUserInteraction < Minitest::Test
  def setup
    @host = UserInteractionTestHost.new
  end

  def test_module_exists
    assert Vibe.const_defined?(:UserInteraction)
  end

  def test_module_is_a_module
    assert Vibe::UserInteraction.is_a?(Module)
  end

  def test_non_interactive_hint_constant
    assert Vibe::UserInteraction.const_defined?(:NON_INTERACTIVE_HINT)
    hint = Vibe::UserInteraction::NON_INTERACTIVE_HINT
    assert_match(%r{bin/vibe init}, hint)
    assert_match(/interactive terminal/, hint)
  end

  def test_ensure_interactive_setup_available_returns_when_tty
    skip 'Requires TTY environment' unless $stdin.respond_to?(:tty?) && $stdin.tty?

    # Should not raise when in TTY
    result = @host.ensure_interactive_setup_available!
    assert_nil result
  end

  def test_ensure_interactive_setup_available_raises_with_context_when_not_tty
    if $stdin.respond_to?(:tty?) && $stdin.tty?
      skip 'Requires non-TTY environment for proper testing'
    end

    error = assert_raises(Vibe::ValidationError) do
      @host.ensure_interactive_setup_available!('test prompt')
    end

    assert_match(/interactive terminal/, error.message)
    assert_match(/test prompt/, error.message)
  end

  def test_ensure_interactive_setup_available_raises_without_context_when_not_tty
    if $stdin.respond_to?(:tty?) && $stdin.tty?
      skip 'Requires non-TTY environment for proper testing'
    end

    error = assert_raises(Vibe::ValidationError) do
      @host.ensure_interactive_setup_available!
    end

    assert_match(/interactive terminal/, error.message)
  end

  def test_open_url_returns_nil_on_unknown_platform
    # Mock unknown platform
    original_host_os = RbConfig::CONFIG['host_os']

    begin
      RbConfig::CONFIG.replace('host_os' => 'unknown-platform')

      # Should print message and return nil
      result = @host.open_url('http://example.com')
      assert_nil result
    ensure
      RbConfig::CONFIG.replace('host_os' => original_host_os)
    end
  end

  def test_open_url_accepts_url_parameter
    # Test that method accepts string parameter without actually opening URL
    # We stub the system call to avoid opening browser during tests
    original_method = @host.method(:system)

    # Track if system was called with correct arguments
    system_called = false
    url_arg = nil

    @host.define_singleton_method(:system) do |*args|
      system_called = true
      url_arg = args.last if args.length.positive?
      true # Return success without actually calling system
    end

    begin
      @host.open_url('http://example.com')
      assert system_called, 'open_url should call system command'
      assert_equal 'http://example.com', url_arg, 'URL should be passed to system'
    ensure
      # Restore original method
      @host.define_singleton_method(:system, original_method)
    end
  end

  def test_module_methods_exist
    # Check that key methods are defined
    instance_methods = Vibe::UserInteraction.instance_methods(false)

    %i[open_url ask_yes_no ask_choice
       ensure_interactive_setup_available!].each do |method|
      assert instance_methods.include?(method), "Module should have #{method} method"
    end
  end
end
