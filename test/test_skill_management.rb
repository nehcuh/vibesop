# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/vibe/skill_detector"
require_relative "../lib/vibe/skill_adapter"
require_relative "../lib/vibe/skill_manager"

class TestSkillManager < Minitest::Test
  def setup
    @repo_root = Dir.pwd
    @test_dir = Dir.mktmpdir("skill-manager-test")
    @manager = Vibe::SkillManager.new(@repo_root, @test_dir)
  end

  def teardown
    FileUtils.rm_rf(@test_dir)
  end

  def test_list_skills_returns_structure
    skills = @manager.list_skills

    assert skills.key?(:available)
    assert skills.key?(:adapted)
    assert skills.key?(:skipped)
    assert skills.key?(:not_adapted)

    assert_kind_of Array, skills[:available]
    assert_kind_of Array, skills[:adapted]
    assert_kind_of Array, skills[:skipped]
    assert_kind_of Array, skills[:not_adapted]
  end

  def test_detect_new_skills_finds_unadapted
    # Initially all skills are new
    new_skills = @manager.detector.detect_new_skills

    # Should find skills from registry
    assert new_skills.length > 0

    # Should include builtin skills
    builtin_skills = new_skills.select { |s| s[:namespace] == 'builtin' }
    assert builtin_skills.length > 0
  end

  def test_adapt_skill_creates_config
    skill_id = 'systematic-debugging'

    # Adapt skill
    assert @manager.adapt_skill(skill_id, :suggest)

    # Check config file created
    config_path = File.join(@test_dir, ".vibe/skills.yaml")
    assert File.exist?(config_path)

    # Check config content
    config = YAML.safe_load(File.read(config_path))
    assert config['adapted_skills'].key?(skill_id)
    assert_equal 'suggest', config['adapted_skills'][skill_id]['mode']
  end

  def test_skip_skill_records_skip
    skill_id = 'superpowers/optimize'

    # Skip skill
    assert @manager.skip_skill(skill_id)

    # Check config
    config_path = File.join(@test_dir, ".vibe/skills.yaml")
    config = YAML.safe_load(File.read(config_path))

    skipped = config['skipped_skills'].find { |s| s['id'] == skill_id }
    assert skipped
    assert_equal 'user_choice', skipped['reason']
  end

  def test_skill_info_returns_metadata
    skill_id = 'systematic-debugging'
    info = @manager.skill_info(skill_id)

    assert_equal skill_id, info[:id]
    assert_equal 'builtin', info[:namespace]
    assert info[:intent]
    assert info[:adaptation_status]
  end

  def test_update_check_timestamp
    @manager.update_check_timestamp

    config_path = File.join(@test_dir, ".vibe/skills.yaml")
    config = YAML.safe_load(File.read(config_path))

    assert config['last_checked']
    assert_kind_of String, config['last_checked']
  end

  def test_update_check_timestamp_creates_directory_if_missing
    FileUtils.rm_rf(File.join(@test_dir, ".vibe"))
    @manager.update_check_timestamp
    config_path = File.join(@test_dir, ".vibe/skills.yaml")
    assert File.exist?(config_path)
  end

  def test_update_check_timestamp_preserves_existing_fields
    config_path = File.join(@test_dir, ".vibe/skills.yaml")
    FileUtils.mkdir_p(File.dirname(config_path))
    File.write(config_path, YAML.dump('schema_version' => 1, 'custom_key' => 'preserved'))
    @manager.update_check_timestamp
    config = YAML.safe_load(File.read(config_path))
    assert_equal 1, config['schema_version']
    assert_equal 'preserved', config['custom_key']
    assert config['last_checked']
  end

  def test_update_check_timestamp_no_tmp_file_left_behind
    @manager.update_check_timestamp
    config_path = File.join(@test_dir, ".vibe/skills.yaml")
    tmp_files = Dir.glob("#{config_path}.tmp.*")
    assert_empty tmp_files, "Temporary file left behind after atomic write"
  end

  def test_update_check_timestamp_last_checked_is_iso8601
    @manager.update_check_timestamp
    config_path = File.join(@test_dir, ".vibe/skills.yaml")
    config = YAML.safe_load(File.read(config_path))
    assert_match(/\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}/, config['last_checked'])
  end

  def test_skill_info_returns_nil_for_nonexistent_skill
    result = @manager.skill_info("nonexistent-skill-xyz")
    assert_nil result
  end

  def test_list_skills_adapted_skipped_are_empty_for_fresh_project
    skills = @manager.list_skills
    assert_empty skills[:adapted]
    assert_empty skills[:skipped]
  end

  def test_list_skills_tolerates_non_hash_adapted_skill_entry
    # Write a skills.yaml where one adapted_skills entry is a plain string, not a Hash.
    # Before the fix, this raised TypeError from **info splat.
    config_path = File.join(@test_dir, ".vibe/skills.yaml")
    FileUtils.mkdir_p(File.dirname(config_path))
    malformed = {
      'schema_version' => 1,
      'adapted_skills' => {
        'systematic-debugging' => 'just-a-string'
      },
      'skipped_skills' => []
    }
    File.write(config_path, YAML.dump(malformed))

    # Should not raise — returns adapted item with only :id key
    skills = @manager.list_skills
    assert_equal 1, skills[:adapted].size
    assert_equal 'systematic-debugging', skills[:adapted].first[:id]
  end

  def test_list_skills_tolerates_nil_adapted_skill_entry
    config_path = File.join(@test_dir, ".vibe/skills.yaml")
    FileUtils.mkdir_p(File.dirname(config_path))
    malformed = {
      'schema_version' => 1,
      'adapted_skills' => { 'session-end' => nil },
      'skipped_skills' => []
    }
    File.write(config_path, YAML.dump(malformed))

    skills = @manager.list_skills
    assert_equal 1, skills[:adapted].size
    assert_equal 'session-end', skills[:adapted].first[:id]
  end
