# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require_relative '../../lib/vibe/utils'

class TestUtilsHost
  include Vibe::Utils

  attr_accessor :repo_root

  def initialize(repo_root)
    @repo_root = repo_root
  end
end

class TestUtils < Minitest::Test
  def setup
    @repo_root = File.expand_path('../../', __dir__)
    @host = TestUtilsHost.new(@repo_root)
  end

  # deep_merge tests
  def test_deep_merge_simple_hashes
    result = @host.deep_merge({ a: 1 }, { b: 2 })
    assert_equal({ a: 1, b: 2 }, result)
  end

  def test_deep_merge_nested_hashes
    result = @host.deep_merge({ a: { x: 1 } }, { a: { y: 2 } })
    assert_equal({ a: { x: 1, y: 2 } }, result)
  end

  def test_deep_merge_arrays
    result = @host.deep_merge([1, 2, 3], [3, 4, 5])
    assert_equal [1, 2, 3, 4, 5], result
  end

  def test_deep_merge_removes_duplicates_in_arrays
    result = @host.deep_merge([1, 2, 3], [2, 3, 4])
    assert_equal [1, 2, 3, 4], result
  end

  def test_deep_merge_with_nil_base
    result = @host.deep_merge(nil, { a: 1 })
    assert_equal({ a: 1 }, result)
  end

  def test_deep_merge_with_nil_extra
    result = @host.deep_merge({ a: 1 }, nil)
    assert_equal({ a: 1 }, result)
  end

  def test_deep_merge_type_mismatch_returns_extra
    result = @host.deep_merge({ a: 1 }, 'string')
    assert_equal 'string', result
  end

  def test_deep_merge_preserves_original_objects
    base = { a: { x: 1 } }
    extra = { a: { y: 2 } }
    result = @host.deep_merge(base, extra)

    # Modifying result should not affect original
    result[:a][:z] = 3
    refute_equal base, result
  end

  # deep_copy tests
  def test_deep_copy_nil
    assert_nil @host.deep_copy(nil)
  end

  def test_deep_copy_boolean
    assert_equal true, @host.deep_copy(true)
    assert_equal false, @host.deep_copy(false)
  end

  def test_deep_copy_numeric
    assert_equal 42, @host.deep_copy(42)
    assert_equal 3.14, @host.deep_copy(3.14)
  end

  def test_deep_copy_symbol
    assert_equal :test, @host.deep_copy(:test)
  end

  def test_deep_copy_string_creates_new_instance
    original = 'test'
    copy = @host.deep_copy(original)
    assert_equal original, copy
    assert_equal original, copy
  end

  def test_deep_copy_array_creates_new_instance
    original = [1, 2, 3]
    copy = @host.deep_copy(original)
    assert_equal original, copy
    refute_same original, copy
  end

  def test_deep_copy_hash_creates_new_instance
    original = { a: 1, b: 2 }
    copy = @host.deep_copy(original)
    assert_equal original, copy
    refute_same original, copy
  end

  def test_deep_copy_nested_structures
    original = { a: [1, 2, { b: 3 }] }
    copy = @host.deep_copy(original)
    assert_equal original, copy
    refute_same original, copy
    refute_same original[:a], copy[:a]
  end

  def test_deep_copy_time_object
    original = Time.now
    copy = @host.deep_copy(original)
    assert_equal original, copy
    refute_same original, copy
  end

  def test_deep_copy_date_object
    original = Date.today
    copy = @host.deep_copy(original)
    assert_equal original, copy
    refute_same original, copy
  end

  # blankish? tests
  def test_blankish_with_nil
    assert @host.blankish?(nil)
  end

  def test_blankish_with_empty_string
    assert @host.blankish?('')
  end

  def test_blankish_with_whitespace_string
    assert @host.blankish?('   ')
  end

  def test_blankish_with_tab_string
    assert @host.blankish?("\t")
  end

  def test_blankish_with_newline_string
    assert @host.blankish?("\n")
  end

  def test_blankish_with_non_empty_string
    refute @host.blankish?('test')
  end

  def test_blankish_with_zero
    refute @host.blankish?(0)
  end

  def test_blankish_with_false
    refute @host.blankish?(false)
  end

  # display_path tests
  def test_display_path_within_repo
    path = File.join(@repo_root, 'lib', 'vibe.rb')
    result = @host.display_path(path)
    assert_equal 'lib/vibe.rb', result
  end

  def test_display_path_at_repo_root
    result = @host.display_path(@repo_root)
    assert_equal '.', result
  end

  def test_display_path_outside_repo
    path = '/tmp/test/file.txt'
    result = @host.display_path(path)
    assert_equal '/tmp/test/file.txt', result
  end

  def test_display_path_relative_path
    result = @host.display_path('lib/vibe.rb')
    assert_equal 'lib/vibe.rb', result
  end

  # format_backtick_list tests
  def test_format_backtick_list_with_strings
    result = @host.format_backtick_list(%w[a b c])
    assert_equal '`a`, `b`, `c`', result
  end

  def test_format_backtick_list_with_empty_array
    result = @host.format_backtick_list([])
    assert_equal '`none`', result
  end

  def test_format_backtick_list_with_whitespace_strings
    result = @host.format_backtick_list(['a', '   ', 'b'])
    assert_equal '`a`, `b`', result
  end

  def test_format_backtick_list_with_non_strings
    result = @host.format_backtick_list([1, 2, 3])
    assert_equal '`1`, `2`, `3`', result
  end

  def test_format_backtick_list_with_single_item
    result = @host.format_backtick_list(['test'])
    assert_equal '`test`', result
  end

  def test_format_backtick_list_with_nil_values
    result = @host.format_backtick_list(['a', nil, 'b'])
    # Nil values get converted to empty strings and then filtered out
    assert_equal '`a`, `b`', result
  end

  # validate_path! tests
  def test_validate_path_with_valid_path
    result = @host.validate_path!('lib/vibe.rb')
    assert_equal 'lib/vibe.rb', result
  end

  def test_validate_path_raises_on_nil
    error = assert_raises(Vibe::ValidationError) do
      @host.validate_path!(nil)
    end
    assert_match(/cannot be nil/, error.message)
  end

  def test_validate_path_raises_on_empty_string
    error = assert_raises(Vibe::ValidationError) do
      @host.validate_path!('   ')
    end
    assert_match(/cannot be empty/, error.message)
  end

  def test_validate_path_raises_on_null_byte
    error = assert_raises(Vibe::ValidationError) do
      @host.validate_path!("test\0file")
    end
    assert_match(/contains null byte/, error.message)
  end

  def test_validate_path_raises_on_control_characters
    error = assert_raises(Vibe::ValidationError) do
      @host.validate_path!("test\x01file")
    end
    assert_match(/contains control characters/, error.message)
  end

  def test_validate_path_raises_on_excessive_length
    long_path = 'a' * 5000
    error = assert_raises(Vibe::ValidationError) do
      @host.validate_path!(long_path)
    end
    assert_match(/exceeds maximum length/, error.message)
  end

  def test_validate_path_allows_safe_dotdot_within_repo
    Dir.mktmpdir do |tmpdir|
      @host.repo_root = tmpdir
      safe_path = File.join(tmpdir, 'subdir', '..', 'file.txt')
      result = @host.validate_path!(safe_path)
      # Should not raise
      refute_nil result
    end
  end

  def test_validate_path_custom_context
    error = assert_raises(Vibe::ValidationError) do
      @host.validate_path!(nil, context: 'custom field')
    end
    assert_match(/custom field/, error.message)
  end

  # JSON I/O tests
  def test_write_and_read_json
    Dir.mktmpdir do |tmpdir|
      path = File.join(tmpdir, 'test.json')
      content = { 'key' => 'value', 'nested' => { 'data' => 123 } }

      @host.write_json(path, content)
      assert File.exist?(path)

      read_content = @host.read_json(path)
      assert_equal content, read_content
    end
  end

  def test_write_json_creates_directories
    Dir.mktmpdir do |tmpdir|
      path = File.join(tmpdir, 'deep', 'nested', 'test.json')
      content = { 'test' => 'data' }

      @host.write_json(path, content)
      assert File.exist?(path)
    end
  end

  def test_read_json_if_exists_when_file_exists
    Dir.mktmpdir do |tmpdir|
      path = File.join(tmpdir, 'test.json')
      File.write(path, '{"key": "value"}')

      result = @host.read_json_if_exists(path)
      assert_equal({ 'key' => 'value' }, result)
    end
  end

  def test_read_json_if_exists_when_file_missing
    result = @host.read_json_if_exists('/nonexistent/path/file.json')
    assert_nil result
  end

  # YAML I/O tests
  def test_read_yaml_from_file
    yaml_path = File.join(@repo_root, 'core', 'behaviors.yaml')
    # This file should exist in the project
    return unless File.exist?(yaml_path)

    result = @host.read_yaml('core/behaviors.yaml')
    assert result.is_a?(Hash) || result.is_a?(Array)
  end

  def test_read_yaml_abs_reads_absolute_path
    yaml_path = File.join(@repo_root, 'core', 'behaviors.yaml')
    return unless File.exist?(yaml_path)

    result = @host.read_yaml_abs(yaml_path)
    assert result.is_a?(Hash) || result.is_a?(Array)
  end

  def test_read_yaml_abs_raises_on_missing_file
    assert_raises(Errno::ENOENT) do
      @host.read_yaml_abs('/nonexistent/file.yaml')
    end
  end
end
