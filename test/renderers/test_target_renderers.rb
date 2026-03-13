# frozen_string_literal: true

require_relative "../test_helper"
require "yaml"
require "vibe/utils"
require "vibe/overlay_support"
require "vibe/doc_rendering"
require "vibe/native_configs"
require "vibe/path_safety"
require "vibe/external_tools"
require "vibe/platform_utils"
require "vibe/target_renderers"

# Test class that includes all required modules
class TargetRenderersTester
  include Vibe::Utils
  include Vibe::OverlaySupport
  include Vibe::DocRendering
  include Vibe::NativeConfigs
  include Vibe::PathSafety
  include Vibe::ExternalTools
  include Vibe::PlatformUtils
  include Vibe::TargetRenderers

  attr_accessor :repo_root, :policies_doc, :tiers_doc, :providers, :skip_integrations

  def initialize(repo_root)
    @repo_root = repo_root
    @yaml_cache = {}
    @skip_integrations = true
    # Load required docs
    @policies_doc = YAML.safe_load(File.read(File.join(repo_root, "core/policies/behaviors.yaml")), aliases: true)
    @tiers_doc = YAML.safe_load(File.read(File.join(repo_root, "core/models/tiers.yaml")), aliases: true)
    providers_path = File.join(repo_root, "core/models/providers.yaml")
    @providers = File.exist?(providers_path) ? YAML.safe_load(File.read(providers_path), aliases: true) : {}
  end

  # Override doc loaders to load from files
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

  private

  def load_doc(relative_path)
    path = File.join(@repo_root, relative_path)
    File.exist?(path) ? YAML.safe_load(File.read(path), aliases: true) : nil
  end
end

class TestTargetRenderers < Minitest::Test
  def setup
    @repo_root = File.expand_path("../../..", __FILE__)
    @renderer = TargetRenderersTester.new(@repo_root)
    @build_root = Dir.mktmpdir("vibe-test")

    # Minimal manifest for testing - includes all required fields
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
          "target_support" => "native-skill",
          "intent" => "Find root cause before fixes"
        }
      ],
      "tiers" => {
        "critical_reasoner" => {
          "description" => "Highest-assurance reasoning",
          "default_role" => "maker_or_final_decider",
          "route_when" => ["Critical business logic"],
          "avoid_when" => ["Docs-only edits"]
        }
      },
      "routing_defaults" => {
        "direct_handle_max_changed_lines" => 50
      },
      "security" => {
        "severity_levels" => {
          "P0" => {"label" => "block", "runtime_action" => "deny_and_stop"},
          "P1" => {"label" => "high_risk_review", "runtime_action" => "require_context_review"},
          "P2" => {"label" => "warning", "runtime_action" => "warn_log_continue"}
        },
        "signal_categories" => [
          {"id" => "network_egress", "base_severity" => "P1", "indicators" => ["http_url"]},
          {"id" => "destructive_operation", "base_severity" => "P0", "indicators" => ["rm -rf"]}
        ],
        "adjudication_factors" => ["asset_sensitivity", "execution_capability", "scope_of_change"],
        "target_actions" => {
          "P0" => "Prefer hooks or permissions deny",
          "P1" => "Prefer hook-mediated confirmation",
          "P2" => "Warn in output and continue"
        }
      },
      "overlay" => nil
    }
  end

  def teardown
    FileUtils.rm_rf(@build_root) if @build_root && File.exist?(@build_root)
  end

  # === write_target_docs tests ===

  def test_write_target_docs_creates_expected_files
    doc_types = %i[behavior routing safety]
    output_dir = File.join(@build_root, "docs")
    FileUtils.mkdir_p(output_dir)

    @renderer.write_target_docs(output_dir, @base_manifest, doc_types)

    assert File.exist?(File.join(output_dir, "behavior-policies.md"))
    assert File.exist?(File.join(output_dir, "routing.md"))
    assert File.exist?(File.join(output_dir, "safety.md"))
  end

  def test_write_target_docs_unknown_type_raises_error
    output_dir = File.join(@build_root, "docs")
    FileUtils.mkdir_p(output_dir)

    assert_raises(Vibe::Error) do
      @renderer.write_target_docs(output_dir, @base_manifest, [:unknown_type])
    end
  end
end
