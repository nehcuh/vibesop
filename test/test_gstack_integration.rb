# frozen_string_literal: true

require_relative "test_helper"
require "fileutils"
require "yaml"
require "tmpdir"
require_relative "../lib/vibe/external_tools"
require_relative "../lib/vibe/skill_detector"

class TestGstackIntegration < Minitest::Test
  def setup
    @repo_root = File.expand_path("..", __dir__)
  end

  # --- gstack.yaml validity ---

  def test_gstack_yaml_loads_without_error
    config = YAML.safe_load(
      File.read(File.join(@repo_root, "core/integrations/gstack.yaml")),
      aliases: true
    )
    assert_equal "gstack", config["name"]
    assert_equal "skill_pack", config["type"]
    assert_equal "gstack", config["namespace"]
  end

  def test_gstack_yaml_has_required_fields
    config = YAML.safe_load(
      File.read(File.join(@repo_root, "core/integrations/gstack.yaml")),
      aliases: true
    )

    assert config["source"], "Should have source URL"
    assert config["description"], "Should have description"
    assert config["detection"], "Should have detection config"
    assert config["skills"], "Should have skills list"
    assert config["installation_methods"], "Should have installation methods"
  end

  def test_gstack_yaml_skills_have_required_fields
    config = YAML.safe_load(
      File.read(File.join(@repo_root, "core/integrations/gstack.yaml")),
      aliases: true
    )

    config["skills"].each do |skill|
      assert skill["id"], "Skill missing id: #{skill.inspect}"
      assert skill["registry_id"], "Skill missing registry_id: #{skill["id"]}"
      assert skill["intent"], "Skill missing intent: #{skill["id"]}"
      assert skill["trigger_context"], "Skill missing trigger_context: #{skill["id"]}"
      assert skill["registry_id"].start_with?("gstack/"),
             "registry_id should be namespaced: #{skill["registry_id"]}"
    end
  end

  def test_gstack_yaml_has_all_expected_skills
    config = YAML.safe_load(
      File.read(File.join(@repo_root, "core/integrations/gstack.yaml")),
      aliases: true
    )

    expected = %w[
      office-hours plan-ceo-review plan-eng-review plan-design-review
      design-consultation review design-review codex investigate
      qa qa-only browse setup-browser-cookies ship document-release
      retro careful freeze guard unfreeze gstack-upgrade
    ]

    actual_ids = config["skills"].map { |s| s["id"] }
    expected.each do |id|
      assert_includes actual_ids, id, "Missing skill: #{id}"
    end
  end

  # --- Registry entries ---

  def test_registry_has_gstack_namespace
    registry = YAML.safe_load(
      File.read(File.join(@repo_root, "core/skills/registry.yaml")),
      aliases: true
    )

    assert registry["namespaces"]["gstack"], "Registry should have gstack namespace"
    assert_equal "external_skill_pack", registry["namespaces"]["gstack"]["owner"]
  end

  def test_registry_gstack_in_merge_precedence
    registry = YAML.safe_load(
      File.read(File.join(@repo_root, "core/skills/registry.yaml")),
      aliases: true
    )

    precedence = registry["merge_policy"]["precedence"]
    assert_includes precedence, "gstack"

    # gstack should be after builtin and superpowers, before project
    gstack_idx = precedence.index("gstack")
    assert gstack_idx > precedence.index("builtin")
    assert gstack_idx > precedence.index("superpowers")
    assert gstack_idx < precedence.index("project")
  end

  def test_registry_gstack_skills_have_valid_structure
    registry = YAML.safe_load(
      File.read(File.join(@repo_root, "core/skills/registry.yaml")),
      aliases: true
    )

    gstack_skills = registry["skills"].select { |s| s["namespace"] == "gstack" }
    assert gstack_skills.length > 0, "Should have gstack skills in registry"

    gstack_skills.each do |skill|
      assert skill["id"].start_with?("gstack/"), "ID should be namespaced: #{skill["id"]}"
      assert skill["intent"], "Missing intent: #{skill["id"]}"
      assert %w[suggest manual mandatory].include?(skill["trigger_mode"]),
             "Invalid trigger_mode for #{skill["id"]}: #{skill["trigger_mode"]}"
      assert_equal "external", skill["entrypoint"], "Entrypoint should be external: #{skill["id"]}"
      assert_equal "gstack_installed", skill["conditional"], "Should be conditional: #{skill["id"]}"
    end
  end

  def test_registry_gstack_skills_match_integration_yaml
    registry = YAML.safe_load(
      File.read(File.join(@repo_root, "core/skills/registry.yaml")),
      aliases: true
    )
    integration = YAML.safe_load(
      File.read(File.join(@repo_root, "core/integrations/gstack.yaml")),
      aliases: true
    )

    registry_ids = registry["skills"]
      .select { |s| s["namespace"] == "gstack" }
      .map { |s| s["id"] }
      .sort

    integration_ids = integration["skills"]
      .map { |s| s["registry_id"] }
      .reject { |id| id == "gstack/upgrade" } # upgrade mapped from gstack-upgrade
      .sort

    # Every integration skill should have a registry entry
    integration_ids.each do |id|
      assert_includes registry_ids, id,
        "Integration skill #{id} missing from registry"
    end
  end

  # --- Skill-triggers.md ---

  def test_skill_triggers_has_gstack_section
    triggers = File.read(File.join(@repo_root, "rules/skill-triggers.md"))

    assert triggers.include?("## gstack Skill Pack Integration"),
           "skill-triggers.md should have gstack section"
    assert triggers.include?("gstack/office-hours"),
           "Should list gstack/office-hours"
    assert triggers.include?("gstack/review"),
           "Should list gstack/review"
    assert triggers.include?("gstack/qa"),
           "Should list gstack/qa"
    assert triggers.include?("gstack/ship"),
           "Should list gstack/ship"
  end

  def test_skill_triggers_documents_builtin_overlap
    triggers = File.read(File.join(@repo_root, "rules/skill-triggers.md"))

    assert triggers.include?("Overlap with Builtin Skills"),
           "Should document overlap with builtin skills"
    assert triggers.include?("systematic-debugging"),
           "Should mention systematic-debugging overlap"
  end
