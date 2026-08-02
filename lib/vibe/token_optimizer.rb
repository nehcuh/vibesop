# frozen_string_literal: true

require 'set'

module Vibe
  # Token optimization for reducing prompt size and API costs
  class TokenOptimizer
    # Rough estimation: 1 token ≈ 0.75 words (English), 1 token ≈ 0.5 words (Chinese)
    TOKENS_PER_WORD_EN = 0.75
    TOKENS_PER_WORD_ZH = 0.5

    attr_reader :stats

    def initialize
      @stats = {
        total_analyzed: 0,
        total_optimized: 0,
        savings: []
      }
    end

    # Analyze prompt token usage
    # @param content [String] The prompt content
    # @return [Hash] Analysis results
    def analyze(content)
      lines = content.split("\n")
      sections = extract_sections(content)

      {
        total_tokens: estimate_tokens(content),
        total_words: content.split.size,
        total_lines: lines.size,
        sections: sections.map { |s| analyze_section(s) },
        redundancies: detect_redundancies(content),
        whitespace_ratio: calculate_whitespace_ratio(content)
      }
    end

    # Optimize prompt content
    # @param content [String] The prompt content
    # @param options [Hash] Optimization options
    #   - :remove_redundancies [Boolean] Remove duplicate content
    #   - :compress_whitespace [Boolean] Remove extra whitespace
    #   - :selective_load [Array<String>] Only load specified sections
    # @return [String] Optimized content
    def optimize(content, options = {})
      original_tokens = estimate_tokens(content)
      optimized = content.dup

      # Selective load should be done first, before other optimizations
      if options[:selective_load]
        optimized = selective_load(optimized,
                                   options[:selective_load])
      end
      optimized = remove_redundancies(optimized) if options[:remove_redundancies]
      optimized = compress_whitespace(optimized) if options[:compress_whitespace]

      optimized_tokens = estimate_tokens(optimized)
      savings_pct = if original_tokens.positive?
                      savings_ratio = (original_tokens - optimized_tokens).to_f /
                                      original_tokens
                      (savings_ratio * 100).round(1)
                    else
                      0
                    end

      @stats[:total_optimized] += 1
      @stats[:savings] << savings_pct

      {
        content: optimized,
        original_tokens: original_tokens,
        optimized_tokens: optimized_tokens,
        savings_tokens: original_tokens - optimized_tokens,
        savings_percent: savings_pct
      }
    end

    # Estimate token count (rough approximation)
    # @param text [String] Text to estimate
    # @return [Integer] Estimated token count
    def estimate_tokens(text)
      return 0 if text.nil? || text.empty?

      # Split by language
      words = text.split
      chinese_chars = text.scan(/[\u4e00-\u9fa5]/).size
      english_words = [words.size - (chinese_chars / 2), 0].max

      (english_words / TOKENS_PER_WORD_EN + chinese_chars / TOKENS_PER_WORD_ZH).round
    end

    private

    # Extract sections from markdown content
    def extract_sections(content)
      sections = []
      current_section = nil

      content.split("\n").each do |line|
        if line.start_with?('#')
          sections << current_section if current_section
          current_section = { title: line, content: '' }
        elsif current_section
          current_section[:content] += "#{line}\n"
        end
      end

      sections << current_section if current_section
      sections
    end

    # Analyze a single section
    def analyze_section(section)
      {
        title: section[:title],
        tokens: estimate_tokens(section[:content]),
        lines: section[:content].split("\n").size
      }
    end

    # Detect redundant content
    def detect_redundancies(content)
      lines = content.split("\n").reject(&:empty?)
      redundancies = []

      # Find duplicate lines
      line_counts = Hash.new(0)
      lines.each { |line| line_counts[line] += 1 }

      line_counts.each do |line, count|
        redundancies << { line: line, count: count } if count > 1 && line.length > 20
      end

      redundancies
    end

    # Calculate whitespace ratio
    def calculate_whitespace_ratio(content)
      return 0 if content.empty?

      whitespace_count = content.scan(/\s/).size
      (whitespace_count.to_f / content.length * 100).round(1)
    end

    # Remove redundant content
    def remove_redundancies(content)
      lines = content.split("\n")
      seen = Set.new
      result = []

      lines.each do |line|
        # Keep empty lines and short lines
        if line.strip.empty? || line.length < 20
          result << line
          next
        end

        # Remove duplicate long lines
        normalized = line.strip.downcase
        unless seen.include?(normalized)
          seen.add(normalized)
          result << line
        end
      end

      result.join("\n")
    end

    # Compress whitespace
    def compress_whitespace(content)
      content
        .gsub(/[ \t]+/, ' ')           # Multiple spaces/tabs -> single space
        .gsub(/\n{3,}/, "\n\n")        # Multiple newlines -> double newline
        .gsub(/^ +/, '')               # Leading spaces
        .gsub(/ +$/, '')               # Trailing spaces
    end

    # Selective section loading
    def selective_load(content, sections_to_load)
      return content if sections_to_load.nil? || sections_to_load.empty?

      all_sections = extract_sections(content)
      selected = all_sections.select do |section|
        sections_to_load.any? do |pattern|
          # Use word boundary to avoid partial matches
          section[:title].match?(/\b#{Regexp.escape(pattern)}\b/i)
        end
      end

      return '' if selected.empty?

      selected.map { |s| "#{s[:title]}\n#{s[:content]}" }.join("\n")
    end
  end
end
