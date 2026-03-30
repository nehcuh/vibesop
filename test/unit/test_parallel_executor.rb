# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../lib/vibe/skill_router/parallel_executor'

class TestParallelExecutor < Minitest::Test
  def setup
    @config = {
      'enabled' => true,
      'max_parallel' => 2,
      'mode' => 'auto',
      'conditions' => {
        'max_confidence_diff' => 0.10,
        'min_candidates' => 2,
        'max_candidates' => 3
      },
      'aggregation' => {
        'method' => 'merged',
        'timeout' => 5,
        'on_timeout' => 'return_partial'
      }
    }

    @executor = Vibe::SkillRouter::ParallelExecutor.new(config: @config)
  end

  def test_parallel_available
    assert @executor.parallel_available?
  end

  def test_parallel_not_available_when_disabled
    executor = Vibe::SkillRouter::ParallelExecutor.new(config: { 'enabled' => false })
    refute executor.parallel_available?
  end

  def test_max_parallel
    assert_equal 2, @executor.max_parallel
  end

  def test_execute_empty_candidates_returns_error
    executor = ->(candidate, context) { { success: true } }

    result = @executor.execute([], executor: executor, context: {})

    assert_equal :error, result[:status]
    assert_includes result[:message], 'No candidates'
  end

  def test_execute_single_candidate_returns_single_result
    candidates = [{ skill: 'test-skill', confidence: 0.9 }]

    executor = ->(candidate, context) {
      { skill: candidate[:skill], result: 'executed' }
    }

    result = @executor.execute(candidates, executor: executor, context: {})

    assert_equal :single, result[:status]
    assert_equal 'test-skill', result[:result][:skill]
  end

  def test_execute_parallel_with_multiple_candidates
    candidates = [
      { skill: 'skill-a', confidence: 0.9 },
      { skill: 'skill-b', confidence: 0.85 }
    ]

    executor = ->(candidate, context) {
      { skill: candidate[:skill], result: "executed #{candidate[:skill]}" }
    }

    result = @executor.execute(candidates, executor: executor, context: {})

    assert_equal :merged, result[:status]
    assert_equal 2, result[:participants]
    assert_equal 0, result[:failed]
  end

  def test_execute_parallel_handles_partial_failure
    candidates = [
      { skill: 'skill-a', confidence: 0.9 },
      { skill: 'skill-b', confidence: 0.85 },
      { skill: 'skill-c', confidence: 0.8 }
    ]

    call_count = 0
    executor = ->(candidate, context) {
      call_count += 1
      if call_count == 2
        raise StandardError, 'Simulated failure'
      end
      { skill: candidate[:skill], result: 'ok' }
    }

    result = @executor.execute(candidates, executor: executor, context: {})

    assert_equal :merged, result[:status]
    # max_parallel is 2, but first 2 calls where 1 fails
    assert_operator result[:participants], :<=, 2
  end

  def test_aggregate_consensus_all_agree
    successful = [
      { result: { conclusion: 'fix-bug' } },
      { result: { conclusion: 'fix-bug' } },
      { result: { conclusion: 'fix-bug' } }
    ]

    result = @executor.send(:aggregate_consensus, successful)

    assert_equal :consensus, result[:status]
    assert_equal 1.0, result[:consensus_rate]
    assert_equal 3, result[:participants]
  end

  def test_aggregate_consensus_disagree
    successful = [
      { result: { conclusion: 'fix-bug' } },
      { result: { conclusion: 'refactor' } },
      { result: { conclusion: 'fix-bug' } }
    ]

    result = @executor.send(:aggregate_consensus, successful)

    assert_equal :no_consensus, result[:status]
    assert_equal 0.0, result[:consensus_rate]
    assert_includes result[:conflicting_conclusions], 'fix-bug'
    assert_includes result[:conflicting_conclusions], 'refactor'
  end

  def test_aggregate_majority
    successful = [
      { result: { conclusion: 'fix-bug' } },
      { result: { conclusion: 'fix-bug' } },
      { result: { conclusion: 'refactor' } }
    ]

    result = @executor.send(:aggregate_majority, successful)

    assert_equal :majority, result[:status]
    assert_equal 2.0 / 3.0, result[:consensus_rate]
    assert_equal 'fix-bug', result[:result][:conclusion]
  end

  def test_aggregate_first_success
    successful = [
      { result: { conclusion: 'fix-bug' } },
      { result: { conclusion: 'refactor' } }
    ]

    result = @executor.send(:aggregate_first_success, successful)

    assert_equal :first_success, result[:status]
    assert_equal 'fix-bug', result[:result][:conclusion]
  end

  def test_aggregate_all
    successful = [
      { result: { conclusion: 'fix-bug' } },
      { result: { conclusion: 'refactor' } }
    ]

    result = @executor.send(:aggregate_all, successful, [])

    assert_equal :all, result[:status]
    assert_equal 2, result[:successful].size
    assert_equal 1.0, result[:success_rate]
  end

  def test_aggregate_merged
    successful = [
      { result: { insights: ['insight-a'], recommendation: 'rec-a' } },
      { result: { insights: ['insight-b'], recommendation: 'rec-b' } }
    ]

    result = @executor.send(:aggregate_merged, successful, [])

    assert_equal :merged, result[:status]
    assert_equal 2, result[:participants]
    assert_equal 2, result[:insights].size
    assert_equal 2, result[:recommendations].size
    assert_includes result[:insights], 'insight-a'
    assert_includes result[:insights], 'insight-b'
  end

  def test_score_result
    result_with_structure = {
      structured: true,
      evidence: true,
      actions: true,
      recommendations: true,
      error: nil
    }

    score = @executor.send(:score_result, result_with_structure)

    # All fields present = 1.0
    assert_in_delta 1.0, score, 0.001
  end

  def test_score_result_minimal
    minimal_result = {
      structured: false,
      evidence: false,
      actions: false,
      recommendations: false
    }

    score = @executor.send(:score_result, minimal_result)

    # Only no-error field = 0.1
    assert_equal 0.1, score
  end
end
