# frozen_string_literal: true

require 'yaml'
require 'time'
require 'securerandom'
require 'open3'

module Vibe
  # Grader system for continuous code quality evaluation
  class Grader
    # Grader types
    TYPES = {
      unit_test: 'unit_test',
      integration_test: 'integration_test',
      linter: 'linter',
      security: 'security',
      custom: 'custom'
    }.freeze

    # Grade levels
    GRADE = {
      pass: 'pass',
      fail: 'fail',
      warning: 'warning',
      skip: 'skip'
    }.freeze

    attr_reader :results, :stats

    def initialize
      @results = []
      @stats = {
        total_runs: 0,
        passes: 0,
        failures: 0,
        warnings: 0
      }
    end

    # Run a grader
    # @param type [Symbol] Grader type (:unit_test, :integration_test, :linter, :security)
    # @param command [String] Command to execute
    # @param options [Hash] Grader options
    #   - :description [String] Human-readable description
    #   - :timeout [Integer] Timeout in seconds
    #   - :working_dir [String] Working directory
    # @return [Hash] Grading result
    def run(type, command, options = {})
      raise "Invalid grader type: #{type}" unless TYPES.key?(type)

      @stats[:total_runs] += 1

      result = {
        id: SecureRandom.uuid,
        type: TYPES[type],
        command: command,
        description: options[:description] || command,
        started_at: Time.now.iso8601,
        completed_at: nil,
        grade: nil,
        output: nil,
        error: nil,
        exit_code: nil,
        duration: nil
      }

      start_time = Time.now

      begin
        # Execute command
        output, status = if options[:working_dir]
                           Open3.capture2e('/bin/sh', '-c', command,
                                           chdir: options[:working_dir])
                         else
                           Open3.capture2e('/bin/sh', '-c', command)
                         end

        exit_code = status.exitstatus
        duration = Time.now - start_time

        # Determine grade based on exit code and output
        grade = determine_grade(type, exit_code, output)

        result.merge!(
          completed_at: Time.now.iso8601,
          grade: grade,
          output: output,
          exit_code: exit_code,
          duration: duration.round(2)
        )

        update_stats(grade)
      rescue StandardError => e
        result.merge!(
          completed_at: Time.now.iso8601,
          grade: GRADE[:fail],
          error: e.message,
          duration: (Time.now - start_time).round(2)
        )

        @stats[:failures] += 1
      end

      @results << result
      result
    end

    # Run pass@k evaluation
    # @param candidates [Array<Hash>] Array of candidate solutions
    #   Each candidate: { code: "...", description: "..." }
    # @param grader_config [Hash] Grader configuration
    #   - :type [Symbol] Grader type
    #   - :command [String] Test command template (use {code_file} placeholder)
    #   - :k [Integer] Number of candidates to evaluate (default: all)
    #   - :language [String] File extension for temp files, e.g. 'py', 'js'
    #     (default: 'rb')
    # @return [Hash] pass@k result
    def pass_at_k(candidates, grader_config)
      k = grader_config[:k] || candidates.size
      evaluated = candidates.take(k)
      @language = grader_config[:language]
      token_budget = grader_config[:token_budget]
      budget_exceeded = 0

      results = evaluated.map.with_index do |candidate, index|
        # Token budget check (estimate: chars / 4)
        if token_budget
          estimated_tokens = candidate[:code].length / 4
          if estimated_tokens > token_budget
            budget_exceeded += 1
            next({ grade: :skipped, reason: 'exceeds_token_budget',
                   estimated_tokens: estimated_tokens, budget: token_budget })
          end
        end

        # Write candidate code to temp file
        temp_file = write_temp_candidate(candidate[:code], index)

        # Run grader with candidate
        command = grader_config[:command].gsub('{code_file}', temp_file)
        result = run(grader_config[:type], command, description: candidate[:description])

        # Cleanup temp file
        File.delete(temp_file) if File.exist?(temp_file)

        result
      end

      passes = results.count { |r| r[:grade] == GRADE[:pass] }
      skipped = results.count { |r| r[:grade] == :skipped }
      evaluated_count = k - skipped
      pass_rate = evaluated_count.positive? ? (passes.to_f / evaluated_count * 100).round(1) : 0.0

      {
        k: k,
        total_candidates: candidates.size,
        evaluated: k,
        passes: passes,
        failures: k - passes - skipped,
        pass_rate: pass_rate,
        token_budget: token_budget,
        budget_exceeded_count: budget_exceeded,
        results: results
      }
    end

    # Get grading summary
    # @return [Hash] Summary statistics
    def summary
      {
        total_runs: @stats[:total_runs],
        passes: @stats[:passes],
        failures: @stats[:failures],
        warnings: @stats[:warnings],
        pass_rate: calculate_pass_rate,
        recent_results: @results.last(5)
      }
    end

    # Clear all results
    def clear
      @results.clear
      @stats = {
        total_runs: 0,
        passes: 0,
        failures: 0,
        warnings: 0
      }
    end

    private

    # Determine grade based on grader type and output
    def determine_grade(type, exit_code, output)
      case type
      when TYPES[:unit_test], TYPES[:integration_test]
        exit_code.zero? ? GRADE[:pass] : GRADE[:fail]
      when TYPES[:linter]
        if exit_code.zero?
          GRADE[:pass]
        elsif output&.match?(/warning/i)
          GRADE[:warning]
        else
          GRADE[:fail]
        end
      when TYPES[:security]
        if exit_code.zero?
          GRADE[:pass]
        elsif output&.match?(/low|info/i)
          GRADE[:warning]
        else
          GRADE[:fail]
        end
      else
        exit_code.zero? ? GRADE[:pass] : GRADE[:fail]
      end
    end

    def update_stats(grade)
      case grade
      when GRADE[:pass]
        @stats[:passes] += 1
      when GRADE[:fail]
        @stats[:failures] += 1
      when GRADE[:warning]
        @stats[:warnings] += 1
      end
    end

    def calculate_pass_rate
      return 0.0 if @stats[:total_runs].zero?

      (@stats[:passes].to_f / @stats[:total_runs] * 100).round(1)
    end

    def write_temp_candidate(code, index)
      ext = @language ? ".#{@language}" : '.rb'
      temp_file = File.join(Dir.tmpdir, "candidate_#{index}_#{SecureRandom.hex(4)}#{ext}")
      File.write(temp_file, code)
      temp_file
    end
  end
end
