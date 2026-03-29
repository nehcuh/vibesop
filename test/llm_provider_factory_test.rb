#!/usr/bin/env ruby
# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/vibe/llm_provider/factory'

# Test suite for LLM Provider Factory
class LLMProviderFactoryTest < Minitest::Test
  def setup
    # Save original environment variables
    @original_anthropic_key = ENV['ANTHROPIC_API_KEY']
    @original_openai_key = ENV['OPENAI_API_KEY']
  end

  def teardown
    # Restore original environment variables
    ENV['ANTHROPIC_API_KEY'] = @original_anthropic_key
    ENV['OPENAI_API_KEY'] = @original_openai_key
  end

  # Test 1: Factory creates Anthropic provider
  def test_creates_anthropic_provider
    ENV['ANTHROPIC_API_KEY'] = 'test-key'

    provider = Vibe::LLMProvider::Factory.create(provider: 'anthropic')

    assert_instance_of Vibe::LLMProvider::AnthropicProvider, provider
    assert_equal 'Anthropic', provider.provider_name
    assert provider.configured?
  end

  # Test 2: Factory creates OpenAI provider
  def test_creates_openai_provider
    ENV['OPENAI_API_KEY'] = 'test-key'

    provider = Vibe::LLMProvider::Factory.create(provider: 'openai')

    assert_instance_of Vibe::LLMProvider::OpenAIProvider, provider
    assert_equal 'OpenAI', provider.provider_name
    assert provider.configured?
  end

  # Test 3: Factory auto-detects Anthropic
  def test_auto_detects_anthropic
    ENV['ANTHROPIC_API_KEY'] = 'test-key'
    ENV['OPENAI_API_KEY'] = nil

    provider = Vibe::LLMProvider::Factory.create_from_env

    assert_equal 'AnthropicProvider', provider.class.name.gsub('Vibe::LLMProvider::', '')
    assert provider.configured?
  end

  # Test 4: Factory auto-detects OpenAI as fallback
  def test_auto_detects_openai_fallback
    ENV['ANTHROPIC_API_KEY'] = nil
    ENV['OPENAI_API_KEY'] = 'test-key'

    provider = Vibe::LLMProvider::Factory.create_from_env

    assert_equal 'OpenAIProvider', provider.class.name.gsub('Vibe::LLMProvider::', '')
    assert provider.configured?
  end

  # Test 5: Factory raises error when no keys available
  def test_raises_error_when_no_keys
    ENV['ANTHROPIC_API_KEY'] = nil
    ENV['OPENAI_API_KEY'] = nil

    error = assert_raises(ArgumentError) do
      Vibe::LLMProvider::Factory.create_from_env
    end

    assert_match(/No API key found/, error.message)
  end

  # Test 6: Factory.with_fallback works
  def test_fallback_to_openai_when_anthropic_unavailable
    ENV['ANTHROPIC_API_KEY'] = nil
    ENV['OPENAI_API_KEY'] = 'test-key'

    provider = Vibe::LLMProvider::Factory.create_with_fallback(%w[anthropic openai])

    assert_equal 'OpenAIProvider', provider.class.name.gsub('Vibe::LLMProvider::', '')
    assert provider.configured?
  end

  # Test 7: Detect available providers
  def test_detects_available_providers
    ENV['ANTHROPIC_API_KEY'] = 'test-key'
    ENV['OPENAI_API_KEY'] = nil

    available = Vibe::LLMProvider::Factory.available_providers

    assert_equal ['anthropic'], available
  end

  # Test 8: Detect both providers available
  def test_detects_both_providers
    ENV['ANTHROPIC_API_KEY'] = 'test-key-1'
    ENV['OPENAI_API_KEY'] = 'test-key-2'

    available = Vibe::LLMProvider::Factory.available_providers

    assert_equal 2, available.length
    assert_includes available, 'anthropic'
    assert_includes available, 'openai'
  end

  # Test 9: Recommended provider detection
  def test_recommended_provider_defaults_to_anthropic
    # No OpenCode config, should default to anthropic
    recommended = Vibe::LLMProvider::Factory.recommended_provider

    assert_equal 'anthropic', recommended
  end

  # Test 10: Provider stats include correct info
  def test_anthropic_provider_stats
    ENV['ANTHROPIC_API_KEY'] = 'test-key'

    provider = Vibe::LLMProvider::Factory.create(provider: 'anthropic')
    stats = provider.stats

    assert_equal 'Anthropic', stats[:provider]
    assert_equal true, stats[:configured]
    assert_equal 0, stats[:call_count]
  end

  # Test 11: OpenAI provider stats include correct info
  def test_openai_provider_stats
    ENV['OPENAI_API_KEY'] = 'test-key'

    provider = Vibe::LLMProvider::Factory.create(provider: 'openai')
    stats = provider.stats

    assert_equal 'OpenAI', stats[:provider]
    assert_equal true, stats[:configured]
    assert_equal 0, stats[:call_count]
  end
end
