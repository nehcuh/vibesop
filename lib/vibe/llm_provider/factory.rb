# frozen_string_literal: true

require_relative 'base'
require_relative 'anthropic'
require_relative 'openai'
require 'yaml'

module Vibe
  module LLMProvider
    # Factory for creating LLM provider instances
    #
    # This factory creates provider instances based on configuration.
    # It supports automatic provider detection from environment variables
    # and OpenCode configuration files.
    #
    # Usage:
    #   # Auto-detect from environment
    #   provider = Factory.create_from_env
    #
    #   # Explicit provider selection
    #   provider = Factory.create(provider: 'anthropic')
    #
    #   # From OpenCode configuration
    #   provider = Factory.create_from_opencode_config('/path/to/opencode.json')
    class Factory
      # Environment variable names for API keys
      ANTHROPIC_API_KEY = 'ANTHROPIC_API_KEY'
      OPENAI_API_KEY = 'OPENAI_API_KEY'

      # Base URLs
      ANTHROPIC_BASE_URL = 'https://api.anthropic.com'
      OPENAI_BASE_URL = 'https://api.openai.com'

      class << self
        # Create provider instance from environment variables
        #
        # @param preferred_provider [String] Preferred provider ('anthropic' or 'openai')
        # @return [LLMProvider::Base] Provider instance
        # @raise [ArgumentError] If no API key is found
        def create_from_env(preferred_provider = nil)
          # If preferred provider is specified, try it first
          if preferred_provider
            provider = create(provider: preferred_provider)
            return provider if provider&.configured?
          end

          # Auto-detect: try Anthropic first, then OpenAI
          %w[anthropic openai].each do |provider_name|
            provider = create(provider: provider_name)
            return provider if provider&.configured?
          end

          raise ArgumentError, 'No API key found. Set ANTHROPIC_API_KEY or OPENAI_API_KEY environment variable.'
        end

        # Create provider instance explicitly
        #
        # @param provider [String] Provider name ('anthropic' or 'openai')
        # @param api_key [String] API key (optional, will use ENV if not provided)
        # @return [LLMProvider::Base] Provider instance
        def create(provider:, api_key: nil)
          case provider.downcase
          when 'anthropic'
            AnthropicProvider.new(
              api_key: api_key || ENV[ANTHROPIC_API_KEY],
              base_url: ENV['ANTHROPIC_BASE_URL'] || ANTHROPIC_BASE_URL
            )
          when 'openai'
            OpenAIProvider.new(
              api_key: api_key || ENV[OPENAI_API_KEY],
              base_url: ENV['OPENAI_BASE_URL'] || OPENAI_BASE_URL
            )
          else
            raise ArgumentError, "Unknown provider: #{provider}. Supported: anthropic, openai"
          end
        end

        # Create provider from OpenCode configuration file
        #
        # @param config_path [String] Path to opencode.json
        # @return [LLMProvider::Base] Provider instance
        # @raise [ArgumentError] If config file not found or invalid
        def create_from_opencode_config(config_path = nil)
          # Default path
          config_path ||= File.join(Dir.pwd, 'opencode.json')

          unless File.exist?(config_path)
            # Try in .vibe directory
            config_path = File.join(Dir.pwd, '.vibe', 'opencode.json')
          end

          raise ArgumentError, "OpenCode config not found: #{config_path}" unless File.exist?(config_path)

          config = JSON.parse(File.read(config_path))
          models_config = config['models'] || {}

          # Determine which provider to use for routing
          # Priority: fast agent > workhorse coder > critical reasoner
          model_config = models_config['fast'] || models_config['workhorse'] || models_config['critical']

          unless model_config
            raise ArgumentError, "No model configuration found in opencode.json"
          end

          provider_name = model_config['provider']

          case provider_name
          when 'anthropic'
            AnthropicProvider.new(
              api_key: ENV[ANTHROPIC_API_KEY],
              base_url: ENV['ANTHROPIC_BASE_URL'] || ANTHROPIC_BASE_URL
            )
          when 'openai'
            OpenAIProvider.new(
              api_key: ENV[OPENAI_API_KEY],
              base_url: ENV['OPENAI_BASE_URL'] || OPENAI_BASE_URL
            )
          when nil, ''
            # No provider specified, default to Anthropic
            AnthropicProvider.new(
              api_key: ENV[ANTHROPIC_API_KEY],
              base_url: ENV['ANTHROPIC_BASE_URL'] || ANTHROPIC_BASE_URL
            )
          else
            raise ArgumentError, "Unsupported provider in OpenCode config: #{provider_name}. Supported: anthropic, openai"
          end
        rescue JSON::ParserError => e
          raise ArgumentError, "Invalid OpenCode config JSON: #{e.message}"
        end

        # Detect provider from OpenCode configuration
        #
        # @return [String, nil] Detected provider name ('anthropic', 'openai', or nil)
        def detect_opencode_provider
          return nil unless File.exist?('opencode.json') || File.exist?('.vibe/opencode.json')

          config_file = File.exist?('opencode.json') ? 'opencode.json' : '.vibe/opencode.json'
          config = JSON.parse(File.read(config_file))
          models_config = config['models'] || {}

          # Check fast router model (used for AI triage)
          model_config = models_config['fast'] || models_config['workhorse']
          model_config&.dig('provider')
        rescue JSON::ParserError, Errno::ENOENT
          nil
        end

        # Check if a specific provider is available
        #
        # @param provider_name [String] Provider name to check
        # @return [Boolean] true if provider has API key configured
        def provider_available?(provider_name)
          case provider_name
          when 'anthropic'
            !ENV[ANTHROPIC_API_KEY].nil? && !ENV[ANTHROPIC_API_KEY].empty?
          when 'openai'
            !ENV[OPENAI_API_KEY].nil? && !ENV[OPENAI_API_KEY].empty?
          else
            false
          end
        end

        # Get list of available providers
        #
        # @return [Array<String>] List of available provider names
        def available_providers
          providers = []
          providers << 'anthropic' if provider_available?('anthropic')
          providers << 'openai' if provider_available?('openai')
          providers
        end

        # Create provider with automatic fallback
        #
        # Tries to create preferred provider, falls back to available alternatives
        #
        # @param preferred_providers [Array<String>] List of providers in priority order
        # @return [LLMProvider::Base] Provider instance
        # @raise [ArgumentError] If no provider is available
        def create_with_fallback(preferred_providers = %w[anthropic openai])
          preferred_providers.each do |provider_name|
            begin
              provider = create(provider: provider_name)
              return provider if provider&.configured?
            rescue ArgumentError => e
              # Try next provider
              next
            end
          end

          available = available_providers.join(', ')
          raise ArgumentError, "No LLM provider available. Configure one of: #{available}"
        end

        # Get recommended provider for AI routing
        #
        # Anthropic models are recommended for AI triage due to:
        # - Fast response times
        # - Low cost
        # - Good understanding of natural language
        #
        # @return [String] Recommended provider name
        def recommended_provider
          # Check if we're in an OpenCode environment
          opencode_provider = detect_opencode_provider

          if opencode_provider
            # Use whatever OpenCode is configured with
            # (assuming the user knows what they're doing)
            opencode_provider
          else
            # Default to Anthropic for AI routing
            'anthropic'
          end
        end
      end
    end
  end
end
