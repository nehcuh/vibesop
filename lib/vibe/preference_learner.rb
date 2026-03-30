# frozen_string_literal: true

require 'time'
require_relative 'platform_paths'
require_relative 'config_loader'

module Vibe
  class PreferenceLearner
    attr_reader :preference_file, :learning_config, :selection_history

    # Initialize PreferenceLearner
    #
    # @param preference_file [String] Path to preference file
    # @param learning_config [Hash] Learning configuration (optional)
    def initialize(preference_file, learning_config = nil)
      @preference_file = preference_file
      @learning_config = learning_config || default_learning_config
      load_history
    end

    # Record user selection
    #
    # @param input [String] User input text
    # @param selected_skill [String] Skill user selected
    # @param route_result [Hash] AI routing result
    # @return [Symbol] :recorded, :suggest_preference, or :ask_user
    def record_selection(input, selected_skill, route_result)
      entry = build_selection_entry(input, selected_skill, route_result)

      @selection_history << entry

      # Trim history if needed
      max_size = @learning_config['max_history_size'] || 1000
      trim_history if @selection_history.size > max_size

      save_history

      # Check if we should suggest saving as preference
      if should_suggest_preference?(selected_skill)
        return :suggest_preference
      end

      :recorded
    end

    # Record user satisfaction
    #
    # @param skill_id [String] Skill identifier
    # @param satisfied [Boolean] User satisfaction
    # @return [void]
    def record_satisfaction(skill_id, satisfied)
      # Find most recent selection for this skill
      entry = @selection_history.reverse.find do |e|
        e[:selected_skill] == skill_id
      end

      return unless entry

      # Update satisfaction
      entry[:user_satisfaction] = satisfied

      save_history
    end

    # Multi-dimensional evaluation: should we suggest this as a preference?
    #
    # @param skill [String] Skill identifier
    # @return [Boolean, :ask_user] True if auto-promote, :ask_user if should prompt, false otherwise
    def should_suggest_preference?(skill)
      # Need minimum samples
      return false if skill_selection_count(skill) < @learning_config['min_samples']

      # Dimension 1: Consistency (最近 N 次的选择比例)
      consistency = calculate_consistency(skill)
      return false if consistency < @learning_config['consistency_threshold']

      # Dimension 2: Time span (是否跨越多个会话)
      time_span = calculate_time_span(skill)
      min_time_span = @learning_config['min_time_span_days'] || 3
      return false if time_span < min_time_span

      # Dimension 3: User satisfaction (如果有的话)
      satisfaction = calculate_satisfaction(skill)
      return false if satisfaction && satisfaction < 0.8

      # Dimension 4: Explicit confirmation (用户是否说过"总是用这个")
      return true if user_explicitly_confirmed?(skill)

      # Check if auto-promote is enabled
      if @learning_config['auto_promote']
        true
      else
        :ask_user  # Should ask user for confirmation
      end
    end

    # Calculate consistency score for a skill
    #
    # @param skill [String] Skill identifier
    # @return [Float] Consistency score (0.0-1.0)
    def calculate_consistency(skill)
      # Get recent selections within time window
      recent = recent_selections_within_window

      return 0.0 if recent.empty?

      # Count how many times this skill was selected
      skill_count = recent.count { |e| e[:selected_skill] == skill }

      skill_count.to_f / recent.size
    end

    # Calculate time span for a skill (in days)
    #
    # @param skill [String] Skill identifier
    # @return [Integer] Number of days between first and last selection
    def calculate_time_span(skill)
      skill_entries = @selection_history.select { |e| e[:selected_skill] == skill }

      return 0 if skill_entries.size < 2

      first_date = parse_date(skill_entries.first[:timestamp])
      last_date = parse_date(skill_entries.last[:timestamp])

      (last_date - first_date).to_i
    end

    # Calculate user satisfaction score for a skill
    #
    # @param skill [String] Skill identifier
    # @return [Float, nil] Satisfaction score (0.0-1.0) or nil if no data
    def calculate_satisfaction(skill)
      skill_entries = @selection_history.select { |e| e[:selected_skill] == skill }

      # Count satisfied vs unsatisfied
      satisfied = skill_entries.count { |e| e[:user_satisfaction] == true }
      unsatisfied = skill_entries.count { |e| e[:user_satisfaction] == false }

      total = satisfied + unsatisfied
      return nil if total == 0

      satisfied.to_f / total
    end

    # Get selection count for a skill
    #
    # @param skill [String] Skill identifier
    # @return [Integer] Number of times this skill was selected
    def skill_selection_count(skill)
      @selection_history.count { |e| e[:selected_skill] == skill }
    end

    # Check if user explicitly confirmed this skill preference
    #
    # @param skill [String] Skill identifier
    # @return [Boolean] True if user explicitly confirmed
    def user_explicitly_confirmed?(skill)
      # Check if there's an entry with explicit confirmation
      @selection_history.any? do |e|
        e[:selected_skill] == skill && e[:explicitly_confirmed] == true
      end
    end

    # Mark user explicitly confirmed preference
    #
    # @param skill [String] Skill identifier
    # @return [void]
    def mark_explicitly_confirmed(skill)
      # Find most recent selection for this skill
      entry = @selection_history.reverse.find { |e| e[:selected_skill] == skill }
      return unless entry

      entry[:explicitly_confirmed] = true
      save_history
    end

    # Get learning statistics
    #
    # @return [Hash] Statistics about learning progress
    def stats
      total_selections = @selection_history.size

      # Count by skill
      skill_counts = Hash.new(0)
      @selection_history.each do |entry|
        skill_counts[entry[:selected_skill]] += 1
      end

      # Calculate consistency for each skill
      consistency_scores = {}
      skill_counts.each_key do |skill|
        consistency_scores[skill] = calculate_consistency(skill)
      end

      {
        total_selections: total_selections,
        unique_skills: skill_counts.size,
        skill_usage: skill_counts,
        consistency_scores: consistency_scores,
        time_window_days: @learning_config['time_window_days'],
        min_samples: @learning_config['min_samples'],
        consistency_threshold: @learning_config['consistency_threshold']
      }
    end

    # Get recent selections within time window
    #
    # @return [Array] Recent selection entries
    def recent_selections_within_window
      time_window = @learning_config['time_window_days'] || 14
      cutoff_date = Date.today - time_window

      @selection_history.select do |entry|
        entry_date = parse_date(entry[:timestamp])
        entry_date >= cutoff_date
      end
    end

    # Find patterns where user consistently overrides AI recommendations
    #
    # @param min_overrides [Integer] Minimum override count
    # @return [Hash] Skills that user consistently overrides
    def find_override_patterns(min_overrides: 3)
      # Group selections by input pattern
      input_groups = @selection_history.group_by do |entry|
        # Normalize input for grouping
        normalize_input_for_pattern(entry[:input])
      end

      # Find patterns where user consistently chooses different skill
      override_patterns = {}

      input_groups.each do |input_pattern, entries|
        next if entries.size < min_overrides

        # Count skill selections for this input pattern
        skill_counts = Hash.new(0)
        entries.each do |entry|
          skill_counts[entry[:selected_skill]] += 1
        end

        # Check if one skill dominates (consistently chosen)
        dominant_skill, count = skill_counts.max_by { |_, v| v }

        if count >= entries.size * 0.7  # 70% consistency
          override_patterns[input_pattern] = {
            skill: dominant_skill,
            count: count,
            total: entries.size,
            consistency: count.to_f / entries.size
          }
        end
      end

      override_patterns
    end

    private

    # Build selection entry
    #
    # @param input [String] User input
    # @param selected_skill [String] Selected skill
    # @param route_result [Hash] Route result
    # @return [Hash] Selection entry
    def build_selection_entry(input, selected_skill, route_result)
      {
        timestamp: Time.now.strftime('%Y-%m-%dT%H:%M:%S%z'),
        input: input,
        intent: route_result.dig(:intent),
        selected_skill: selected_skill,
        ai_recommended: route_result.dig(:primary, :skill),
        was_recommended: (selected_skill == route_result.dig(:primary, :skill)),
        confidence: route_result.dig(:primary, :confidence),
        platform: detect_platform,
        user_satisfaction: nil,
        explicitly_confirmed: false
      }
    end

    # Load selection history from preference file
    #
    # @return [void]
    def load_history
      prefs = ConfigLoader.load_yaml_silent(@preference_file, default: {})
      @selection_history = (prefs['selection_history'] || []).map do |h|
        # Convert to symbol keys for consistency with build_selection_entry
        h.transform_keys(&:to_s).transform_keys(&:to_sym)
      end
    end

    # Save selection history to preference file
    #
    # @return [void]
    def save_history
      # Load existing preferences
      prefs = ConfigLoader.load_yaml_silent(@preference_file, default: {})

      # Update selection history
      prefs['selection_history'] = @selection_history
      prefs['updated_at'] = Time.now.iso8601

      # Save
      ConfigLoader.save_yaml(@preference_file, prefs, context: 'selection history')
    end

    # Trim history to max size
    #
    # @return [void]
    def trim_history
      max_size = @learning_config['max_history_size'] || 1000
      @selection_history = @selection_history.last(max_size)
    end

    # Normalize input for pattern matching
    #
    # @param input [String] User input
    # @return [String] Normalized input
    def normalize_input_for_pattern(input)
      # Remove numbers, quoted content, extra whitespace
      input
        .gsub(/\d+/, 'N')
        .gsub(/['"].*?['"]/, 'X')
        .gsub(/\s+/, ' ')
        .strip
        .downcase
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

    # Detect current platform
    #
    # @return [String] Platform name
    def detect_platform
      case
      when File.exist?(PlatformPaths.target_config_dir(:claude_code))
        'claude-code'
      when File.exist?(PlatformPaths.target_config_dir(:opencode))
        'opencode'
      else
        'unknown'
      end
    end

    # Default learning configuration
    #
    # @return [Hash] Default config
    def default_learning_config
      {
        'min_samples' => 5,
        'consistency_threshold' => 0.7,
        'time_window_days' => 14,
        'min_time_span_days' => 3,
        'auto_promote' => false,
        'max_history_size' => 1000
      }
    end
  end
end
