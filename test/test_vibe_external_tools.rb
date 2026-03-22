# frozen_string_literal: true

require_relative "test_helper"
require "fileutils"
require "tmpdir"
require "json"
require_relative "../lib/vibe/external_tools"

class TestVibeExternalTools < Minitest::Test
  include Vibe::ExternalTools

  def setup
    @repo_root = File.expand_path("..", __dir__)
    @test_dir = Dir.mktmpdir("vibe_test")
  end

  def teardown
    FileUtils.rm_rf(@test_dir) if @test_dir && Dir.exist?(@test_dir)
  end

  # --- Integration Config Loading ---

  def test_load_integration_config_superpowers
    config = load_integration_config("superpowers")
    refute_nil config
    assert_equal "superpowers", config["name"]
    assert_equal "skill_pack", config["type"]
  end

  def test_load_integration_config_rtk
    config = load_integration_config("rtk")
    refute_nil config
    assert_equal "rtk", config["name"]
    assert_equal "cli_tool", config["type"]
  end

  def test_load_integration_config_nonexistent
    config = load_integration_config("nonexistent")
    assert_nil config
  end

  def test_list_integrations
    integrations = list_integrations
    assert_includes integrations, "superpowers"
    assert_includes integrations, "rtk"
    refute_includes integrations, "README"
  end

  # --- Detection Methods Exist ---

  def test_detect_superpowers_method_exists
    assert_respond_to self, :detect_superpowers
  end

  def test_detect_rtk_method_exists
    assert_respond_to self, :detect_rtk
  end

  def test_superpowers_location_method_exists
    assert_respond_to self, :superpowers_location
  end

  def test_rtk_version_method_exists
    assert_respond_to self, :rtk_version
  end

  def test_rtk_binary_path_method_exists
    assert_respond_to self, :rtk_binary_path
  end

  def test_rtk_hook_configured_method_exists
    assert_respond_to self, :rtk_hook_configured?
  end

  # --- Verification Methods ---

  def test_verify_superpowers_returns_hash
    result = verify_superpowers
    assert_kind_of Hash, result
    assert_includes result.keys, :installed
  end

  def test_verify_rtk_returns_hash
    result = verify_rtk
    assert_kind_of Hash, result
    assert_includes result.keys, :installed
  end

  def test_integration_status_returns_hash
    status = integration_status
    assert_kind_of Hash, status
    assert_includes status.keys, :superpowers
    assert_includes status.keys, :rtk
  end

  def test_missing_integrations_returns_array
    missing = missing_integrations
    assert_kind_of Array, missing
  end

  def test_all_integrations_installed_returns_boolean
    result = all_integrations_installed?
    assert [true, false].include?(result)
  end

  # --- RTK Hook Configuration Test ---

  def test_rtk_hook_configured_with_test_settings
    settings_path = File.join(@test_dir, "settings.json")
    File.write(settings_path, JSON.generate({
      "hooks" => {
        "bashCommandPrepare" => "rtk rewrite"
      }
    }))

    stub_expand_path = lambda do |path|
      return settings_path if path == "~/.claude/settings.json"
      File.expand_path(path)
    end

    File.stub :expand_path, stub_expand_path do
      assert rtk_hook_configured?
    end
  end

  def test_rtk_hook_not_configured_with_empty_hooks
    settings_path = File.join(@test_dir, "settings.json")
    File.write(settings_path, JSON.generate({ "hooks" => {} }))

    stub_expand_path = lambda do |path|
      return settings_path if path == "~/.claude/settings.json"
      File.expand_path(path)
    end

    File.stub :expand_path, stub_expand_path do
      refute rtk_hook_configured?
    end
  end

  def test_verify_rtk_hook_only_reports_not_installed
    settings_path = File.join(@test_dir, "settings.json")
    File.write(settings_path, JSON.generate({
      "hooks" => {
        "bashCommandPrepare" => "rtk rewrite"
      }
    }))

    stub_expand_path = lambda do |path|
      return settings_path if path == "~/.claude/settings.json"

      path
    end

    self.stub(:system, ->(*_args) { false }) do
      File.stub :expand_path, stub_expand_path do
        assert_equal :hook_configured, detect_rtk

        result = verify_rtk
        refute result[:installed]
        refute result[:ready]
        assert_equal :hook_configured, result[:status]
        assert result[:hook_configured]
        assert_nil result[:binary]
        assert_nil result[:version]
      end
    end
  end

  # --- rtk_hook_configured?: PreToolUse array format ---

  def test_rtk_hook_configured_with_pretooluse_array_format
    settings_path = File.join(@test_dir, "settings.json")
    File.write(settings_path, JSON.generate({
      "hooks" => {
        "PreToolUse" => [
          {
            "matcher" => "Bash",
            "hooks" => [{ "type" => "command", "command" => "rtk proxy -- something" }]
          }
        ]
      }
    }))

    File.stub :expand_path, ->(p, *) { p == "~/.claude/settings.json" ? settings_path : File.expand_path(p) } do
      assert rtk_hook_configured?
    end
  end

  def test_rtk_hook_configured_false_when_pretooluse_matcher_not_bash
    settings_path = File.join(@test_dir, "settings.json")
    File.write(settings_path, JSON.generate({
      "hooks" => {
        "PreToolUse" => [
          {
            "matcher" => "Edit",
            "hooks" => [{ "type" => "command", "command" => "rtk proxy" }]
          }
        ]
      }
    }))

    File.stub :expand_path, ->(p, *) { p == "~/.claude/settings.json" ? settings_path : File.expand_path(p) } do
      refute rtk_hook_configured?
    end
  end

  def test_rtk_hook_configured_false_when_settings_file_missing
    missing_path = File.join(@test_dir, "nonexistent_settings.json")
    File.stub :expand_path, ->(p, *) { p == "~/.claude/settings.json" ? missing_path : File.expand_path(p) } do
      refute rtk_hook_configured?
    end
  end

  def test_rtk_hook_configured_false_on_invalid_json
    settings_path = File.join(@test_dir, "settings.json")
    File.write(settings_path, "this is not : valid { json }")

    File.stub :expand_path, ->(p, *) { p == "~/.claude/settings.json" ? settings_path : File.expand_path(p) } do
      refute rtk_hook_configured?
    end
  end

  # --- superpowers_symlinks_in ---

  def test_superpowers_symlinks_in_returns_empty_for_missing_dir
    result = superpowers_symlinks_in("/nonexistent_skills_dir_xyz", "/any/source")
    assert_equal [], result
  end

  def test_superpowers_symlinks_in_returns_empty_when_no_symlinks
    skills_dir  = File.join(@test_dir, "skills")
    source_dir  = File.join(@test_dir, "source")
    FileUtils.mkdir_p(skills_dir)
    FileUtils.mkdir_p(source_dir)
    File.write(File.join(skills_dir, "regular_file.txt"), "content")

    result = superpowers_symlinks_in(skills_dir, source_dir)
    assert_equal [], result
  end

  def test_superpowers_symlinks_in_returns_matching_symlinks
    skills_dir  = File.join(@test_dir, "skills")
    source_dir  = File.join(@test_dir, "superpowers")
    skill_src   = File.join(source_dir, "my-skill")
    FileUtils.mkdir_p(skills_dir)
    FileUtils.mkdir_p(skill_src)
    File.symlink(skill_src, File.join(skills_dir, "my-skill"))

    result = superpowers_symlinks_in(skills_dir, source_dir)
    assert_includes result, "my-skill"
  end

  def test_superpowers_symlinks_in_excludes_symlinks_pointing_elsewhere
    skills_dir  = File.join(@test_dir, "skills")
    source_dir  = File.join(@test_dir, "superpowers")
    other_dir   = File.join(@test_dir, "other")
    FileUtils.mkdir_p(skills_dir)
    FileUtils.mkdir_p(source_dir)
    FileUtils.mkdir_p(other_dir)
    File.symlink(other_dir, File.join(skills_dir, "unrelated"))

    result = superpowers_symlinks_in(skills_dir, source_dir)
    assert_equal [], result
  end

  # --- integration_status memoization & reset ---

  def test_integration_status_is_memoized
    first  = integration_status
    second = integration_status
    assert_same first, second, "integration_status should return the same cached object"
  end

  def test_reset_integration_status_clears_cache
    first = integration_status
    reset_integration_status!
    second = integration_status
    refute_same first, second, "After reset, integration_status should recompute"
  end

  # --- pending_integrations & all_integrations_ready? ---

  def test_pending_integrations_returns_keys_not_ready
    fake_status = {
      superpowers: { installed: true,  ready: false },
      rtk:         { installed: true,  ready: true  },
      gstack:      { installed: false, ready: false }
    }
    self.stub(:integration_status, fake_status) do
      pending = pending_integrations
      assert_includes pending, :superpowers
      assert_includes pending, :gstack
      refute_includes pending, :rtk
    end
  end

  def test_all_integrations_ready_false_when_any_not_ready
    fake_status = {
      superpowers: { installed: true, ready: false },
      rtk:         { installed: true, ready: true  }
    }
    self.stub(:integration_status, fake_status) do
      refute all_integrations_ready?
    end
  end

  def test_all_integrations_ready_true_when_all_ready
    fake_status = {
      superpowers: { installed: true, ready: true },
      rtk:         { installed: true, ready: true }
    }
    self.stub(:integration_status, fake_status) do
      assert all_integrations_ready?
    end
  end

  # --- verify_rtk with non-claude-code platform ---

  def test_verify_rtk_non_claude_code_platform_does_not_require_hook
    # For non-claude-code platforms, hook is irrelevant; ready depends only on binary
    self.stub(:detect_rtk, :not_installed) do
      self.stub(:rtk_hook_configured?, false) do
        result = verify_rtk('opencode')
        refute result[:installed]
        refute result[:ready]
      end
    end
  end

  # --- load_integration_config rescue path ---

  def test_load_integration_config_returns_nil_on_bad_yaml
    bad_yaml_dir = File.join(@test_dir, "core", "integrations")
    FileUtils.mkdir_p(bad_yaml_dir)
    File.write(File.join(bad_yaml_dir, "broken.yaml"), ":\nbad: : yaml")

    # Temporarily point @repo_root to our test dir
    original = @repo_root
    @repo_root = @test_dir
    result = load_integration_config("broken")
    @repo_root = original

    assert_nil result
  end

  # --- list_integrations when dir missing ---

  def test_list_integrations_returns_empty_when_dir_missing
    original = @repo_root
    @repo_root = @test_dir  # no core/integrations subdirectory
    result = list_integrations
    @repo_root = original
    assert_equal [], result
  end
end
