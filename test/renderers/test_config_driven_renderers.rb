# frozen_string_literal: true

require_relative "../test_helper"
require "yaml"
require "vibe/utils"
require "vibe/overlay_support"
require "vibe/doc_rendering"
require "vibe/native_configs"
require "vibe/path_safety"
require "vibe/external_tools"
require "vibe/target_renderers"
require "vibe/config_driven_renderers"
require "vibe/platform_utils"

# Test class that includes all required modules
class ConfigDrivenRenderersTester
  include Vibe::Utils
  include Vibe::OverlaySupport
  include Vibe::DocRendering
  include Vibe::NativeConfigs
  include Vibe::PathSafety
  include Vibe::ExternalTools
  include Vibe::TargetRenderers
  include Vibe::ConfigDrivenRenderers
  include Vibe::PlatformUtils

  attr_accessor :repo_root, :policies_doc, :tiers_doc, :providers, :skip_integrations

  def initialize(repo_root)
    @repo_root = repo_root
    @yaml_cache = {}
    @skip_integrations = true
    @policies_doc = YAML.safe_load(File.read(File.join(repo_root, "core/policies/behaviors.yaml")), aliases: true)
    @tiers_doc = YAML.safe_load(File.read(File.join(repo_root, "core/models/tiers.yaml")), aliases: true)
    providers_path = File.join(repo_root, "core/models/providers.yaml")
    @providers = File.exist?(providers_path) ? YAML.safe_load(File.read(providers_path), aliases: true) : {}
  end

  def task_routing_doc
    @task_routing_doc ||= load_doc("core/policies/task-routing.yaml")
  end

  def test_standards_doc
    @test_standards_doc ||= load_doc("core/policies/test-standards.yaml")
  end

  def security_doc
    @security_doc ||= load_doc("core/security/policy.yaml")
  end

  def skills_doc
    @skills_doc ||= load_doc("core/skills/registry.yaml")
  end

  def superpowers_doc
    @superpowers_doc ||= load_doc("core/integrations/superpowers.yaml")
  end

  private

  def load_doc(relative_path)
    path = File.join(@repo_root, relative_path)
    File.exist?(path) ? YAML.safe_load(File.read(path), aliases: true) : nil
  end
end

