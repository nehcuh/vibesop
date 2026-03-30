# frozen_string_literal: true

require 'time'
require_relative 'platform_paths'
require_relative 'preference_learner'
require_relative 'config_loader'

module Vibe
  # Multi-Dimensional Preference Analyzer
  #
  # Analyzes user preferences across multiple dimensions:
  # - Consistency: User's historical consistency for similar tasks
  # - Satisfaction: User's past satisfaction ratings
  # - Context: File type, project type, time of day
  # - Recency: Recent choices weighted more heavily
  #
  class PreferenceDimensionAnalyzer
    attr_reader :config, :preference_file

    def initialize(config: {}, preference_file: nil)
      @config = default_config.merge(config)
      @preference_file = preference_file || PlatformPaths.preference_file
      load_history
    end

    # Analyze candidates and return preference boost scores
    #
    # @param candidates [Array<Hash>] Candidate skills
    # @param context [Hash] Current context (user_input, file_type, etc.)
    # @return [Hash] Skill ID -> preference boost score (0.0-1.0)
    def analyze(candidates, context = {})
      return {} unless @config['enabled']
      return {} if @selection_history.empty?

      # Extract skill IDs from candidates
      skill_ids = candidates.map { |c| c[:skill] || c[:id] }.compact

      # Calculate scores for each dimension
      consistency_scores = calculate_consistency_scores(skill_ids, context)
      satisfaction_scores = calculate_satisfaction_scores(skill_ids)
      context_scores = calculate_context_scores(skill_ids, context)
      recency_scores = calculate_recency_scores(skill_ids)

      # Combine weighted scores - only for skills with actual data
      combined_scores = {}
      skill_ids.each do |skill_id|
        # Only include if at least one dimension has meaningful data
        has_data = [
          consistency_scores[skill_id],
          satisfaction_scores[skill_id],
          context_scores[skill_id],
          recency_scores[skill_id]
        ].any? { |score| score && score > 0 }

        next unless has_data

        combined_scores[skill_id] = combine_scores(
          consistency: consistency_scores[skill_id] || 0,
          satisfaction: satisfaction_scores[skill_id] || 0,
          context: context_scores[skill_id] || 0,
          recency: recency_scores[skill_id] || 0
        )
      end

      combined_scores
    end

    # Get detailed analysis for a specific skill
    #
    # @param skill_id [String] Skill identifier
    # @return [Hash] Detailed analysis per dimension
    def detailed_analysis(skill_id)
      {
        consistency: calculate_consistency_for_skill(skill_id),
        satisfaction: calculate_satisfaction_for_skill(skill_id),
        context: calculate_context_for_skill(skill_id),
        recency: calculate_recency_for_skill(skill_id),
        overall: overall_score(skill_id)
      }
    end

    # Reload history from preference file (for testing)
    #
    # @return [void]
    def reload
      load_history
    end

    private

    # Load selection history from preference file
    #
    # @return [void]
    def load_history
      prefs = ConfigLoader.load_yaml_silent(@preference_file, default: {})
      @selection_history = (prefs['selection_history'] || []).map do |h|
        # Convert to symbol keys for consistent access
        h.transform_keys(&:to_s).transform_keys(&:to_sym)
      end
    end

    # Calculate consistency scores for skills
    #
    # @param skill_ids [Array<String>] Skill IDs to analyze
    # @param context [Hash] Current context
    # @return [Hash] Skill ID -> consistency score (0.0-1.0)
    def calculate_consistency_scores(skill_ids, context)
      return {} unless enough_samples?

      # Get recent selections within time window
      recent = recent_selections
      return {} if recent.empty?

      scores = {}
      skill_ids.each do |skill_id|
        # Count how often this skill was selected for similar tasks
        similar_count = recent.count do |entry|
          entry[:selected_skill] == skill_id && similar_context?(entry, context)
        end

        total_similar = recent.count { |entry| similar_context?(entry, context) }
        next if total_similar.zero?

        scores[skill_id] = similar_count.to_f / total_similar
      end

      scores
    end

    # Calculate satisfaction scores for skills
    #
    # @param skill_ids [Array<String>] Skill IDs to analyze
    # @return [Hash] Skill ID -> satisfaction score (0.0-1.0)
    def calculate_satisfaction_scores(skill_ids)
      skill_entries = @selection_history.select do |entry|
        skill_ids.include?(entry[:selected_skill])
      end

      scores = {}
      skill_ids.each do |skill_id|
        entries = skill_entries.select { |e| e[:selected_skill] == skill_id }

        satisfied = entries.count { |e| e[:user_satisfaction] == true }
        unsatisfied = entries.count { |e| e[:user_satisfaction] == false }
        total = satisfied + unsatisfied

        scores[skill_id] = total.zero? ? 0 : satisfied.to_f / total
      end

      scores
    end

    # Calculate context-aware scores for skills
    #
    # @param skill_ids [Array<String>] Skill IDs to analyze
    # @param context [Hash] Current context
    # @return [Hash] Skill ID -> context score (0.0-1.0)
    def calculate_context_scores(skill_ids, context)
      return {} if context.empty?

      scores = {}
      skill_ids.each do |skill_id|
        # Find entries with similar context
        similar_entries = @selection_history.select do |entry|
          entry[:selected_skill] == skill_id && similar_context?(entry, context)
        end

        next if similar_entries.empty?

        # Score based on how often this skill was chosen in similar context
        context_matches = similar_entries.count
        total_entries = @selection_history.count { |e| e[:selected_skill] == skill_id }

        scores[skill_id] = total_entries.zero? ? 0 : context_matches.to_f / total_entries
      end

      scores
    end

    # Calculate recency scores for skills
    #
    # @param skill_ids [Array<String>] Skill IDs to analyze
    # @return [Hash] Skill ID -> recency score (0.0-1.0)
    def calculate_recency_scores(skill_ids)
      decay_days = @config.dig('dimensions', 'recency', 'decay_days') || 30
      cutoff_date = Date.today - decay_days

      scores = {}
      skill_ids.each do |skill_id|
        recent_entries = @selection_history.select do |entry|
          entry[:selected_skill] == skill_id &&
            parse_date(entry[:timestamp]) >= cutoff_date
        end

        next if recent_entries.empty?

        # Calculate exponential decay score based on most recent use
        most_recent = recent_entries.max_by { |e| parse_date(e[:timestamp]) }
        days_ago = (Date.today - parse_date(most_recent[:timestamp])).to_i

        # Exponential decay: score = e^(-days / decay_period)
        decay_period = decay_days.to_f / 3
        scores[skill_id] = Math.exp(-days_ago / decay_period)
      end

      scores
    end

    # Combine scores from all dimensions using weights
    #
    # @param scores [Hash] Dimension scores
    # @return [Float] Combined score
    def combine_scores(scores)
      dims = @config['dimensions']

      total = 0.0
      total += scores[:consistency] * dims['consistency']['weight']
      total += scores[:satisfaction] * dims['satisfaction']['weight']
      total += scores[:context] * dims['context']['weight']
      total += scores[:recency] * dims['recency']['weight']

      [[total, 0].max, 1].min  # Clamp to [0, 1]
    end

    # Helper: Calculate consistency for a specific skill
    #
    # @param skill_id [String] Skill ID
    # @return [Float] Consistency score
    def calculate_consistency_for_skill(skill_id)
      threshold = @config.dig('dimensions', 'consistency', 'threshold') || 0.7
      min_samples = @config.dig('dimensions', 'consistency', 'min_samples') || 5

      recent = recent_selections
      return 0 if recent.size < min_samples

      skill_count = recent.count { |e| e[:selected_skill] == skill_id }
      return 0 if skill_count.zero?

      skill_count.to_f / recent.size
    end

    # Helper: Calculate satisfaction for a specific skill
    #
    # @param skill_id [String] Skill ID
    # @return [Float] Satisfaction score
    def calculate_satisfaction_for_skill(skill_id)
      entries = @selection_history.select { |e| e[:selected_skill] == skill_id }
      return 0 if entries.empty?

      satisfied = entries.count { |e| e[:user_satisfaction] == true }
      unsatisfied = entries.count { |e| e[:user_satisfaction] == false }
      total = satisfied + unsatisfied

      total.zero? ? 0 : satisfied.to_f / total
    end

    # Helper: Calculate context score for a specific skill
    #
    # @param skill_id [String] Skill ID
    # @return [Float] Context score
    def calculate_context_for_skill(skill_id)
      # Simplified - count how many different contexts this skill was used in
      entries = @selection_history.select { |e| e[:selected_skill] == skill_id }
      return 0 if entries.empty?

      # Higher score for skill used in diverse contexts
      unique_contexts = entries.map { |e| e[:file_type] }.compact.uniq.size
      [unique_contexts.to_f / 10, 1].min  # Cap at 10 different file types
    end

    # Helper: Calculate recency score for a specific skill
    #
    # @param skill_id [String] Skill ID
    # @return [Float] Recency score
    def calculate_recency_for_skill(skill_id)
      entries = @selection_history.select { |e| e[:selected_skill] == skill_id }
      return 0 if entries.empty?

      most_recent = entries.max_by { |e| parse_date(e[:timestamp]) }
      days_ago = (Date.today - parse_date(most_recent[:timestamp])).to_i

      decay_period = 10
      Math.exp(-days_ago / decay_period)
    end

    # Helper: Calculate overall score for a skill
    #
    # @param skill_id [String] Skill ID
    # @return [Float] Overall score
    def overall_score(skill_id)
      combine_scores(
        consistency: calculate_consistency_for_skill(skill_id),
        satisfaction: calculate_satisfaction_for_skill(skill_id),
        context: calculate_context_for_skill(skill_id),
        recency: calculate_recency_for_skill(skill_id)
      )
    end

    # Get recent selections within time window
    #
    # @return [Array] Recent selection entries
    def recent_selections
      time_window = @config.dig('dimensions', 'consistency', 'time_window_days') || 14
      cutoff_date = Date.today - time_window

      @selection_history.select do |entry|
        parse_date(entry[:timestamp]) >= cutoff_date
      end
    end

    # Check if we have enough samples for learning
    #
    # @return [Boolean] True if enough samples
    def enough_samples?
      min_samples = @config.dig('dimensions', 'consistency', 'min_samples') || 5
      recent_selections.size >= min_samples
    end

    # Check if two contexts are similar
    #
    # @param entry [Hash] History entry
    # @param context [Hash] Current context
    # @return [Boolean] True if contexts are similar
    def similar_context?(entry, context)
      # Check file type match
      if context[:file_type] && entry[:file_type]
        return false unless entry[:file_type] == context[:file_type]
      end

      # Check project type match (if available)
      if context[:project_type] && entry[:project_type]
        return false unless entry[:project_type] == context[:project_type]
      end

      true
    end

    # Parse date from ISO8601 string
    #
    # @param iso_string [String] ISO8601 date string
    # @return [Date] Date object
    def parse_date(iso_string)
      Date.parse(iso_string)
    rescue ArgumentError, TypeError
      Date.today
    end

    # Default configuration
    #
    # @return [Hash] Default config
    def default_config
      {
        'enabled' => true,
        'dimensions' => {
          'consistency' => {
            'weight' => 0.4,
            'threshold' => 0.7,
            'min_samples' => 5,
            'time_window_days' => 14
          },
          'satisfaction' => {
            'weight' => 0.3,
            'min_samples' => 3
          },
          'context' => {
            'weight' => 0.2,
            'factors' => ['file_type', 'project_type', 'time_of_day', 'recent_files']
          },
          'recency' => {
            'weight' => 0.1,
            'decay_days' => 30
          }
        }
      }
    end
  end
end