end

class TestGstackDetection < Minitest::Test
  include Vibe::ExternalTools

  def setup
    @repo_root = File.expand_path("..", __dir__)
    @tmp_dir = Dir.mktmpdir("gstack-detect-test")
    @skip_integrations = false
  end

  def teardown
    FileUtils.rm_rf(@tmp_dir)
  end

  def test_detect_gstack_not_installed
    # Skip if gstack is actually installed on this system
    if gstack_location
      skip "gstack is installed at #{gstack_location} — skipping negative test"
    end

    # With no gstack directory, should return :not_installed
    assert_equal :not_installed, detect_gstack
  end

  def test_detect_gstack_skip_integrations
    @skip_integrations = true
    assert_equal :not_installed, detect_gstack
  end

  def test_verify_gstack_not_installed
    # Skip if gstack is actually installed on this system
    if gstack_location
      skip "gstack is installed at #{gstack_location} — skipping negative test"
    end

    result = verify_gstack
    assert_equal false, result[:installed]
    assert_equal false, result[:ready]
  end

  def test_gstack_detection_paths_defined
    assert Vibe::ExternalTools::GSTACK_DETECTION_PATHS.length > 0
    assert Vibe::ExternalTools::GSTACK_MARKER_FILES.length > 0
  end

  def test_gstack_markers_check
    # Create a fake gstack directory with markers
    fake_gstack = File.join(@tmp_dir, "gstack")
    FileUtils.mkdir_p(fake_gstack)
    Vibe::ExternalTools::GSTACK_MARKER_FILES.each do |f|
      File.write(File.join(fake_gstack, f), "test")
    end

    assert gstack_markers_present?(fake_gstack)
  end

  def test_gstack_markers_incomplete
    # Missing markers should fail
    fake_gstack = File.join(@tmp_dir, "gstack-incomplete")
    FileUtils.mkdir_p(fake_gstack)
    File.write(File.join(fake_gstack, "SKILL.md"), "test")
    # Missing VERSION and setup

    refute gstack_markers_present?(fake_gstack)
  end

  def test_gstack_skills_count_zero_when_not_installed
    # Skip if gstack is actually installed on this system
    if gstack_location
      skip "gstack is installed at #{gstack_location} — skipping negative test"
    end

    assert_equal 0, gstack_skills_count
  end

  def test_gstack_version_nil_when_not_installed
    # Skip if gstack is actually installed on this system
    if gstack_location
      skip "gstack is installed at #{gstack_location} — skipping negative test"
    end

    assert_nil gstack_version
  end
end
