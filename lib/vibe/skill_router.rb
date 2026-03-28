# frozen_string_literal: true

require 'yaml'
require_relative 'semantic_matcher'

module Vibe
  # Intelligent Skill Router - Enhanced Edition
  #
  # Features:
  # - Four-layer routing (explicit → scenario → semantic → fallback)
  # - Advanced semantic matching (TF-IDF, cosine similarity)
  # - User preference learning (records successful matches)
  # - Context-aware routing (file type, project state, history)
  # - Fuzzy matching (handles typos and variations)
  #
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
    end

    # Enhanced routing with four layers
    # @param user_input [String] User's request
    # @param context [Hash] Additional context:
    #   - current_task: current active task
    #   - file_type: type of files being worked on
    #   - recent_files: recently modified files
    #   - error_count: number of recent errors
    # @return [Hash] Routing result with skill info and confidence
    def route(user_input, context = {})
      input_normalized = normalize_input(user_input)

      # Layer 1: Check for explicit override
      override = check_explicit_override(input_normalized)
      return enrich_result(override, context) if override

      # Layer 2: Match scenarios from routing config
      scenario = match_scenario(input_normalized, context)
      return enrich_result(scenario, context) if scenario

      # Layer 3: Enhanced semantic matching
      semantic = enhanced_semantic_match(input_normalized, context)
      return enrich_result(semantic, context) if semantic

      # Layer 4: Fuzzy fallback + user preferences
      fallback = fuzzy_fallback_match(input_normalized, context)
      return enrich_result(fallback, context) if fallback

      # No match found - provide helpful suggestions
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

    private

    def normalize_input(input)
      # Normalize Chinese and English punctuation, whitespace
      normalized = input.downcase
                        .gsub(/[[:punct:]]/, ' ')
                        .gsub(/\s+/, ' ')
                        .strip
      normalized
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
      # Try project root first, then current directory
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

    # Layer 1: Explicit user override
    def check_explicit_override(input)
      return nil unless routing_config['user_override']&.dig('enabled')

      keywords = routing_config['user_override']['keywords'] || {}

      keywords.each do |keyword, description|
        if input.include?(keyword.downcase)
          source = keyword.split.last
          return {
            matched: true,
            skill: nil,
            source: source,
            reason: "User explicit override: #{description}",
            confidence: :absolute,
            override: true
          }
        end
      end

      nil
    end

    # Layer 2: Scenario-based matching
    def match_scenario(input, context)
      # First check routing_rules
      rules = routing_config['routing_rules'] || []

      scored_rules = rules.map do |rule|
        score = calculate_scenario_score(rule, input, context)
        [rule, score]
      end.sort_by { |_, score| -score }

      best_rule, best_score = scored_rules.first

      if best_rule && best_score > 0.15
        primary = best_rule['primary']
        return {
          matched: true,
          skill: primary['skill'],
          source: primary['source'],
          scenario: best_rule['scenario'],
          reason: primary['reason'],
          confidence: score_to_confidence(best_score),
          alternatives: format_alternatives(best_rule['alternatives']),
          context_boost: context_boost_description(context)
        }
      end

      # Then check exclusive_skills
      exclusive_skills = routing_config['exclusive_skills'] || []
      exclusive_skills.each do |exclusive|
        keywords = Array(exclusive['keywords']).map(&:downcase)
        next if keywords.empty?

        matched_keyword = keywords.find { |kw| input.include?(kw) }
        next unless matched_keyword

        return {
          matched: true,
          skill: exclusive['skill'],
          source: exclusive['source'],
          scenario: exclusive['scenario'],
          reason: exclusive['reason'],
          confidence: :high,
          exclusive: true
        }
      end

      nil
    end

    # Layer 3: Enhanced semantic matching
    def enhanced_semantic_match(input, context)
      return nil unless registry['skills']

      skills = registry['skills']

      # Build candidate texts from intents and descriptions
      candidates = skills.map do |skill|
        {
          skill: skill,
          text: [skill['intent'], skill['description']].compact.join(' ').downcase
        }
      end

      # Use fuzzy matching for better typo tolerance
      matches = fuzzy_match(input, candidates.map { |c| c[:text] })

      # Filter by threshold and boost by user preferences
      best_match = nil
      best_score = 0

      matches.each_with_index do |match, idx|
        next if match[:score] < 0.25

        candidate = candidates[idx]
        skill = candidate[:skill]

        score = match[:score]

        # Boost by user preference history
        pref_boost = preference_boost(skill['id'])
        score *= (1 + pref_boost)

        # Boost by context relevance
        context_boost = context_skill_relevance(skill, context)
        score *= (1 + context_boost)

        if score > best_score
          best_score = score
          best_match = skill
        end
      end

      return nil unless best_match && best_score > 0.3

      {
        matched: true,
        skill: best_match['id'],
        source: best_match['namespace'],
        reason: "Semantic match: #{best_match['intent']}",
        confidence: semantic_score_to_confidence(best_score),
        semantic: true,
        similarity: best_score.round(3)
      }
    end

    # Layer 4: Fuzzy fallback with user preferences
    def fuzzy_fallback_match(input, context)
      # Check user preferences
      personalized = personalized_skills_for_input(input)

      return nil if personalized.empty?

      best_skill_id, best_data = personalized.first

      # Find skill details
      skill = registry['skills']&.find { |s| s['id'] == best_skill_id }
      return nil unless skill

      {
        matched: true,
        skill: skill['id'],
        source: skill['namespace'],
        reason: "Based on your usage history: #{best_data[:reasons].first}",
        confidence: :medium,
        personalized: true,
        usage_count: best_data[:reasons].size
      }
    end

    # Helper: Calculate scenario match score
    def calculate_scenario_score(rule, input, context)
      keywords = Array(rule['keywords']).map(&:downcase)
      return 0 if keywords.empty?

      # Keyword matching
      keyword_matches = keywords.select { |kw| input.include?(kw) }
      keyword_score = keyword_matches.size.to_f / keywords.size

      # Boost by context relevance
      context_score = 0
      if rule['context_conditions']
        context_score = evaluate_context_conditions(rule['context_conditions'], context)
      end

      # Boost by recency/frequency
      recency_boost = 0
      if rule['scenario'] && @preferences['context_patterns'][rule['scenario']]
        recency_boost = 0.1 * @preferences['context_patterns'][rule['scenario']]['count'].to_i
        recency_boost = [recency_boost, 0.3].min
      end

      keyword_score * (1 + context_score) + recency_boost
    end

    def evaluate_context_conditions(conditions, context)
      score = 0

      conditions.each do |condition|
        case condition['type']
        when 'file_extension'
          if context[:recent_files]&.any? { |f| f.end_with?(condition['value']) }
            score += 0.2
          end
        when 'error_present'
          score += 0.3 if context[:error_count].to_i > 0
        when 'task_type'
          score += 0.15 if context[:current_task] == condition['value']
        end
      end

      score
    end

    def context_skill_relevance(skill, context)
      return 0 unless context[:file_type] && skill['file_types']

      skill['file_types'].include?(context[:file_type]) ? 0.15 : 0
    end

    def preference_boost(skill_id)
      usage = @preferences['skill_usage'][skill_id]
      return 0 unless usage && usage[:count] > 0

      helpfulness = usage[:helpful].to_f / usage[:count]
      frequency_bonus = [Math.log(usage[:count]) * 0.05, 0.2].min

      helpfulness * frequency_bonus
    end

    def score_to_confidence(score)
      case score
      when 0.8..1.0 then :very_high
      when 0.6...0.8 then :high
      when 0.4...0.6 then :medium
      when 0.3...0.4 then :low
      else :very_low
      end
    end

    def semantic_score_to_confidence(score)
      case score
      when 0.7..1.0 then :high
      when 0.5...0.7 then :medium
      when 0.3...0.5 then :low
      else :very_low
      end
    end

    def format_alternatives(alternatives)
      Array(alternatives).map do |alt|
        {
          skill: alt['skill'],
          source: alt['source'],
          trigger: alt['trigger']
        }
      end
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
      # Find skills often used together
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

      # Based on keywords
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

      # Based on context
      if context[:file_type] == 'ruby' || context[:recent_files]&.any? { |f| f.end_with?('.rb') }
        suggestions << { skill: '/optimize', reason: 'Ruby optimization' }
      end

      suggestions.uniq.first(3)
    end

    def context_boost_description(context)
      boosts = []
      boosts << "errors detected" if context[:error_count].to_i > 0
      boosts << "#{context[:file_type]} files" if context[:file_type]
      boosts << "#{context[:recent_files].size} recent files" if context[:recent_files]&.size&.> 3

      boosts.empty? ? nil : boosts.join(', ')
    end
  end
end
