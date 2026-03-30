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

      # Local model configuration
      LOCAL_MODEL_URL = 'http://localhost:11434/v1'  # Default Ollama endpoint
      LOCAL_MODEL_NAME = 'llama3.2'                   # Default local model

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
        # Also checks for .vibe/llm-config.json for model configuration
        # This allows separating model config from OpenCode's native config
        #
        # @param config_path [String] Path to opencode.json
        # @return [LLMProvider::Base] Provider instance
        # @raise [ArgumentError] If config file not found or invalid
        def create_from_opencode_config(config_path = nil)
          # First, try to load from .vibe/llm-config.json (Vibe-specific model config)
          vibe_config_path = File.join(Dir.pwd, '.vibe', 'llm-config.json')
          if File.exist?(vibe_config_path)
            return create_provider_from_config_file(vibe_config_path)
          end

          # Fallback to opencode.json
          config_path ||= File.join(Dir.pwd, 'opencode.json')

          unless File.exist?(config_path)
            # Try in .vibe directory
            config_path = File.join(Dir.pwd, '.vibe', 'opencode.json')
          end

          raise ArgumentError, "OpenCode config not found: #{config_path}" unless File.exist?(config_path)

          config = JSON.parse(File.read(config_path))

          # Check if config has models field (Vibe extension)
          if config['models']
            return create_provider_from_config_hash(config['models'])
          end

          # No models configuration found
          raise ArgumentError, "No model configuration found. Create .vibe/llm-config.json or add 'models' field to opencode.json"
        rescue JSON::ParserError => e
          raise ArgumentError, "Invalid OpenCode config JSON: #{e.message}"
        end

        # Create provider from a configuration file
        #
        # @param config_path [String] Path to config file
        # @return [LLMProvider::Base] Provider instance
        def create_provider_from_config_file(config_path)
          config = JSON.parse(File.read(config_path))
          models_config = config['models'] || {}

          create_provider_from_config_hash(models_config)
        end

        # Create provider from models configuration hash
        #
        # @param models_config [Hash] Models configuration
        # @return [LLMProvider::Base] Provider instance
        def create_provider_from_config_hash(models_config)
          # Determine which provider to use for routing
          # Priority: fast agent > workhorse coder > critical reasoner
          model_config = models_config['fast'] || models_config['workhorse'] || models_config['critical']

          unless model_config
            raise ArgumentError, "No model configuration found. Please configure 'fast', 'workhorse', or 'critical' model."
          end

          provider_name = model_config['provider']
          api_key = model_config['api_key'] # Support API key in config
          base_url = model_config['base_url']   # Support custom base URL in config

          case provider_name
          when 'anthropic'
            AnthropicProvider.new(
              api_key: api_key || ENV[ANTHROPIC_API_KEY],
              base_url: base_url || ENV['ANTHROPIC_BASE_URL'] || ANTHROPIC_BASE_URL
            )
          when 'openai'
            OpenAIProvider.new(
              api_key: api_key || ENV[OPENAI_API_KEY],
              base_url: base_url || ENV['OPENAI_BASE_URL'] || OPENAI_BASE_URL
            )
          when nil, ''
            # No provider specified, default to Anthropic
            AnthropicProvider.new(
              api_key: api_key || ENV[ANTHROPIC_API_KEY],
              base_url: base_url || ENV['ANTHROPIC_BASE_URL'] || ANTHROPIC_BASE_URL
            )
          else
            raise ArgumentError, "Unsupported provider: #{provider_name}. Supported: anthropic, openai"
          end
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

        # Create local model provider (Ollama, LM Studio, vLLM, etc.)
        #
        # Uses OpenAI-compatible API with configurable endpoint.
        # Common local model endpoints:
        # - Ollama: http://localhost:11434/v1
        # - LM Studio: http://localhost:1234/v1
        # - vLLM: http://localhost:8000/v1
        # - Oobabooga: http://localhost:5000/v1
        #
        # @param url [String] API base URL (optional, uses env or default)
        # @param api_key [String] API key (optional, often not needed for local)
        # @param model [String] Model name (optional, for reference only)
        # @return [LLMProvider::OpenAIProvider] Provider instance configured for local model
        def create_local_provider(url: nil, api_key: nil, model: nil)
          url ||= ENV.fetch('LOCAL_MODEL_URL', LOCAL_MODEL_URL)
          api_key ||= ENV.fetch('LOCAL_MODEL_API_KEY', 'local') # Dummy key for local
          model ||= ENV.fetch('LOCAL_MODEL_NAME', LOCAL_MODEL_NAME)

          OpenAIProvider.new(
            api_key: api_key,
            base_url: url
          )
        end

        # Check if local model is configured and available
        #
        # @return [Boolean] true if local model URL is configured
        def local_model_available?
          !ENV.fetch('LOCAL_MODEL_URL', nil).nil? ||
          !ENV.fetch('VIBE_LOCAL_MODEL_URL', nil).nil?
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
