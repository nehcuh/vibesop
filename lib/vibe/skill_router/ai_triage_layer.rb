# frozen_string_literal: true

require_relative '../defaults'
require_relative '../llm_client'
require_relative '../cache_manager'
require_relative '../llm_provider/factory'

module Vibe
  class SkillRouter
    # Layer 0: AI-Powered Semantic Triage
    #
    # Uses Claude Haiku for fast semantic analysis before traditional routing.
    # This layer improves matching accuracy from ~70% (algorithm-based) to ~95% (AI-based).
    #
    # Architecture:
    #   1. Cache check (multi-level: memory → file → redis)
    #   2. Quick algorithm pre-check (high confidence matches)
    #   3. AI semantic analysis (Haiku, ~150ms)
    #   4. Skill matching with context awareness
    #
    # Cost Optimization:
    #   - 70%+ cache hit rate → minimal API calls
    #   - Token optimization → reduce prompt size
    #   - Rate limiting → prevent cost overruns
    #
    # Reliability:
    #   - Automatic fallback to existing layers on error
    #   - Timeout protection (5s max)
    #   - Circuit breaker for repeated failures
    #
    class AITriageLayer
      include Defaults

      attr_reader :registry, :preferences, :cache, :llm_client, :llm_provider, :enabled

      def initialize(registry, preferences, cache: nil, llm_client: nil, llm_provider: nil)
        @registry = registry
        @preferences = preferences
        @cache = cache || CacheManager.new

        # Support both old (llm_client) and new (llm_provider) interfaces
        if llm_provider
          @llm_provider = llm_provider
          @llm_client = nil # Deprecated, use llm_provider instead
        else
          # For backward compatibility, create provider from LLMClient or auto-detect
          @llm_client = llm_client # Keep for backward compatibility
          @llm_provider = create_provider_from_config
        end

        # Configuration from environment or defaults
        @enabled = ENV.fetch('VIBE_AI_TRIAGE_ENABLED', 'true') == 'true'

        # 🔧 Smart environment detection
        # Priority: Project configuration > Environment variables
        #
        # 1. OpenCode project (has opencode.json) → AI triage enabled
        # 2. Claude Code (has CLAUDECODE env var) → AI triage disabled by default
        # 3. Standalone → AI triage enabled
        #
        # Reasoning: Project configuration should take precedence over runtime environment.
        # If a project has opencode.json, it's designed for OpenCode behavior regardless
        # of where it's being executed (even if inside Claude Code for testing).
        if running_in_opencode?
          # OpenCode project - AI triage should be enabled
          @enabled = true
          @disabled_reason = nil
        elsif running_in_claude_code?
          # Claude Code environment (but not an OpenCode project)
          # Check if user explicitly enabled AI triage in Claude Code
          explicitly_enabled = ENV.key?('VIBE_AI_TRIAGE_ENABLED')

          if !explicitly_enabled
            @enabled = false
            @disabled_reason = "Running inside Claude Code - using built-in reasoning. " \
                               "Set VIBE_AI_TRIAGE_ENABLED=true in settings.json to enable external AI triage."
          end
        end

        # Auto-detect if we should disable AI triage based on provider availability
        if @enabled && !@llm_provider&.configured?
          @enabled = false
          @disabled_reason = "No LLM provider configured. Set ANTHROPIC_API_KEY or OPENAI_API_KEY."
        end

        @triage_model = detect_triage_model
        @cache_ttl = Integer(ENV.fetch('VIBE_TRIAGE_CACHE_TTL', '86400')) # 24 hours
        @confidence_threshold = Float(ENV.fetch('VIBE_TRIAGE_CONFIDENCE', '0.7'))
        @timeout = Integer(ENV.fetch('VIBE_TRIAGE_TIMEOUT', '5')) # seconds

        # Circuit breaker state
        @failure_count = 0
        @last_failure_time = nil
        @circuit_open_until = nil
      end

      # Main routing entry point for AI triage
      # @param input [String] Normalized user input
      # @param context [Hash] Additional context:
      #   - file_type: Type of files being worked on
      #   - error_count: Number of recent errors
      #   - recent_files: Recently modified files
      #   - current_task: Current active task
      # @return [Hash, nil] Routing result or nil if no match/fallback needed
      def route(input, context = {})
        return nil unless enabled?
        return nil if circuit_open?

        # Step 1: Check cache (fastest path)
        cached_result = check_cache(input, context)
        return enrich_result(cached_result, :cache) if cached_result

        # Step 2: Quick algorithm check for obvious matches
        quick_result = quick_algorithm_check(input, context)
        if quick_result && quick_result[:confidence] == :very_high
          cache_result(input, context, quick_result)
          return enrich_result(quick_result, :algorithm)
        end

        # Step 3: AI semantic analysis (the main value add)
        begin
          ai_result = call_with_timeout do
            ai_semantic_analysis(input, context)
          end

          # Record failure if AI returned nil
          if ai_result.nil? || ai_result[:skills]&.empty?
            record_failure
            return nil
          end

          # Build and cache final result
          result = build_multi_candidate_result(ai_result)
          cache_result(input, context, result)

          reset_circuit_breaker # Success - reset failure count
          enrich_result(result, :ai)

        rescue Timeout::Error
          log_error("AI Triage timeout after #{@timeout}s", input, context)
          record_failure
          nil # Fall through to next layer
        rescue StandardError => e
          log_error(e.message, input, context)
          record_failure
          nil # Fall through to next layer
        end
      end

      # Check if AI triage is enabled
      def enabled?
        @enabled
      end

      # Detect if we're running inside Claude Code
      #
      # Checks for Claude Code environment variables:
      # - CLAUDECODE=1
      # - CLAUDE_CODE_ENTRYPOINT=cli
      # - CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC=1
      #
      # @return [Boolean] true if running inside Claude Code
      def running_in_claude_code?
        ENV['CLAUDECODE'] == '1' ||
          ENV['CLAUDE_CODE_ENTRYPOINT'] == 'cli' ||
          ENV.key?('CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC')
      end

      # Detect if we're running inside OpenCode
      #
      # Checks for OpenCode configuration files:
      # - opencode.json (project root)
      # - .vibe/opencode.json (hidden config)
      # - OPENCODE=1 environment variable
      #
      # @return [Boolean] true if running inside OpenCode
      def running_in_opencode?
        ENV['OPENCODE'] == '1' ||
          File.exist?('opencode.json') ||
          File.exist?('.vibe/opencode.json') ||
          File.exist?('.vibe/opencode/config.json')
      end

      # Get the current runtime environment
      #
      # Priority: OpenCode project > Claude Code env > Standalone
      #
      # @return [Symbol] :opencode, :claude_code, or :standalone
      def runtime_environment
        if running_in_opencode?
          :opencode
        elsif running_in_claude_code?
          :claude_code
        else
          :standalone
        end
      end

      # Enable AI triage
      def enable
        @enabled = true
      end

      # Disable AI triage
      def disable
        @enabled = false
      end

      # Get statistics about AI triage performance
      def stats
        cache_stats = @cache.stats
        provider_stats = @llm_provider&.stats || {}

        # Detect if using local model
        local_url = ENV.fetch('LOCAL_MODEL_URL', nil) || ENV.fetch('VIBE_LOCAL_MODEL_URL', nil)
        is_local = local_url && provider_stats[:base_url]&.include?(local_url.gsub('/v1', ''))

        {
          enabled: @enabled,
          disabled_reason: @disabled_reason,
          runtime_environment: runtime_environment,
          model: @triage_model,
          provider: is_local ? 'Local' : (provider_stats[:provider_name] || 'unknown'),
          provider_configured: provider_stats[:configured] || false,
          base_url: provider_stats[:base_url],
          is_local_model: is_local,
          circuit_state: circuit_open? ? :open : :closed,
          failure_count: @failure_count,
          cache_stats: cache_stats
        }
      end

      # Reset circuit breaker (for testing or manual recovery)
      def reset_circuit_breaker
        @failure_count = 0
        @last_failure_time = nil
        @circuit_open_until = nil
      end

      private

      # Step 1: Check cache
      def check_cache(input, context)
        cache_key = generate_cache_key(input, context)
        @cache.get(cache_key)
      end

      # Step 2: Quick algorithm check for high-confidence matches
      def quick_algorithm_check(input, context)
        # Explicit overrides (e.g., "use gstack for debugging")
        # Only these should return :very_high confidence to skip AI
        if input.match?(/用\s+(gstack|superpowers)\s+(.+)/)
          return extract_explicit_skill(input)
        end

        # Direct skill invocation (e.g., "/review this code")
        # Also return :very_high confidence for explicit skill invocations
        if input.match?(/(?:\/\w+|调用|使用)\s*[\u4e00-\u9fa5\w]+/)
          return extract_direct_skill(input)
        end

        # Keyword patterns - return :high confidence instead of :very_high
        # This allows AI to still be consulted for better semantic understanding
        keyword_patterns = [
          { pattern: /(?:帮我|请)\s*(调试|debug|fix|修复| investigate)/, skill_hint: 'debugging' },
          { pattern: /(?:审查|review|评审|检查)\s*(?:代码|code)/, skill_hint: 'review' },
          { pattern: /(?:重构|refactor|重构)/, skill_hint: 'refactoring' }
        ]

        keyword_patterns.each do |pattern_info|
          if input.match?(pattern_info[:pattern])
            # Try to find best skill for this hint
            skill = find_best_skill_for_hint(pattern_info[:skill_hint], context)
            # Return :high confidence instead of :very_high
            # This allows AI to provide better semantic matching
            return build_quick_result(skill, :high) if skill
          end
        end

        nil
      end

      # AI semantic analysis using configured provider
      def ai_semantic_analysis(input, context)
        prompt = build_triage_prompt(input, context)

        # Use new provider interface if available, otherwise fall back to old llm_client
        response = if @llm_provider
                    @llm_provider.call(
                      model: @triage_model,
                      prompt: prompt,
                      max_tokens: 500,
                      temperature: 0.3
                    )
                  elsif @llm_client
                    # Backward compatibility
                    @llm_client.call(
                      model: @triage_model,
                      prompt: prompt,
                      max_tokens: 500,
                      temperature: 0.3
                    )
                  else
                    raise "No LLM client or provider configured"
                  end

        puts "[AI Triage] Response for '#{input[0..30]}':"
        puts response[0..500] if response.length > 0
        puts ""

        parse_ai_response(response)
      end

      # Build optimized prompt for Haiku
      def build_triage_prompt(input, context)
        # Build skills summary (only high-priority skills to save tokens)
        skills_summary = build_skills_summary

        # Build context information (only relevant fields)
        context_info = build_context_info(context)

        # Use simplified prompt for common cases
        if complex_context?(context)
          build_detailed_prompt(input, context_info, skills_summary)
        else
          build_simple_prompt(input, context_info, skills_summary)
        end
      end

      def build_simple_prompt(input, context_info, skills_summary)
        <<~PROMPT
          分析用户请求，选择最合适的技能（最多 3 个）。

          用户请求: #{input}

          #{context_info}

          可用技能:
          #{skills_summary}

          返回JSON格式（仅JSON，不要其他内容）：
          {
            "skills": [
              {"id": "技能ID", "confidence": 0.0-1.0, "reasoning": "简短原因"},
              {"id": "技能ID", "confidence": 0.0-1.0, "reasoning": "简短原因"}
            ]
          }

          匹配规则：
          - 返回 1-3 个最相关的技能，按 confidence 降序排列
          - confidence >= #{@confidence_threshold} 的技能才返回
          - 如果只有一个相关技能，只返回一个
          - 如果没有相关技能，返回 {"skills": []}

          注意：
          - "我要走了"、"保存进度"、"今天先到这" → session-end
          - "review"、"审查"、"评审代码" → /review 或 gstack/review
          - "refactor"、"重构" → /refactor 或 superpowers/refactor
        PROMPT
      end

      def build_detailed_prompt(input, context_info, skills_summary)
        <<~PROMPT
          你是一个技能路由专家。分析用户请求，返回最合适的技能（最多 3 个）。

          ## 用户请求
          #{input}

          ## 上下文
          #{context_info}

          ## 可用技能
          #{skills_summary}

          ## 任务
          分析用户请求的意图，返回 top-3 相关技能的 JSON：

          ```json
          {
            "skills": [
              {"id": "技能ID", "confidence": 0.0-1.0, "reasoning": "原因"},
              {"id": "技能ID", "confidence": 0.0-1.0, "reasoning": "原因"}
            ]
          }
          ```

          ## 匹配规则
          - 返回 1-3 个最相关的技能，按 confidence 降序
          - confidence >= #{@confidence_threshold} 才返回
          - 没有相关技能时返回 {"skills": []}

          ## 特殊规则
          - "我要走了"、"保存进度" → session-end
          - "review"、"审查" → /review 或 gstack/review
          - "refactor"、"重构" → /refactor 或 superpowers/refactor
          - "测试失败"、"bug" → systematic-debugging
        PROMPT
      end

      def build_skills_summary
        return '' unless @registry['skills']

        # Show all available skills (P0, P1, P2) for accurate matching
        # Previously only showed P0/P1, causing P2 skills to never match
        @registry['skills']
          .map { |s| "- #{s['id']}: #{s['intent']}" }
          .join("\n")
      end

      def build_context_info(context)
        info = []

        if context[:file_type]
          info << "文件类型: #{context[:file_type]}"
        end

        if context[:error_count]&.positive?
          info << "错误数量: #{context[:error_count]}"
        end

        if context[:urgency]
          info << "紧急度: #{context[:urgency]}"
        end

        info.join("\n")
      end

      def complex_context?(context)
        # Consider context complex if:
        # - Multiple errors
        # - Specific file type with specialized skills
        # - Current task in progress
        (context[:error_count]&.> 3) ||
          (context[:file_type] && context[:current_task])
      end

      # Parse AI response from Haiku
      # Supports both single-skill and multi-skill response formats
      def parse_ai_response(response)
        # Extract JSON from response (handle various formats)
        # AI may wrap JSON in markdown code blocks: ```json ... ```
        json_str = extract_json_from_response(response)
        return nil unless json_str

        begin
          parsed = JSON.parse(json_str)

          # DEBUG: Log the parsed response
          puts "[AI Triage Debug] Parsed response: #{parsed.inspect[0..500]}" if ENV['VIBE_DEBUG_AI_TRIAGE']

          # Handle both old single-skill and new multi-skill formats
          if parsed['skills']
            # New multi-skill format: {"skills": [...]}
            parsed
          elsif parsed['skill']
            # Old single-skill format: {"skill": ..., "confidence": ...}
            # Convert to new format for consistency
            {'skills' => [parsed]}
          else
            # Unknown format
            nil
          end
        rescue JSON::ParserError => e
          log_error("JSON parsing error: #{e.message}", response, {})
          nil
        end
      end

      # Extract JSON string from AI response
      # Handles markdown code blocks and plain JSON
      def extract_json_from_response(response)
        return nil if response.nil? || response.empty?

        # Try to extract JSON from markdown code block first
        # Format: ```json\n{...}\n``` or ```\n{...}\n```
        code_block_match = response.match(/```(?:json)?\s*\n([\s\S]*?)\n```/)
        if code_block_match
          return code_block_match[1].strip
        end

        # Fallback: find JSON object (from first { to last })
        json_match = response.match(/\{[\s\S]*\}/)
        json_match ? json_match[0] : nil
      end

      # Match skills from AI analysis result (supports multiple candidates)
      def match_skills_from_analysis(ai_result, context)
        skills_list = ai_result['skills']
        return nil unless skills_list
        return [] if skills_list.empty?

        matched_skills = []
        skills_list.each do |skill_data|
          skill_id = skill_data['id']
          skill = find_skill(skill_id)
          next unless skill

          # Calculate preference boost (user history)
          preference_boost = calculate_preference_boost(skill_id)

          # Calculate context boost (file type relevance)
          context_boost = calculate_context_boost(skill, context)

          # Combine AI confidence with boosts
          final_confidence = skill_data['confidence'] * (1 + preference_boost + context_boost)

          matched_skills << {
            skill: skill,
            ai_confidence: skill_data['confidence'],
            final_confidence: final_confidence,
            reasoning: skill_data['reasoning'] || ''
          }
        end

        matched_skills.sort_by { |s| -s[:final_confidence] }
      end

      # Find skill by ID in registry
      # Supports both full IDs (gstack/review) and shorthand (/review)
      def find_skill(skill_id)
        return nil unless skill_id
        return nil unless @registry['skills']

        # Try exact match first
        skill = @registry['skills']&.find { |s| s['id'] == skill_id }
        return skill if skill

        # Try shorthand match (e.g., /review → gstack/review or superpowers/review)
        if skill_id.start_with?('/')
          shorthand = skill_id.gsub('/', '')
          @registry['skills']&.find do |s|
            s['id']&.end_with?(shorthand) || s['id']&.end_with?("/#{shorthand}")
          end
        else
          # Try matching just the suffix
          @registry['skills']&.find { |s| s['id']&.end_with?("/#{skill_id}") || s['id']&.end_with?("-#{skill_id}") }
        end
      end

      # Calculate preference boost based on user history
      def calculate_preference_boost(skill_id)
        usage = @preferences['skill_usage']&.dig(skill_id)
        return 0 unless usage && usage[:count] && usage[:count] > 0

        helpfulness = usage[:helpful].to_f / usage[:count]
        frequency_bonus = [Math.log(usage[:count]) * 0.05, 0.2].min

        helpfulness * frequency_bonus
      end

      # Calculate context boost based on file type relevance
      def calculate_context_boost(skill, context)
        return 0 unless context[:file_type] && skill['file_types']

        skill['file_types'].include?(context[:file_type]) ? 0.15 : 0
      end

      # Extract skill from explicit user command
      def extract_explicit_skill(input)
        # Match "use gstack for debugging"
        if match = input.match(/用\s+(gstack|superpowers)\s+(.+)/)
          source = match[1]
          action = match[2]

          # Find skill from action
          skill = find_skill_from_action(action, source)
          return build_quick_result(skill, :very_high) if skill
        end

        nil
      end

      # Extract skill from direct invocation
      def extract_direct_skill(input)
        # Match "/review this code"
        if match = input.match(/(?:\/(\w+)|调用\s*([\u4e00-\u9fa5\w]+))/)
          skill_name = match[1] || match[2]
          skill = find_skill_by_name(skill_name)
          return build_quick_result(skill, :very_high) if skill
        end

        nil
      end

      # Find best skill for a hint
      def find_best_skill_for_hint(hint, context)
        # Find skills that match this hint
        matching_skills = @registry['skills']&.select do |s|
          s['intent']&.include?(hint) || s['keywords']&.include?(hint)
        end

        return nil unless matching_skills && !matching_skills.empty?

        # Return highest priority skill
        matching_skills
          .sort_by { |s| priority_value(s['priority']) }
          .first
      end

      # Find skill from action description
      def find_skill_from_action(action, source)
        # Map common actions to skill IDs
        action_mappings = {
          'debugging' => 'systematic-debugging',
          'debug' => 'gstack/investigate',
          'review' => 'gstack/review',
          'refactor' => 'superpowers/refactor'
        }

        skill_id = action_mappings[action.downcase]
        find_skill(skill_id) if skill_id
      end

      # Find skill by name (supports both English and Chinese)
      def find_skill_by_name(name)
        @registry['skills']&.find do |s|
          s['id']&.include?(name) ||
            s['name']&.include?(name) ||
            s['aliases']&.any? { |a| a.include?(name) }
        end
      end

      # Build quick result from algorithm match
      def build_quick_result(skill, confidence)
        return nil unless skill

        {
          matched: true,
          skill: skill['id'],
          source: skill['namespace'],
          reason: "Algorithm match: #{skill['intent']}",
          confidence: confidence,
          algorithm: true
        }
      end

      # Build result with multiple candidates for user selection or parallel execution
      def build_multi_candidate_result(matched_skills)
        return nil if matched_skills.empty?

        # Convert to CandidateSelector format
        candidates = matched_skills.map do |s|
          {
            id: s[:skill]['id'],
            skill: s[:skill]['id'],
            namespace: s[:skill]['namespace'],
            confidence: s[:final_confidence],
            source: :layer_0_ai,
            metadata: {
              reasoning: s[:reasoning],
              ai_confidence: s[:ai_confidence],
              intent: s[:intent],
              urgency: s[:urgency],
              complexity: s[:complexity]
            }
          }
        end

        {
          matched: true,
          candidates: candidates,
          source: :layer_0_ai,
          ai_triaged: true,
          candidate_count: candidates.size
        }
      end

      # Enrich result with metadata
      def enrich_result(result, source)
        return result unless result

        result.merge({
          triage_source: source,
          model: @triage_model,
          timestamp: Time.now.to_s
        })
      end

      # Cache result for future use
      def cache_result(input, context, result)
        cache_key = generate_cache_key(input, context)
        @cache.set(cache_key, result, ttl: @cache_ttl)
      end

      # Generate cache key from input and context
      def generate_cache_key(input, context)
        # Normalize input to reduce cache misses
        normalized = normalize_for_cache(input)

        # Extract only relevant context
        relevant_context = extract_relevant_context(context)

        # Generate hash
        base = "#{normalized}:#{relevant_context.sort.to_h}"
        Digest::SHA256.hexdigest(base)[0..16]
      end

      # Normalize input for cache key
      def normalize_for_cache(input)
        input
          .gsub(/\d+/, 'N') # Normalize numbers
          .gsub(/['"].*?['"]/, 'X') # Normalize quoted content
          .gsub(/\s+/, ' ') # Normalize whitespace
          .strip
          .downcase
      end

      # Extract only relevant context for caching
      def extract_relevant_context(context)
        {
          file_type: context[:file_type],
          has_errors: context[:error_count]&.positive?
        }
      end

      # Convert confidence score to symbol
      def confidence_level(score)
        case score
        when CONFIDENCE_VERY_HIGH..1.0 then :very_high
        when CONFIDENCE_HIGH..CONFIDENCE_VERY_HIGH then :high
        when CONFIDENCE_MEDIUM..CONFIDENCE_HIGH then :medium
        when CONFIDENCE_LOW..CONFIDENCE_MEDIUM then :low
        else :very_low
        end
      end

      # Priority value for sorting (higher = more important)
      def priority_value(priority)
        case priority
        when 'P0' then 4
        when 'P1' then 3
        when 'P2' then 2
        else 1
        end
      end

      # Circuit breaker: check if circuit is open
      def circuit_open?
        return false unless @circuit_open_until

        Time.now < @circuit_open_until
      end

      # Circuit breaker: record a failure
      def record_failure
        @failure_count += 1
        @last_failure_time = Time.now

        # Open circuit after 3 failures within 1 minute
        if @failure_count >= 3 &&
           (@last_failure_time - (@circuit_open_until || Time.now)) < 60
          @circuit_open_until = Time.now + 60 # Open for 1 minute
          log_error("Circuit breaker opened due to repeated failures", {}, {})
        end
      end

      # Execute block with timeout
      def call_with_timeout(&block)
        Timeout.timeout(@timeout, &block)
      end

      # Create LLM provider from configuration
      #
      # Priority:
      #   1. .vibe/llm-config.json (explicit project model configuration)
      #   2. opencode.json with models field (OpenCode native config)
      #   3. Local model environment variables (fallback for local dev)
      #   4. Auto-detect from environment variables
      #
      # @return [LLMProvider::Base] Provider instance
      def create_provider_from_config
        # Priority 1: Try .vibe/llm-config.json (Vibe's explicit model configuration)
        if File.exist?('.vibe/llm-config.json')
          begin
            provider = LLMProvider::Factory.create_from_opencode_config
            # Only use if provider is configured (has API key)
            return provider if provider&.configured?
          rescue ArgumentError => e
            # Config exists but is invalid, fall through to next option
            warn "llm-config.json found but invalid: #{e.message}"
          end
        end

        # Priority 2: Try opencode.json (OpenCode native config)
        if File.exist?('opencode.json') || File.exist?('.vibe/opencode.json')
          begin
            provider = LLMProvider::Factory.create_from_opencode_config
            return provider if provider&.configured?
          rescue ArgumentError => e
            warn "opencode.json found but invalid: #{e.message}"
          end
        end

        # Priority 3: Check for local model configuration
        local_url = ENV.fetch('LOCAL_MODEL_URL', nil) || ENV.fetch('VIBE_LOCAL_MODEL_URL', nil)
        if local_url
          return LLMProvider::Factory.create_local_provider(url: local_url)
        end

        # Priority 4: Auto-detect from environment variables
        # Prefer Anthropic for AI routing, fallback to OpenAI
        LLMProvider::Factory.create_from_env('anthropic')
      rescue ArgumentError => e
        # If no provider available, create an unconfigured AnthropicProvider
        # This allows the system to initialize but AI triage will be disabled
        require_relative '../llm_provider/anthropic'
        LLMProvider::AnthropicProvider.new(
          api_key: nil,
          base_url: 'https://api.anthropic.com'
        )
      end

      # Detect which triage model to use based on provider
      #
      # Priority:
      #   1. VIBE_TRIAGE_MODEL env (explicit override)
      #   2. OpenCode/.vibe/llm-config.json (project configuration)
      #   3. Local model environment variables (fallback for local dev)
      #   4. Auto-detect based on provider
      #
      # @return [String] Model identifier
      def detect_triage_model
        # Priority 1: Explicit environment variable override
        env_model = ENV.fetch('VIBE_TRIAGE_MODEL', nil)
        return env_model if env_model

        # Priority 2: OpenCode config (includes .vibe/llm-config.json)
        # This is the explicit project configuration and should have priority
        opencode_model = detect_model_from_opencode_config
        return opencode_model if opencode_model

        # Priority 3: Local model configuration (fallback for local development)
        local_model = ENV.fetch('LOCAL_MODEL_NAME', nil) || ENV.fetch('VIBE_LOCAL_MODEL_NAME', nil)
        local_url = ENV.fetch('LOCAL_MODEL_URL', nil) || ENV.fetch('VIBE_LOCAL_MODEL_URL', nil)
        return local_model if local_model && local_url

        # Auto-detect based on provider
        if @llm_provider&.provider_name == 'OpenAI'
          # Use GPT-4o-mini for OpenAI (fast and cost-effective)
          'gpt-4o-mini'
        else
          # Default to Claude Haiku for Anthropic
          'claude-haiku-4-5-20251001'
        end
      end

      # Detect model from OpenCode configuration
      #
      # Checks multiple config files in priority order:
      #   1. .vibe/llm-config.json (Vibe's explicit model configuration)
      #   2. opencode.json (OpenCode native config)
      #   3. .vibe/opencode.json (OpenCode config in .vibe directory)
      #
      # @return [String, nil] Model identifier or nil
      def detect_model_from_opencode_config
        # Priority 1: .vibe/llm-config.json (Vibe's explicit model configuration)
        vibe_config = File.join(Dir.pwd, '.vibe', 'llm-config.json')
        if File.exist?(vibe_config)
          config = JSON.parse(File.read(vibe_config))
          models_config = config['models'] || {}
          model_config = models_config['fast'] || models_config['workhorse'] || models_config['critical']
          return model_config&.dig('model')
        end

        # Priority 2: opencode.json or .vibe/opencode.json
        return nil unless File.exist?('opencode.json') || File.exist?('.vibe/opencode.json')

        config_file = File.exist?('opencode.json') ? 'opencode.json' : '.vibe/opencode.json'
        config = JSON.parse(File.read(config_file))
        models_config = config['models'] || {}

        # Check fast router model (used for AI triage)
        model_config = models_config['fast'] || models_config['workhorse'] || models_config['critical']
        model_config&.dig('model')
      rescue JSON::ParserError, Errno::ENOENT
        nil
      end

      # Log error (placeholder - can be extended)
      def log_error(message, input, context)
        require 'logger'
        logger = Logger.new('log/ai_triage_errors.log') if File.exist?('log')
        return unless logger

        logger.error("[AI Triage] #{message}")
        logger.error("Input: #{input}") if input
        logger.error("Context: #{context.inspect}") if context && !context.empty?
      rescue StandardError => e
        # Silently fail if logging fails
        nil
      end
    end
  end
end
