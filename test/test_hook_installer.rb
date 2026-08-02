# frozen_string_literal: true

require "minitest/autorun"
require "fileutils"
require "tmpdir"
require "json"
require_relative "../lib/vibe/hook_installer"

class TestHookInstaller < Minitest::Test
  include Vibe::HookInstaller

  def setup
    @repo_root = File.expand_path("../..", __FILE__)
    @test_dir = Dir.mktmpdir("vibe-hook-test")
    @destination_root = File.join(@test_dir, ".claude")
    FileUtils.mkdir_p(@destination_root)
  end

  def teardown
    FileUtils.rm_rf(@test_dir) if @test_dir && Dir.exist?(@test_dir)
  end

  def test_install_pre_session_end_hook
    result = install_pre_session_end_hook(destination_root: @destination_root)

    assert result, "Hook installation should succeed"

    hook_path = File.join(@destination_root, "hooks", "pre-session-end.sh")
    assert File.exist?(hook_path), "Hook script should be copied"
    assert File.executable?(hook_path), "Hook script should be executable"
  end

  def test_hook_configured_in_settings
    install_pre_session_end_hook(destination_root: @destination_root)

    settings_file = File.join(@destination_root, "settings.json")
    assert File.exist?(settings_file), "settings.json should be created"

    settings = JSON.parse(File.read(settings_file))
    assert settings["hooks"], "hooks section should exist"
    assert settings["hooks"]["Stop"], "Stop hook should be configured"

    matcher_group = settings["hooks"]["Stop"].first
    assert matcher_group["hooks"], "hooks array should exist in matcher group"

    hook_config = matcher_group["hooks"].first
    assert_equal "command", hook_config["type"]
    assert_includes hook_config["command"], "pre-session-end.sh"
  end

  def test_verify_pre_session_end_hook
    install_pre_session_end_hook(destination_root: @destination_root)

    status = verify_pre_session_end_hook(destination_root: @destination_root)

    assert status[:installed], "Hook should be installed"
    assert status[:executable], "Hook should be executable"
    assert status[:configured], "Hook should be configured"
    assert status[:ready], "Hook should be ready"
  end

  def test_hook_not_installed
    status = verify_pre_session_end_hook(destination_root: @destination_root)

    refute status[:installed], "Hook should not be installed"
    refute status[:ready], "Hook should not be ready"
  end

  def test_install_hook_twice_idempotent
    install_pre_session_end_hook(destination_root: @destination_root)
    result = install_pre_session_end_hook(destination_root: @destination_root)

    assert result, "Second installation should succeed (idempotent)"

    settings_file = File.join(@destination_root, "settings.json")
    settings = JSON.parse(File.read(settings_file))

    # Should not duplicate hook entries
    assert_equal 1, settings["hooks"]["Stop"].length
  end

  def test_install_with_existing_settings
    # Create existing settings.json with other hooks
    settings_file = File.join(@destination_root, "settings.json")
    existing_settings = {
      "hooks" => {
        "PreToolUse" => [
          {
            "matcher" => "Bash",
            "hooks" => [
              {
                "type" => "command",
                "command" => "/some/other/hook.sh"
              }
            ]
          }
        ]
      }
    }
    File.write(settings_file, JSON.pretty_generate(existing_settings))

    install_pre_session_end_hook(destination_root: @destination_root)

    settings = JSON.parse(File.read(settings_file))

    # Should preserve existing hooks
    assert settings["hooks"]["PreToolUse"], "Existing hooks should be preserved"
    assert settings["hooks"]["Stop"], "New hook should be added"
  end
end
