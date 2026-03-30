# frozen_string_literal: true

require 'yaml'
require_relative 'semantic_matcher'
require_relative 'llm_client'                         # NEW
require_relative 'cache_manager'                      # NEW
require_relative 'skill_router/ai_triage_layer'       # NEW
require_relative 'skill_router/candidate_selector'    # NEW
require_relative 'skill_router/parallel_executor'     # NEW
require_relative 'skill_router/explicit_layer'
require_relative 'skill_router/scenario_layer'
require_relative 'skill_router/semantic_layer'
require_relative 'skill_router/fuzzy_layer'
require_relative 'preference_dimension_analyzer'   # NEW

module Vibe
  # Intelligent Skill Router - Enhanced Edition
  #
  # Features:
  # - Four-layer routing (explicit -> scenario -> semantic -> fallback)
  # - Advanced semantic matching (TF-IDF, cosine similarity)
  # - User preference learning (records successful matches)
  # - Context-aware routing (file type, project state, history)
  # - Fuzzy matching (handles typos and variations)
  #
  # Routing layers are delegated to strategy classes under SkillRouter::*Layer.
  class SkillRouter
    include SemanticMatcher

    ROUTING_FILE = '.vibe/skill-routing.yaml'
    REGISTRY_FILE = 'core/skills/registry.yaml'
    SELECTION_POLICY_FILE = 'core/policies/skill-selection.yaml'
    PREFERENCES_FILE = '.vibe/skill-preferences.yaml'

    attr_reader :routing_config, :registry, :preferences, :project_root, :selection_policy

    def initialize(project_root = Dir.pwd)
      @project_root = project_root
      @routing_config = load_routing_config
      @registry = load_registry
      @preferences = load_preferences
      @selection_policy = load_selection_policy

      # Initialize routing statistics
      @stats = {
        total_routes: 0,
        layer_distribution: {
          layer_0_ai: 0,
          layer_1_explicit: 0,
          layer_2_scenario: 0,
          layer_3_semantic: 0,
          layer_4_fuzzy: 0,
          no_match: 0
        }
      }

      @explicit_layer  = ExplicitLayer.new(@routing_config)
      @scenario_layer  = ScenarioLayer.new(@routing_config, @preferences)
      @semantic_layer  = SemanticLayer.new(@registry, @preferences)
      @fuzzy_layer     = FuzzyLayer.new(@registry, @preferences)

      # NEW: Initialize AI Triage infrastructure
      @cache = Vibe::CacheManager.new(
        cache_dir: File.join(@project_root, '.vibe', 'cache'),
        memory_cache_max_size: 500
      )
      @llm_client = Vibe::LLMClient.new
      @ai_triage_layer = Vibe::SkillRouter::AITriageLayer.new(
        @registry,
        @preferences,
        cache: @cache,
        llm_client: @llm_client
      )

      # NEW: Initialize candidate selection and parallel execution
      @preference_analyzer = Vibe::PreferenceDimensionAnalyzer.new(
        config: @selection_policy.dig('preference_learning') || {}
      )
      @candidate_selector = Vibe::SkillRouter::CandidateSelector.new(
        config: @selection_policy,
        preference_analyzer: @preference_analyzer
      )
      @parallel_executor = Vibe::SkillRouter::ParallelExecutor.new(
        config: @selection_policy.dig('parallel_execution') || {}
      )
    end

    # Enhanced routing with FIVE layers (Layer 0 added) + Multi-candidate selection
    # @param user_input [String] User's request
    # @param context [Hash] Additional context:
    #   - current_task: current active task
    #   - file_type: type of files being worked on
    #   - recent_files: recently modified files
    #   - error_count: number of recent errors
    # @return [Hash] Routing result with skill info and confidence
    def route(user_input, context = {})
      input_normalized = normalize_input(user_input)
      @stats[:total_routes] += 1

      # Collect all candidates from all layers
      candidates = collect_all_candidates(input_normalized, context)

      if candidates.empty?
        @stats[:layer_distribution][:no_match] += 1
        return no_match_result(input_normalized, context)
      end

      # Use CandidateSelector to make the final decision
      decision = @candidate_selector.select(candidates, context)

      # Handle different decision types
      case decision[:action]
      when :auto_select
        # Auto-selected by confidence or preference
        record_layer_usage_for(decision[:selected])
        format_routing_result(decision[:selected], context)

      when :user_choice
        # Multiple candidates with similar confidence - present to user
        {
          matched: true,
          requires_user_choice: true,
          candidates: decision[:candidates],
          prompt: decision[:prompt],
          message: "Multiple skills match your request. Please choose."
        }

      when :parallel_execute
        # Execute multiple skills in parallel
        execute_parallel_skills(decision[:candidates], context)

      when :no_candidates
        no_match_result(input_normalized, context)

      else
        # Fallback to first candidate
        record_layer_usage(:layer_0_ai)  # Assume AI triage
        format_routing_result(candidates.first, context)
      end
    end

    # Collect candidates from all routing layers
    #
    # @param input_normalized [String] Normalized user input
    # @param context [Hash] Additional context
    # @return [Array<Hash>] All candidates from all layers
    def collect_all_candidates(input_normalized, context)
      candidates = []

      # Layer 0: AI-Powered Semantic Triage
      ai_result = @ai_triage_layer.route(input_normalized, context)
      if ai_result && ai_result[:matched]
        candidates << normalize_candidate(ai_result, :layer_0_ai)
      end

      # Layer 1: Explicit override (highest priority)
      override = @explicit_layer.check_explicit_override(input_normalized)
      if override
        candidates << normalize_candidate(override, :layer_1_explicit)
        # Explicit override always wins, return immediately
        return candidates
      end

      # Layer 2: Scenario matching
      scenario = @scenario_layer.match_scenario(input_normalized, context)
      if scenario
        candidates << normalize_candidate(scenario, :layer_2_scenario)
      end

      # Layer 3: Semantic matching
      semantic = @semantic_layer.enhanced_semantic_match(input_normalized, context)
      if semantic
        candidates << normalize_candidate(semantic, :layer_3_semantic)
      end

      # Layer 4: Fuzzy fallback
      fallback = @fuzzy_layer.fuzzy_fallback_match(input_normalized, context)
      if fallback
        candidates << normalize_candidate(fallback, :layer_4_fuzzy)
      end

      candidates
    end

    # Normalize candidate to common format
    #
    # @param result [Hash] Raw routing result
    # @param layer [Symbol] Source layer
    # @return [Hash] Normalized candidate
    def normalize_candidate(result, layer)
      {
        skill: result[:skill] || result[:id],
        id: result[:skill] || result[:id],
        source: result[:source] || result[:namespace] || 'builtin',
        confidence: normalize_confidence(result[:confidence]),
        reason: result[:reason],
        layer: layer,
        original: result
      }
    end

    # Normalize confidence to 0-1 float
    #
    # @param confidence [Symbol, Float, Integer] Confidence value
    # @return [Float] Normalized confidence
    def normalize_confidence(confidence)
      case confidence
      when :very_high then 0.95
      when :high then 0.85
      when :medium then 0.70
      when :low then 0.55
      when :very_low then 0.40
      when Float then [[confidence, 0].max, 1].min
      when Integer then [[confidence.to_f / 100, 0].max, 1].min
      else 0.70
      end
    end

    # Record layer usage for a candidate
    #
    # @param candidate [Hash] Candidate with layer info
    # @return [void]
    def record_layer_usage_for(candidate)
      layer = candidate[:layer] || :layer_0_ai
      record_layer_usage(layer)
    end

    # Execute skills in parallel
    #
    # @param candidates [Array<Hash>] Candidates to execute
    # @param context [Hash] Execution context
    # @return [Hash] Parallel execution result
    def execute_parallel_skills(candidates, context)
      # Define the skill executor
      executor = ->(candidate, ctx) {
        # For now, return the candidate info
        # In real implementation, this would trigger the skill execution
        {
          skill: candidate[:skill],
          status: :ready,
          message: "Skill ready for execution: #{candidate[:skill]}"
        }
      }

      @parallel_executor.execute(candidates, executor: executor, context: context)
    end

    # No match result
    #
    # @param input [String] User input
    # @param context [Hash] Context
    # @return [Hash] No match result
    def no_match_result(input, context)
      @stats[:layer_distribution][:no_match] += 1
      {
        matched: false,
        skill: nil,
        reason: 'No matching skill found for this request',
        suggestions: generate_suggestions(input, context),
        alternatives: find_similar_skills(input)
      }
    end

    # Format a candidate as a routing result
    #
    # @param candidate [Hash] Normalized candidate
    # @param context [Hash] Execution context
    # @return [Hash] Formatted routing result
    def format_routing_result(candidate, context = {})
      return { matched: false } unless candidate

      # Build result with matched flag
      result = {
        matched: true,
        skill: candidate[:skill],
        id: candidate[:id],
        source: candidate[:source],
        confidence: denormalize_confidence(candidate[:confidence]),
        reason: candidate[:reason],
        layer: candidate[:layer]
      }

      # Add original data if available
      result[:original] = candidate[:original] if candidate[:original]

      # Add scenario if available from original
      if candidate[:original] && candidate[:original][:scenario]
        result[:scenario] = candidate[:original][:scenario]
      end

      # Add override flag for explicit overrides
      if candidate[:layer] == :layer_1_explicit
        result[:override] = true
      end

      enrich_result(result, context)
    end

    # Convert float confidence back to symbol (for backward compatibility)
    #
    # @param confidence [Float] Normalized confidence 0-1
    # @return [Symbol] Confidence symbol
    def denormalize_confidence(confidence)
      case confidence
      when 0.90..1.0 then :very_high
      when 0.75..0.89 then :high
      when 0.60..0.74 then :medium
      when 0.45..0.59 then :low
      when 0.0..0.44 then :very_low
      else :medium
      end
    end

    # Quick check if input should trigger a skill
    def should_route?(user_input)
      result = route(user_input)
      result[:matched] && result[:confidence] != :very_low
    end

    # Get all available skills for a scenario
    # @param scenario_name [String] Scenario identifier
    # @return [Array<Hash>] List of matching skills with priorities
    def skills_for_scenario(scenario_name)
      rule = routing_config['routing_rules']&.find { |r| r['scenario'] == scenario_name }
      return [] unless rule

      skills = []

      # Add primary skill
      if rule['primary']
        skills << {
          skill: rule['primary']['skill'],
          source: rule['primary']['source'],
          priority: 'P0',
          reason: rule['primary']['reason']
        }
      end

      # Add alternatives
      Array(rule['alternatives']).each do |alt|
        skills << {
          skill: alt['skill'],
          source: alt['source'],
          priority: alt['priority'] || 'P2',
          trigger: alt['trigger']
        }
      end

      skills
    end

    # Record user preference for learning
    # @param input [String] Original user input
    # @param skill_id [String] Selected skill
    # @param was_helpful [Boolean] Whether the skill was helpful
    def record_preference(input, skill_id, was_helpful: true)
      words = tokenize(input.downcase)

      words.each do |word|
        next if STOP_WORDS.include?(word)

        @preferences['word_to_skill'][word] ||= {}
        @preferences['word_to_skill'][word][skill_id] ||= { count: 0, helpful: 0 }
        @preferences['word_to_skill'][word][skill_id][:count] += 1
        @preferences['word_to_skill'][word][skill_id][:helpful] += 1 if was_helpful
      end

      @preferences['skill_usage'][skill_id] ||= { count: 0, helpful: 0 }
      @preferences['skill_usage'][skill_id][:count] += 1
      @preferences['skill_usage'][skill_id][:helpful] += 1 if was_helpful

      save_preferences
    end

    # Get personalized recommendations based on history
    def personalized_skills_for_input(input)
      words = tokenize(input.downcase)
      skill_scores = Hash.new { |h, k| h[k] = { score: 0, reasons: [] } }

      words.each do |word|
        next if STOP_WORDS.include?(word)

        matches = @preferences['word_to_skill'][word]
        next unless matches

        matches.each do |skill_id, stats|
          helpfulness = stats[:count] > 0 ? stats[:helpful].to_f / stats[:count] : 0
          skill_scores[skill_id][:score] += helpfulness * Math.log(stats[:count] + 1)
          skill_scores[skill_id][:reasons] << "Matched word '#{word}' (#{stats[:count]}x used)"
        end
      end

      skill_scores.sort_by { |_, v| -v[:score] }.first(5).to_h
    end

    # NEW: Get comprehensive router statistics
    # @return [Hash] Statistics about routing performance and distribution
    def stats
      {
        ai_triage: @ai_triage_layer.stats,
        cache: @cache.stats,
        llm_client: @llm_client.stats,
        routing: {
          total_routes: @stats[:total_routes],
          layer_distribution: @stats[:layer_distribution]
        }
      }
    end

    # NEW: Reset AI triage circuit breaker (for testing/recovery)
    def reset_circuit_breaker
      @ai_triage_layer.reset_circuit_breaker
    end

    # NEW: Enable/disable AI triage dynamically
    def enable_ai_triage
      @ai_triage_layer.enable if @ai_triage_layer.respond_to?(:enable)
    end

    def disable_ai_triage
      @ai_triage_layer.disable if @ai_triage_layer.respond_to?(:disable)
    end

    # NEW: Clear AI triage cache
    def clear_ai_cache
      @cache.clear
    end

    # NEW: Check if AI triage is enabled
    def ai_triage_enabled?
      @ai_triage_layer.enabled?
    end

    private

    def normalize_input(input)
      input.downcase
           .gsub(/[[:punct:]]/, ' ')
           .gsub(/\s+/, ' ')
           .strip
    end

    def load_routing_config
      routing_path = File.join(@project_root, ROUTING_FILE)
      return {} unless File.exist?(routing_path)

      YAML.safe_load(File.read(routing_path), aliases: true) || {}
    rescue StandardError => e
      puts "Warning: Failed to load skill routing config: #{e.message}"
      {}
    end

    def load_registry
      registry_path = File.join(@project_root, REGISTRY_FILE)
      registry_path = REGISTRY_FILE unless File.exist?(registry_path)
      return {} unless File.exist?(registry_path)

      YAML.safe_load(File.read(registry_path), aliases: true) || {}
    rescue StandardError => e
      puts "Warning: Failed to load skill registry: #{e.message}"
      {}
    end

    def load_preferences
      prefs_path = File.join(@project_root, PREFERENCES_FILE)
      return default_preferences unless File.exist?(prefs_path)

      YAML.safe_load(File.read(prefs_path), aliases: true) || default_preferences
    rescue StandardError
      default_preferences
    end

    def default_preferences
      {
        'word_to_skill' => {},
        'skill_usage' => {},
        'context_patterns' => {}
      }
    end

    def save_preferences
      prefs_path = File.join(@project_root, PREFERENCES_FILE)
      File.write(prefs_path, YAML.dump(@preferences))
    rescue StandardError => e
      puts "Warning: Failed to save preferences: #{e.message}"
    end

    # Load selection policy from skill-selection.yaml
    #
    # @return [Hash] Selection policy configuration
    def load_selection_policy
      policy_path = File.join(@project_root, SELECTION_POLICY_FILE)
      return default_selection_policy unless File.exist?(policy_path)

      YAML.safe_load(File.read(policy_path), aliases: true) || default_selection_policy
    rescue StandardError => e
      puts "Warning: Failed to load selection policy: #{e.message}"
      default_selection_policy
    end

    # Default selection policy
    #
    # @return [Hash] Default policy config
    def default_selection_policy
      {
        'candidate_selection' => {
          'max_candidates' => 3,
          'auto_select_threshold' => 0.15,
          'min_confidence' => 0.6,
          'sort_by' => 'balanced'
        },
        'preference_learning' => {
          'enabled' => true,
          'dimensions' => {
            'consistency' => { 'weight' => 0.4, 'threshold' => 0.7, 'min_samples' => 5 },
            'satisfaction' => { 'weight' => 0.3, 'min_samples' => 3 },
            'context' => { 'weight' => 0.2 },
            'recency' => { 'weight' => 0.1, 'decay_days' => 30 }
          }
        },
        'parallel_execution' => {
          'enabled' => true,
          'max_parallel' => 2,
          'mode' => 'auto',
          'conditions' => {
            'max_confidence_diff' => 0.10,
            'min_candidates' => 2,
            'max_candidates' => 3
          },
          'aggregation' => {
            'method' => 'merged',
            'timeout' => 300
          }
        }
      }
    end

    def enrich_result(result, context)
      return result unless result[:matched]

      # Add context-aware suggestions
      result[:context_notes] = generate_context_notes(context)

      # Add related skills based on user's successful history
      if result[:skill]
        result[:related] = find_related_skills(result[:skill])
      end

      result
    end

    def generate_context_notes(context)
      notes = []

      if context[:error_count].to_i > 0
        notes << "#{context[:error_count]} errors detected - debugging skills prioritized"
      end

      if context[:recent_files] && context[:recent_files].size > 5
        notes << "High file activity - batch operation skills available"
      end

      notes
    end

    def find_related_skills(skill_id)
      cooccurrence = Hash.new(0)

      @preferences['word_to_skill'].each do |word, skills|
        if skills.key?(skill_id)
          skills.each do |other_id, _|
            cooccurrence[other_id] += 1 unless other_id == skill_id
          end
        end
      end

      cooccurrence.sort_by { |_, count| -count }.first(3).map(&:first)
    end

    def find_similar_skills(input)
      return [] unless registry['skills']

      intents = registry['skills'].map { |s| s['intent']&.downcase }.compact
      return [] if intents.empty?

      matches = fuzzy_match(input, intents)
      matches.select { |m| m[:score] > 0.2 }.first(3).map do |match|
        idx = intents.index(match[:candidate])
        skill = registry['skills'][idx]
        { skill: skill['id'], intent: skill['intent'] }
      end
    end

    def generate_suggestions(input, context)
      suggestions = []

      if input.include?('test') || input.include?('测试')
        suggestions << { skill: '/qa', reason: 'Browser testing' }
        suggestions << { skill: '/test-driven-development', reason: 'TDD workflow' }
      end

      if input.include?('error') || input.include?('bug') || input.include?('fix')
        suggestions << { skill: 'systematic-debugging', reason: 'Error investigation' }
        suggestions << { skill: '/investigate', reason: 'Root cause analysis' }
      end

      if input.include?('review') || input.include?('检查')
        suggestions << { skill: '/review', reason: 'Code review' }
        suggestions << { skill: '/refactor', reason: 'Refactoring' }
      end

      if context[:file_type] == 'ruby' || context[:recent_files]&.any? { |f| f.end_with?('.rb') }
        suggestions << { skill: '/optimize', reason: 'Ruby optimization' }
      end

      suggestions.uniq.first(3)
    end

    # NEW: Record which layer handled a request
    def record_layer_usage(layer)
      @stats[:layer_distribution][layer] += 1 if @stats[:layer_distribution][layer]
    end
  end
end
