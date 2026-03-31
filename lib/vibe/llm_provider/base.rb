# frozen_string_literal: true

require_relative '../llm_client'

module Vibe
  module LLMProvider
    # Abstract base class for LLM providers
    #
    # This class defines the interface that all LLM providers must implement.
    # It provides a unified way to interact with different AI model providers
    # (Anthropic, OpenAI, etc.) while maintaining provider-specific optimizations.
    #
    # @abstract
    class Base
      # Default configuration values
      DEFAULT_TIMEOUT = 10 # seconds
      DEFAULT_MAX_TOKENS = 300
      DEFAULT_TEMPERATURE = 0.3

      attr_reader :api_key, :base_url, :timeout, :logger, :configured

      # Initialize the LLM provider
      #
      # @param api_key [String] API key for the provider
      # @param base_url [String] Base URL for the provider's API
      # @param timeout [Integer] Request timeout in seconds
      # @param logger [Logger] Logger instance for debugging
      def initialize(api_key:, base_url:, timeout: DEFAULT_TIMEOUT, logger: nil)
        @api_key = api_key
        @base_url = base_url
        @timeout = timeout
        @logger = logger || Logger.new($stderr)
        @configured = !@api_key.nil? && !@api_key.empty?
      end

      # Make an API call to the LLM provider
      #
      # @param model [String] Model identifier (e.g., 'claude-haiku-4-5-20251001', 'gpt-4o-mini')
      # @param prompt [String] Prompt text to send to the model
      # @param max_tokens [Integer] Maximum tokens to generate
      # @param temperature [Float] Sampling temperature (0.0-1.0)
      # @return [String] Response text from the model
      # @raise [ArgumentError] If parameters are invalid
      # @raise [Timeout::Error] If request times out
      # @raise [StandardError] If request fails after retries
      def call(model:, prompt:, max_tokens: DEFAULT_MAX_TOKENS, temperature: DEFAULT_TEMPERATURE)
        raise NotImplementedError, "#{self.class} must implement #call method"
      end

      # Check if the provider is properly configured
      #
      # @return [Boolean] true if API key is set and valid
      def configured?
        @configured
      end

      # Get statistics about provider usage
      #
      # @return [Hash] Statistics including call count, errors, etc.
      def stats
        {
          provider: provider_name,
          configured: @configured,
          base_url: @base_url,
          timeout: @timeout
        }
      end

      # Get the provider name
      #
      # @return [String] Human-readable provider name
      def provider_name
        raise NotImplementedError, "#{self.class} must implement #provider_name method"
      end

      # Get supported models by this provider
      #
      # @return [Array<String>] List of supported model identifiers
      def supported_models
        raise NotImplementedError, "#{self.class} must implement #supported_models method"
      end

      protected

      # Validate required parameters
      #
      # @param model [String] Model identifier
      # @param prompt [String] Prompt text
      # @raise [ArgumentError] If validation fails
      def validate_parameters(model, prompt)
        raise ArgumentError, 'Model cannot be empty' if model.nil? || model.empty?
        raise ArgumentError, 'Prompt cannot be empty' if prompt.nil? || prompt.empty?
      end

      # Build URI for API request
      #
      # Handles custom base URLs that may include path segments.
      # If api_endpoint starts with '/', it's treated as an absolute path.
      # Otherwise, it's joined relative to the base URL.
      #
      # @return [URI] Parsed URI object
      def build_uri
        base_uri = URI.parse(@base_url)

        # Use custom endpoint override if provided (for non-standard APIs)
        endpoint_override = instance_variable_get(:@api_endpoint_override)

        # Check if this is a standard provider base_url
        # (e.g., https://api.openai.com or https://api.anthropic.com)
        standard_hosts = ['api.openai.com', 'api.anthropic.com']

        if standard_hosts.include?(base_uri.host)
          # Standard provider - use URI.join behavior (leading / replaces path)
          URI.join(@base_url, api_endpoint)
        elsif endpoint_override
          # Custom endpoint specified in config - use it directly
          base_path = base_uri.path.sub(/\/$/, '')
          endpoint_path = endpoint_override.sub(/^\//, '')
          full_path = [base_path, endpoint_path].join('/')

          URI.parse("#{base_uri.scheme}://#{base_uri.host}#{base_uri.port ? ":#{base_uri.port}" : ''}#{full_path}")
        else
          # Custom provider - append default endpoint to base_url path
          # Remove leading / from endpoint, and ensure base_path doesn't end with /
          base_path = base_uri.path.sub(/\/$/, '')
          endpoint_path = api_endpoint.sub(/^\//, '')
          full_path = [base_path, endpoint_path].join('/')

          URI.parse("#{base_uri.scheme}://#{base_uri.host}#{base_uri.port ? ":#{base_uri.port}" : ''}#{full_path}")
        end
      end

      # Get the API endpoint path
      #
      # @return [String] API endpoint path (e.g., '/v1/messages')
      def api_endpoint
        raise NotImplementedError, "#{self.class} must implement #api_endpoint method"
      end
    end
  end
end
