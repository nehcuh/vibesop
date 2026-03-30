# frozen_string_literal: true

require 'yaml'
require 'json'
require 'securerandom'
require 'digest'
require_relative 'defaults'
require_relative 'cache_manager'
require_relative 'llm_provider/factory'
require_relative 'platform_paths'

module Vibe
  class PreferenceManager
    include Defaults

    attr_reader :preference_file, :preferences, :llm_provider, :cache

    # Initialize PreferenceManager
    #
    # @param llm_provider [LLMProvider::Base] LLM provider for Fast Model calls
    # @param cache [CacheManager] Cache manager for caching results
    # @param preference_file [String] Path to preference file (optional, uses default)
    def initialize(llm_provider: nil, cache: nil, preference_file: nil)
      @preference_file = preference_file || PlatformPaths.preference_file
      @cache = cache || CacheManager.new

      # Initialize or detect LLM provider
      if llm_provider
        @llm_provider = llm_provider
      else
        # Auto-detect from environment (same as AITriageLayer)
        @llm_provider = detect_llm_provider
      end

      # Load preferences
      @preferences = load_preferences

      # Detect triage model
      @triage_model = detect_triage_model
    end

    # Match user preference using Fast Model intent recognition
    #
    # @param input [String] User input text
    # @param context [Hash] Additional context (file_type, error_count, etc.)
    # @return [Hash, nil] Matched preference or nil
    def match_preference(input, context = {})
      # Step 1: Quick check for explicit rules (fallback)
      explicit_match = check_explicit_rules(input)
      return explicit_match if explicit_match

      # Step 2: Use Fast Model for intent recognition
      return nil unless @llm_provider&.configured?

      intent = recognize_intent(input, context)
      return nil unless intent

      # Step 3: Find preference by intent
      find_preference_by_intent(intent)
    end

    # Check explicit rules (regex matching)
    #
    # @param input [String] User input text
    # @return [Hash, nil] Matched rule or nil
    def check_explicit_rules(input)
      rules = @preferences.dig('explicit_rules') || []
      return nil if rules.empty?

      # Sort by priority (highest first)
      sorted_rules = rules.sort_by { |r| -r.fetch('priority', 0) }

      sorted_rules.each do |rule|
        pattern = rule['match_pattern']
        next unless pattern

        # Match regex pattern
        if input.match?(Regexp.new(pattern))
          return {
            type: :explicit_rule,
            rule_id: rule['rule_id'],
            name: rule['name'],
            skill: rule['preferred_skill'],
            priority: rule['priority'],
            requires_confirmation: rule.fetch('requires_confirmation', false),
            metadata: rule.fetch('metadata', {})
          }
        end
      end

      nil
    end

    # Recognize user intent using Fast Model
    #
    # @param input [String] User input text
    # @param context [Hash] Additional context
    # @return [String, nil] Recognized intent or nil
    def recognize_intent(input, context = {})
      return nil unless @llm_provider&.configured?

      # Check cache first
      cache_key = generate_cache_key('intent', input, context)
      cached = @cache.get(cache_key)
      return cached[:intent] if cached

      # Build prompt
      prompt = build_intent_recognition_prompt(input, context)

      begin
        # Call Fast Model
        response = @llm_provider.call(
          model: @triage_model,
          prompt: prompt,
          max_tokens: 150,
          temperature: 0.3
        )

        # Parse response
        intent = parse_intent_response(response)

        # Cache result
        if intent
          @cache.set(cache_key, { intent: intent }, ttl: 3600)  # 1 hour
        end

        intent
      rescue StandardError => e
        log_error("Intent recognition failed: #{e.message}")
        nil
      end
    end

    # Find preference by intent pattern
    #
    # @param intent [String] Recognized intent
    # @return [Hash, nil] Matched preference or nil
    def find_preference_by_intent(intent)
      intent_prefs = @preferences.dig('intent_preferences') || []
      return nil if intent_pref.empty?

      # Find matching preference
      intent_pref.find do |pref|
        patterns = pref.dig('intent_patterns') || []
        patterns.any? { |pattern| pattern == intent || intent.include?(pattern) }
      end&.then do |pref|
        {
          type: :intent_preference,
          intent_id: pref['intent_id'],
          name: pref['name'],
          skill: pref['preferred_skill'],
          confidence: pref.dig('confidence'),
          stats: pref.dig('stats') || {},
          metadata: pref.fetch('metadata', {})
        }
      end
    end

    # Record user selection
    #
    # @param input [String] User input text
    # @param selected_skill [String] Skill user selected
    # @param route_result [Hash] AI routing result
    # @return [Hash] Record entry
    def record_selection(input, selected_skill, route_result)
      entry = {
        'timestamp' => Time.now.iso8601,
        'input' => input,
        'intent' => route_result.dig(:intent),
        'selected_skill' => selected_skill,
        'ai_recommended' => route_result.dig(:primary, :skill),
        'was_recommended' => (selected_skill == route_result.dig(:primary, :skill)),
        'confidence' => route_result.dig(:primary, :confidence),
        'platform' => detect_platform,
        'user_satisfaction' => nil
      }

      # Add to history
      @preferences['selection_history'] ||= []
      @preferences['selection_history'] << entry

      # Keep only recent history (last 1000 entries)
      if @preferences['selection_history'].size > 1000
        @preferences['selection_history'] = @preferences['selection_history'].last(1000)
      end

      # Save to file
      save_preferences

      entry
    end

    # Update user satisfaction rating
    #
    # @param skill_id [String] Skill identifier
    # @param satisfied [Boolean] User satisfaction
    # @return [void]
    def record_satisfaction(skill_id, satisfied)
      # Find most recent selection for this skill
      history = @preferences['selection_history']&.reverse || []
      entry = history.find { |e| e['selected_skill'] == skill_id }

      return unless entry

      # Update satisfaction
      entry['user_satisfaction'] = satisfied

      # Update preference confidence
      update_preference_confidence(skill_id, satisfied)

      # Save
      save_preferences
    end

    # Get preference statistics
    #
    # @return [Hash] Statistics about preferences
    def stats
      history = @preferences['selection_history'] || []

      # Count by skill
      skill_counts = Hash.new(0)
      history.each do |entry|
        skill_counts[entry['selected_skill']] += 1
      end

      # Count satisfaction
      satisfaction_counts = Hash.new(0)
      history.each do |entry|
        if entry['user_satisfaction']
          satisfaction_counts[entry['selected_skill']] ||= { satisfied: 0, unsatisfied: 0 }
          if entry['user_satisfaction']
            satisfaction_counts[entry['selected_skill']][:satisfied] += 1
          else
            satisfaction_counts[entry['selected_skill']][:unsatisfied] += 1
          end
        end
      end

      {
        total_selections: history.size,
        skill_usage: skill_counts,
        satisfaction: satisfaction_counts,
        intent_preferences_count: @preferences.dig('intent_preferences')&.size || 0,
        explicit_rules_count: @preferences.dig('explicit_rules')&.size || 0
      }
    end

    # Get learning config
    #
    # @return [Hash] Learning configuration
    def learning_config
      @preferences.dig('learning_config') || default_learning_config
    end

    # Get interaction config
    #
    # @return [Hash] Interaction configuration
    def interaction_config
      @preferences.dig('interaction_config') || default_interaction_config
    end

    # Add or update intent preference
    #
    # @param intent_pattern [String] Intent pattern
    # @param skill_id [String] Skill identifier
    # @param confidence [Float] Confidence score
    # @return [void]
    def set_intent_preference(intent_pattern, skill_id, confidence: 0.8)
      @preferences['intent_preferences'] ||= []

      # Check if already exists
      existing = @preferences['intent_preferences'].find do |pref|
        pref['intent_patterns']&.include?(intent_pattern)
      end

      if existing
        existing['preferred_skill'] = skill_id
        existing['confidence'] = confidence
        existing['metadata']['last_updated'] = Time.now.iso8601
      else
        @preferences['intent_preferences'] << {
          'intent_id' => "pref_#{SecureRandom.uuid[0..7]}",
          'name' => "Intent preference: #{intent_pattern}",
          'intent_patterns' => [intent_pattern],
          'preferred_skill' => skill_id,
          'confidence' => confidence,
          'stats' => {
            'total_usages' => 0,
            'satisfaction_score' => nil
          },
          'metadata' => {
            'source' => 'user_manual',
            'first_created' => Time.now.iso8601
          }
        }
      end

      save_preferences
    end

    # Add or update explicit rule
    #
    # @param name [String] Rule name
    # @param pattern [String] Regex pattern
    # @param skill_id [String] Skill identifier
    # @param priority [Integer] Rule priority
    # @return [void]
    def set_explicit_rule(name, pattern, skill_id, priority: 50)
      @preferences['explicit_rules'] ||= []

      # Check if already exists
      existing = @preferences['explicit_rules'].find do |rule|
        rule['name'] == name
      end

      if existing
        existing['match_pattern'] = pattern
        existing['preferred_skill'] = skill_id
        existing['priority'] = priority
        existing['metadata']['updated_at'] = Time.now.iso8601
      else
        @preferences['explicit_rules'] << {
          'rule_id' => "rule_#{SecureRandom.uuid[0..7]}",
          'name' => name,
          'match_pattern' => pattern,
          'priority' => priority,
          'preferred_skill' => skill_id,
          'requires_confirmation' => false,
          'metadata' => {
            'source' => 'user_manual',
            'created_at' => Time.now.iso8601
          }
        }
      end

      save_preferences
    end

    # Reset all preferences to default
    #
    # @return [void]
    def reset
      @preferences = default_preferences
      save_preferences
    end

    private

    # Load preferences from file
    #
    # @return [Hash] Preferences hash
    def load_preferences
      if File.exist?(@preference_file)
        begin
          YAML.load_file(@preference_file) || default_preferences
        rescue StandardError => e
          log_error("Failed to load preferences: #{e.message}")
          default_preferences
        end
      else
        # Create default preferences file
        default_preferences.tap do |prefs|
          ensure_directory_exists
          File.write(@preference_file, YAML.dump(prefs))
        end
      end
    end

    # Save preferences to file
    #
    # @return [void]
    def save_preferences
      ensure_directory_exists

      @preferences['updated_at'] = Time.now.iso8601
      @preferences['schema_version'] ||= '1.0'

      File.write(@preference_file, YAML.dump(@preferences))
    end

    # Ensure preference directory exists
    #
    # @return [void]
    def ensure_directory_exists
      dir = File.dirname(@preference_file)
      FileUtils.mkdir_p(dir) unless File.exist?(dir)
    end

    # Generate cache key
    #
    # @param type [String] Cache type
    # @param input [String] User input
    # @param context [Hash] Context
    # @return [String] Cache key
    def generate_cache_key(type, input, context)
      base = "#{type}:#{input}:#{context.sort.to_h}"
      Digest::SHA256.hexdigest(base)[0..16]
    end

    # Build intent recognition prompt
    #
    # @param input [String] User input
    # @param context [Hash] Context
    # @return [String] Prompt
    def build_intent_recognition_prompt(input, context)
      context_info = build_context_info(context)

      <<~PROMPT
        识别用户请求的核心意图（不要过度分析）。

        用户请求: #{input}

        #{context_info}

        返回 JSON 格式（仅 JSON，不要其他内容）：
        {
          "intent": "code_review|debugging|refactoring|planning|testing|documentation|other",
          "confidence": 0.0-1.0,
          "keywords": ["关键词1", "关键词2"]
        }

        注意：
        - intent 只能是上述列举的类别之一
        - confidence >= 0.5 才输出结果
        - 如果不确定，设 intent 为 "other"
      PROMPT
    end

    # Build context info string
    #
    # @param context [Hash] Context
    # @return [String] Context info string
    def build_context_info(context)
      return '' if context.empty?

      info = []
      info << "文件类型: #{context[:file_type]}" if context[:file_type]
      info << "错误数量: #{context[:error_count]}" if context[:error_count]&.positive?
      info << "当前任务: #{context[:current_task]}" if context[:current_task]

      info.empty? ? '' : "上下文:\n#{info.join("\n")}"
    end

    # Parse intent response from LLM
    #
    # @param response [String] LLM response
    # @return [String, nil] Intent or nil
    def parse_intent_response(response)
      # Extract JSON from response
      json_match = response.match(/\{[\s\S]*?\}/)
      return nil unless json_match

      begin
        parsed = JSON.parse(json_match[0])
        intent = parsed['intent']

        # Validate confidence threshold
        confidence = parsed['confidence']
        return nil unless confidence && confidence >= 0.5

        intent
      rescue JSON::ParserError, TypeError => e
        log_error("JSON parsing error: #{e.message}, response: #{response}")
        nil
      end
    end

    # Update preference confidence based on user satisfaction
    #
    # @param skill_id [String] Skill identifier
    # @param satisfied [Boolean] User satisfaction
    # @return [void]
    def update_preference_confidence(skill_id, satisfied)
      intent_prefs = @preferences.dig('intent_preferences') || []
      pref = intent_prefs.find { |p| p['preferred_skill'] == skill_id }
      return unless pref

      # Update satisfaction score
      stats = pref['stats'] ||= {}
      stats['satisfaction_score'] ||= 0.0

      # Exponential moving average
      alpha = 0.3
      new_score = satisfied ? 1.0 : 0.0
      stats['satisfaction_score'] = alpha * new_score + (1 - alpha) * stats['satisfaction_score'].to_f
    end

    # Detect current platform
    #
    # @return [String] Platform name
    def detect_platform
      case
      when ENV['CLAUDE_CODE'] || File.exist?(File.join(PlatformPaths.target_config_dir(:claude_code), 'CLAUDE.md'))
        'claude-code'
      when File.exist?(PlatformPaths.target_config_dir(:opencode))
        'opencode'
      else
        'unknown'
      end
    end

    # Detect LLM provider
    #
    # @return [LLMProvider::Base, nil] Provider or nil
    def detect_llm_provider
      begin
        # Priority 1: Check for local model configuration
        local_url = ENV.fetch('LOCAL_MODEL_URL', ENV.fetch('VIBE_LOCAL_MODEL_URL', nil))
        if local_url
          return LLMProvider::Factory.create_local_provider(url: local_url)
        end

        # Priority 2: Try to detect from OpenCode config
        # (This would require OpenCode config parsing logic)

        # Priority 3: Auto-detect from environment variables
        # Prefer Anthropic for intent recognition, fallback to OpenAI
        LLMProvider::Factory.create_from_env('anthropic')
      rescue ArgumentError => e
        # No provider available - this is ok, preference matching will fall back to explicit rules
        log_error("LLM provider not available: #{e.message}")
        nil
      end
    end

    # Detect triage model
    #
    # @return [String] Model identifier
    def detect_triage_model
      env_model = ENV.fetch('VIBE_TRIAGE_MODEL', nil)
      return env_model if env_model

      # Check for local model
      local_model = ENV.fetch('LOCAL_MODEL_NAME', ENV.fetch('VIBE_LOCAL_MODEL_NAME', nil))
      return local_model if local_model

      # Auto-detect based on provider
      if @llm_provider&.provider_name == 'OpenAI'
        'gpt-4o-mini'
      else
        'claude-haiku-4-5-20251001'  # Default to Haiku for Anthropic
      end
    end

    # Default preferences structure
    #
    # @return [Hash] Default preferences
    def default_preferences
      {
        'version' => 1,
        'schema_version' => '1.0',
        'created_at' => Time.now.iso8601,
        'updated_at' => Time.now.iso8601,
        'metadata' => {
          'vibe_version' => '1.0.0'
        },
        'intent_preferences' => [],
        'explicit_rules' => [],
        'learning_config' => default_learning_config,
        'interaction_config' => default_interaction_config,
        'platform_integration' => {},
        'selection_history' => []
      }
    end

    # Default learning config
    #
    # @return [Hash] Default learning config
    def default_learning_config
      {
        'min_samples' => 5,
        'consistency_threshold' => 0.7,
        'time_window_days' => 14,
        'auto_promote' => false
      }
    end

    # Default interaction config
    #
    # @return [Hash] Default interaction config
    def default_interaction_config
      {
        'default_mode' => 'smart',
        'smart_mode' => {
          'ask_threshold' => 0.85,
          'ask_on_preference_mismatch' => true
        },
        'parallel_mode' => {
          'enabled' => true,
          'max_parallel' => 3,
          'fallback_to_serial' => true
        }
      }
    end

    # Log error
    #
    # @param message [String] Error message
    # @return [void]
    def log_error(message)
      require 'logger'
      logger = Logger.new('log/preference_manager.log') if File.exist?('log')
      logger&.error("[PreferenceManager] #{message}")
    end
  end
end
