# frozen_string_literal: true

module Vibe
  # Context Engineering Kit — helps manage and optimize context window usage.
  #
  # Provides utilities for:
  # - Estimating token usage of context blocks
  # - Prioritizing which context to include
  # - Compressing verbose context into summaries
  # - Building structured context packages for AI prompts
  #
  # Usage:
  #   optimizer = ContextOptimizer.new
  #   pkg = optimizer.build_package(blocks, budget: 4000)
  #   puts pkg[:included].length   # => number of blocks that fit
  #   puts pkg[:total_tokens]      # => estimated token count
  class ContextOptimizer
    TOKENS_PER_WORD_EN = 0.75
    TOKENS_PER_WORD_ZH = 0.5
    CHARS_PER_ZH_CHAR  = 1

    PRIORITY_WEIGHTS = {
      critical: 100,
      high:     50,
      medium:   20,
      low:      5,
      optional: 1
    }.freeze

    # A context block: { id:, content:, priority:, tags: [] }
    attr_reader :blocks

    def initialize
      @blocks = []
    end

    # Add a context block
    # @param id [String] unique identifier
    # @param content [String] the text content
    # @param priority [Symbol] :critical, :high, :medium, :low, :optional
    # @param tags [Array<String>] optional categorization tags
    def add(id, content, priority: :medium, tags: [])
      @blocks << {
        id:       id,
        content:  content,
        priority: priority,
        tags:     Array(tags),
        tokens:   estimate_tokens(content)
      }
      self
    end

    # Build an optimized context package within a token budget
    # @param budget [Integer] max tokens to include
    # @param required_ids [Array<String>] block IDs that must be included
    # @return [Hash] { included:, excluded:, total_tokens:, budget:, utilization: }
    def build_package(budget: 8000, required_ids: [])
      required, optional = @blocks.partition { |b| required_ids.include?(b[:id]) }

      required_tokens = required.sum { |b| b[:tokens] }
      if required_tokens > budget
        return {
          included:    required,
          excluded:    optional,
          total_tokens: required_tokens,
          budget:      budget,
          utilization: (required_tokens.to_f / budget * 100).round(1),
          warning:     "Required blocks exceed budget by #{required_tokens - budget} tokens"
        }
      end

      remaining = budget - required_tokens
      sorted    = optional.sort_by { |b| -PRIORITY_WEIGHTS.fetch(b[:priority], 1) }

      included = required.dup
      excluded = []

      sorted.each do |block|
        if block[:tokens] <= remaining
          included << block
          remaining -= block[:tokens]
        else
          excluded << block
        end
      end

      total = included.sum { |b| b[:tokens] }
      {
        included:    included,
        excluded:    excluded,
        total_tokens: total,
        budget:      budget,
        utilization: (total.to_f / budget * 100).round(1)
      }
    end

    # Compress a block's content by removing filler and redundancy
    # @param content [String]
    # @return [String] compressed content
    def compress(content)
      lines = content.split("\n")

      # Remove blank lines clusters (keep max 1 consecutive blank)
      compressed = []
      prev_blank = false
      lines.each do |line|
        blank = line.strip.empty?
        compressed << line unless blank && prev_blank
        prev_blank = blank
      end

      # Remove common filler phrases
      FILLER_PATTERNS.each do |pattern|
        compressed = compressed.map { |l| l.gsub(pattern, "") }
      end

      compressed.join("\n").strip
    end

    # Estimate token count for a string
    # @param text [String]
    # @return [Integer]
    def estimate_tokens(text)
      return 0 if text.nil? || text.empty?

      zh_chars = text.scan(/\p{Han}/).length
      remaining = text.gsub(/\p{Han}/, "")
      en_words  = remaining.split(/\s+/).reject(&:empty?).length

      (zh_chars * CHARS_PER_ZH_CHAR * TOKENS_PER_WORD_ZH +
       en_words * TOKENS_PER_WORD_EN).ceil
    end

    # Summarize context usage stats
    # @return [Hash]
    def stats
      total_tokens = @blocks.sum { |b| b[:tokens] }
      by_priority  = @blocks.group_by { |b| b[:priority] }
                             .transform_values { |bs| bs.sum { |b| b[:tokens] } }

      {
        block_count:  @blocks.length,
        total_tokens: total_tokens,
        by_priority:  by_priority
      }
    end

    private

    FILLER_PATTERNS = [
      /\bplease note that\b/i,
      /\bit is (important|worth noting) (to note |that )?/i,
      /\bas (mentioned|noted|stated) (above|before|previously|earlier)\b/i,
      /\bin (other|simple) words\b/i,
      /\bbasically\b/i,
      /\bactually\b/i
    ].freeze
  end
end
