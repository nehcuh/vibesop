# frozen_string_literal: true

require "minitest/autorun"
require "fileutils"
require "tmpdir"
require_relative "../../lib/vibe/grader"

class TestGrader < Minitest::Test
  def setup
    @grader = Vibe::Grader.new
  end

  def test_run_unit_test_pass
    result = @grader.run(:unit_test, "exit 0", description: "Passing test")

    assert_equal "pass", result[:grade]
    assert_equal 0, result[:exit_code]
    assert_equal "unit_test", result[:type]
    refute_nil result[:duration]
  end

  def test_run_unit_test_fail
    result = @grader.run(:unit_test, "exit 1", description: "Failing test")

    assert_equal "fail", result[:grade]
    assert_equal 1, result[:exit_code]
  end

  def test_run_linter_with_warnings
    result = @grader.run(:linter, "echo 'warning: unused variable' && exit 0")

    assert_equal "pass", result[:grade]
    assert result[:output].include?("warning")
  end

  def test_run_linter_pass
    result = @grader.run(:linter, "exit 0")

    assert_equal "pass", result[:grade]
  end

  def test_run_security_with_low_severity
    result = @grader.run(:security, "echo 'low severity issue' && exit 0")

    assert_equal "pass", result[:grade]
  end

  def test_run_security_fail
    result = @grader.run(:security, "echo 'critical vulnerability' && exit 1")

    assert_equal "fail", result[:grade]
  end

  def test_run_with_working_dir
    temp_dir = Dir.mktmpdir
    test_file = File.join(temp_dir, "test.txt")
    File.write(test_file, "content")

    result = @grader.run(:unit_test, "test -f test.txt", working_dir: temp_dir)

    assert_equal "pass", result[:grade]

    FileUtils.rm_rf(temp_dir)
  end

  def test_run_invalid_type
    assert_raises(RuntimeError) do
      @grader.run(:invalid_type, "echo test")
    end
  end

  def test_stats_tracking
    @grader.run(:unit_test, "exit 0")
    @grader.run(:unit_test, "exit 1")
    @grader.run(:linter, "echo 'warning' && exit 0")

    assert_equal 3, @grader.stats[:total_runs]
    assert_equal 2, @grader.stats[:passes]
    assert_equal 1, @grader.stats[:failures]
    assert_equal 0, @grader.stats[:warnings]
  end

  def test_summary
    @grader.run(:unit_test, "exit 0")
    @grader.run(:unit_test, "exit 1")

    summary = @grader.summary

    assert_equal 2, summary[:total_runs]
    assert_equal 1, summary[:passes]
    assert_equal 1, summary[:failures]
    assert_equal 50.0, summary[:pass_rate]
    assert_equal 2, summary[:recent_results].size
  end

  def test_clear
    @grader.run(:unit_test, "exit 0")
    @grader.clear

    assert_equal 0, @grader.stats[:total_runs]
    assert_equal 0, @grader.results.size
  end

  def test_pass_at_k_all_pass
    candidates = [
      { code: "def test; true; end", description: "Solution 1" },
      { code: "def test; true; end", description: "Solution 2" },
      { code: "def test; true; end", description: "Solution 3" }
    ]

    result = @grader.pass_at_k(candidates, {
      type: :unit_test,
      command: "ruby -e 'load \"{code_file}\"'",
      k: 3
    })

    assert_equal 3, result[:k]
    assert_equal 3, result[:evaluated]
    assert_equal 3, result[:passes]
    assert_equal 0, result[:failures]
    assert_equal 100.0, result[:pass_rate]
  end

  def test_pass_at_k_partial_pass
    candidates = [
      { code: "def test; true; end", description: "Good solution" },
      { code: "def test; raise 'error'; end", description: "Bad solution" },
      { code: "def test; true; end", description: "Another good solution" }
    ]

    result = @grader.pass_at_k(candidates, {
      type: :unit_test,
      command: "ruby -e 'load \"{code_file}\"'",
      k: 3
    })

    assert_equal 3, result[:evaluated]
    assert result[:passes] >= 2
    assert_equal 3, result[:results].size
  end

  def test_pass_at_k_with_limit
    candidates = [
      { code: "def test; true; end", description: "Solution 1" },
      { code: "def test; true; end", description: "Solution 2" },
      { code: "def test; true; end", description: "Solution 3" }
    ]

    result = @grader.pass_at_k(candidates, {
      type: :unit_test,
      command: "ruby -e 'load \"{code_file}\"'",
      k: 2
    })

    assert_equal 2, result[:k]
    assert_equal 2, result[:evaluated]
    assert_equal 3, result[:total_candidates]
  end

  def test_result_structure
    result = @grader.run(:unit_test, "exit 0")

    assert result[:id]
    assert result[:type]
    assert result[:command]
    assert result[:started_at]
    assert result[:completed_at]
    assert result[:grade]
    assert result[:duration]
  end

  def test_error_handling
    result = @grader.run(:unit_test, "nonexistent_command_xyz 2>&1")

    assert_equal "fail", result[:grade]
    assert result[:output].length > 0
  end

  # --- pass_at_k token budget ---

  def test_pass_at_k_no_budget_behavior_unchanged
    candidates = [
      { code: "exit 0", description: "pass" },
      { code: "exit 1", description: "fail" }
    ]
    result = @grader.pass_at_k(candidates, { type: :unit_test, command: "sh {code_file}", k: 2 })

    assert_equal 2, result[:k]
    assert_nil result[:token_budget]
    assert_equal 0, result[:budget_exceeded_count]
  end

  def test_pass_at_k_token_budget_skips_large_candidates
    # small passes budget and test, large exceeds budget
    small_code = "exit 0"   # ~1.5 tokens, passes budget of 5
    large_code = "x" * 40   # ~10 tokens, exceeds budget of 5
    candidates = [
      { code: small_code, description: "small" },
      { code: large_code, description: "large" }
    ]
    result = @grader.pass_at_k(candidates, {
      type: :unit_test,
      command: "sh {code_file}",
      k: 2,
      token_budget: 5
    })

    assert_equal 5, result[:token_budget]
    assert_equal 1, result[:budget_exceeded_count]
    skipped = result[:results].select { |r| r[:grade] == :skipped }
    assert_equal 1, skipped.size
    assert_equal "exceeds_token_budget", skipped.first[:reason]
    # Skipped candidates should NOT count as failures
    assert_equal 0, result[:failures]
    # pass_rate denominator excludes skipped: 1 pass / 1 evaluated = 100%
    assert_equal 100.0, result[:pass_rate]
  end

  def test_pass_at_k_all_skipped_pass_rate_is_zero
    large_code = "x" * 40  # ~10 tokens, exceeds budget of 5
    candidates = [
      { code: large_code, description: "large1" },
      { code: large_code, description: "large2" }
    ]
    result = @grader.pass_at_k(candidates, {
      type: :unit_test,
      command: "sh {code_file}",
      k: 2,
      token_budget: 5
    })

    assert_equal 2, result[:budget_exceeded_count]
    assert_equal 0, result[:passes]
    assert_equal 0, result[:failures]
    assert_equal 0.0, result[:pass_rate]
  end

  def test_pass_at_k_budget_exceeded_count_zero_when_all_fit
    candidates = [{ code: "x", description: "tiny" }]
    result = @grader.pass_at_k(candidates, {
      type: :unit_test,
      command: "sh {code_file}",
      k: 1,
      token_budget: 100
    })

    assert_equal 0, result[:budget_exceeded_count]
  end
end
