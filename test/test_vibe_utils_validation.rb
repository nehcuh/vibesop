#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative "test_helper"
require_relative "../lib/vibe/utils"

class UtilsHost
  include Vibe::Utils

  def initialize(repo_root)
    @repo_root = repo_root
  end
end

class TestVibeUtilsValidation < Minitest::Test
  def setup
    @host = UtilsHost.new("/fake/repo")
  end

  def test_deep_merge_validates_base_type
    error = assert_raises(Vibe::ValidationError) do
      @host.deep_merge("invalid", {})
    end
    assert_includes error.message, "base must be a Hash, Array, or nil"
  end

  def test_deep_merge_validates_extra_type
    error = assert_raises(Vibe::ValidationError) do
      @host.deep_merge({}, "invalid")
    end
    assert_includes error.message, "extra must be a Hash, Array, or nil"
  end

  def test_deep_merge_accepts_nil_base
    result = @host.deep_merge(nil, { a: 1 })
    assert_equal({ a: 1 }, result)
  end

  def test_deep_merge_accepts_nil_extra
    result = @host.deep_merge({ a: 1 }, nil)
    assert_equal({ a: 1 }, result)
  end

  def test_deep_merge_validates_base_with_numeric
    error = assert_raises(Vibe::ValidationError) do
      @host.deep_merge(123, {})
    end
    assert_includes error.message, "base must be a Hash, Array, or nil"
  end

  def test_deep_merge_validates_extra_with_numeric
    error = assert_raises(Vibe::ValidationError) do
      @host.deep_merge({}, 456)
    end
    assert_includes error.message, "extra must be a Hash, Array, or nil"
  end
end
