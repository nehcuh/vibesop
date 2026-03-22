# frozen_string_literal: true

require "test_helper"
require "vibe/session_analyzer"
require "tmpdir"
require "fileutils"

class TestSessionAnalyzer < Minitest::Test
  def setup
    @analyzer = Vibe::SessionAnalyzer.new
    @tmpdir = Dir.mktmpdir("session-analyzer-test")
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  # --- detect_format ---

  def test_detect_format_v1
    content = "### S1 (14:35) [topic]\nsome content\n"
    assert_equal "v1", @analyzer.send(:detect_format, content)
  end

  def test_detect_format_v2
    content = "## Session 2026-03-22\nsome content\n"
    assert_equal "v2", @analyzer.send(:detect_format, content)
  end

  def test_detect_format_unknown_returns_nil
    content = "# Random header\nno recognizable session format\n"
    assert_nil @analyzer.send(:detect_format, content)
  end

  def test_detect_format_empty_returns_nil
    assert_nil @analyzer.send(:detect_format, "")
  end

  # --- load_sessions ---

  def test_load_sessions_returns_empty_for_missing_file
    result = @analyzer.load_sessions(File.join(@tmpdir, "nonexistent.md"))
    assert_equal [], result
  end

  def test_load_sessions_returns_empty_for_empty_file
    path = File.join(@tmpdir, "session.md")
    File.write(path, "   \n")
    assert_equal [], @analyzer.load_sessions(path)
  end

  def test_load_sessions_warns_and_returns_empty_for_unknown_format
    path = File.join(@tmpdir, "session.md")
    File.write(path, "# Unknown Format\nsome content\n")
    output = capture_io { @analyzer.load_sessions(path) }
    assert_equal [], @analyzer.sessions
    assert_match(/unknown session format/, output[1])
  end

  # --- v1 parsing ---

  def test_load_sessions_v1_parses_sessions
    content = <<~MD
      ### S1 (14:00) [task-a]
      Did some work
      Bash: ls -la
      ### S2 (15:30) [task-b]
      More work
      Edit: some_file.rb
    MD
    path = File.join(@tmpdir, "session.md")
    File.write(path, content)

    sessions = @analyzer.load_sessions(path)
    assert_equal 2, sessions.size
    assert_equal "14:00", sessions[0][:time]
    assert_equal "15:30", sessions[1][:time]
  end

  def test_load_sessions_v1_extracts_tool_calls
    content = "### S1 (10:00) [debug]\nBash: git status\nEdit: foo.rb\n"
    path = File.join(@tmpdir, "session.md")
    File.write(path, content)

    sessions = @analyzer.load_sessions(path)
    assert_equal 2, sessions[0][:tool_calls].size
    assert_equal "Bash", sessions[0][:tool_calls][0][:tool]
    assert_equal "Edit", sessions[0][:tool_calls][1][:tool]
  end

  # --- v2 parsing ---

  def test_load_sessions_v2_parses_sessions
    content = <<~MD
      ## Session 2026-03-20
      Did some work
      Bash: echo hello
      ## Session 2026-03-21
      More work
      Edit: file.rb
    MD
    path = File.join(@tmpdir, "session.md")
    File.write(path, content)

    sessions = @analyzer.load_sessions(path)
    assert_equal 2, sessions.size
    assert_equal "2026-03-20", sessions[0][:time]
    assert_equal "2026-03-21", sessions[1][:time]
  end

  def test_load_sessions_v2_extracts_tool_calls
    content = "## Session 2026-03-22\nBash: ls\nRead: foo.md\n"
    path = File.join(@tmpdir, "session.md")
    File.write(path, content)

    sessions = @analyzer.load_sessions(path)
    assert_equal 2, sessions[0][:tool_calls].size
    assert_equal "Bash", sessions[0][:tool_calls][0][:tool]
    assert_equal "Read", sessions[0][:tool_calls][1][:tool]
  end

  # --- SUPPORTED_FORMATS constant ---

  def test_supported_formats_has_v1_and_v2
    assert Vibe::SessionAnalyzer::SUPPORTED_FORMATS.key?("v1")
    assert Vibe::SessionAnalyzer::SUPPORTED_FORMATS.key?("v2")
  end

  # --- analyze: empty sessions ---

  def test_analyze_returns_empty_when_no_sessions_loaded
    result = @analyzer.analyze
    assert_equal [], result
  end

  # --- summary: no patterns ---

  def test_summary_returns_fixed_string_when_no_patterns
    result = @analyzer.summary
    assert_equal 'No patterns detected', result
  end

  def test_summary_returns_formatted_string_after_patterns_set
    # Manually inject a pattern so summary has something to format
    @analyzer.instance_variable_set(:@patterns, [{
      type: :tool_sequence,
      pattern: 'Bash → Edit',
      occurrences: 3,
      success_rate: 1.0,
      confidence: 0.9
    }])
    result = @analyzer.summary
    refute_equal 'No patterns detected', result
    assert_kind_of String, result
    assert result.length > 0
  end

  # --- extract_tags: language and domain matching ---

  def test_extract_tags_returns_language_tag
    tags = @analyzer.send(:extract_tags, "fixed a ruby bug in the parser")
    assert_includes tags, "ruby"
  end

  def test_extract_tags_returns_domain_tag
    tags = @analyzer.send(:extract_tags, "improved performance of the query")
    assert_includes tags, "performance"
  end

  def test_extract_tags_returns_multiple_tags
    tags = @analyzer.send(:extract_tags, "python debugging session")
    assert_includes tags, "python"
    assert_includes tags, "debugging"
  end

  def test_extract_tags_deduplicates
    # "ruby" appears twice conceptually via case variants
    tags = @analyzer.send(:extract_tags, "ruby Ruby refactoring refactoring")
    assert_equal tags.uniq, tags
  end

  def test_extract_tags_returns_empty_for_unmatched_line
    tags = @analyzer.send(:extract_tags, "did some general work today")
    assert_equal [], tags
  end

  # --- parse_sessions_v1: failure branch (→ Failed) ---

  def test_parse_sessions_v1_records_failed_tool_call
    content = "### S1 (10:00) [debug]\nBash: git status → Failed\n"
    path = File.join(@tmpdir, "session.md")
    File.write(path, content)

    sessions = @analyzer.load_sessions(path)
    call = sessions[0][:tool_calls][0]
    assert_equal "Bash", call[:tool]
    refute call[:success], "Tool call marked with '→ Failed' should have success: false"
  end

  def test_parse_sessions_v1_records_successful_tool_call
    content = "### S1 (10:00) [debug]\nBash: git status\n"
    path = File.join(@tmpdir, "session.md")
    File.write(path, content)

    sessions = @analyzer.load_sessions(path)
    call = sessions[0][:tool_calls][0]
    assert call[:success], "Tool call without '→ Failed' should have success: true"
  end

  # --- calculate_confidence: clamp at 1.0 ---

  def test_calculate_confidence_caps_at_one_for_high_occurrences
    result = @analyzer.send(:calculate_confidence, 20, 1.0)
    assert result <= 1.0, "confidence must not exceed 1.0"
    assert result > 0.5,  "high occurrences + perfect success should give high confidence"
  end

  def test_calculate_confidence_returns_partial_for_few_occurrences
    result = @analyzer.send(:calculate_confidence, 1, 0.5)
    assert result < 1.0
    assert result > 0.0
  end

  # --- detect_tool_sequences: min_sequence_length guard ---

  def test_detect_tool_sequences_skips_sessions_with_too_few_calls
    # inject a session with only 1 tool call (below min_sequence_length of 3)
    @analyzer.instance_variable_set(:@sessions, [{
      id: "s1", time: "10:00", content: "work",
      tool_calls: [{ tool: "Bash", command: "ls", success: true }],
      tags: []
    }])
    patterns = @analyzer.send(:detect_tool_sequences)
    assert_equal [], patterns
  end
end
