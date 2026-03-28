# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'yaml'
require_relative '../../lib/vibe/skill_adapter'

# Extended unit tests for SkillAdapter, complementing test_skill_management.rb.
# Uses the real project registry (Dir.pwd) to avoid SkillCache contamination.
class TestSkillAdapterUnit < Minitest::Test
  def setup
    # Use the real repo root so SkillCache stays consistent with test_skill_management.rb
    @repo_root    = Dir.pwd
    @project_root = Dir.mktmpdir('vibe-adapter-project')
    @adapter      = Vibe::SkillAdapter.new(@repo_root, @project_root)

    # Flush cache entries from any previous test run
    Vibe::SkillCache.instance.invalidate_pattern('registry')
    Vibe::SkillCache.instance.invalidate_project_config(@project_root)
  end

  def teardown
    FileUtils.rm_rf(@project_root) if @project_root && File.exist?(@project_root)
    Vibe::SkillCache.instance.invalidate_project_config(@project_root)
  end

  # --- recommend_mode ---

  def test_recommend_mode_p0_is_mandatory
    skill = { id: 'systematic-debugging', priority: 'P0' }
    assert_equal :mandatory, @adapter.recommend_mode(skill)
  end

  def test_recommend_mode_p1_is_suggest
    skill = { id: 'tdd', priority: 'P1' }
    assert_equal :suggest, @adapter.recommend_mode(skill)
  end

  def test_recommend_mode_p2_is_suggest
    skill = { id: 'tdd', priority: 'P2' }
    assert_equal :suggest, @adapter.recommend_mode(skill)
  end

  def test_recommend_mode_unknown_priority_is_suggest
    skill = { id: 'anything', priority: 'P9' }
    assert_equal :suggest, @adapter.recommend_mode(skill)
  end

  # --- adapt_skill: suggest mode ---

  def test_adapt_skill_suggest_creates_config
    result = @adapter.adapt_skill('systematic-debugging', :suggest)
    assert result

    config_path = File.join(@project_root, '.vibe/skills.yaml')
    assert File.exist?(config_path)
    config = YAML.safe_load(File.read(config_path), aliases: true)
    assert_equal 'suggest', config['adapted_skills']['systematic-debugging']['mode']
  end

  def test_adapt_skill_skip_removes_from_adapted
    @adapter.adapt_skill('systematic-debugging', :suggest)
    @adapter.adapt_skill('systematic-debugging', :skip)

    config = YAML.safe_load(
      File.read(File.join(@project_root, '.vibe/skills.yaml')), aliases: true
    )
    assert_nil config['adapted_skills']['systematic-debugging']
    assert(config['skipped_skills'].any? { |s| s['id'] == 'systematic-debugging' })
  end

  def test_adapt_skill_suggest_removes_from_skipped
    @adapter.adapt_skill('systematic-debugging', :skip)
    @adapter.adapt_skill('systematic-debugging', :suggest)

    config = YAML.safe_load(
      File.read(File.join(@project_root, '.vibe/skills.yaml')), aliases: true
    )
    assert_equal 'suggest', config['adapted_skills']['systematic-debugging']['mode']
    refute(config['skipped_skills'].any? { |s| s['id'] == 'systematic-debugging' })
  end

  def test_adapt_skill_no_duplicate_skips
    @adapter.adapt_skill('systematic-debugging', :skip)
    @adapter.adapt_skill('systematic-debugging', :skip)

    config = YAML.safe_load(
      File.read(File.join(@project_root, '.vibe/skills.yaml')), aliases: true
    )
    skip_count = config['skipped_skills'].count { |s| s['id'] == 'systematic-debugging' }
    assert_equal 1, skip_count
  end

  def test_adapt_skill_records_timestamp
    @adapter.adapt_skill('systematic-debugging', :suggest)

    config = YAML.safe_load(
      File.read(File.join(@project_root, '.vibe/skills.yaml')), aliases: true
    )
    adapted_at = config['adapted_skills']['systematic-debugging']['adapted_at']
    assert adapted_at
    assert_match(/\d{4}-\d{2}-\d{2}/, adapted_at)
  end

  def test_adapt_skill_unknown_skill_returns_false
    _, err = capture_io do
      result = @adapter.adapt_skill('nonexistent-xyz-skill', :suggest)
      assert_equal false, result
    end
    assert_match(/Skill not found/, err)
  end

  def test_adapt_skill_invalid_mode_returns_false
    _, err = capture_io do
      result = @adapter.adapt_skill('systematic-debugging', :invalid_mode)
      assert_equal false, result
    end
    assert_match(/Invalid adaptation mode/, err)
  end

  # --- adapt_all_as ---

  def test_adapt_all_as_returns_failed_for_unknown_skill
    skills = [{ id: 'nonexistent-xyz' }, { id: 'systematic-debugging' }]
    result = nil
    capture_io { result = @adapter.adapt_all_as(skills, :suggest) }
    assert_includes result[:failed], 'nonexistent-xyz'
    assert_includes result[:adapted], 'systematic-debugging'
  end

  # --- skip_all ---

  def test_skip_all_returns_skipped_list
    skills = [{ id: 'systematic-debugging' }]
    result = nil
    capture_io { result = @adapter.skip_all(skills) }
    assert_equal ['systematic-debugging'], result[:skipped]
    assert_empty result[:adapted]
  end

  # --- adapt_interactively (empty skills) ---

  def test_adapt_interactively_empty_returns_immediately
    result = @adapter.adapt_interactively([])
    assert_equal({ adapted: [], skipped: [] }, result)
  end

  # --- load_project_config (via adapt_skill) ---

  def test_loads_existing_config_without_overwriting
    config_path = File.join(@project_root, '.vibe/skills.yaml')
    FileUtils.mkdir_p(File.dirname(config_path))
    File.write(config_path, YAML.dump({
                                        'schema_version' => 1,
                                        'adapted_skills' => { 'existing' => { 'mode' => 'suggest' } },
                                        'skipped_skills' => []
                                      }))

    @adapter.adapt_skill('systematic-debugging', :suggest)

    config = YAML.safe_load(File.read(config_path), aliases: true)
    assert config['adapted_skills']['existing']
    assert config['adapted_skills']['systematic-debugging']
  end

  # --- show_adaptation_help (smoke test) ---

  def test_show_adaptation_help_outputs_content
    $stdin = StringIO.new("\n")
    out, = capture_io { @adapter.show_adaptation_help }
    assert_match(/Skill Adaptation Help/, out)
    assert_match(/Suggest Mode/, out)
    assert_match(/Mandatory Mode/, out)
  ensure
    $stdin = STDIN
  end

  # --- adapt_interactively via stubbed $stdin ---

  def test_adapt_interactively_choice_1_suggest_all
    skills = [{ id: 'systematic-debugging' }]
    $stdin = StringIO.new("1\n")
    out, = capture_io { @adapter.adapt_interactively(skills) }
    assert_match(/Adapting all 1 skills as suggest/, out)
  ensure
    $stdin = STDIN
  end

  def test_adapt_interactively_choice_2_mandatory_all
    skills = [{ id: 'systematic-debugging' }]
    $stdin = StringIO.new("2\n")
    out, = capture_io { @adapter.adapt_interactively(skills) }
    assert_match(/Adapting all 1 skills as mandatory/, out)
  ensure
    $stdin = STDIN
  end

  def test_adapt_interactively_choice_4_skip_all
    skills = [{ id: 'systematic-debugging' }]
    $stdin = StringIO.new("4\n")
    result = nil
    capture_io { result = @adapter.adapt_interactively(skills) }
    assert_equal ['systematic-debugging'], result[:skipped]
  ensure
    $stdin = STDIN
  end
end
