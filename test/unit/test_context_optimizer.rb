# frozen_string_literal: true

require "minitest/autorun"
require_relative "../../lib/vibe/context_optimizer"

class TestContextOptimizer < Minitest::Test
  def setup
    @opt = Vibe::ContextOptimizer.new
  end

  # ── token estimation ──────────────────────────────────────────────────────────

  def test_empty_string_is_zero
    assert_equal 0, @opt.estimate_tokens("")
  end

  def test_nil_is_zero
    assert_equal 0, @opt.estimate_tokens(nil)
  end

  def test_english_words
    # 4 words * 0.75 = 3 tokens
    tokens = @opt.estimate_tokens("hello world foo bar")
    assert_equal 3, tokens
  end

  def test_chinese_chars
    # 4 CJK chars * 0.5 = 2 tokens
    tokens = @opt.estimate_tokens("你好世界")
    assert_equal 2, tokens
  end

  def test_mixed_text
    tokens = @opt.estimate_tokens("hello 你好")
    assert tokens > 0
  end

  # ── add and stats ─────────────────────────────────────────────────────────────

  def test_add_returns_self_for_chaining
    result = @opt.add("a", "some content")
    assert_same @opt, result
  end

  def test_stats_empty
    s = @opt.stats
    assert_equal 0, s[:block_count]
    assert_equal 0, s[:total_tokens]
  end

  def test_stats_after_add
    @opt.add("a", "hello world", priority: :high)
    @opt.add("b", "foo bar baz", priority: :low)
    s = @opt.stats
    assert_equal 2, s[:block_count]
    assert s[:total_tokens] > 0
    assert s[:by_priority][:high]
    assert s[:by_priority][:low]
  end

  # ── build_package ─────────────────────────────────────────────────────────────

  def test_all_fit_within_budget
    @opt.add("a", "hello world", priority: :high)
    @opt.add("b", "foo bar",     priority: :low)
    pkg = @opt.build_package(budget: 10_000)
    assert_equal 2, pkg[:included].length
    assert_empty pkg[:excluded]
  end

  def test_high_priority_included_over_low
    # Add a low-priority block that would push us over budget, and a high-priority one
    big_low = "word " * 200   # ~150 tokens
    @opt.add("big",  big_low,       priority: :low)
    @opt.add("small", "hello world", priority: :high)

    pkg = @opt.build_package(budget: 10)
    included_ids = pkg[:included].map { |b| b[:id] }
    assert_includes included_ids, "small"
    refute_includes included_ids, "big"
  end

  def test_required_ids_always_included
    @opt.add("must", "hello world", priority: :low)
    @opt.add("opt",  "word " * 200, priority: :critical)

    pkg = @opt.build_package(budget: 5, required_ids: ["must"])
    included_ids = pkg[:included].map { |b| b[:id] }
    assert_includes included_ids, "must"
  end

  def test_utilization_is_percentage
    @opt.add("a", "hello world", priority: :high)
    pkg = @opt.build_package(budget: 100)
    assert pkg[:utilization] >= 0
    assert pkg[:utilization] <= 100
  end

  def test_warning_when_required_exceeds_budget
    @opt.add("big", "word " * 500, priority: :critical)
    pkg = @opt.build_package(budget: 1, required_ids: ["big"])
    assert pkg[:warning]
  end

  # ── compress ──────────────────────────────────────────────────────────────────

  def test_compress_removes_consecutive_blanks
    text = "line1\n\n\n\nline2"
    result = @opt.compress(text)
    refute_match(/\n{3,}/, result)
  end

  def test_compress_removes_filler
    text = "Please note that this is important. Basically it works."
    result = @opt.compress(text)
    refute_match(/please note that/i, result)
    refute_match(/basically/i, result)
  end

  def test_compress_preserves_content
    text = "def foo\n  bar\nend"
    result = @opt.compress(text)
    assert_includes result, "def foo"
    assert_includes result, "bar"
  end
end
