# frozen_string_literal: true

require 'timeout'
require_relative '../defaults'
require_relative '../utils'

module Vibe
  class SkillRouter
    # Parallel Executor - Runs multiple skills in parallel and aggregates results
    #
    # Responsibilities:
    # - Execute multiple skills concurrently
    # - Aggregate results based on strategy
    # - Handle timeouts and errors
    #
    class ParallelExecutor
      include Defaults

      attr_reader :config

      # Initialize ParallelExecutor
      #
      # @param config [Hash] Execution configuration from skill-selection.yaml
      def initialize(config: {})
        @config = Utils.deep_merge(defaults, config)
      end

      # Execute skills in parallel
      #
      # @param candidates [Array<Hash>] Skills to execute with execution context
      # @param executor [Proc] Callable that executes a single skill
      # @param context [Hash] Additional execution context
      # @return [Hash] Aggregated results
      def execute(candidates, executor:, context: {})
        return error_result("No candidates to execute") if candidates.empty?
        return single_result(execute_single(candidates.first, executor, context)) if candidates.one?

        # Execute in parallel using threads
        results = execute_parallel(candidates, executor, context)

        # Aggregate results
        aggregate(results, context)
      end

      # Check if parallel execution is supported
      #
      # @return [Boolean] True if parallel execution is available
      def parallel_available?
        @config['enabled']
      end

      # Get maximum parallel executions
      #
      # @return [Integer] Max parallel count
      def max_parallel
        @config['max_parallel']
      end

      private

      # Execute multiple skills in parallel
      #
      # @param candidates [Array<Hash>] Skills to execute
      # @param executor [Proc] Skill executor
      # @param context [Hash] Execution context
      # @return [Array<Hash>] Results from each execution
      def execute_parallel(candidates, executor, context)
        timeout = @config['aggregation']['timeout']

        # Limit to max_parallel
        to_execute = candidates.first(@config['max_parallel'])

        # Use threads for parallel execution
        threads = to_execute.map do |candidate|
          Thread.new do
            Thread.current[:candidate] = candidate
            Thread.current[:result] = nil
            Thread.current[:error] = nil

            begin
              Thread.current[:result] = execute_single(candidate, executor, context)
            rescue StandardError => e
              Thread.current[:error] = {
                message: e.message,
                backtrace: e.backtrace[0..5]
              }
            end
          end
        end

        # Wait for all threads with timeout
        results = nil
        begin
          Timeout.timeout(timeout) do
            results = threads.map do |thread|
              thread.join
              {
                candidate: thread[:candidate],
                result: thread[:result],
                error: thread[:error]
              }
            end
          end
        rescue Timeout::Error
          # Handle timeout
          results = threads.map do |thread|
            thread.kill if thread.alive?
            {
              candidate: thread[:candidate],
              result: thread[:result],
              error: thread[:error] || { message: "Execution timed out" }
            }
          end
        end

        results
      end

      # Execute a single skill
      #
      # @param candidate [Hash] Skill candidate
      # @param executor [Proc] Skill executor
      # @param context [Hash] Execution context
      # @return [Hash] Execution result
      def execute_single(candidate, executor, context)
        # The executor is responsible for actually running the skill
        # It receives the candidate and context, returns result hash
        executor.call(candidate, context)
      end

      # Aggregate results from parallel executions
      #
      # @param results [Array<Hash>] Results from parallel execution
      # @param context [Hash] Execution context
      # @return [Hash] Aggregated result
      def aggregate(results, context)
        successful = results.select { |r| r[:error].nil? }
        failed = results.select { |r| r[:error] }

        # If all failed, return error
        if successful.empty?
          return {
            status: :failed,
            errors: failed.map { |f| f[:error] },
            message: "All parallel executions failed"
          }
        end

        # Apply aggregation strategy
        method = @config['aggregation']['method']

        case method.to_sym
        when :consensus
          aggregate_consensus(successful)
        when :majority
          aggregate_majority(successful)
        when :first_success
          aggregate_first_success(successful)
        when :all
          aggregate_all(successful, failed)
        when :merged
          aggregate_merged(successful, failed)
        else
          aggregate_merged(successful, failed)
        end
      end

      # Consensus: All successful results must agree
      #
      # @param results [Array<Hash>] Successful results
      # @return [Hash] Consensus result
      def aggregate_consensus(results)
        # Check if all results agree on the main conclusion
        conclusions = results.map { |r| extract_conclusion(r[:result]) }.compact

        if conclusions.uniq.size == 1
          {
            status: :consensus,
            result: results.first[:result],
            consensus_rate: 1.0,
            participants: results.size,
            message: "All #{results.size} executions reached consensus"
          }
        else
          {
            status: :no_consensus,
            results: results,
            consensus_rate: 0.0,
            conflicting_conclusions: conclusions,
            message: "Executions did not reach consensus"
          }
        end
      end

      # Majority: Most results must agree
      #
      # @param results [Array<Hash>] Successful results
      # @return [Hash] Majority result
      def aggregate_majority(results)
        conclusions = results.map { |r| extract_conclusion(r[:result]) }.compact

        # Count occurrences of each conclusion
        counts = conclusions.group_by(&:itself).transform_values(&:size)

        # Find most common
        most_common = counts.max_by { |_, v| v }
        majority_count = most_common[1]
        majority_conclusion = most_common[0]

        {
          status: :majority,
          result: results.find { |r| extract_conclusion(r[:result]) == majority_conclusion }[:result],
          consensus_rate: majority_count.to_f / results.size,
          participants: results.size,
          breakdown: counts,
          message: "#{majority_count}/#{results.size} executions agreed"
        }
      end

      # First success: Return first successful result
      #
      # @param results [Array<Hash>] Successful results
      # @return [Hash] First success result
      def aggregate_first_success(results)
        {
          status: :first_success,
          result: results.first[:result],
          participants: results.size,
          message: "Returned first successful result"
        }
      end

      # All: Return all results for comparison
      #
      # @param successful [Array<Hash>] Successful results
      # @param failed [Array<Hash>] Failed results
      # @return [Hash] All results
      def aggregate_all(successful, failed)
        {
          status: :all,
          successful: successful.map { |r| r[:result] },
          failed: failed,
          total: successful.size + failed.size,
          success_rate: successful.size.to_f / (successful.size + failed.size),
          message: "All #{successful.size} successful results returned"
        }
      end

      # Merged: Merge insights from all results
      #
      # @param successful [Array<Hash>] Successful results
      # @param failed [Array<Hash>] Failed results
      # @return [Hash] Merged result
      def aggregate_merged(successful, failed)
        # Extract key insights from each result
        insights = successful.map do |r|
          extract_insights(r[:result])
        end.compact.flatten

        # Find common recommendations
        recommendations = successful.map do |r|
          extract_recommendation(r[:result])
        end.compact

        # Merge into comprehensive result
        {
          status: :merged,
          insights: insights,
          recommendations: recommendations,
          participants: successful.size,
          failed: failed.size,
          success_rate: successful.size.to_f / (successful.size + failed.size),
          message: "Merged insights from #{successful.size} executions",
          # Include best match as primary recommendation
          best_match: find_best_match(successful)
        }
      end

      # Find best match among results
      #
      # @param results [Array<Hash>] Results
      # @return [Hash, nil] Best match
      def find_best_match(results)
        return nil if results.empty?

        # Score each result based on various factors
        scored = results.map do |r|
          {
            candidate: r[:candidate],
            result: r[:result],
            score: score_result(r[:result])
          }
        end

        scored.max_by { |s| s[:score] }
      end

      # Score a result for quality comparison
      #
      # @param result [Hash] Execution result
      # @return [Float] Quality score
      def score_result(result)
        score = 0.0

        # Has structured output
        score += 0.3 if result[:structured]

        # Has evidence/references
        score += 0.2 if result[:evidence]

        # Has action items
        score += 0.2 if result[:actions]

        # Has recommendations
        score += 0.2 if result[:recommendations]

        # No errors
        score += 0.1 if result[:error].nil?

        score
      end

      # Extract conclusion from result
      #
      # @param result [Hash] Result hash
      # @return [String, nil] Conclusion
      def extract_conclusion(result)
        return nil unless result

        result[:conclusion] || result[:verdict] || result[:decision]
      end

      # Extract insights from result
      #
      # @param result [Hash] Result hash
      # @return [Array] Insights
      def extract_insights(result)
        return [] unless result

        result[:insights] || result[:findings] || []
      end

      # Extract recommendation from result
      #
      # @param result [Hash] Result hash
      # @return [String, nil] Recommendation
      def extract_recommendation(result)
        return nil unless result

        result[:recommendation] || result[:suggested_action]
      end

      # Single result wrapper
      #
      # @param result [Hash] Single result
      # @return [Hash] Wrapped result
      def single_result(result)
        {
          status: :single,
          result: result,
          message: "Single skill executed"
        }
      end

      # Error result wrapper
      #
      # @param message [String] Error message
      # @return [Hash] Error result
      def error_result(message)
        {
          status: :error,
          message: message
        }
      end

      # Default configuration
      #
      # @return [Hash] Default config
      def defaults
        {
          'enabled' => true,
          'max_parallel' => 2,
          'mode' => 'auto',
          'conditions' => {
            'max_confidence_diff' => 0.10,
            'min_candidates' => 2,
            'max_candidates' => 3,
            'max_estimated_duration' => 300
          },
          'aggregation' => {
            'method' => 'merged',
            'timeout' => 300,
            'on_timeout' => 'return_partial'
          }
        }
      end

    end
  end
end

