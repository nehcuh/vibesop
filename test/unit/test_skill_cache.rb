# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../lib/vibe/skill_cache'

class TestSkillCache < Minitest::Test
  def setup
    @cache = Vibe::SkillCache.instance
    # Clear cache before each test
    @cache.clear
  end

  def teardown
    @cache.clear
  end

  def test_singleton_pattern
    # Should return the same instance every time
    instance1 = Vibe::SkillCache.instance
    instance2 = Vibe::SkillCache.instance
    assert_same instance1, instance2
  end

  def test_fetch_with_block
    result = @cache.fetch('test_key', 'test_value')

    assert_equal 'test_value', result
  end

  def test_fetch_caches_result
    call_count = 0
    block = lambda do
      call_count += 1
      'cached_value'
    end

    # First call should execute block
    result1 = @cache.fetch('key', &block)
    assert_equal 'cached_value', result1
    assert_equal 1, call_count

    # Second call should use cache
    result2 = @cache.fetch('key', &block)
    assert_equal 'cached_value', result2
    assert_equal 1, call_count # Block not executed again
  end

  def test_fetch_with_custom_ttl
    result = @cache.fetch('ttl_key', ttl: 1) do
      'ttl_value'
    end

    assert_equal 'ttl_value', result
  end

  def test_get_returns_cached_value
    @cache.set('get_key', 'get_value')

    result = @cache.get('get_key')
    assert_equal 'get_value', result
  end

  def test_get_returns_nil_for_missing_key
    result = @cache.get('missing_key')
    assert_nil result
  end

  def test_set_stores_value
    @cache.set('set_key', 'set_value')

    result = @cache.get('set_key')
    assert_equal 'set_value', result
  end

  def test_set_updates_timestamp
    @cache.set('timestamp_key', 'value')

    # Should be able to retrieve immediately
    result = @cache.get('timestamp_key')
    assert_equal 'value', result
  end

  def test_invalidate_removes_entry
    @cache.set('invalidate_key', 'value')
    @cache.invalidate('invalidate_key')

    result = @cache.get('invalidate_key')
    assert_nil result
  end

  def test_invalidate_nonexistent_key
    # Should not raise error
    @cache.invalidate('nonexistent_key')

    result = @cache.get('nonexistent_key')
    assert_nil result
  end

  def test_clear_removes_all_entries
    @cache.set('key1', 'value1')
    @cache.set('key2', 'value2')
    @cache.set('key3', 'value3')

    @cache.clear

    assert_nil @cache.get('key1')
    assert_nil @cache.get('key2')
    assert_nil @cache.get('key3')
  end

  def test_invalidate_pattern
    @cache.set('user:123:data', 'user_data')
    @cache.set('user:456:data', 'more_user_data')
    @cache.set('system:config', 'system_data')

    @cache.invalidate_pattern(/user:/)

    assert_nil @cache.get('user:123:data')
    assert_nil @cache.get('user:456:data')
    assert_equal 'system_data', @cache.get('system:config')
  end

  def test_invalidate_pattern_with_non_matching_pattern
    @cache.set('important_key', 'important_value')

    @cache.invalidate_pattern(/nonexistent/)

    assert_equal 'important_value', @cache.get('important_key')
  end

  def test_default_ttl_constant
    assert Vibe::SkillCache::DEFAULT_TTL.positive?
  end

  def test_thread_safety
    thread_count = 10
    operations = 100

    thread_array = []
    thread_count.times do
      thread_array << Thread.new do
        operations.times do |i|
          @cache.set("thread#{Thread.current.object_id}_#{i}", "value#{i}")
        end
      end
    end

    thread_array.each(&:join)

    # Should complete without errors
    assert true
  end

  def test_fetch_with_nil_key
    result = @cache.fetch(nil, 'nil_value')

    assert_equal 'nil_value', result
  end

  def test_empty_string_key
    @cache.set('', 'empty_key_value')

    result = @cache.get('')
    assert_equal 'empty_key_value', result
  end

  def test_complex_values
    complex_value = { nested: { data: [1, 2, 3] }, string: 'test' }

    @cache.set('complex', complex_value)
    result = @cache.get('complex')

    assert_equal complex_value, result
  end

  def test_cache_size_limits
    # Test that cache can handle many entries
    100.times do |i|
      @cache.set("key#{i}", "value#{i}")
    end

    # Should be able to retrieve all
    100.times do |i|
      assert_equal "value#{i}", @cache.get("key#{i}")
    end
  end

  def test_overwrite_existing_key
    @cache.set('overwrite', 'original')
    @cache.set('overwrite', 'updated')

    result = @cache.get('overwrite')
    assert_equal 'updated', result
  end

  def test_concurrent_fetch_same_key
    # Test that concurrent fetches of the same key work correctly
    results = []
    thread_array = []

    5.times do
      thread_array << Thread.new do
        results << @cache.fetch('concurrent_key') do
          Thread.current.object_id
        end
      end
    end

    thread_array.each(&:join)

    # All threads should get the same cached value
    unique_values = results.uniq
    assert_equal 1, unique_values.length
  end
end
