# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../lib/vibe/preference_learner'
require 'yaml'
require 'fileutils'
require 'tempfile'

class TestPreferenceLearner < Minitest::Test
  def setup
    @temp_dir = Dir.mktmpdir
    @preference_file = File.join(@temp_dir, 'skill-preferences.yaml')

    @learning_config = {
      'min_samples' => 3,  # Lower for testing
      'consistency_threshold' => 0.7,
      'time_window_days' => 14,
      'min_time_span_days' => 3,
      'auto_promote' => false
    }

    @learner = Vibe::PreferenceLearner.new(@preference_file, @learning_config)
  end

  def teardown
    FileUtils.rm_rf(@temp_dir) if Dir.exist?(@temp_dir)
  end

  def test_record_selection
    input = "审查代码"
    skill = "gstack/review"
    route_result = {
      primary: { skill: "riper-workflow", confidence: 0.95 },
      intent: "code_review"
    }

    result = @learner.record_selection(input, skill, route_result)

    assert_equal :recorded, result
    assert_equal 1, @learner.selection_history.size
  end

  def test_record_selection_persists
    input = "测试输入"
    skill = "test-skill"
    route_result = {
      primary: { skill: skill, confidence: 0.9 },
      intent: "test"
    }

    @learner.record_selection(input, skill, route_result)

    # Create new learner instance
    learner2 = Vibe::PreferenceLearner.new(@preference_file, @learning_config)

    assert_equal 1, learner2.selection_history.size
    assert_equal input, learner2.selection_history.first[:input]
  end

  def test_record_satisfaction
    skill = "test-skill"
    route_result = {
      primary: { skill: skill, confidence: 0.9 },
      intent: "test"
    }

    @learner.record_selection("input", skill, route_result)
    @learner.record_satisfaction(skill, true)

    entry = @learner.selection_history.first
    assert_equal true, entry[:user_satisfaction]
  end

  def test_calculate_consistency
    # Record selections: 7 out of 10 are for skill-a
    10.times do |i|
      skill = i < 7 ? "skill-a" : "skill-b"
      @learner.record_selection("test", skill, {
        primary: { skill: skill, confidence: 0.9 },
        intent: "test"
      })
    end

    consistency = @learner.calculate_consistency("skill-a")
    assert_equal 0.7, consistency
  end

  def test_calculate_consistency_with_time_window
    # Create some old selections outside time window
    old_time = Time.now - ((@learning_config['time_window_days'] + 5) * 24 * 60 * 60)
    @learner.selection_history << {
      timestamp: old_time.strftime('%Y-%m-%dT%H:%M:%S%z'),
      input: "old test",
      selected_skill: "skill-old",
      ai_recommended: "skill-old",
      was_recommended: true,
      confidence: 0.9,
      platform: "test",
      user_satisfaction: nil,
      explicitly_confirmed: false
    }

    # Record recent selections
    5.times do
      @learner.record_selection("new test", "skill-new", {
        primary: { skill: "skill-new", confidence: 0.9 },
        intent: "test"
      })
    end

    # Old selection should not be counted
    consistency = @learner.calculate_consistency("skill-new")
    assert_equal 1.0, consistency
  end

  def test_calculate_time_span
    # Record selections across multiple days
    now = Time.now

    # First selection
    @learner.selection_history << {
      timestamp: (now - (5 * 24 * 60 * 60)).strftime('%Y-%m-%dT%H:%M:%S%z'),
      input: "test",
      selected_skill: "skill-a",
      ai_recommended: "skill-a",
      was_recommended: true,
      confidence: 0.9,
      platform: "test",
      user_satisfaction: nil,
      explicitly_confirmed: false
    }

    # Last selection
    @learner.record_selection("test", "skill-a", {
      primary: { skill: "skill-a", confidence: 0.9 },
      intent: "test"
    })

    time_span = @learner.calculate_time_span("skill-a")
    assert time_span >= 5, "Time span should be at least 5 days"
  end

  def test_calculate_satisfaction
    skill = "skill-a"
    route_result = {
      primary: { skill: skill, confidence: 0.9 },
      intent: "test"
    }

    # Record some selections with satisfaction
    3.times do
      @learner.record_selection("test", skill, route_result)
      @learner.record_satisfaction(skill, true)
    end

    1.times do
      @learner.record_selection("test", skill, route_result)
      @learner.record_satisfaction(skill, false)
    end

    satisfaction = @learner.calculate_satisfaction(skill)
    assert_equal 0.75, satisfaction  # 3/4 = 0.75
  end

  def test_should_suggest_preference_insufficient_samples
    result = @learner.should_suggest_preference?("skill-new")
    assert_equal false, result
  end

  def test_should_suggest_preference_meets_all_criteria
    skill = "skill-a"
    route_result_recommended = {
      primary: { skill: skill, confidence: 0.95 },
      intent: "test"
    }

    route_result_other = {
      primary: { skill: "skill-other", confidence: 0.8 },
      intent: "test"
    }

    now = Time.now

    # Record enough selections (7/10 consistent) across multiple days
    7.times do |i|
      timestamp = (now - ((7 - i) * 24 * 60 * 60)).strftime('%Y-%m-%dT%H:%M:%S%z')
      entry = @learner.send(:build_selection_entry, "test", skill, route_result_recommended)
      entry[:timestamp] = timestamp
      @learner.selection_history << entry
    end

    3.times do |i|
      timestamp = (now - ((3 - i) * 24 * 60 * 60)).strftime('%Y-%m-%dT%H:%M:%S%z')
      entry = @learner.send(:build_selection_entry, "test", "skill-b", route_result_other)
      entry[:timestamp] = timestamp
      @learner.selection_history << entry
    end

    # Add positive satisfaction
    3.times do |i|
      timestamp = (now - ((3 - i) * 24 * 60 * 60)).strftime('%Y-%m-%dT%H:%M:%S%z')
      entry = @learner.send(:build_selection_entry, "test", skill, route_result_recommended)
      entry[:timestamp] = timestamp
      @learner.selection_history << entry
      @learner.record_satisfaction(skill, true)
    end

    # Should meet all criteria now
    result = @learner.should_suggest_preference?(skill)
    assert result, "Should suggest preference when all criteria met"
  end

  def test_should_suggest_preference_with_explicit_confirmation
    skill = "skill-a"

    now = Time.now

    # Record minimum selections across multiple days (span at least 3 days)
    # Using: 6 days ago, 4 days ago, 1 day ago = span of 5 days
    timestamps = [
      (now - (6 * 24 * 60 * 60)).strftime('%Y-%m-%dT%H:%M:%S%z'),
      (now - (4 * 24 * 60 * 60)).strftime('%Y-%m-%dT%H:%M:%S%z'),
      (now - (1 * 24 * 60 * 60)).strftime('%Y-%m-%dT%H:%M:%S%z')
    ]

    timestamps.each do |timestamp|
      entry = @learner.send(:build_selection_entry, "test", skill, {
        primary: { skill: skill, confidence: 0.9 },
        intent: "test"
      })
      entry[:timestamp] = timestamp
      @learner.selection_history << entry
    end

    # Mark as explicitly confirmed
    @learner.mark_explicitly_confirmed(skill)

    # Should suggest even with minimum samples
    result = @learner.should_suggest_preference?(skill)
    assert result, "Should suggest when explicitly confirmed"
  end

  def test_mark_explicitly_confirmed
    skill = "skill-a"
    @learner.record_selection("test", skill, {
      primary: { skill: skill, confidence: 0.9 },
      intent: "test"
    })

    @learner.mark_explicitly_confirmed(skill)

    assert @learner.user_explicitly_confirmed?(skill)
  end

  def test_stats
    # Record various selections
    5.times { @learner.record_selection("test", "skill-a", {
      primary: { skill: "skill-a", confidence: 0.9 },
      intent: "test"
    })}

    3.times { @learner.record_selection("test", "skill-b", {
      primary: { skill: "skill-a", confidence: 0.9 },
      intent: "test"
    })}

    stats = @learner.stats

    assert_equal 8, stats[:total_selections]
    assert_equal 2, stats[:unique_skills]
    assert_equal 5, stats[:skill_usage]["skill-a"]
    assert_equal 3, stats[:skill_usage]["skill-b"]
  end

  def test_recent_selections_within_window
    # Add old selection (outside window)
    old_time = Time.now - ((@learning_config['time_window_days'] + 5) * 24 * 60 * 60)
    @learner.selection_history << {
      timestamp: old_time.strftime('%Y-%m-%dT%H:%M:%S%z'),
      input: "old",
      selected_skill: "old-skill",
      ai_recommended: "old-skill",
      was_recommended: true,
      confidence: 0.9,
      platform: "test",
      user_satisfaction: nil,
      explicitly_confirmed: false
    }

    # Add recent selections
    5.times do
      @learner.record_selection("new", "new-skill", {
        primary: { skill: "new-skill", confidence: 0.9 },
        intent: "test"
      })
    end

    recent = @learner.recent_selections_within_window

    # Should not include old selection
    assert_equal 5, recent.size
    assert recent.all? { |e| e[:selected_skill] == "new-skill" }
  end

  def test_find_override_patterns
    # Create pattern: user consistently chooses "custom-review" for "审查" inputs
    7.times do |i|
      input = "审查代码 #{i}"
      entry = @learner.send(:build_selection_entry, input, "custom-review", {
        primary: { skill: "ai-review", confidence: 0.85 },
        intent: "code_review"
      })
      @learner.selection_history << entry
    end

    # Add some noise (3 times choose different skill)
    3.times do |i|
      input = "审查代码 #{i + 7}"
      entry = @learner.send(:build_selection_entry, input, "other-skill", {
        primary: { skill: "ai-review", confidence: 0.85 },
        intent: "code_review"
      })
      @learner.selection_history << entry
    end

    patterns = @learner.find_override_patterns(min_overrides: 3)

    assert patterns.any?, "Should find override patterns"

    # Check if we found the pattern (key might be normalized)
    pattern_key = patterns.keys.find { |k| k.include?("审查") }
    assert pattern_key, "Should find pattern for '审查' inputs"

    pattern = patterns[pattern_key]
    assert_equal "custom-review", pattern[:skill]
    assert pattern[:consistency] >= 0.7
  end

  def test_skill_selection_count
    skill = "skill-a"

    3.times do
      @learner.record_selection("test", skill, {
        primary: { skill: skill, confidence: 0.9 },
        intent: "test"
      })
    end

    count = @learner.skill_selection_count(skill)
    assert_equal 3, count
  end

  def test_trim_history
    max_size = 5

    # Set max_history_size in config
    @learning_config['max_history_size'] = max_size

    # Record more than max
    10.times do |i|
      entry = @learner.send(:build_selection_entry, "test #{i}", "skill-a", {
        primary: { skill: "skill-a", confidence: 0.9 },
        intent: "test"
      })
      @learner.selection_history << entry
    end

    # Manually call trim
    @learner.send(:trim_history)

    # Should trim to max size
    assert_equal max_size, @learner.selection_history.size
  end
end
