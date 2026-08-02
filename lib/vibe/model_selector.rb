# frozen_string_literal: true

module Vibe
  # Model selection based on task complexity
  # TODO: Not wired into any CLI command. Scoring logic exists but is never invoked.
  class ModelSelector
    # Model tier mapping
    MODEL_MAP = {
      simple: 'haiku',
      medium: 'sonnet',
      complex: 'opus'
    }.freeze

    # Complexity evaluation rules
    COMPLEXITY_RULES = {
      simple: {
        max_files: 3,
        max_lines: 100,
        keywords: %w[status list show read get check]
      },
      medium: {
        max_files: 10,
        max_lines: 500,
        keywords: %w[edit update refactor test generate format]
      },
      complex: {
        max_files: Float::INFINITY,
        max_lines: Float::INFINITY,
        keywords: %w[design architect debug security integrate migrate]
      }
    }.freeze

    # Model fallback chain (downgrade when current model fails)
    FALLBACK_CHAIN = {
      'opus' => 'sonnet',
      'sonnet' => 'haiku',
      'haiku' => nil
    }.freeze

    attr_reader :stats

    def initialize
      @stats = {
        selections: Hash.new(0),
        fallbacks: Hash.new(0),
        total_evaluations: 0
      }
    end

    # Evaluate task complexity
    # @param task_description [String] Description of the task
    # @param context [Hash] Additional context
    #   - :file_count [Integer] Number of files involved
    #   - :line_count [Integer] Total lines of code
    #   - :has_tests [Boolean] Whether tests are involved
    # @return [Symbol] Complexity level (:simple, :medium, :complex)
    def evaluate_complexity(task_description, context = {})
      @stats[:total_evaluations] += 1

      score = 0

      # File count scoring
      file_count = context[:file_count] || 0
      score += file_count * 10

      # Line count scoring
      line_count = context[:line_count] || 0
      score += line_count * 0.1

      # Keyword complexity scoring
      score += keyword_complexity_score(task_description)

      # Test involvement adds complexity
      score += 20 if context[:has_tests]

      # Determine complexity level
      case score
      when 0..50 then :simple
      when 51..200 then :medium
      else :complex
      end
    end

    # Select appropriate model for given complexity
    # @param complexity [Symbol] Task complexity level
    # @return [String] Model name
    def select_model(complexity)
      model = MODEL_MAP[complexity]
      @stats[:selections][model] += 1
      model
    end

    # Get fallback model when current model fails
    # @param current_model [String] Current model that failed
    # @param reason [String] Reason for fallback
    # @return [String, nil] Fallback model or nil if no fallback available
    def fallback_model(current_model, _reason = nil)
      fallback = FALLBACK_CHAIN[current_model]
      @stats[:fallbacks][current_model] += 1 if fallback
      fallback
    end

    # Recommend model for a task
    # @param task_description [String] Task description
    # @param context [Hash] Task context
    # @return [Hash] Recommendation with model and reasoning
    def recommend(task_description, context = {})
      complexity = evaluate_complexity(task_description, context)
      model = select_model(complexity)

      {
        model: model,
        complexity: complexity,
        reasoning: build_reasoning(complexity, context),
        fallback: FALLBACK_CHAIN[model]
      }
    end

    private

    # Calculate keyword-based complexity score
    def keyword_complexity_score(description)
      return 0 if description.nil? || description.empty?

      desc_lower = description.downcase
      score = 0

      # Check for complex keywords
      COMPLEXITY_RULES[:complex][:keywords].each do |keyword|
        score += 50 if desc_lower.include?(keyword)
      end

      # Check for medium keywords
      COMPLEXITY_RULES[:medium][:keywords].each do |keyword|
        score += 20 if desc_lower.include?(keyword)
      end

      # Check for simple keywords
      COMPLEXITY_RULES[:simple][:keywords].each do |keyword|
        score += 5 if desc_lower.include?(keyword)
      end

      score
    end

    # Build reasoning for model selection
    def build_reasoning(complexity, context)
      reasons = []

      case complexity
      when :simple
        reasons << 'Task appears straightforward'
        reasons << "#{context[:file_count]} files involved" if context[:file_count]
      when :medium
        reasons << 'Moderate complexity task'
        reasons << 'Multiple files or refactoring involved'
      when :complex
        reasons << 'High complexity task'
        reasons << 'Requires deep reasoning or architectural decisions'
      end

      reasons.join('; ')
    end
  end
end
