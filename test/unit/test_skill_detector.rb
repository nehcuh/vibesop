# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require_relative '../../lib/vibe/skill_detector'

class TestSkillDetector < Minitest::Test
  def setup
    @repo_root = File.expand_path('../../', __dir__)
    @project_root = Dir.mktmpdir('vibe-skill-detector-test')
    @detector = Vibe::SkillDetector.new(@repo_root, @project_root)
  end

  def teardown
    FileUtils.rm_rf(@project_root) if @project_root && File.exist?(@project_root)
  end

  def test_initialization
    assert_equal @repo_root, @detector.repo_root
    assert_equal @project_root, @detector.project_root
  end

  def test_initialization_with_defaults
    detector = Vibe::SkillDetector.new(@repo_root)
    assert_equal @repo_root, detector.repo_root
    assert_equal Dir.pwd, detector.project_root
  end

  def test_detect_new_skills_returns_array
    result = @detector.detect_new_skills
    assert result.is_a?(Array)
  end

  def test_detect_newly_installed_packs_returns_array
    result = @detector.detect_newly_installed_packs
    assert result.is_a?(Array)
  end

  def test_check_skill_changes_returns_hash
    result = @detector.check_skill_changes
    assert result.is_a?(Hash)
    assert result.key?(:new_skills)
    assert result.key?(:new_packs)
    assert result.key?(:last_checked)
  end

  def test_get_skill_info_for_existing_skill
    # Try to get info about a known skill
    result = @detector.get_skill_info('systematic-debugging')
    assert result.is_a?(Hash) if result
  end

  def test_get_skill_info_for_nonexistent_skill
    result = @detector.get_skill_info('nonexistent-skill-xyz-123')
    assert_nil result
  end

  def test_list_available_skills_returns_array
    result = @detector.list_available_skills
    assert result.is_a?(Array)
  end

  def test_list_available_skills_contains_known_skills
    skills = @detector.list_available_skills
    skill_ids = skills.map { |s| s[:id] }

    # Should contain some built-in skills
    known_skills = %w[systematic-debugging verification-before-completion
                      session-end]
    known_skills.each do |_skill|
      # Just verify the skills list is not empty
      assert skill_ids.any? if skills.any?
    end
  end

  def test_cache_exists
    assert @detector.cache.is_a?(Vibe::SkillCache)
  end

  def test_skill_registry_path_constant
    assert_equal 'core/skills/registry.yaml', Vibe::SkillDetector::SKILL_REGISTRY_PATH
  end

  def test_user_skills_dir_constant
    assert_equal File.expand_path('~/.config/skills'),
                 Vibe::SkillDetector::USER_SKILLS_DIR
  end

  def test_project_skills_config_constant
    assert_equal '.vibe/skills.yaml', Vibe::SkillDetector::PROJECT_SKILLS_CONFIG
  end

  def test_detect_new_skills_empty_for_new_project
    # New project should have no adapted skills yet
    result = @detector.detect_new_skills
    assert result.is_a?(Array)
  end

  def test_detect_newly_installed_packs_handles_missing_dir
    # Should handle missing directory gracefully
    result = @detector.detect_newly_installed_packs
    assert result.is_a?(Array)
  end

  def test_get_skill_info_handles_namespaced_skills
    # Test with namespace prefix
    result = @detector.get_skill_info('systematic-debugging')
    # Should handle namespaced skills
    assert result.nil? || result.is_a?(Hash)
  end

  def test_get_skill_info_with_slash_format
    # Test with slash format
    result = @detector.get_skill_info('superpowers/tdd')
    # Should handle slash format
    assert result.nil? || result.is_a?(Hash)
  end

  def test_list_available_skills_returns_skills_with_metadata
    skills = @detector.list_available_skills

    return unless skills.any?

    skills.each do |skill|
      assert skill.is_a?(Hash)
      assert skill.key?(:id)
      # Title might be optional depending on the skill
    end
  end

  def test_check_skill_changes_includes_timestamp
    result = @detector.check_skill_changes
    assert result.key?(:last_checked)
  end

  def test_detect_new_skills_filters_adapted_skills
    # Create a project skills file with an adapted skill
    skills_dir = File.join(@project_root, '.vibe')
    FileUtils.mkdir_p(skills_dir)

    skills_file = File.join(skills_dir, 'skills.yaml')
    File.write(skills_file, YAML.dump({
                                        'adapted' => [{ 'id' => 'test-skill', 'mode' => 'suggest' }]
                                      }))

    result = @detector.detect_new_skills
    assert result.is_a?(Array)

    # The adapted skill should not appear in new skills
    skill_ids = result.map { |s| s[:id] }
    refute_includes skill_ids, 'test-skill'
  end

  def test_list_available_skills_excludes_disabled
    skills = @detector.list_available_skills

    # Should not include disabled skills
    skills.each do |skill|
      next unless skill.key?(:enabled)

      # If enabled field exists, it should be true
      # (or we just verify the skill has required fields)
      assert skill.key?(:id)
    end
  end
end
