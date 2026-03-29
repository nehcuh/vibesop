# frozen_string_literal: true

require 'yaml'
require_relative 'semantic_matcher'
require_relative 'llm_client'                         # NEW
require_relative 'cache_manager'                      # NEW
require_relative 'skill_router/ai_triage_layer'       # NEW
require_relative 'skill_router/explicit_layer'
require_relative 'skill_router/scenario_layer'
require_relative 'skill_router/semantic_layer'
require_relative 'skill_router/fuzzy_layer'

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
    PREFERENCES_FILE = '.vibe/skill-preferences.yaml'

    attr_reader :routing_config, :registry, :preferences, :project_root

    def initialize(project_root = Dir.pwd)
      @project_root = project_root
      @routing_config = load_routing_config
      @registry = load_registry
      @preferences = load_preferences

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
    end

    # Enhanced routing with FIVE layers (Layer 0 added)
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

      # Layer 0: AI-Powered Semantic Triage (NEW)
      ai_result = @ai_triage_layer.route(input_normalized, context)
      if ai_result && ai_result[:matched]
        record_layer_usage(:layer_0_ai)
        return enrich_result(ai_result, context)
      end

      # Layer 1: Check for explicit override
      override = @explicit_layer.check_explicit_override(input_normalized)
      if override
        record_layer_usage(:layer_1_explicit)
        return enrich_result(override, context)
      end

      # Layer 2: Match scenarios from routing config
      scenario = @scenario_layer.match_scenario(input_normalized, context)
      if scenario
        record_layer_usage(:layer_2_scenario)
        return enrich_result(scenario, context)
      end

      # Layer 3: Enhanced semantic matching
      semantic = @semantic_layer.enhanced_semantic_match(input_normalized, context)
      if semantic
        record_layer_usage(:layer_3_semantic)
        return enrich_result(semantic, context)
      end

      # Layer 4: Fuzzy fallback + user preferences
      fallback = @fuzzy_layer.fuzzy_fallback_match(input_normalized, context)
      if fallback
        record_layer_usage(:layer_4_fuzzy)
        return enrich_result(fallback, context)
      end

      # No match found - provide helpful suggestions
      @stats[:layer_distribution][:no_match] += 1
      {
        matched: false,
        skill: nil,
        reason: 'No matching skill found for this request',
        suggestions: generate_suggestions(input_normalized, context),
        alternatives: find_similar_skills(input_normalized)
      }
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

    private

    # NEW: Record which layer handled a request
    def record_layer_usage(layer)
      @stats[:layer_distribution][layer] += 1 if @stats[:layer_distribution][layer]
    end
  end
end
