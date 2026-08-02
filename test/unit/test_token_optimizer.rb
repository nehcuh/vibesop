# frozen_string_literal: true

require "minitest/autorun"
require_relative "../../lib/vibe/token_optimizer"

class TestTokenOptimizer < Minitest::Test
  def setup
    @optimizer = Vibe::TokenOptimizer.new
  end

  def test_estimate_tokens_english
    text = "Hello world this is a test"
    tokens = @optimizer.estimate_tokens(text)
    assert tokens > 0, "Should estimate tokens for English text"
    assert tokens < text.split.size * 2, "Token estimate should be reasonable"
  end

  def test_estimate_tokens_chinese
    text = "这是一个测试文本"
    tokens = @optimizer.estimate_tokens(text)
    assert tokens > 0, "Should estimate tokens for Chinese text"
  end

  def test_estimate_tokens_mixed
    text = "Hello 世界 this is 测试"
    tokens = @optimizer.estimate_tokens(text)
    assert tokens > 0, "Should estimate tokens for mixed language text"
  end

  def test_estimate_tokens_empty
    assert_equal 0, @optimizer.estimate_tokens("")
    assert_equal 0, @optimizer.estimate_tokens(nil)
  end

  def test_analyze_basic
    content = <<~MD
      # Section 1
      This is content for section 1.

      # Section 2
      This is content for section 2.
    MD

    result = @optimizer.analyze(content)

    assert result[:total_tokens] > 0
    assert result[:total_words] > 0
    assert result[:total_lines] > 0
    assert_equal 2, result[:sections].size
  end

  def test_detect_redundancies
    content = <<~MD
      This is a duplicate line that appears multiple times.
      Some other content here.
      This is a duplicate line that appears multiple times.
      More content.
      This is a duplicate line that appears multiple times.
    MD

    result = @optimizer.analyze(content)
    redundancies = result[:redundancies]

    assert redundancies.size > 0, "Should detect duplicate lines"
    assert redundancies.first[:count] > 1, "Should count duplicates"
  end

  def test_compress_whitespace
    content = "Hello    world\n\n\n\nTest"
    result = @optimizer.optimize(content, compress_whitespace: true)

    optimized = result[:content]
    refute optimized.include?("    "), "Should remove multiple spaces"
    refute optimized.include?("\n\n\n\n"), "Should compress multiple newlines"
    assert result[:savings_tokens] >= 0, "Should save tokens"
  end

  def test_remove_redundancies
    content = <<~MD
      This is a unique line.
      This is a duplicate line that should be removed on second occurrence.
      Another unique line.
      This is a duplicate line that should be removed on second occurrence.
    MD

    result = @optimizer.optimize(content, remove_redundancies: true)
    optimized = result[:content]

    # Count occurrences of the duplicate line
    count = optimized.scan(/duplicate line that should be removed/).size
    assert_equal 1, count, "Should remove duplicate lines"
  end

  def test_selective_load
    content = <<~MD
      # Configuration Section
      This is configuration content.

      # Database Section
      This is database content.

      # Security Section
      This is security content.
    MD

    result = @optimizer.optimize(content, selective_load: ["Configuration", "Security"])
    optimized = result[:content]

    assert optimized.include?("Configuration Section"), "Should include selected sections"
    assert optimized.include?("Security Section"), "Should include selected sections"
    refute optimized.include?("Database Section"), "Should exclude non-selected sections"
  end

  def test_optimize_combined
    content = <<~MD
      # Section 1
      This is some content with    extra spaces.



      This is a duplicate line.
      This is a duplicate line.

      # Section 2
      More content here.
    MD

    result = @optimizer.optimize(content,
      compress_whitespace: true,
      remove_redundancies: true
    )

    assert result[:original_tokens] > result[:optimized_tokens], "Should reduce tokens"
    assert result[:savings_percent] > 0, "Should show savings percentage"
  end

  def test_whitespace_ratio
    content = "Hello     world\n\n\n\nTest"
    result = @optimizer.analyze(content)

    assert result[:whitespace_ratio] > 0, "Should calculate whitespace ratio"
    assert result[:whitespace_ratio] <= 100, "Ratio should be percentage"
  end

  def test_stats_tracking
    content = "Test content for optimization"

    @optimizer.optimize(content, compress_whitespace: true)
    @optimizer.optimize(content, compress_whitespace: true)

    assert_equal 2, @optimizer.stats[:total_optimized], "Should track optimization count"
    assert_equal 2, @optimizer.stats[:savings].size, "Should track savings"
  end
end
