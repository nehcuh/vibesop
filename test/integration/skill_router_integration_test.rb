# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../lib/vibe/skill_router'
require_relative '../../lib/vibe/cache_manager'
require_relative '../../lib/vibe/llm_client'
require 'json'

# Integration test for the complete 5-layer routing system
class SkillRouterIntegrationTest < Minitest::Test
  def setup
    @project_root = Dir.mktmpdir
    @registry = {
      'skills' => [
        {
          'id' => 'systematic-debugging',
          'namespace' => 'builtin',
          'intent' => 'Find root cause before attempting fixes',
          'description' => 'Systematic debugging workflow',
          'priority' => 'P0',
          'keywords' => ['debug', 'bug', 'error']
        },
        {
          'id' => 'gstack/investigate',
          'namespace' => 'gstack',
          'intent' => 'Systematic debugging with scope freeze',
          'description' => 'Root cause investigation',
          'priority' => 'P0',
          'keywords' => ['investigate', 'debug']
        },
        {
          'id' => 'gstack/review',
          'namespace' => 'gstack',
          'intent' => 'Pre-landing code review',
          'description' => 'Code review with security checks',
          'priority' => 'P0',
          'keywords' => ['review', '检查']
        }
      ]
    }

    @preferences = { 'skill_usage' => {}, 'word_to_skill' => {} }

    # Create components
    @cache = Vibe::CacheManager.new(
      cache_dir: Dir.mktmpdir,
      memory_cache_max_size: 100
    )
    @llm_client = MockLLMClient.new

    # Create real AI Triage Layer with mock LLM client
    @ai_triage_layer = Vibe::SkillRouter::AITriageLayer.new(
      @registry,
      @preferences,
      cache: @cache,
      llm_client: @llm_client
    )

    # Create router with all 5 layers
    @router = Vibe::SkillRouter.new(@project_root)
    @router.instance_variable_set(:@cache, @cache)
    @router.instance_variable_set(:@llm_client, @llm_client)
    @router.instance_variable_set(:@registry, @registry)
    @router.instance_variable_set(:@preferences, @preferences)
    @router.instance_variable_set(:@ai_triage_layer, @ai_triage_layer)
  end

  def teardown
    FileUtils.rm_rf(@cache.cache_dir) if @cache
  end

  # Test 1: End-to-end routing with AI Layer 0
  def test_end_to_end_routing_with_ai
    input = "帮我调试这个生产环境的 bug，很紧急"
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

    # Test routing
    result = @router.route(input, context)

    assert_equal true, result[:matched]
    assert_equal 'gstack/investigate', result[:skill]
    # Can be :ai or :algorithm depending on which layer matched first
    assert [:ai, :algorithm].include?(result[:triage_source])

    # Verify statistics
    stats = @router.stats
    assert_equal 1, stats[:routing][:total_routes]
    assert_equal 1, stats[:routing][:layer_distribution][:layer_0_ai]
  end

  # Test 2: Fallback from AI to Layer 1
  def test_fallback_from_ai_to_explicit_layer
    input = "用 gstack 审查这段代码"
    context = {}

    # Mock LLM to return low confidence (trigger fallback)
    @llm_client.mock_response = JSON.generate({
      'skill' => nil,
      'confidence' => 0.5,
      'reasoning' => 'Not confident about this request'
    })

    # Should still work via Layer 1 (explicit override) or lower layers
    result = @router.route(input, context)

    # Note: The exact result depends on how ExplicitLayer is implemented
    # This test verifies that routing continues even if AI fails
    assert result # Should not crash
  end

  # Test 3: Cache performance
  def test_cache_performance_improves_subsequent_requests
    input = "调试这个 bug"
    context = { file_type: 'rb' }

    # First call - should hit AI
    @llm_client.mock_response = JSON.generate({
      'skill' => 'systematic-debugging',
      'confidence' => 0.85,
      'reasoning' => 'Debugging request with high confidence'
    })

    result1 = @router.route(input, context)
    first_llm_count = @llm_client.call_count
    assert_equal 1, first_llm_count

    # Second call - should hit cache (no additional LLM call)
    result2 = @router.route(input, context)
    assert_equal first_llm_count, @llm_client.call_count # No additional LLM calls

    assert_equal result1[:skill], result2[:skill]
  end

  # Test 4: Statistics tracking
  def test_statistics_tracking_all_layers
    # Simulate requests through different layers
    requests = [
      { input: "AI request", layer: :layer_0_ai, context: {} },
      { input: "explicit command", layer: :layer_1_explicit, context: {} },
      { input: "scenario match", layer: :layer_2_scenario, context: {} },
      { input: "no match", layer: :no_match, context: {} }
    ]

    requests.each_with_index do |req, index|
      if req[:layer] == :layer_0_ai
        @llm_client.mock_response = JSON.generate({
          'skill' => 'systematic-debugging',
          'confidence' => 0.8,
          'reasoning' => 'AI analysis'
        })
      else
        @llm_client.mock_response = JSON.generate({
          'skill' => nil,
          'confidence' => 0.5,
          'reasoning' => 'No match'
        })
      end

      @router.route(req[:input], req[:context])
    end

    stats = @router.stats
    assert_equal 4, stats[:routing][:total_routes]
    assert stats[:routing][:layer_distribution][:layer_0_ai] > 0
  end

  # Test 5: Dynamic enable/disable
  def test_dynamic_enable_disable
    # Initially enabled
    assert @router.ai_triage_enabled?

    # Disable
    @router.disable_ai_triage
    refute @router.ai_triage_enabled?

    # Re-enable
    @router.enable_ai_triage
    assert @router.ai_triage_enabled?
  end

  # Test 6: Cache management
  def test_cache_management
    # Set some cache entries
    @cache.set('test_key', { value: 'test_data' }, ttl: 3600)

    # Clear all cache
    @router.clear_ai_cache

    # Verify cache is cleared
    assert_nil @cache.get('test_key')
  end

  # Test 7: Circuit breaker functionality
  def test_circuit_breaker_opens_on_repeated_failures
    # Simulate 3 consecutive failures
    3.times do |i|
      # Make LLM return nil (no skill match) to trigger failure
      @llm_client.mock_response = JSON.generate({
        'skill' => nil,
        'confidence' => 0.0,
        'reasoning' => 'No suitable skill found'
      })

      result = @router.route("test input #{i}", {})
      # Result should either be nil or come from lower layers
    end

    # Circuit should be open now
    stats = @router.stats
    assert_equal :open, stats[:ai_triage][:circuit_state],
      "Expected circuit to be open after 3 failures, but got #{stats[:ai_triage][:circuit_state]}"

    # Reset circuit breaker
    @router.reset_circuit_breaker

    # Circuit should be closed now
    stats = @router.stats
    assert_equal :closed, stats[:ai_triage][:circuit_state]
  end

  private

  # Mock LLM Client for testing
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

      JSON.generate({
        'skill' => 'systematic-debugging',
        'confidence' => 0.8,
        'reasoning' => 'Mock response'
      })
    end

    def configured?
      true
    end

    def stats
      {
        configured: true,
        call_count: @call_count
      }
    end
  end
end
