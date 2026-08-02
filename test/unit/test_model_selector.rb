# frozen_string_literal: true

require "minitest/autorun"
require_relative "../../lib/vibe/model_selector"

class TestModelSelector < Minitest::Test
  def setup
    @selector = Vibe::ModelSelector.new
  end

  def test_evaluate_complexity_simple
    complexity = @selector.evaluate_complexity("show status", file_count: 1, line_count: 20)
    assert_equal :simple, complexity
  end

  def test_evaluate_complexity_medium
    complexity = @selector.evaluate_complexity("refactor user module", file_count: 5, line_count: 200)
    assert_equal :medium, complexity
  end

  def test_evaluate_complexity_complex
    complexity = @selector.evaluate_complexity("design authentication system", file_count: 15, line_count: 1000)
    assert_equal :complex, complexity
  end

  def test_evaluate_complexity_with_tests
    complexity = @selector.evaluate_complexity("update function", file_count: 2, line_count: 50, has_tests: true)
    assert_includes [:medium, :simple], complexity
  end

  def test_select_model_simple
    model = @selector.select_model(:simple)
    assert_equal "haiku", model
  end

  def test_select_model_medium
    model = @selector.select_model(:medium)
    assert_equal "sonnet", model
  end

  def test_select_model_complex
    model = @selector.select_model(:complex)
    assert_equal "opus", model
  end

  def test_fallback_model_opus
    fallback = @selector.fallback_model("opus")
    assert_equal "sonnet", fallback
  end

  def test_fallback_model_sonnet
    fallback = @selector.fallback_model("sonnet")
    assert_equal "haiku", fallback
  end

  def test_fallback_model_haiku
    fallback = @selector.fallback_model("haiku")
    assert_nil fallback
  end

  def test_recommend_simple_task
    result = @selector.recommend("list files", file_count: 1)

    assert_equal "haiku", result[:model]
    assert_equal :simple, result[:complexity]
    assert result[:reasoning].length > 0
    assert_nil result[:fallback]  # haiku has no fallback
  end

  def test_recommend_medium_task
    result = @selector.recommend("refactor code", file_count: 5, line_count: 300)

    assert_equal "sonnet", result[:model]
    assert_equal :medium, result[:complexity]
    assert_equal "haiku", result[:fallback]
  end

  def test_recommend_complex_task
    result = @selector.recommend("architect new system", file_count: 20)

    assert_equal "opus", result[:model]
    assert_equal :complex, result[:complexity]
    assert_equal "sonnet", result[:fallback]
  end

  def test_keyword_detection_simple
    complexity = @selector.evaluate_complexity("check status and list items")
    assert_equal :simple, complexity
  end

  def test_keyword_detection_medium
    complexity = @selector.evaluate_complexity("edit and update the configuration", file_count: 3, line_count: 150)
    assert_equal :medium, complexity
  end

  def test_keyword_detection_complex
    complexity = @selector.evaluate_complexity("debug security issues in the system", file_count: 10, line_count: 500)
    assert_equal :complex, complexity
  end

  def test_stats_tracking
    @selector.evaluate_complexity("test task")
    @selector.select_model(:simple)
    @selector.fallback_model("opus")

    assert_equal 1, @selector.stats[:total_evaluations]
    assert_equal 1, @selector.stats[:selections]["haiku"]
    assert_equal 1, @selector.stats[:fallbacks]["opus"]
  end

  def test_empty_description
    complexity = @selector.evaluate_complexity("", file_count: 0, line_count: 0)
    assert_equal :simple, complexity
  end

  def test_nil_description
    complexity = @selector.evaluate_complexity(nil, file_count: 0, line_count: 0)
    assert_equal :simple, complexity
  end
end
