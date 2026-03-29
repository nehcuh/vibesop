# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'json'
require 'timeout'
require 'logger'
require_relative 'base'

module Vibe
  module LLMProvider
    # OpenAI API provider
    #
    # Implements LLM provider interface for OpenAI's models.
    # Supports GPT-4o, GPT-4-turbo, GPT-3.5-turbo, etc.
    #
    # Usage:
    #   provider = OpenAIProvider.new(
    #     api_key: 'sk-xxxxx',
    #     base_url: 'https://api.openai.com'
    #   )
    #   response = provider.call(
    #     model: 'gpt-4o-mini',
    #     prompt: 'What is 2+2?'
    #   )
    class OpenAIProvider < Base
      API_VERSION = 'v1'
      MAX_RETRIES = 2

      attr_reader :call_count

      def initialize(api_key:, base_url:, timeout: DEFAULT_TIMEOUT, logger: nil)
        super
        @call_count = 0
        @connection_pool = {}
      end

      # Make API call to OpenAI
      #
      # @param model [String] Model identifier
      # @param prompt [String] Prompt text
      # @param max_tokens [Integer] Maximum tokens to generate
      # @param temperature [Float] Sampling temperature
      # @return [String] Response text
      def call(model:, prompt:, max_tokens: DEFAULT_MAX_TOKENS, temperature: DEFAULT_TEMPERATURE)
        validate_parameters(model, prompt)

        @call_count += 1
        uri = build_uri
        request_body = build_request_body(model, prompt, max_tokens, temperature)

        response_with_retry(uri, request_body)
      end

      # Get provider name
      #
      # @return [String] Provider name
      def provider_name
        'OpenAI'
      end

      # Get supported models
      #
      # @return [Array<String>] List of supported model identifiers
      def supported_models
        %w[
          gpt-4o
          gpt-4o-mini
          gpt-4-turbo
          gpt-4
          gpt-3.5-turbo
        ]
      end

      # Get provider statistics
      #
      # @return [Hash] Statistics including call count
      def stats
        super.merge(
          call_count: @call_count,
          connection_pool_size: @connection_pool.size
        )
      end

      private

      # API endpoint for OpenAI
      #
      # @return [String] API endpoint path
      def api_endpoint
        "/#{API_VERSION}/chat/completions"
      end

      # Build request body for OpenAI API
      #
      # @param model [String] Model identifier
      # @param prompt [String] Prompt text
      # @param max_tokens [Integer] Maximum tokens
      # @param temperature [Float] Sampling temperature
      # @return [Hash] Request body hash
      def build_request_body(model, prompt, max_tokens, temperature)
        {
          model: model,
          messages: [
            { role: 'user', content: prompt }
          ],
          max_tokens: max_tokens,
          temperature: temperature
        }
      end

      # Make HTTP request with retry logic
      #
      # @param uri [URI] Request URI
      # @param request_body [Hash] Request body
      # @param retry_count [Integer] Current retry attempt
      # @return [String] Response text
      def response_with_retry(uri, request_body, retry_count = 0)
        Timeout.timeout(@timeout) do
          response = post_request(uri, request_body)

          case response
          when Net::HTTPSuccess
            parse_response(response.body)
          when Net::HTTPTooManyRequests
            retry_after = handle_rate_limit(response, retry_count)
            if retry_after && retry_count < MAX_RETRIES
              sleep(retry_after)
              return response_with_retry(uri, request_body, retry_count + 1)
            else
              raise "Rate limit exceeded after #{MAX_RETRIES} retries"
            end
          when Net::HTTPServerError
            delay = handle_server_error(response, retry_count)
            if delay && retry_count < MAX_RETRIES
              sleep(delay)
              return response_with_retry(uri, request_body, retry_count + 1)
            else
              raise "Server error: #{response.code} after #{MAX_RETRIES} retries"
            end
          when Net::HTTPBadRequest, Net::HTTPUnauthorized
            handle_client_error(response)
          else
            raise "HTTP Error: #{response.code} - #{response.message}"
          end
        end
      rescue Timeout::Error => e
        log_retry("Timeout after #{@timeout}s", retry_count)
        if retry_count < MAX_RETRIES
          sleep(calculate_backoff(retry_count))
          response_with_retry(uri, request_body, retry_count + 1)
        else
          raise Timeout::Error, "Request timeout after #{MAX_RETRIES} retries"
        end
      end

      # Make POST request
      #
      # @param uri [URI] Request URI
      # @param request_body [Hash] Request body
      # @return [Net::HTTPResponse] HTTP response
      def post_request(uri, request_body)
        http = get_connection(uri)
        request = Net::HTTP::Post.new(uri)

        request['Content-Type'] = 'application/json'
        request['Authorization'] = "Bearer #{@api_key}"
        request['User-Agent'] = 'VibeSOP/1.0'

        request.body = JSON.generate(request_body)

        @logger.debug("Sending request to #{uri}") if @logger.debug?
        http.request(request)
      end

      # Get or create connection for host
      #
      # @param uri [URI] Request URI
      # @return [Net::HTTP] HTTP connection
      def get_connection(uri)
        host = uri.host
        port = uri.port

        @connection_pool[host] ||= Net::HTTP.new(host, port)
        @connection_pool[host].use_ssl = true
        @connection_pool[host].open_timeout = @timeout
        @connection_pool[host].read_timeout = @timeout

        @connection_pool[host]
      end

      # Parse response body
      #
      # @param body [String] Response body
      # @return [String] Extracted text
      def parse_response(body)
        parsed = JSON.parse(body)

        # OpenAI chat completions format
        if parsed['choices'] && parsed['choices'][0]
          parsed['choices'][0]['message']['content']
        else
          raise "Unexpected response format: #{parsed.keys}"
        end
      rescue JSON::ParserError => e
        raise "JSON parsing error: #{e.message}\nResponse: #{body[0..200]}"
      end

      # Handle rate limit response
      #
      # @param response [Net::HTTPResponse] Rate limit response
      # @param retry_count [Integer] Current retry count
      # @return [Integer, nil] Seconds to wait before retry
      def handle_rate_limit(response, retry_count)
        if retry_count < MAX_RETRIES
          # OpenAI uses Retry-After header
          retry_after = response['Retry-After']&.to_i || 5
          @logger.warn("Rate limited, waiting #{retry_after}s before retry")
          retry_after
        else
          nil
        end
      end

      # Handle server error response
      #
      # @param response [Net::HTTPResponse] Server error response
      # @param retry_count [Integer] Current retry count
      # @return [Integer, nil] Seconds to wait before retry
      def handle_server_error(response, retry_count)
        if retry_count < MAX_RETRIES
          delay = calculate_backoff(retry_count)
          @logger.warn("Server error (#{response.code}), retrying after #{delay}s")
          delay
        else
          nil
        end
      end

      # Handle client error response
      #
      # @param response [Net::HTTPResponse] Client error response
      def handle_client_error(response)
        error_body = response.body[0..500] rescue 'N/A'
        raise "Client error (#{response.code}): #{error_body}"
      end

      # Calculate exponential backoff delay
      #
      # @param retry_count [Integer] Current retry count
      # @return [Integer] Seconds to wait
      def calculate_backoff(retry_count)
        # Exponential backoff: 2^retry_count seconds, max 60s
        [2 ** retry_count, 60].min
      end

      # Log retry attempt
      #
      # @param message [String] Log message
      # @param retry_count [Integer] Retry count
      def log_retry(message, retry_count)
        return unless @logger
        @logger.warn("[#{provider_name}] #{message} (retry #{retry_count + 1}/#{MAX_RETRIES})")
      end
    end
  end
end
