# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require_relative '../../lib/vibe/cli/skill_craft_commands'
require_relative '../../lib/vibe/errors'

class SkillCraftCommandsTestHost
  include Vibe::SkillCraftCommands
end

class TestSkillCraftCommands < Minitest::Test
  def setup
    @host = SkillCraftCommandsTestHost.new
  end

  def test_module_exists
    assert Vibe.const_defined?(:SkillCraftCommands)
  end

  def test_help_subcommand
    out, = capture_io { @host.run_skill_craft_command(['help']) }
    assert_match(/Usage/, out)
    assert_match(/analyze/, out)
    assert_match(/generate/, out)
  end

  def test_dash_h_shows_usage
    out, = capture_io { @host.run_skill_craft_command(['-h']) }
    assert_match(/Usage/, out)
  end

  def test_analyze_runs
    out, = capture_io { @host.run_skill_craft_command(['analyze']) }
    assert_match(/Analyzing/, out)
  end

  def test_triggers_runs
    out, = capture_io { @host.run_skill_craft_command(['triggers']) }
    # triggers falls through to interactive crafting (no dedicated subcommand)
    assert_match(/Skill Crafting Session|Crafting|pattern|No patterns found/i, out)
  end

  def test_status_runs
    out, = capture_io { @host.run_skill_craft_command(['status']) }
    assert_match(/Skill Craft Status/, out)
    assert_match(/skill-craft analyze/, out)
  end

  def test_generate_no_pattern
    out, = capture_io { @host.run_skill_craft_command(['generate']) }
    assert_match(/No pattern specified/, out)
  end

  def test_generate_no_patterns_found
    out, = capture_io { @host.run_skill_craft_command(['generate', '--pattern', '1']) }
    assert_match(/No patterns found/, out)
  end

  def test_parse_analyze_options_defaults
    opts = @host.send(:parse_analyze_options, [])
    assert_equal 3, opts[:min_occurrences]
    assert_in_delta 0.7, opts[:min_success_rate]
  end

  def test_parse_analyze_options_custom
    opts = @host.send(:parse_analyze_options, ['--min-occurrences=5', '--min-success-rate=0.9'])
    assert_equal 5, opts[:min_occurrences]
    assert_in_delta 0.9, opts[:min_success_rate]
  end

  def test_parse_generate_options_pattern
    opts = @host.send(:parse_generate_options, ['--pattern', '2'])
    assert_equal '2', opts[:pattern]
    refute opts[:force]
  end

  def test_parse_generate_options_force
    opts = @host.send(:parse_generate_options, ['--force', '--pattern', '1'])
    assert opts[:force]
  end

  def test_parse_generate_options_output
    opts = @host.send(:parse_generate_options, ['--output', '/tmp/skills'])
    assert_equal '/tmp/skills', opts[:output]
  end
end
