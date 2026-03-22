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
end
