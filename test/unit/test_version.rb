# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../lib/vibe/version'

class TestVersion < Minitest::Test
  def test_version_constant_exists
    assert Vibe.const_defined?(:VERSION)
  end

  def test_version_is_string
    assert Vibe::VERSION.is_a?(String)
  end

  def test_version_follows_semver_format
    assert_match(/^\d+\.\d+\.\d+/, Vibe::VERSION)
  end

  def test_version_is_not_empty
    refute_empty Vibe::VERSION
  end

  def test_version_has_three_parts
    parts = Vibe::VERSION.split('.')
    assert_equal 3, parts.length
  end

  def test_version_parts_are_numeric
    parts = Vibe::VERSION.split('.')
    parts.each do |part|
      # Remove any non-numeric suffixes (like -rc1, -beta, etc.)
      numeric_part = part.match(/^\d+/)[0]
      assert_match(/^\d+$/, numeric_part)
    end
  end
end
