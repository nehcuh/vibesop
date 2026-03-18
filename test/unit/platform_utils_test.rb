# frozen_string_literal: true

require "test_helper"
require "vibe/platform_utils"

class PlatformUtilsTest < Minitest::Test
  include Vibe::PlatformUtils

  def test_detect_os_returns_symbol
    os = detect_os
    assert_includes [:windows, :macos, :linux, :unknown], os
  end

  def test_windows_predicate
    result = windows?
    assert [true, false].include?(result)
  end

  def test_default_global_destination_windows
    # Mock Windows environment
    original_config = RbConfig::CONFIG["host_os"]

    # Test Windows path
    with_mocked_os("mingw") do
      with_env("USERPROFILE" => "C:\\Users\\TestUser") do
        path = default_global_destination("claude-code")
        assert_match(/TestUser/, path)
        assert_match(/\.claude/, path)
      end
    end
  end

  def test_default_global_destination_unix
    # Test Unix path (current system)
    unless windows?
      path = default_global_destination("claude-code")
      assert_match(/\.claude/, path)
      refute_match(/USERPROFILE/, path)
    end
  end

  def test_normalize_target_with_aliases
    assert_equal "claude-code", normalize_target("claude")
    assert_equal "claude-code", normalize_target("claude-code")
    assert_equal "claude-code", normalize_target("claude_code")
    assert_equal "opencode", normalize_target("opencode")
  end

  def test_platform_label
    assert_equal "Claude Code", platform_label("claude-code")
    assert_equal "OpenCode", platform_label("opencode")
  end

  private

  def with_mocked_os(os_string)
    original = RbConfig::CONFIG["host_os"]
    RbConfig::CONFIG["host_os"] = os_string
    yield
  ensure
    RbConfig::CONFIG["host_os"] = original
  end

  def with_env(env_vars)
    original_env = {}
    env_vars.each do |key, value|
      original_env[key] = ENV[key]
      ENV[key] = value
    end
    yield
  ensure
    original_env.each do |key, value|
      ENV[key] = value
    end
  end
end
