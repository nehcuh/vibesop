# frozen_string_literal: true

require_relative '../test_helper'
require_relative '../../lib/vibe/skill_discovery'
require_relative '../../lib/vibe/skill_registration'
require 'tmpdir'
require 'fileutils'

class TestSkillDiscovery < Minitest::Test
  def setup
    @test_dir = Dir.mktmpdir('skill-discovery-test')
    create_test_skills
    # Pass nil for repo_root to auto-detect, @test_dir as project_root
    @discovery = Vibe::SkillDiscovery.new(nil, @test_dir)
  end

  def teardown
    FileUtils.rm_rf(@test_dir) if @test_dir && File.exist?(@test_dir)
  end

  def test_discover_in_directory
    skills_dir = File.join(@test_dir, 'skills')
    skills = @discovery.discover_in_directory(skills_dir)

    assert_equal 2, skills.size
    assert skills.any? { |s| s[:name] == 'my-debug-skill' }
    assert skills.any? { |s| s[:name] == 'custom-review' }
  end

  def test_extract_skill_metadata
    skill_path = File.join(@test_dir, 'skills', 'my-debug-skill')
    @discovery.instance_variable_set(:@found_skills, [])
    skill = @discovery.send(:extract_skill_metadata, skill_path, 'my-debug-skill')

    assert_equal 'my-debug-skill', skill[:name]
    assert_equal 'project', skill[:namespace]
    assert_equal 'My Debug Skill', skill[:display_name]
    assert_equal 'Custom debugging workflow', skill[:description]
    assert_includes skill[:keywords], 'debug'
  end

  def test_registered_check
    # Create routing config with one skill registered
    create_test_routing_config

    assert @discovery.registered?('systematic-debugging')
    refute @discovery.registered?('my-debug-skill')
  end

  def test_unregistered_skills
    create_test_routing_config
    unregistered = @discovery.unregistered_skills

    # Should find skills not in routing
    assert unregistered.any? { |s| s[:name] == 'my-debug-skill' }
    refute unregistered.any? { |s| s[:id] == 'systematic-debugging' }
  end

  def test_security_audit_safe_skill
    skill_path = File.join(@test_dir, 'skills', 'my-debug-skill')
    result = @discovery.security_audit(skill_path)

    assert result[:safe]
    assert_empty result[:red_flags]
    assert_equal :low, result[:risk_level]
  end

  def test_security_audit_with_red_flags
    # Create a skill with dangerous content
    dangerous_skill_dir = File.join(@test_dir, 'skills', 'dangerous-skill')
    FileUtils.mkdir_p(dangerous_skill_dir)
    File.write(File.join(dangerous_skill_dir, 'SKILL.md'), <<~SKILL)
      ---
      name: Dangerous Skill
      description: This skill has dangerous patterns
      ---

      # Dangerous Skill

      This skill uses eval and system commands.

      Run this code: eval(user_input)
      And this: rm -rf /
    SKILL

    result = @discovery.security_audit(dangerous_skill_dir)

    refute result[:safe]
    # Check that eval and rm -rf patterns were detected
    assert result[:red_flags].any? { |f| f.include?('eval') },
           "Expected red_flags to detect eval, got: #{result[:red_flags].inspect}"
    assert result[:red_flags].any? { |f| f.include?('Recursive delete') },
           "Expected red_flags to detect rm -rf, got: #{result[:red_flags].inspect}"
    assert_includes [:high, :critical, :medium], result[:risk_level]
  end

  def test_parse_frontmatter
    content = <<~YAML
      ---
      name: Test Skill
      description: A test skill
      tools:
        - Read
        - Write
      ---

      # Content
    YAML

    metadata = @discovery.send(:parse_frontmatter, content)

    assert_equal 'Test Skill', metadata['name']
    assert_equal 'A test skill', metadata['description']
    assert_equal ['Read', 'Write'], metadata['tools']
  end

  def test_determine_namespace
    assert_equal 'superpowers', @discovery.send(:determine_namespace, '/home/user/.config/skills/superpowers/test')
    assert_equal 'gstack', @discovery.send(:determine_namespace, '/home/user/.config/skills/gstack/test')
    assert_equal 'project', @discovery.send(:determine_namespace, @test_dir)
  end

  private

  def create_test_skills
    skills_dir = File.join(@test_dir, 'skills')
    FileUtils.mkdir_p(skills_dir)

    # Create test skill 1
    skill1_dir = File.join(skills_dir, 'my-debug-skill')
    FileUtils.mkdir_p(skill1_dir)
    File.write(File.join(skill1_dir, 'SKILL.md'), <<~SKILL)
      ---
      name: My Debug Skill
      description: Custom debugging workflow
      intent: Debug application errors with custom approach
      tools:
        - Read
        - Grep
        - Bash
      ---

      # My Debug Skill

      ## When to use

      When you encounter debug errors and need custom handling.

      ## Steps

      1. Read error logs
      2. Grep for patterns
      3. Fix the issue
    SKILL

    # Create test skill 2
    skill2_dir = File.join(skills_dir, 'custom-review')
    FileUtils.mkdir_p(skill2_dir)
    File.write(File.join(skill2_dir, 'SKILL.md'), <<~SKILL)
      ---
      name: Custom Review
      description: Project-specific code review
      intent: Review code with project standards
      ---

      # Custom Review

      Custom code review for this project.
    SKILL
  end

  def create_test_routing_config
    vibe_dir = File.join(@test_dir, '.vibe')
    FileUtils.mkdir_p(vibe_dir)

    routing = {
      'routing_rules' => [
        {
          'scenario' => 'debugging',
          'primary' => {
            'skill' => 'systematic-debugging',
            'source' => 'builtin',
            'reason' => 'Find root cause'
          },
          'alternatives' => []
        }
      ],
      'exclusive_skills' => []
    }

    File.write(File.join(vibe_dir, 'skill-routing.yaml'), YAML.dump(routing))
  end
