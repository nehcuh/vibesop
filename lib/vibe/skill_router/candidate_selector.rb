# frozen_string_literal: true

require_relative '../defaults'
require_relative '../preference_dimension_analyzer'

module Vibe
  class SkillRouter
    # Candidate Selector - Decides which skill to use from multiple candidates
    #
    # Responsibilities:
    # - Analyze confidence differences between candidates
    # - Apply user preference learning
    # - Decide between auto-selection, user choice, or parallel execution
    #
    class CandidateSelector
      include Defaults

      attr_reader :config, :preference_analyzer

      # Initialize CandidateSelector
      #
      # @param config [Hash] Selection configuration from skill-selection.yaml
      # @param preference_analyzer [PreferenceDimensionAnalyzer] Preference learning
      def initialize(config: {}, preference_analyzer: nil)
        @config = deep_merge(defaults, config)
        @preference_analyzer = preference_analyzer || PreferenceDimensionAnalyzer.new
      end

      # Select the best action from multiple candidates
      #
      # @param candidates [Array<Hash>] Candidate skills with confidence scores
      # @param context [Hash] Additional context (user_input, file_type, etc.)
      # @return [Hash] Selection decision with action and metadata
      def select(candidates, context = {})
        return no_candidates_decision if candidates.empty?
        return single_candidate_decision(candidates.first) if candidates.one?

        # Sort candidates by confidence
        sorted = sort_candidates(candidates)

        # Filter by minimum confidence
        filtered = filter_by_min_confidence(sorted)
        return no_candidates_decision if filtered.empty?

        # Get top candidates up to max_candidates
        top_candidates = filtered.first(@config['candidate_selection']['max_candidates'])

        # Apply preference learning if enabled
        if @config['preference_learning']['enabled']
          preference_boost = @preference_analyzer.analyze(top_candidates, context)
          apply_preference_boost!(top_candidates, preference_boost)
        end

        # Make decision
        make_selection_decision(top_candidates, context)
      end

      # Check if we should auto-select based on confidence gap
      #
      # @param candidates [Array<Hash>] Sorted candidates (highest first)
      # @return [Boolean] True if should auto-select top choice
      def should_auto_select?(candidates)
        return true if candidates.size < 2

        threshold = @config['candidate_selection']['auto_select_threshold']
        top_confidence = candidates.first[:confidence]
        second_confidence = candidates[1][:confidence]

        (top_confidence - second_confidence) >= threshold
      end

      # Get candidates suitable for parallel execution
      #
      # @param candidates [Array<Hash>] Candidate skills
      # @return [Array<Hash>] Candidates that meet parallel execution criteria
      def parallel_candidates(candidates)
        return [] unless @config['parallel_execution']['enabled']

        conditions = @config['parallel_execution']['conditions']

        # Check candidate count
        return [] if candidates.size < conditions['min_candidates']
        return [] if candidates.size > conditions['max_candidates']

        # Check confidence spread
        # Get max confidence using map to ensure numeric comparison
        confidences = candidates.map { |c| c[:confidence] }
        max_conf = confidences.max
        min_conf = confidences.min
        diff = max_conf - min_conf

        return [] if diff > conditions['max_confidence_diff']

        candidates.first(@config['parallel_execution']['max_parallel'])
      end

      private

      # Sort candidates by configured strategy
      #
      # @param candidates [Array<Hash>] Unsorted candidates
      # @return [Array<Hash>] Sorted candidates
      def sort_candidates(candidates)
        strategy = @config['candidate_selection']['sort_by']

        case strategy
        when :confidence
          candidates.sort_by { |c| -c[:confidence] }
        when :preference
          # Sort by preference score (if available)
          candidates.sort_by { |c| -(c[:preference_score] || 0) }
        when :balanced
          # Combine confidence and preference
          candidates.sort_by { |c| -combined_score(c) }
        else
          candidates.sort_by { |c| -c[:confidence] }
        end
      end

      # Filter candidates by minimum confidence threshold
      #
      # @param candidates [Array<Hash>] Sorted candidates
      # @return [Array<Hash>] Filtered candidates
      def filter_by_min_confidence(candidates)
        min_conf = @config['candidate_selection']['min_confidence']
        candidates.select { |c| c[:confidence] >= min_conf }
      end

      # Calculate combined score for balanced sorting
      #
      # @param candidate [Hash] Candidate with confidence and preference_score
      # @return [Float] Combined score
      def combined_score(candidate)
        conf = candidate[:confidence] || 0
        pref = candidate[:preference_score] || 0
        # Weight: 70% confidence, 30% preference
        (conf * 0.7) + (pref * 0.3)
      end

      # Apply preference boost to candidates
      #
      # @param candidates [Array<Hash>] Candidates to modify
      # @param boost_scores [Hash] Skill ID -> boost score
      # @return [void]
      def apply_preference_boost!(candidates, boost_scores)
        candidates.each do |candidate|
          skill_id = candidate[:skill] || candidate[:id]
          candidate[:preference_score] = boost_scores[skill_id] || 0
        end
      end

      # Make the final selection decision
      #
      # @param candidates [Array<Hash>] Top candidates
      # @param context [Hash] Additional context
      # @return [Hash] Decision with action and metadata
      def make_selection_decision(candidates, context)
        # Check if we should auto-select
        if should_auto_select?(candidates)
          return auto_select_decision(candidates.first)
        end

        # Check if we should run parallel
        parallel = parallel_candidates(candidates)
        if parallel.any? && @config['parallel_execution']['mode'] != 'disabled'
          return parallel_decision(parallel)
        end

        # Default: offer user choice
        user_choice_decision(candidates)
      end

      # Decision: No candidates available
      #
      # @return [Hash] No candidates decision
      def no_candidates_decision
        {
          action: :no_candidates,
          candidates: [],
          message: "No matching skills found",
          fallback: @config['fallback']['no_candidates']
        }
      end

      # Decision: Single candidate - auto-select
      #
      # @param candidate [Hash] The single candidate
      # @return [Hash] Auto-select decision
      def single_candidate_decision(candidate)
        {
          action: :auto_select,
          selected: candidate,
          candidates: [candidate],
          reason: "Only one matching skill"
        }
      end

      # Decision: Auto-select based on confidence gap or preference
      #
      # @param candidate [Hash] Top candidate
      # @return [Hash] Auto-select decision
      def auto_select_decision(candidate)
        {
          action: :auto_select,
          selected: candidate,
          candidates: [candidate],
          reason: "Highest confidence score (gap > threshold) OR strong user preference"
        }
      end

      # Decision: Offer user choice
      #
      # @param candidates [Array<Hash>] Candidates to choose from
      # @return [Hash] User choice decision
      def user_choice_decision(candidates)
        {
          action: :user_choice,
          candidates: candidates,
          prompt: build_choice_prompt(candidates),
          max_selections: 1
        }
      end

      # Decision: Execute skills in parallel
      #
      # @param candidates [Array<Hash>] Candidates for parallel execution
      # @return [Hash] Parallel execution decision
      def parallel_decision(candidates)
        {
          action: :parallel_execute,
          candidates: candidates,
          aggregation: @config['parallel_execution']['aggregation'],
          timeout: @config['parallel_execution']['aggregation']['timeout']
        }
      end

      # Build user choice prompt
      #
      # @param candidates [Array<Hash>] Candidates
      # @return [String] Prompt for user
      def build_choice_prompt(candidates)
        prompt = "Multiple skills match your request. Please choose:\n"
        candidates.each_with_index do |candidate, i|
          conf = (candidate[:confidence] * 100).round(1)
          prompt += "#{i + 1}. #{candidate[:skill]} (confidence: #{conf}%"
          prompt += ", preference: #{(candidate[:preference_score] * 100).round(1)}%" if candidate[:preference_score]
          prompt += ")\n"
        end
        prompt
      end

      # Default configuration
      #
      # @return [Hash] Default config
      def defaults
        {
          'candidate_selection' => {
            'max_candidates' => 3,
            'auto_select_threshold' => 0.15,
            'min_confidence' => 0.6,
            'sort_by' => 'balanced'
          },
          'preference_learning' => {
            'enabled' => true
          },
          'parallel_execution' => {
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
          },
          'fallback' => {
            'no_candidates' => 'suggest_similar',
            'no_preferences' => 'use_confidence',
            'parallel_failed' => 'fallback_to_serial'
          }
        }
      end

      # Deep merge two hashes
      #
      # @param base [Hash] Base hash
      # @param override [Hash] Override hash
      # @return [Hash] Merged hash
      def deep_merge(base, override)
        base.merge(override) do |key, old_val, new_val|
          if old_val.is_a?(Hash) && new_val.is_a?(Hash)
            deep_merge(old_val, new_val)
          else
            new_val
          end
        end
      end
    end
  end
end