end

class TestSkillDetector < Minitest::Test
  def setup
    @repo_root = Dir.pwd
    @test_dir = Dir.mktmpdir("skill-detector-test")
    @detector = Vibe::SkillDetector.new(@repo_root, @test_dir)
  end

  def teardown
    FileUtils.rm_rf(@test_dir)
  end

  def test_load_registry_skills
    skills = @detector.send(:load_registry_skills)

    assert skills.length > 0

    # Check skill structure
    skill = skills.first
    assert skill[:id]
    assert skill[:namespace]
    assert skill[:intent]
  end

  def test_detect_new_skills_empty_project
    new_skills = @detector.detect_new_skills

    # All registry skills should be new
    registry = @detector.send(:load_registry_skills)
    assert_equal registry.length, new_skills.length
  end

  def test_get_skill_info_found
    info = @detector.get_skill_info('systematic-debugging')

    assert info
    assert_equal 'systematic-debugging', info[:id]
    assert_equal 'builtin', info[:namespace]
  end

  def test_get_skill_info_not_found
    info = @detector.get_skill_info('nonexistent-skill')

    assert_nil info
  end
end

class TestSkillAdapter < Minitest::Test
  def setup
    @repo_root = Dir.pwd
    @test_dir = Dir.mktmpdir("skill-adapter-test")
    @adapter = Vibe::SkillAdapter.new(@repo_root, @test_dir)
  end

  def teardown
    FileUtils.rm_rf(@test_dir)
  end

  def test_adapt_skill_suggest_mode
    skill_id = 'systematic-debugging'

    assert @adapter.adapt_skill(skill_id, :suggest)

    config = @adapter.send(:load_project_config)
    assert config['adapted_skills'].key?(skill_id)
    assert_equal 'suggest', config['adapted_skills'][skill_id]['mode']
  end

  def test_adapt_skill_mandatory_mode
    skill_id = 'verification-before-completion'

    assert @adapter.adapt_skill(skill_id, :mandatory)

    config = @adapter.send(:load_project_config)
    assert_equal 'mandatory', config['adapted_skills'][skill_id]['mode']
  end

  def test_adapt_skill_skip_mode
    skill_id = 'superpowers/optimize'

    assert @adapter.adapt_skill(skill_id, :skip)

    config = @adapter.send(:load_project_config)
    skipped = config['skipped_skills'].find { |s| s['id'] == skill_id }
    assert skipped
  end

  def test_adapt_all_as_batch
    skills = [
      { id: 'systematic-debugging' },
      { id: 'verification-before-completion' },
      { id: 'session-end' }
    ]

    results = @adapter.adapt_all_as(skills, :suggest)

    assert_equal 3, results[:adapted].length
    assert_equal 0, results[:skipped].length

    config = @adapter.send(:load_project_config)
    assert_equal 3, config['adapted_skills'].keys.length
  end

  def test_recommend_mode_based_on_priority
    p0_skill = { priority: 'P0' }
    p1_skill = { priority: 'P1' }

    assert_equal :mandatory, @adapter.recommend_mode(p0_skill)
    assert_equal :suggest, @adapter.recommend_mode(p1_skill)
  end

  def test_project_config_created_with_defaults
    config = @adapter.send(:load_project_config)

    assert_equal 1, config['schema_version']
    assert_kind_of Hash, config['adapted_skills']
    assert_kind_of Array, config['skipped_skills']
    assert_kind_of Hash, config['installed_packs']
  end

  # --- adapt_skill: nonexistent skill returns false ---

  def test_adapt_skill_returns_false_for_nonexistent_skill
    result = @adapter.adapt_skill('no-such-skill-xyz', :suggest)
    assert_equal false, result
  end

  # --- adapt_skill: invalid mode returns false ---

  def test_adapt_skill_returns_false_for_invalid_mode
    result = @adapter.adapt_skill('systematic-debugging', :invalid_mode)
    assert_equal false, result
  end

  # --- adapt_skill: skip → suggest removes from skipped list ---

  def test_adapt_skill_suggest_removes_from_skipped_list
    skill_id = 'systematic-debugging'
    @adapter.adapt_skill(skill_id, :skip)
    config = @adapter.send(:load_project_config)
    assert config['skipped_skills'].any? { |s| s['id'] == skill_id }

    @adapter.adapt_skill(skill_id, :suggest)
    config = @adapter.send(:load_project_config)
    refute config['skipped_skills'].any? { |s| s['id'] == skill_id }
    assert config['adapted_skills'].key?(skill_id)
  end

  # --- adapt_skill: suggest → skip removes from adapted hash ---

  def test_adapt_skill_skip_removes_from_adapted_hash
    skill_id = 'systematic-debugging'
    @adapter.adapt_skill(skill_id, :suggest)
    assert @adapter.send(:load_project_config)['adapted_skills'].key?(skill_id)

    @adapter.adapt_skill(skill_id, :skip)
    config = @adapter.send(:load_project_config)
    refute config['adapted_skills'].key?(skill_id)
    assert config['skipped_skills'].any? { |s| s['id'] == skill_id }
  end

  # --- adapt_interactively: empty skills returns early ---

  def test_adapt_interactively_returns_empty_results_for_empty_skills
    result = @adapter.adapt_interactively([])
    assert_equal [], result[:adapted]
    assert_equal [], result[:skipped]
  end

  # --- recommend_mode: P2 and unknown priority → :suggest ---

  def test_recommend_mode_p2_returns_suggest
    assert_equal :suggest, @adapter.recommend_mode({ priority: 'P2' })
  end

  def test_recommend_mode_unknown_priority_returns_suggest
    assert_equal :suggest, @adapter.recommend_mode({ priority: 'P9' })
  end

  def test_recommend_mode_nil_priority_returns_suggest
    assert_equal :suggest, @adapter.recommend_mode({ priority: nil })
  end
end
