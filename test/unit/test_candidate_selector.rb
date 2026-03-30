# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../lib/vibe/skill_router/candidate_selector'

class TestCandidateSelector < Minitest::Test
  def setup
    @config = {
      'candidate_selection' => {
        'max_candidates' => 3,
        'auto_select_threshold' => 0.15,
        'min_confidence' => 0.6,
        'sort_by' => 'balanced'
      },
      'preference_learning' => {
        'enabled' => false  # Disable for basic tests
      },
      'parallel_execution' => {
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
          'timeout' => 300
        }
      },
      'fallback' => {
        'no_candidates' => 'suggest_similar',
        'no_preferences' => 'use_confidence',
        'parallel_failed' => 'fallback_to_serial'
      }
    }

    @selector = Vibe::SkillRouter::CandidateSelector.new(config: @config)
  end

  def test_empty_candidates_returns_no_candidates_decision
    result = @selector.select([], {})

    assert_equal :no_candidates, result[:action]
    assert_empty result[:candidates]
  end

  def test_single_candidate_auto_selects
    candidates = [
      { skill: 'systematic-debugging', confidence: 0.9 }
    ]

    result = @selector.select(candidates, {})

    assert_equal :auto_select, result[:action]
    assert_equal 'systematic-debugging', result[:selected][:skill]
    assert_equal 'Only one matching skill', result[:reason]
  end

  def test_auto_select_when_confidence_gap_high
    candidates = [
      { skill: 'systematic-debugging', confidence: 0.92 },
      { skill: 'gstack/investigate', confidence: 0.70 },
      { skill: 'superpowers/debug', confidence: 0.65 }
    ]

    result = @selector.select(candidates, {})

    # Gap is 0.22 (> 0.15 threshold), should auto-select
    assert_equal :auto_select, result[:action]
    assert_equal 'systematic-debugging', result[:selected][:skill]
  end

  def test_user_choice_when_confidence_gap_low
    # Create selector with parallel disabled
    config = @config.dup
    config['parallel_execution']['enabled'] = false
    config['parallel_execution']['mode'] = 'disabled'
    selector = Vibe::SkillRouter::CandidateSelector.new(config: config)

    candidates = [
      { skill: 'systematic-debugging', confidence: 0.85 },
      { skill: 'gstack/investigate', confidence: 0.80 }
    ]

    result = selector.select(candidates, {})

    # Gap is 0.05 (< 0.15 threshold), should ask user
    assert_equal :user_choice, result[:action]
    assert_equal 2, result[:candidates].size
    assert_includes result[:prompt], 'Please choose'
  end

  def test_filters_below_min_confidence
    candidates = [
      { skill: 'systematic-debugging', confidence: 0.9 },
      { skill: 'gstack/investigate', confidence: 0.7 },
      { skill: 'low-confidence-skill', confidence: 0.5 }
    ]

    result = @selector.select(candidates, {})

    # Should auto-select top, low confidence filtered out
    assert_equal :auto_select, result[:action]
    assert_equal 1, result[:candidates].size
    assert_equal 'systematic-debugging', result[:selected][:skill]
  end

  def test_parallel_candidates_when_confidence_close
    candidates = [
      { skill: 'systematic-debugging', confidence: 0.85 },
      { skill: 'gstack/investigate', confidence: 0.82 }
    ]

    parallel = @selector.parallel_candidates(candidates)

    assert_equal 2, parallel.size
    assert_equal 'systematic-debugging', parallel.first[:skill]
    assert_equal 'gstack/investigate', parallel[1][:skill]
  end

  def test_no_parallel_candidates_when_confidence_far
    candidates = [
      { skill: 'systematic-debugging', confidence: 0.95 },
      { skill: 'gstack/investigate', confidence: 0.70 }
    ]

    parallel = @selector.parallel_candidates(candidates)

    # Gap is 0.25 > 0.10 threshold, no parallel
    assert_empty parallel
  end

  def test_parallel_respects_max_parallel
    candidates = [
      { skill: 'skill-a', confidence: 0.85 },
      { skill: 'skill-b', confidence: 0.84 },
      { skill: 'skill-c', confidence: 0.83 }
    ]

    parallel = @selector.parallel_candidates(candidates)

    # max_parallel is 2
    assert_equal 2, parallel.size
  end

  def test_should_auto_select_with_single_candidate
    candidates = [
      { skill: 'only-option', confidence: 0.75 }
    ]

    assert @selector.should_auto_select?(candidates)
  end

  def test_should_auto_select_with_large_gap
    candidates = [
      { skill: 'top-choice', confidence: 0.90 },
      { skill: 'second-choice', confidence: 0.70 }
    ]

    assert @selector.should_auto_select?(candidates)
  end

  def test_should_not_auto_select_with_small_gap
    candidates = [
      { skill: 'top-choice', confidence: 0.80 },
      { skill: 'second-choice', confidence: 0.75 }
    ]

    refute @selector.should_auto_select?(candidates)
  end

  # Additional tests for parallel_candidates edge cases
  def test_parallel_candidates_requires_min_candidates
    candidates = [
      { skill: 'a', confidence: 0.85 }
    ]

    parallel = @selector.parallel_candidates(candidates)

    assert_empty parallel
  end

  def test_parallel_candidates_checks_confidence_diff
    candidates = [
      { skill: 'high-skill', confidence: 0.95 },
      { skill: 'low-skill', confidence: 0.70 }
    ]

    parallel = @selector.parallel_candidates(candidates)

    # Gap is 0.25 > 0.10 threshold, no parallel
    assert_empty parallel
  end

  def test_parallel_candidates_limits_to_max_parallel
    candidates = [
      { skill: 'a', confidence: 0.85 },
      { skill: 'b', confidence: 0.84 },
      { skill: 'c', confidence: 0.83 }
    ]

    parallel = @selector.parallel_candidates(candidates)

    # max_parallel is 2
    assert_equal 2, parallel.size
  end
end