class TestConfigDrivenRenderers < Minitest::Test
  def setup
    @repo_root = File.expand_path("../../..", __FILE__)
    @renderer = ConfigDrivenRenderersTester.new(@repo_root)
    @build_root = Dir.mktmpdir("vibe-test")

    @base_manifest = {
      "target" => "claude-code",
      "profile" => "claude-code-default",
      "profile_maturity" => "active",
      "generated_at" => "2026-03-12T00:00:00Z",
      "profile_mapping" => {
        "critical_reasoner" => "claude.opus-class",
        "workhorse_coder" => "claude.sonnet-class"
      },
      "policies" => [
        {
          "id" => "ssot-first",
          "category" => "state_management",
          "enforcement" => "mandatory",
          "target_render_group" => "always_on",
          "summary" => "Keep repository files as SSOT",
          "source_refs" => ["rules/behaviors.md"]
        }
      ],
      "skills" => [
        {
          "id" => "systematic-debugging",
          "namespace" => "builtin",
          "priority" => "P0",
          "trigger_mode" => "mandatory",
          "intent" => "Find root cause"
        }
      ],
      "tiers" => {
        "critical_reasoner" => {
          "description" => "Highest-assurance reasoning",
          "default_role" => "maker",
          "route_when" => ["Critical logic"],
          "avoid_when" => ["Docs-only"]
        }
      },
      "routing_defaults" => { "direct_handle_max_changed_lines" => 50 },
      "security" => {
        "severity_levels" => {
          "P0" => { "label" => "block", "runtime_action" => "deny" },
          "P1" => { "label" => "warning", "runtime_action" => "warn" }
        },
        "signal_categories" => [],
        "adjudication_factors" => [],
        "target_actions" => { "P0" => "Block" }
      },
      "overlay" => nil
    }
  end

  def teardown
    FileUtils.rm_rf(@build_root) if @build_root && File.exist?(@build_root)
  end

  def test_platform_configs_loads_from_yaml
    configs = @renderer.platform_configs

    assert configs.is_a?(Hash), "Should return a Hash"
    assert configs.key?("claude-code"), "Should have claude-code config"
    assert configs.key?("opencode"), "Should have opencode config"
  end

  def test_render_claude_creates_expected_structure
    @renderer.render_claude(@build_root, @base_manifest, project_level: false)

    # Check entrypoint
    assert File.exist?(File.join(@build_root, "CLAUDE.md")), "CLAUDE.md should exist"

    # Check vibe directory
    vibe_dir = File.join(@build_root, ".vibe", "claude-code")
    assert File.directory?(vibe_dir), ".vibe/claude-code/ should exist"

    # Check docs
    assert File.exist?(File.join(vibe_dir, "behavior-policies.md"))
    assert File.exist?(File.join(vibe_dir, "safety.md"))
    assert File.exist?(File.join(vibe_dir, "task-routing.md"))
  end

  def test_render_opencode_creates_expected_structure
    manifest = @base_manifest.dup
    manifest["target"] = "opencode"

    @renderer.render_opencode(@build_root, manifest, project_level: false)

    # Check entrypoint
    assert File.exist?(File.join(@build_root, "AGENTS.md")), "AGENTS.md should exist"

    # Check vibe directory
    vibe_dir = File.join(@build_root, ".vibe", "opencode")
    assert File.directory?(vibe_dir), ".vibe/opencode/ should exist"

    # Check docs (aligned with Claude Code)
    assert File.exist?(File.join(vibe_dir, "behavior-policies.md"))
    assert File.exist?(File.join(vibe_dir, "safety.md"))
    assert File.exist?(File.join(vibe_dir, "task-routing.md")), "Should have task-routing.md (aligned with Claude Code)"
    assert File.exist?(File.join(vibe_dir, "test-standards.md")), "Should have test-standards.md (aligned with Claude Code)"
  end

  def test_render_platform_raises_on_unknown_platform
    assert_raises(ArgumentError) do
      @renderer.render_platform(@build_root, @base_manifest, "unknown-platform")
    end
  end

  def test_render_opencode_project_level_generates_project_template
    manifest = @base_manifest.dup
    manifest["target"] = "opencode"

    @renderer.render_opencode(@build_root, manifest, project_level: true)

    # Check entrypoint
    agents_md = File.read(File.join(@build_root, "AGENTS.md"))

    # Should use project template, not global template
    assert_includes agents_md, "Project OpenCode Configuration"
    assert_includes agents_md, "Global workflow rules are loaded from"
    assert_includes agents_md, "This file adds project-specific context only"

    # Should NOT contain global-only content
    refute_includes agents_md, "Vibe workflow for OpenCode"
    refute_includes agents_md, "Non-negotiable rules"
  end

  def test_render_claude_project_level_generates_project_template
    @renderer.render_claude(@build_root, @base_manifest, project_level: true)

    # Check entrypoint
    claude_md = File.read(File.join(@build_root, "CLAUDE.md"))

    # Should use project template
    assert_includes claude_md, "Project Claude Code Configuration"
    assert_includes claude_md, "Global workflow rules are loaded from"
    assert_includes claude_md, "This file adds project-specific context only"

    # Should NOT contain global-only content
    refute_includes claude_md, "Vibe workflow for Claude Code"
    refute_includes claude_md, "Non-negotiable rules"
  end

  # --- platform_config_dir: else branch ---

  def test_platform_config_dir_else_returns_generic_path
    result = @renderer.send(:platform_config_dir, 'cursor')
    assert_equal '~/.cursor', result
  end

  def test_platform_config_dir_opencode
    result = @renderer.send(:platform_config_dir, 'opencode')
    assert_equal '~/.config/opencode', result
  end

  # --- platform_configs: invalid YAML raises ConfigurationError ---

  def test_platform_configs_raises_when_platforms_key_missing
    # Force re-evaluation by clearing the memoized cache
    @renderer.instance_variable_set(:@platform_configs, nil)
    bad_yaml = YAML.dump("not_a_platforms_key" => {})
    File.stub :read, bad_yaml do
      assert_raises(Vibe::ConfigurationError) { @renderer.platform_configs }
    end
  ensure
    @renderer.instance_variable_set(:@platform_configs, nil)
  end

  # --- generate_native_config: error branches ---

  def test_generate_native_config_raises_when_builder_missing
    config = { 'filename' => 'x.json', 'type' => 'json' }  # no 'builder' key
    assert_raises(ArgumentError) do
      @renderer.send(:generate_native_config, @build_root, @base_manifest, config, 'global')
    end
  end

  def test_generate_native_config_raises_on_unsupported_type
    config = { 'filename' => 'x.xml', 'builder' => 'build_claude_settings', 'type' => 'xml' }
    assert_raises(ArgumentError) do
      @renderer.send(:generate_native_config, @build_root, @base_manifest, config, 'global')
    end
  end
end
