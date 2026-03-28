# frozen_string_literal: true

require_relative 'test_helper'
require 'tmpdir'
require 'fileutils'
require_relative '../lib/vibe/session_analyzer'
require_relative '../lib/vibe/skill_generator'

# ────────────────────────────────────────────────────────────
# SessionAnalyzer
# ────────────────────────────────────────────────────────────
class TestSessionAnalyzer < Minitest::Test
  def setup
    @analyzer = Vibe::SessionAnalyzer.new
  end

  def test_load_sessions_returns_empty_for_missing_file
    result = @analyzer.load_sessions('/nonexistent/path/session.md')
    assert_equal [], result
  end

  def test_load_sessions_returns_empty_for_unreadable_file
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'session.md')
      File.write(path, '')
      File.chmod(0o000, path)
      result = @analyzer.load_sessions(path)
      assert_equal [], result
    ensure
      begin
        File.chmod(0o644, path)
      rescue StandardError
        nil
      end
    end
  end

  def test_load_sessions_parses_session_headers
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'session.md')
      File.write(path, <<~MD)
        ### S1 (09:00) Debugging
        Bash: ruby test.rb
        Edit: fixed the bug

        ### S2 (14:30) Feature work
        Write: new_file.rb
      MD
      result = @analyzer.load_sessions(path)
      assert_equal 2, result.size
      assert_equal '09:00', result[0][:time]
      assert_equal '14:30', result[1][:time]
    end
  end

  def test_load_sessions_extracts_tool_calls
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'session.md')
      File.write(path, <<~MD)
        ### S1 (10:00) Test session
        Bash: ruby test.rb
        Edit: fixed something
      MD
      result = @analyzer.load_sessions(path)
      tools = result[0][:tool_calls].map { |tc| tc[:tool] }
      assert_includes tools, 'Bash'
      assert_includes tools, 'Edit'
    end
  end

  def test_analyze_returns_empty_with_no_sessions
    patterns = @analyzer.analyze
    assert_equal [], patterns
  end

  def test_analyze_returns_patterns_when_sessions_present
    Dir.mktmpdir do |dir|
      path = File.join(dir, 'session.md')
      # Build 5 sessions with the same tool sequence to exceed min_occurrences=3
      content = (1..5).map do |i|
        "### S#{i} (0#{i}:00) Session\nBash: cmd\nEdit: file\nBash: verify\n"
      end.join("\n")
      File.write(path, content)
      @analyzer.load_sessions(path)
      patterns = @analyzer.analyze
      assert_kind_of Array, patterns
    end
  end

  def test_summary_with_no_sessions
    summary = @analyzer.summary
    assert_match(/No patterns detected/, summary)
  end

  def test_default_config_keys
    config = @analyzer.config
    assert config.key?(:min_occurrences)
    assert config.key?(:min_success_rate)
    assert config.key?(:pattern_types)
  end
end

# ────────────────────────────────────────────────────────────
# SkillGenerator
# ────────────────────────────────────────────────────────────
class TestSkillGenerator < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @gen = Vibe::SkillGenerator.new(output_dir: @tmpdir)
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  def sample_pattern
    {
      type: :tool_sequence,
      pattern: 'Bash → Edit → Bash',
      occurrences: 5,
      success_rate: 0.9,
      confidence: 0.85,
      sessions: %w[s1 s2 s3]
    }
  end

  def test_generate_creates_skill_file
    result = @gen.generate(sample_pattern)
    assert result[:success], "Expected success but got: #{result.inspect}"
    assert File.exist?(result[:skill_path])
  end

  def test_generate_returns_skill_name_and_path
    result = @gen.generate(sample_pattern)
    refute_nil result[:skill_name]
    refute_nil result[:skill_path]
    assert result[:skill_path].start_with?(@tmpdir)
  end

  def test_generate_skill_file_contains_frontmatter
    result = @gen.generate(sample_pattern)
    content = File.read(result[:skill_path])
    assert_match(/^---/, content)
    assert_match(/name:/, content)
  end

  def test_generate_conflict_returns_error_without_force
    @gen.generate(sample_pattern)
    result2 = @gen.generate(sample_pattern)
    refute result2[:success]
    assert_equal :exists, result2[:error]
    assert_match(/already exists/, result2[:message])
  end

  def test_generate_force_overwrites_existing
    @gen.generate(sample_pattern)
    result2 = @gen.generate(sample_pattern, force: true)
    assert result2[:success]
    assert File.exist?(result2[:skill_path])
  end

  def test_preview_does_not_write_file
    result = @gen.preview(sample_pattern)
    skill_dir = File.join(@tmpdir, result[:skill_name])
    refute Dir.exist?(skill_dir), 'preview should not create directories'
  end

  def test_generate_batch_creates_multiple_skills
    patterns = [
      sample_pattern.merge(pattern: 'Bash → Glob'),
      sample_pattern.merge(pattern: 'Read → Edit → Write')
    ]
    results = @gen.generate_batch(patterns)
    assert_equal 2, results.size
    assert(results.all? { |r| r[:success] })
  end
end