end

class TestSkillRegistration < Minitest::Test
  def setup
    @test_dir = Dir.mktmpdir('skill-registration-test')
    create_test_project
    @registration = Vibe::SkillRegistration.new(@test_dir)
  end

  def teardown
    FileUtils.rm_rf(@test_dir) if @test_dir && File.exist?(@test_dir)
  end

  def test_ensure_project_routing_exists
    FileUtils.rm_rf(File.join(@test_dir, '.vibe'))
    refute File.exist?(File.join(@test_dir, '.vibe', 'skill-routing.yaml'))

    @registration.send(:ensure_project_routing_exists)

    assert File.exist?(File.join(@test_dir, '.vibe', 'skill-routing.yaml'))
    config = YAML.safe_load(File.read(File.join(@test_dir, '.vibe', 'skill-routing.yaml')))
    assert config['project_skills']
    assert config['exclusive_skills']
  end

  def test_register_skill_as_exclusive
    skill = {
      id: 'my-new-skill',
      name: 'my-new-skill',
      namespace: 'project',
      display_name: 'My New Skill',
      intent: 'Test skill registration',
      keywords: ['test', 'registration'],
      path: '/fake/path'
    }

    result = @registration.register_skill(skill)

    assert result[:success]
    assert_equal 'my-new-skill', result[:skill]

    # Verify it was added to routing
    routing = YAML.safe_load(File.read(File.join(@test_dir, '.vibe', 'skill-routing.yaml')))
    assert routing['exclusive_skills'].any? { |e| e['skill'] == 'my-new-skill' }
    assert routing['project_skills'].any? { |p| p['id'] == 'my-new-skill' }
  end

  def test_register_skill_to_scenario
    skill = {
      id: 'advanced-debug',
      name: 'advanced-debug',
      namespace: 'project',
      display_name: 'Advanced Debug',
      intent: 'Advanced debugging with custom tools',
      keywords: ['debug', 'advanced'],
      priority: 'P1',
      path: '/fake/path'
    }

    result = @registration.register_skill(skill, scenario: 'debugging', as_alternative: true)

    assert result[:success]

    routing = YAML.safe_load(File.read(File.join(@test_dir, '.vibe', 'skill-routing.yaml')))
    debug_rule = routing['routing_rules'].find { |r| r['scenario'] == 'debugging' }
    assert debug_rule['alternatives'].any? { |a| a['skill'] == 'advanced-debug' }
  end

  def test_backup_before_modification
    routing_path = File.join(@test_dir, '.vibe', 'skill-routing.yaml')
    original_content = File.read(routing_path)

    skill = { id: 'test-skill', name: 'test-skill', namespace: 'project', intent: 'Test', keywords: [], path: '/fake' }
    @registration.register_skill(skill)

    backup_dir = File.join(@test_dir, '.vibe', 'backups')
    backups = Dir.glob(File.join(backup_dir, 'skill-routing_*.yaml'))

    assert backups.any?
  end

  def test_status
    status = @registration.status

    assert status[:project_file_exists]
    assert status[:total_discovered] >= 0
    assert status[:unregistered] >= 0
  end

  private

  def create_test_project
    vibe_dir = File.join(@test_dir, '.vibe')
    FileUtils.mkdir_p(vibe_dir)

    routing = {
      'schema_version' => 1,
      'routing_rules' => [
        {
          'scenario' => 'debugging',
          'primary' => {
            'skill' => 'systematic-debugging',
            'source' => 'builtin',
            'reason' => 'Find root cause'
          },
          'alternatives' => []
        }
      ],
      'exclusive_skills' => [],
      'project_skills' => []
    }

    File.write(File.join(vibe_dir, 'skill-routing.yaml'), YAML.dump(routing))
  end
end
