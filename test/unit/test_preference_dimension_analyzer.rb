# frozen_string_literal: true

require 'minitest/autorun'
require 'yaml'
require 'fileutils'
require 'tempfile'
require_relative '../../lib/vibe/preference_dimension_analyzer'

class TestPreferenceDimensionAnalyzer < Minitest::Test
  def setup
    @temp_dir = Dir.mktmpdir
    @preference_file = File.join(@temp_dir, 'skill-preferences.yaml')

    @config = {
      'enabled' => true,
      'dimensions' => {
        'consistency' => {
          'weight' => 0.4,
          'threshold' => 0.7,
          'min_samples' => 3,
          'time_window_days' => 14
        },
        'satisfaction' => {
          'weight' => 0.3,
          'min_samples' => 2
        },
        'context' => {
          'weight' => 0.2
        },
        'recency' => {
          'weight' => 0.1,
          'decay_days' => 30
        }
      }
    }

    @analyzer = Vibe::PreferenceDimensionAnalyzer.new(
      config: @config,
      preference_file: @preference_file
    )
  end

  def teardown
    FileUtils.rm_rf(@temp_dir) if Dir.exist?(@temp_dir)
  end

  def test_analyze_returns_empty_when_disabled
    analyzer = Vibe::PreferenceDimensionAnalyzer.new(
      config: { 'enabled' => false },
      preference_file: @preference_file
    )

    candidates = [
      { skill: 'test-skill', confidence: 0.8 }
    ]

    result = analyzer.analyze(candidates, {})
    assert_empty result
  end

  def test_analyze_returns_empty_for_no_history
    candidates = [
      { skill: 'test-skill', confidence: 0.8 }
    ]

    result = @analyzer.analyze(candidates, {})
    assert_empty result
  end

  def test_calculate_consistency_scores
    # Create some history
    create_history_with_consistency('skill-a', 7, 'skill-b', 3)

    # Reload analyzer to pick up new history
    @analyzer.reload

    candidates = [
      { skill: 'skill-a', confidence: 0.8 },
      { skill: 'skill-b', confidence: 0.7 }
    ]

    result = @analyzer.analyze(candidates, {})

    # skill-a was chosen 7/10 times (70%)
    assert_operator result['skill-a'], :>=, result['skill-b']
  end

  def test_calculate_satisfaction_scores
    create_history_with_satisfaction('skill-a', satisfied: 5, unsatisfied: 1)
    create_history_with_satisfaction('skill-b', satisfied: 2, unsatisfied: 4)

    @analyzer.reload

    candidates = [
      { skill: 'skill-a', confidence: 0.8 },
      { skill: 'skill-b', confidence: 0.7 }
    ]

    result = @analyzer.analyze(candidates, {})

    # skill-a has higher satisfaction (5/6 vs 2/6)
    assert_operator result['skill-a'], :>, result['skill-b']
  end

  def test_recency_scores_recent_usage_higher
    # skill-a used yesterday, skill-b used 20 days ago
    create_history_entry('skill-a', days_ago: 1)
    create_history_entry('skill-b', days_ago: 20)

    @analyzer.reload

    candidates = [
      { skill: 'skill-a', confidence: 0.8 },
      { skill: 'skill-b', confidence: 0.7 }
    ]

    result = @analyzer.analyze(candidates, {})

    # skill-a should have higher recency score
    assert_operator result['skill-a'], :>, result['skill-b']
  end

  def test_detailed_analysis_returns_all_dimensions
    create_history_entry('test-skill', days_ago: 1)
    create_history_entry('test-skill', days_ago: 2)
    create_history_entry('test-skill', days_ago: 3, satisfied: true)
    create_history_entry('test-skill', days_ago: 4)

    @analyzer.reload

    result = @analyzer.detailed_analysis('test-skill')

    assert_includes result.keys, :consistency
    assert_includes result.keys, :satisfaction
    assert_includes result.keys, :context
    assert_includes result.keys, :recency
    assert_includes result.keys, :overall
  end

  def test_overall_score_combines_dimensions
    # Create history that boosts all dimensions
    10.times { create_history_entry('popular-skill', days_ago: 1, satisfied: true, file_type: 'rb') }

    @analyzer.reload

    result = @analyzer.detailed_analysis('popular-skill')

    # Overall score should be reasonably high
    assert_operator result[:overall], :>=, 0.3
  end

  def test_combine_scores_uses_weights
    scores = @analyzer.send(:combine_scores,
      consistency: 0.8,
      satisfaction: 0.9,
      context: 0.5,
      recency: 0.6
    )

    # Expected: 0.8*0.4 + 0.9*0.3 + 0.5*0.2 + 0.6*0.1 = 0.32 + 0.27 + 0.1 + 0.06 = 0.75
    expected = 0.75
    assert_in_delta expected, scores, 0.01
  end

  private

  def create_history_with_consistency(skill_a, count_a, skill_b, count_b)
    total = count_a + count_b
    (count_a).times { create_history_entry(skill_a, days_ago: 1) }
    (count_b).times { create_history_entry(skill_b, days_ago: 1) }
  end

  def create_history_with_satisfaction(skill, satisfied:, unsatisfied:)
    satisfied.times { create_history_entry(skill, days_ago: 1, satisfied: true) }
    unsatisfied.times { create_history_entry(skill, days_ago: 1, satisfied: false) }
  end

  def create_history_entry(skill, days_ago: 1, satisfied: nil, file_type: nil)
    timestamp = (Date.today - days_ago).strftime('%Y-%m-%dT%H:%M:%S%z')

    entry = {
      'timestamp' => timestamp,
      'input' => 'test input',
      'intent' => 'test',
      'selected_skill' => skill,
      'ai_recommended' => skill,
      'was_recommended' => true,
      'confidence' => 0.8,
      'platform' => 'claude-code',
      'user_satisfaction' => satisfied
    }

    if file_type
      entry['file_type'] = file_type
    end

    # Load existing history
    history = if File.exist?(@preference_file)
      YAML.load_file(@preference_file)['selection_history'] || []
    else
      []
    end

    history << entry

    # Save
    File.write(@preference_file, YAML.dump({
      'selection_history' => history,
      'updated_at' => Time.now.iso8601
    }))
  end
end
