# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../lib/vibe/preference_manager'
require_relative '../../lib/vibe/llm_provider/base'
require 'fileutils'
require 'tempfile'

# Mock LLM Provider for testing
class MockLLMProvider < Vibe::LLMProvider::Base
  attr_accessor :responses, :calls

  def initialize(api_key: 'test_key', base_url: 'http://test', **kwargs)
    super(api_key: api_key, base_url: base_url, **kwargs)
    @responses = []
    @calls = []
  end

  def call(model:, prompt:, max_tokens: 300, temperature: 0.3)
    @calls << { model: model, prompt: prompt, max_tokens: max_tokens, temperature: temperature }

    # Return next response or default
    response = @responses.shift || default_response
    response
  end

  def provider_name
    'MockProvider'
  end

  def supported_models
    ['mock-model', 'claude-haiku-4-5-20251001']
  end

  def configured?
    true
  end

  private

  def default_response
    # Default intent recognition response
    JSON.generate({
      'intent' => 'code_review',
      'confidence' => 0.85,
      'keywords' => ['review', 'check']
    })
  end
end

class TestPreferenceManager < Minitest::Test
  def setup
    @temp_dir = Dir.mktmpdir
    @preference_file = File.join(@temp_dir, 'skill-preferences.yaml')

    @mock_provider = MockLLMProvider.new
    @manager = Vibe::PreferenceManager.new(
      llm_provider: @mock_provider,
      preference_file: @preference_file
    )
  end

  def teardown
    FileUtils.rm_rf(@temp_dir) if Dir.exist?(@temp_dir)
  end

  def test_initialization_creates_default_preferences
    assert File.exist?(@preference_file)
    prefs = @manager.preferences
    assert_equal 1, prefs['version']
    assert_equal '1.0', prefs['schema_version']
    assert prefs['intent_preferences'].is_a?(Array)
    assert prefs['explicit_rules'].is_a?(Array)
  end

  def test_learning_config_defaults
    config = @manager.learning_config
    assert_equal 5, config['min_samples']
    assert_equal 0.7, config['consistency_threshold']
    assert_equal 14, config['time_window_days']
    refute config['auto_promote']
  end

  def test_interaction_config_defaults
    config = @manager.interaction_config
    assert_equal 'smart', config['default_mode']
    assert config['smart_mode']['ask_on_preference_mismatch']
    assert config['parallel_mode']['enabled']
  end

  def test_check_explicit_rules_no_match
    input = "随便聊聊天"
    result = @manager.check_explicit_rules(input)
    assert_nil result
  end

  def test_check_explicit_rules_with_match
    # Add explicit rule
    @manager.set_explicit_rule(
      "深度审查规则",
      "^深入.*审查.*项目",
      "riper-workflow",
      priority: 100
    )

    input = "深入审查这个项目"
    result = @manager.check_explicit_rules(input)

    assert result
    assert_equal :explicit_rule, result[:type]
    assert_equal "riper-workflow", result[:skill]
    assert_equal 100, result[:priority]
  end

  def test_recognize_intent_with_llm_provider
    input = "帮我审查代码"
    context = { file_type: 'ruby' }

    result = @manager.recognize_intent(input, context)

    assert_equal "code_review", result
    assert_equal 1, @mock_provider.calls.size
  end

  def test_recognize_intent_caches_results
    input = "帮我审查代码"

    # First call
    result1 = @manager.recognize_intent(input)
    # Second call (should use cache)
    result2 = @manager.recognize_intent(input)

    assert_equal result1, result2
    # Should only call LLM once due to caching
    assert_equal 1, @mock_provider.calls.size
  end

  def test_match_preference_falls_back_to_explicit_rules
    # Add explicit rule
    @manager.set_explicit_rule(
      "测试规则",
      "^测试.*规则",
      "test-skill",
      priority: 50
    )

    input = "测试规则匹配"
    result = @manager.match_preference(input)

    assert result
    assert_equal :explicit_rule, result[:type]
    assert_equal "test-skill", result[:skill]
  end

  def test_record_selection
    input = "审查代码"
    skill = "gstack/review"
    route_result = {
      primary: { skill: "riper-workflow", confidence: 0.95 },
      intent: "code_review"
    }

    entry = @manager.record_selection(input, skill, route_result)

    assert_equal input, entry['input']
    assert_equal skill, entry['selected_skill']
    assert_equal "riper-workflow", entry['ai_recommended']
    refute entry['was_recommended']
    assert_equal "code_review", entry['intent']
  end

  def test_record_satisfaction
    # First record a selection
    input = "审查代码"
    skill = "gstack/review"
    route_result = {
      primary: { skill: skill, confidence: 0.95 },
      intent: "code_review"
    }

    @manager.record_selection(input, skill, route_result)
    @manager.record_satisfaction(skill, true)

    # Check history
    history = @manager.preferences['selection_history']
    assert_equal 1, history.size
    assert_equal true, history.last['user_satisfaction']
  end

  def test_stats
    # Add some selections
    3.times do
      @manager.record_selection("test", "skill-a", {
        primary: { skill: "skill-a", confidence: 0.9 },
        intent: "test"
      })
    end

    2.times do
      @manager.record_selection("test", "skill-b", {
        primary: { skill: "skill-a", confidence: 0.9 },
        intent: "test"
      })
    end

    stats = @manager.stats

    assert_equal 5, stats[:total_selections]
    assert_equal 3, stats[:skill_usage]["skill-a"]
    assert_equal 2, stats[:skill_usage]["skill-b"]
  end

  def test_set_intent_preference
    @manager.set_intent_preference("code_review", "gstack/plan-eng-review", confidence: 0.9)

    prefs = @manager.preferences['intent_preferences']
    assert_equal 1, prefs.size
    assert_equal "gstack/plan-eng-review", prefs.first['preferred_skill']
    assert_equal 0.9, prefs.first['confidence']
  end

  def test_set_explicit_rule
    @manager.set_explicit_rule(
      "测试规则",
      "^测试",
      "test-skill",
      priority: 80
    )

    rules = @manager.preferences['explicit_rules']
    assert_equal 1, rules.size
    assert_equal "测试规则", rules.first['name']
    assert_equal "^测试", rules.first['match_pattern']
    assert_equal 80, rules.first['priority']
  end

  def test_reset_clears_all_preferences
    # Add some preferences
    @manager.set_intent_preference("test", "skill-a")
    @manager.set_explicit_rule("test", "^test", "skill-b")

    # Reset
    @manager.reset

    # Check cleared
    assert_equal 0, @manager.preferences['intent_preferences'].size
    assert_equal 0, @manager.preferences['explicit_rules'].size
  end

  def test_handles_corrupted_preference_file
    # Write corrupted YAML
    File.write(@preference_file, "invalid: [yaml: content:")

    # Should load default preferences instead of crashing
    manager = Vibe::PreferenceManager.new(
      preference_file: @preference_file
    )

    assert manager.preferences
    assert_equal 1, manager.preferences['version']
  end
end
