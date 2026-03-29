# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'
require 'timeout'
require 'logger'

module Vibe
  # LLM Client for making API calls to Anthropic Claude
  #
  # Features:
  # - Retry logic with exponential backoff
  # - Timeout protection
  # - Rate limiting handling
  # - Connection pooling support
  # - Comprehensive error handling
  #
  # Supported Models:
  # - Claude Haiku (claude-haiku-4-5-20251001) - Fast, cheap, for triage
  # - Claude Sonnet (claude-sonnet-4-6) - Balanced, for most tasks
  # - Claude Opus (claude-opus-4-6) - Most capable, for complex tasks
  #
  # Usage:
  #   client = LLMClient.new
  #   response = client.call(
  #     model: 'claude-haiku-4-5-20251001',
  #     prompt: 'Analyze this request...',
  #     max_tokens: 300,
  #     temperature: 0.3
  #   )

  # Custom exceptions for retry logic
  class RateLimitError < StandardError; end
  class ServerError < StandardError
    attr_reader :delay
    def initialize(delay, code)
      @delay = delay
      super("Server error: #{code}")
    end
  end

  class LLMClient
    DEFAULT_TIMEOUT = 10 # seconds
    MAX_RETRIES = 2
    BASE_URL = 'https://api.anthropic.com'
    API_VERSION = '2023-06-01'

    attr_reader :api_key, :base_url, :timeout, :logger

    def initialize(api_key: nil, base_url: nil, timeout: DEFAULT_TIMEOUT, logger: nil)
      @api_key = api_key || ENV['ANTHROPIC_API_KEY']
      # Allow nil api_key for testing purposes
      # raise ArgumentError, 'ANTHROPIC_API_KEY not configured' unless @api_key

      @base_url = base_url || ENV['ANTHROPIC_BASE_URL'] || BASE_URL
      @timeout = timeout
      @logger = logger || Logger.new($stderr)

      # Connection pool for better performance
      @connection_pool = {}
    end

    # Main method to call LLM API
    # @param model [String] Model identifier (e.g., 'claude-haiku-4-5-20251001')
    # @param prompt [String] Prompt text
    # @param max_tokens [Integer] Maximum tokens to generate (default: 300)
    # @param temperature [Float] Sampling temperature, 0.0-1.0 (default: 0.3)
    # @return [String] Response text
    # @raise [Timeout::Error] If request times out
    # @raise [StandardError] If request fails after retries
    def call(model:, prompt:, max_tokens: 300, temperature: 0.3)
      raise ArgumentError, 'Model cannot be empty' if model.nil? || model.empty?
      raise ArgumentError, 'Prompt cannot be empty' if prompt.nil? || prompt.empty?

      uri = build_uri
      request_body = build_request_body(model, prompt, max_tokens, temperature)

      response_with_retry(uri, request_body)
    end

    # Check if client is properly configured
    def configured?
      !@api_key.nil? && !@api_key.empty?
    end

    # Get client statistics
    def stats
      {
        configured: configured?,
        base_url: @base_url,
        timeout: @timeout,
        connection_pool_size: @connection_pool.size
      }
    end

    private

    def build_uri
      URI.join(@base_url, '/v1/messages')
    end

    def build_request_body(model, prompt, max_tokens, temperature)
      {
        model: model,
        max_tokens: max_tokens,
        temperature: temperature,
        messages: [
          { role: 'user', content: prompt }
        ]
      }
    end

    def response_with_retry(uri, request_body, retry_count = 0)
      begin
        Timeout.timeout(@timeout) do
          response = post_request(uri, request_body)

          case response
          when Net::HTTPSuccess
            return parse_response(response.body)
          when Net::HTTPTooManyRequests
            retry_after = handle_rate_limit(response, retry_count)
            raise RateLimitError, retry_after.to_s if retry_after && retry_count < MAX_RETRIES
            raise "Rate limit exceeded after #{MAX_RETRIES} retries"
          when Net::HTTPServerError
            delay = handle_server_error(response, retry_count)
            raise ServerError.new(delay, response.code) if delay && retry_count < MAX_RETRIES
            raise "Server error: #{response.code} after #{MAX_RETRIES} retries"
          when Net::HTTPBadRequest, Net::HTTPUnauthorized
            handle_client_error(response)
          else
            raise "HTTP Error: #{response.code} - #{response.message}"
          end
        end
      rescue Timeout::Error => e
        log_retry("Timeout after #{@timeout}s", retry_count)
        if retry_count < MAX_RETRIES
          retry_count += 1
          sleep(calculate_backoff(retry_count))
          retry
        else
          raise Timeout::Error, "Request timeout after #{MAX_RETRIES} retries"
        end
      rescue RateLimitError => e
        retry_count += 1
        sleep(e.message.to_i)
        retry
      rescue ServerError => e
        retry_count += 1
        sleep(e.delay)
        retry
      end
    end

    def post_request(uri, request_body)
      http = get_connection(uri)
      request = Net::HTTP::Post.new(uri)

      request['Content-Type'] = 'application/json'
      request['x-api-key'] = @api_key
      request['anthropic-version'] = API_VERSION
      request['User-Agent'] = 'VibeSOP/1.0'

      request.body = JSON.generate(request_body)

      @logger.debug("Sending request to #{uri}") if @logger.debug?
      http.request(request)
    end

    def get_connection(uri)
      host = uri.host
      port = uri.port

      @connection_pool[host] ||= Net::HTTP.new(host, port)
      @connection_pool[host].use_ssl = true
      @connection_pool[host].open_timeout = @timeout
      @connection_pool[host].read_timeout = @timeout

      @connection_pool[host]
    end

    def parse_response(body)
      parsed = JSON.parse(body)

      # Handle different response formats
      if parsed['content'] && parsed['content'][0]
        # Messages API format
        parsed['content'][0]['text']
      elsif parsed['completion']
        # Legacy completions format
        parsed['completion']
      else
        raise "Unexpected response format: #{parsed.keys}"
      end
    rescue JSON::ParserError => e
      raise "JSON parsing error: #{e.message}\nResponse: #{body[0..200]}"
    end

    def handle_rate_limit(response, retry_count)
      if retry_count < MAX_RETRIES
        # Extract retry-after delay from headers
        retry_after = response['Retry-After']&.to_i || 5

        @logger.warn("Rate limited, waiting #{retry_after}s before retry")
        # Return the delay to sleep before retry
        retry_after
      else
        # Return nil to indicate no more retries
        nil
      end
    end

    def handle_server_error(response, retry_count)
      if retry_count < MAX_RETRIES
        delay = calculate_backoff(retry_count)
        @logger.warn("Server error (#{response.code}), retrying after #{delay}s")
        # Return the delay to sleep before retry
        delay
      else
        # Return nil to indicate no more retries
        nil
      end
    end

    def handle_client_error(response)
      # Don't retry client errors (4xx) - these are likely configuration issues
      error_body = response.body[0..500] rescue 'N/A'

      raise "Client error (#{response.code}): #{error_body}"
    end

    def calculate_backoff(retry_count)
      # Exponential backoff: 2^retry_count seconds (max 4s)
      [2**retry_count, 4].min
    end

    def log_retry(message, retry_count)
      @logger.warn("[LLM Client] #{message} (retry #{retry_count + 1}/#{MAX_RETRIES})")
    end
  end
end
