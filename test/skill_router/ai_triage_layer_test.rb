# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../lib/vibe/llm_client'
require_relative '../../lib/vibe/cache_manager'
require_relative '../../lib/vibe/skill_router/ai_triage_layer'
require 'json'

class AITriageLayerTest < Minitest::Test
  def setup
    # Create test registry
    @registry = {
      'skills' => [
        {
          'id' => 'systematic-debugging',
          'namespace' => 'builtin',
          'intent' => 'Find root cause before attempting fixes',
          'description' => 'Systematic debugging workflow',
          'priority' => 'P0',
          'keywords' => ['debug', 'bug', 'error', '调试', '错误']
        },
        {
          'id' => 'gstack/investigate',
          'namespace' => 'gstack',
          'intent' => 'Systematic debugging with scope freeze',
          'description' => 'Root cause investigation with automatic scope protection',
          'priority' => 'P0',
          'keywords' => ['investigate', 'debug', 'bug']
        },
        {
          'id' => 'gstack/review',
          'namespace' => 'gstack',
          'intent' => 'Pre-landing code review with security checks',
          'description' => 'Comprehensive code review before merging',
          'priority' => 'P0',
          'keywords' => ['review', '检查', '审查']
        },
        {
          'id' => 'superpowers/refactor',
          'namespace' => 'superpowers',
          'intent' => 'Systematic code refactoring with safety checks',
          'description' => 'Safe refactoring workflow',
          'priority' => 'P1',
          'keywords' => ['refactor', '重构']
        }
      ]
    }

    # Create empty preferences
    @preferences = {
      'skill_usage' => {},
      'word_to_skill' => {}
    }

    # Create test components
    @cache = Vibe::CacheManager.new(
      cache_dir: Dir.mktmpdir,
      memory_cache_max_size: 100
    )
    @llm_client = MockLLMClient.new
    @layer = Vibe::SkillRouter::AITriageLayer.new(
      @registry,
      @preferences,
      cache: @cache,
      llm_client: @llm_client
    )
  end

  def teardown
    # Clean up temp directory
    FileUtils.rm_rf(@cache.cache_dir) if @cache && @cache.cache_dir
  end

  # Test 1: Cache hit
  def test_cache_hit_returns_cached_result
    input = "帮我调试这个 bug"
    context = { file_type: 'rb' }

    # Pre-populate cache
    cached_result = {
      matched: true,
      skill: 'systematic-debugging',
      confidence: :high,
      triage_source: :cache
    }
    @cache.set(generate_cache_key(input, context), cached_result)

    # Test
    result = @layer.route(input, context)

    assert_equal cached_result, result
    assert_equal :cache, result[:triage_source]
    assert_equal 0, @llm_client.call_count # Should not call LLM
  end

  # Test 2: AI analysis success
  def test_ai_analysis_returns_correct_skill
    input = "生产环境的 API 报错了，很紧急"
    context = { file_type: 'js', error_count: 5 }

    # Mock LLM response
    @llm_client.mock_response = JSON.generate({
      'skill' => 'gstack/investigate',
      'confidence' => 0.92,
      'reasoning' => '生产环境紧急问题适合系统性调试',
      'intent' => '调试',
      'urgency' => '紧急',
      'complexity' => '中等'
    })

    # Test
    result = @layer.route(input, context)

    assert_equal true, result[:matched]
    assert_equal 'gstack/investigate', result[:skill]
    assert_equal :high, result[:confidence]
    assert_equal true, result[:ai_triaged]
    assert_equal 1, @llm_client.call_count
    assert_equal '调试', result[:intent]
    assert_equal '紧急', result[:urgency]
  end

  # Test 3: Fallback on LLM error
  def test_fallback_on_llm_error
    input = "测试请求"
    context = {}

    # Mock LLM error
    @llm_client.raise_error = StandardError.new("API Error")

    # Test - should return nil and not crash
    result = @layer.route(input, context)

    assert_nil result
    assert_equal 1, @layer.stats[:failure_count]
  end

  # Test 4: Quick algorithm match
  def test_quick_algorithm_match_for_explicit_command
    input = "用 gstack 调试"
    context = {}

    # Test - should match without calling LLM
    result = @layer.route(input, context)

    assert_equal true, result[:matched]
    assert_equal 'gstack/investigate', result[:skill]
    assert_equal :algorithm, result[:triage_source]
    assert_equal 0, @llm_client.call_count # Should not call LLM
  end

  # Test 5: Low confidence returns nil
  def test_low_confidence_returns_nil
    input = "模糊的请求"
    context = {}

    # Mock LLM response with low confidence
    @llm_client.mock_response = JSON.generate({
      'skill' => 'some-skill',
      'confidence' => 0.5, # Below threshold (0.7)
      'reasoning' => 'Not confident'
    })

    # Test
    result = @layer.route(input, context)

    assert_nil result
  end

  # Test 6: Cache statistics
  def test_cache_statistics
    # Set some cache entries
    @cache.set('key1', { value: 'data1' }, ttl: 3600)
    @cache.set('key2', { value: 'data2' }, ttl: 7200)

    # Get statistics
    stats = @cache.stats

    assert_equal 2, stats[:total_entries]
    assert_equal 0, stats[:total_hits] # No hits yet
    assert stats[:total_size_bytes] > 0
  end

  # Test 7: Cache expiration
  def test_cache_expiration
    # Set entry with short TTL
    @cache.set('expiring_key', { value: 'data' }, ttl: 1)

    # Should exist immediately
    assert @cache.exist?('expiring_key')

    # Wait for expiration
    sleep 2

    # Should be expired now
    refute @cache.exist?('expiring_key')
  end

  # Test 8: Feature flag
  def test_feature_flag_disables_ai_triage
    # Create disabled layer
    disabled_layer = Vibe::SkillRouter::AITriageLayer.new(
      @registry,
      @preferences,
      cache: @cache,
      llm_client: @llm_client
    )

    # Mock environment
    disabled_layer.instance_variable_set(:@enabled, false)

    # Test
    result = disabled_layer.route("any input", {})

    assert_nil result
  end

  # Test 9: LLMClient configuration check
  def test_llm_client_requires_api_key
    # This should raise an error
    assert_raises(ArgumentError) do
      Vibe::LLMClient.new(api_key: nil)
    end
  end

  # Test 10: Skill matching with context boost
  def test_context_boost_influences_matching
    input = "审查代码"
    context = { file_type: 'js' }

    # Add a skill that prefers JS files
    @registry['skills'] << {
      'id' => 'javascript-expert-review',
      'namespace' => 'custom',
      'intent' => 'JavaScript code review',
      'description' => 'Expert review for JavaScript code',
      'priority' => 'P1',
      'file_types' => ['js', 'ts']
    }

    # Mock LLM response
    @llm_client.mock_response = JSON.generate({
      'skill' => 'javascript-expert-review',
      'confidence' => 0.75,
      'reasoning' => '匹配文件类型和技能'
    })

    # Test
    result = @layer.route(input, context)

    assert_equal true, result[:matched]
    assert_equal 'javascript-expert-review', result[:skill]
  end

  private

  def generate_cache_key(input, context)
    # Simplified version for testing
    base = "#{input}:#{context.sort.to_h}"
    Digest::SHA256.hexdigest(base)[0..16]
  end

  # Mock LLM client for testing
  class MockLLMClient
    attr_accessor :mock_response, :raise_error, :call_count

    def initialize
      @call_count = 0
      @mock_response = nil
      @raise_error = nil
    end

    def call(model:, prompt:, max_tokens: 300, temperature: 0.3)
      @call_count += 1

      raise @raise_error if @raise_error

      return @mock_response if @mock_response

      # Default response
      JSON.generate({
        'skill' => 'systematic-debugging',
        'confidence' => 0.8,
        'reasoning' => 'Default response'
      })
    end

    def configured?
      true
    end
  end
end
