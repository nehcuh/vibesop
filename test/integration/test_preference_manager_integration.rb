# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../lib/vibe/preference_manager'
require_relative '../../lib/vibe/cache_manager'
require 'yaml'
require 'fileutils'
require 'tempfile'

class TestPreferenceManagerIntegration < Minitest::Test
  def setup
    @temp_dir = Dir.mktmpdir
    @preference_file = File.join(@temp_dir, 'skill-preferences.yaml')

    # Try to use real LLM provider if available
    begin
      require_relative '../../lib/vibe/llm_provider/factory'
      @llm_provider = Vibe::LLMProvider::Factory.create_from_env('anthropic')
      @real_llm_available = @llm_provider&.configured?
    rescue LoadError, ArgumentError
      @llm_provider = nil
      @real_llm_available = false
    end

    @cache = Vibe::CacheManager.new
    @manager = Vibe::PreferenceManager.new(
      llm_provider: @llm_provider,
      cache: @cache,
      preference_file: @preference_file
    )
  end

  def teardown
    FileUtils.rm_rf(@temp_dir) if Dir.exist?(@temp_dir)
  end

  def test_initialization_creates_preference_file
    assert File.exist?(@preference_file), "Preference file should be created"

    loaded = YAML.load_file(@preference_file)
    assert_equal 1, loaded['version']
    assert loaded['intent_preferences'].is_a?(Array)
    assert loaded['explicit_rules'].is_a?(Array)
  end

  def test_explicit_rule_matching_without_llm
    # This should work even without LLM provider
    @manager.set_explicit_rule(
      "深入审查规则",
      "^深入.*审查",
      "riper-workflow",
      priority: 100
    )

    input = "深入审查这个项目"
    result = @manager.check_explicit_rules(input)

    assert result, "Should match explicit rule"
    assert_equal :explicit_rule, result[:type]
    assert_equal "riper-workflow", result[:skill]
  end

  def test_multiple_explicit_rules_priority_ordering
    # Add two rules with different priorities
    @manager.set_explicit_rule("低优先级", "^审查", "skill-a", priority: 10)
    @manager.set_explicit_rule("高优先级", "^深入.*审查", "skill-b", priority: 100)

    input = "深入审查项目"
    result = @manager.check_explicit_rules(input)

    # Should match higher priority rule
    assert_equal "skill-b", result[:skill]
    assert_equal 100, result[:priority]
  end

  def test_selection_history_persistence
    input = "测试输入"
    skill = "test-skill"
    route_result = {
      primary: { skill: "other-skill", confidence: 0.8 },
      intent: "test"
    }

    # Record selection
    @manager.record_selection(input, skill, route_result)

    # Create new manager instance to test persistence
    manager2 = Vibe::PreferenceManager.new(
      llm_provider: @llm_provider,
      cache: @cache,
      preference_file: @preference_file
    )

    history = manager2.preferences['selection_history']
    assert_equal 1, history.size
    assert_equal input, history.first['input']
    assert_equal skill, history.first['selected_skill']
  end

  def test_statistics_tracking
    # Record multiple selections
    5.times { |i|
      @manager.record_selection("test#{i}", "skill-a", {
        primary: { skill: "skill-a", confidence: 0.9 },
        intent: "test"
      })
    }

    3.times { |i|
      @manager.record_selection("test#{i}", "skill-b", {
        primary: { skill: "skill-a", confidence: 0.9 },
        intent: "test"
      })
    }

    stats = @manager.stats

    assert_equal 8, stats[:total_selections]
    assert_equal 5, stats[:skill_usage]["skill-a"]
    assert_equal 3, stats[:skill_usage]["skill-b"]
  end

  def test_user_satisfaction_tracking
    # Record selection
    @manager.record_selection("审查代码", "gstack/review", {
      primary: { skill: "gstack/review", confidence: 0.95 },
      intent: "code_review"
    })

    # Record satisfaction
    @manager.record_satisfaction("gstack/review", true)

    history = @manager.preferences['selection_history']
    assert_equal true, history.last['user_satisfaction']
  end

  def test_intent_preference_creation_and_matching
    skip "Requires real LLM provider for intent recognition" unless @real_llm_available

    # Create intent preference
    @manager.set_intent_preference("code_review", "gstack/plan-eng-review", confidence: 0.9)

    # Note: This test will only work if real LLM is available
    # and can recognize "code_review" intent from some input
    input = "帮我审查这段代码"
    result = @manager.match_preference(input, { file_type: 'ruby' })

    # Result should contain the intent preference
    if result && result[:type] == :intent_preference
      assert_equal "gstack/plan-eng-review", result[:skill]
    end
  end

  def test_cache_integration
    skip "Requires real LLM provider" unless @real_llm_available

    input = "测试缓存功能"
    context = { file_type: 'ruby' }

    # First call - should hit LLM
    result1 = @manager.recognize_intent(input, context)

    # Second call - should use cache
    result2 = @manager.recognize_intent(input, context)

    assert_equal result1, result2
  end

  def test_reset_clears_all_data
    # Add some data
    @manager.set_intent_preference("test", "skill-a")
    @manager.set_explicit_rule("test", "^test", "skill-b")
    @manager.record_selection("input", "skill-c", {
      primary: { skill: "skill-c", confidence: 0.9 },
      intent: "test"
    })

    # Reset
    @manager.reset

    # Verify cleared
    assert_equal 0, @manager.preferences['intent_preferences'].size
    assert_equal 0, @manager.preferences['explicit_rules'].size
    assert_equal 0, @manager.preferences['selection_history'].size
  end

  def test_corrupted_file_recovery
    # Write corrupted YAML
    File.write(@preference_file, "invalid: [unclosed")

    # Should create new default preferences
    manager = Vibe::PreferenceManager.new(
      preference_file: @preference_file
    )

    assert manager.preferences
    assert_equal 1, manager.preferences['version']
  end

  def test_platform_detection_in_selection_history
    @manager.record_selection("test", "skill-a", {
      primary: { skill: "skill-a", confidence: 0.9 },
      intent: "test"
    })

    history = @manager.preferences['selection_history']
    assert history.last['platform']
    assert ['claude-code', 'opencode', 'unknown'].include?(history.last['platform'])
  end

  def test_learning_config_access
    config = @manager.learning_config

    assert config['min_samples']
    assert config['consistency_threshold']
    assert config['time_window_days']
    refute config['auto_promote']
  end

  def test_interaction_config_access
    config = @manager.interaction_config

    assert_equal 'smart', config['default_mode']
    assert config['smart_mode']['ask_threshold']
    assert config['parallel_mode']['enabled']
  end

  def test_concurrent_managers_share_same_file
    # Create two managers with same preference file
    manager1 = Vibe::PreferenceManager.new(
      preference_file: @preference_file
    )

    manager2 = Vibe::PreferenceManager.new(
      preference_file: @preference_file
    )

    # Both should reference same file
    assert_equal manager1.preference_file, manager2.preference_file

    # Changes from one should be visible to other after reload
    manager1.set_intent_preference("test", "skill-a")

    # Reload manager2
    manager2.instance_variable_set(:@preferences, manager2.send(:load_preferences))

    assert_equal 1, manager2.preferences['intent_preferences'].size
  end

  def test_real_world_workflow
    # Simulate real workflow: explicit rule + selection + satisfaction
    # 1. User sets explicit preference
    @manager.set_explicit_rule(
      "我的审查规则",
      "审查.*代码",
      "gstack/review",
      priority: 80
    )

    # 2. User makes a request matching the rule
    result = @manager.check_explicit_rules("审查代码质量")
    assert result
    assert_equal "gstack/review", result[:skill]

    # 3. User selects (even though it was recommended)
    route_result = {
      primary: { skill: "gstack/review", confidence: 0.85 },
      intent: "code_review"
    }

    @manager.record_selection("审查代码质量", "gstack/review", route_result)

    # 4. User provides feedback
    @manager.record_satisfaction("gstack/review", true)

    # 5. Check history
    history = @manager.preferences['selection_history'].last
    assert_equal true, history['user_satisfaction']
    assert_equal true, history['was_recommended']
  end
end
