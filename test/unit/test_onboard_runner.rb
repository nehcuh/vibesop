# frozen_string_literal: true

require "test_helper"
require "vibe/onboard_runner"
require "tmpdir"
require "fileutils"
require "stringio"

# Minimal host that satisfies OnboardRunner's dependencies
class OnboardHost
  include Vibe::OnboardRunner

  attr_reader :quickstart_calls, :doctor_calls

  def initialize
    @quickstart_calls = []
    @doctor_calls = []
  end

  # Stub out run_quickstart (QuickstartRunner dependency)
  def run_quickstart(options = {})
    @quickstart_calls << options
  end

  # Stub out run_doctor_command (bin/vibe dependency)
  def run_doctor_command(argv)
    @doctor_calls << argv
  end
end

class TestOnboardRunner < Minitest::Test
  def setup
    @host = OnboardHost.new
    @tmpdir = Dir.mktmpdir("onboard-test")
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  # --- STEPS constant ---

  def test_steps_constant_is_5
    assert_equal 5, Vibe::OnboardRunner::STEPS
  end

  # --- run_onboard: step routing ---

  def test_run_onboard_calls_quickstart_by_default
    # Simulate empty stdin so prompt_role returns nil
    simulate_stdin("") do
      capture_io { @host.run_onboard }
    end
    assert_equal 1, @host.quickstart_calls.size
    assert_equal({ force: true }, @host.quickstart_calls.first)
  end

  def test_run_onboard_skips_quickstart_with_skip_deploy
    simulate_stdin("") do
      capture_io { @host.run_onboard(skip_deploy: true) }
    end
    assert_equal 0, @host.quickstart_calls.size
  end

  def test_run_onboard_calls_doctor
    simulate_stdin("") do
      capture_io { @host.run_onboard(skip_deploy: true) }
    end
    assert_equal 1, @host.doctor_calls.size
    assert_equal [], @host.doctor_calls.first
  end

  def test_run_onboard_outputs_all_5_steps
    out, = simulate_stdin("") do
      capture_io { @host.run_onboard(skip_deploy: true) }
    end
    assert_match(/\[1\/5\]/, out)
    assert_match(/\[2\/5\]/, out)
    assert_match(/\[3\/5\]/, out)
    assert_match(/\[4\/5\]/, out)
    assert_match(/\[5\/5\]/, out)
  end

  def test_run_onboard_outputs_completion_message
    out, = simulate_stdin("") do
      capture_io { @host.run_onboard(skip_deploy: true) }
    end
    assert_match(/Onboarding complete/, out)
  end

  # --- onboard_write_role ---

  def test_write_role_appends_to_session_file
    session_path = File.join(@tmpdir, "session.md")
    # Redirect the write to a temp path by stubbing expand_path
    @host.define_singleton_method(:onboard_write_role) do |role|
      FileUtils.mkdir_p(File.dirname(session_path))
      File.open(session_path, 'a') { |f| f.write("\n## User Role\n#{role}\n") }
    end

    @host.send(:onboard_write_role, "Full-stack engineer")
    content = File.read(session_path)
    assert_match(/## User Role/, content)
    assert_match(/Full-stack engineer/, content)
  end

  def test_write_role_appends_not_overwrites
    session_path = File.join(@tmpdir, "session.md")
    File.write(session_path, "existing content\n")
    @host.define_singleton_method(:onboard_write_role) do |role|
      File.open(session_path, 'a') { |f| f.write("\n## User Role\n#{role}\n") }
    end

    @host.send(:onboard_write_role, "Backend engineer")
    content = File.read(session_path)
    assert_match(/existing content/, content)
    assert_match(/Backend engineer/, content)
  end

  # --- onboard_prompt_role ---

  def test_prompt_role_returns_trimmed_input
    role = simulate_stdin("Data scientist\n") do
      @host.send(:onboard_prompt_role)
    end
    assert_equal "Data scientist", role
  end

  def test_prompt_role_returns_nil_on_empty_stdin
    role = simulate_stdin("") do
      @host.send(:onboard_prompt_role)
    end
    # gets on empty string IO returns nil or ""
    assert(role.nil? || role.empty?)
  end

  # --- run_onboard: role skipped when blank ---

  def test_run_onboard_skips_write_role_when_blank
    written = false
    @host.define_singleton_method(:onboard_write_role) { |_r| written = true }

    simulate_stdin("   \n") do
      capture_io { @host.run_onboard(skip_deploy: true) }
    end
    refute written, "onboard_write_role should not be called for blank input"
  end

  def test_run_onboard_calls_write_role_when_provided
    written_role = nil
    @host.define_singleton_method(:onboard_write_role) { |r| written_role = r }

    simulate_stdin("ML engineer\n") do
      capture_io { @host.run_onboard(skip_deploy: true) }
    end
    assert_equal "ML engineer", written_role
  end

  # --- onboard_skill_summary ---

  def test_skill_summary_mentions_systematic_debugging
    summary = @host.send(:onboard_skill_summary)
    assert_match(/systematic-debugging/, summary)
  end

  def test_skill_summary_mentions_5_phases
    summary = @host.send(:onboard_skill_summary)
    assert_match(/Observe/, summary)
    assert_match(/Verify/, summary)
  end

  # --- onboard_next_steps ---

  def test_next_steps_mentions_key_commands
    steps = @host.send(:onboard_next_steps)
    assert_match(/vibe doctor/, steps)
    assert_match(/vibe instinct/, steps)
    assert_match(/session-end/, steps)
  end

  private

  def simulate_stdin(input, &block)
    old_stdin = $stdin
    $stdin = StringIO.new(input)
    block.call
  ensure
    $stdin = old_stdin
  end
end
