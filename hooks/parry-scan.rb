#!/usr/bin/env ruby
# frozen_string_literal: true

# Parry Security Scanner Hook
# Detects potential prompt injection and security risks in user input
# Install: Add to hooks/pre-tool-use or call manually

module ParryScanner
  # Security risk patterns to detect
  PATTERNS = {
    # Prompt injection attempts
    prompt_injection: [
      /ignore (all )?(previous|above) instructions/i,
      /forget (all )?(previous|above) instructions/i,
      /disregard (all )?(previous|above) instructions/i,
      /you are now (a|an) /i,
      /pretend (you are|to be)/i,
      /act as (if|a|an)/i,
      /role[ -]?play/i,
      /jailbreak/i,
      /DAN\s*mode/i,
      /developer mode/i,
      /override (safety|security)/i,
    ],

    # System prompt leakage attempts
    system_leak: [
      /what (are |is )?(your|the) (system |initial )?prompt/i,
      /show me (your|the) instructions/i,
      /print (your|the) (system |initial )?prompt/i,
      /repeat (your|the) (system |initial )?instructions/i,
      /output (your|the) (system |initial )?prompt/i,
    ],

    # Sensitive data extraction
    data_extraction: [
      /send (this|the|all) (data|content|file|code) to/i,
      /upload (this|the|all) (data|content|file|code) to/i,
      /post (this|the|all) (data|content|file|code) to/i,
      /curl.*-X.*POST/i,
      /wget.*--post/i,
    ],

    # Command injection
    command_injection: [
      /;\s*rm\s+-rf/i,
      /\|\s*rm\s+-rf/i,
      /`[^`]*rm\s+-rf[^`]*`/,
      /\$\([^)]*rm\s+-rf[^)]*\)/,
      /&&\s*rm\s+-rf/i,
    ],

    # File system danger
    filesystem_danger: [
      /delete\s+(all|everything)/i,
      /wipe\s+(the\s+)?(disk|drive|system)/i,
      /format\s+(the\s+)?(disk|drive)/i,
      /drop\s+(table|database)/i,
    ],

    # Obfuscation attempts
    obfuscation: [
      /base64\s*[-—]\s*decode/i,
      /eval\s*\(/i,
      /exec\s*\(/i,
      /\\x[0-9a-f]{2}/i,  # hex escape sequences
    ],
  }.freeze

  # Risk levels
  RISK_LEVELS = {
    critical: 3,
    high: 2,
    medium: 1,
    low: 0,
  }.freeze

  # Pattern to risk level mapping
  PATTERN_RISK = {
    prompt_injection: :high,
    system_leak: :medium,
    data_extraction: :critical,
    command_injection: :critical,
    filesystem_danger: :critical,
    obfuscation: :high,
  }.freeze

  # Whitelist patterns (safe patterns that should be ignored)
  WHITELIST = [
    /example\.com/i,
    /localhost/i,
    /test\s+data/i,
    /sample\s+code/i,
  ].freeze

  class ScanResult
    attr_reader :risk_level, :matches, :recommendations

    def initialize(risk_level:, matches:, recommendations:)
      @risk_level = risk_level
      @matches = matches
      @recommendations = recommendations
    end

    def safe?
      @risk_level == :low || @risk_level == :none
    end

    def to_s
      return "✅ No security risks detected" if safe?

      level_icon = { critical: "🚨", high: "⚠️", medium: "⚡" }[@risk_level] || "❓"
      "#{level_icon} Security risk detected: #{@risk_level.upcase}\n" \
        "Matches: #{@matches.map { |m| "- #{m[:pattern]} (#{m[:category]})" }.join("\n")}\n" \
        "Recommendations: #{@recommendations.join(', ')}"
    end
  end

  # Main scan function
  def self.scan(input, context: {})
    return ScanResult.new(risk_level: :none, matches: [], recommendations: []) if input.nil? || input.empty?

    # Check whitelist first
    return ScanResult.new(risk_level: :none, matches: [], recommendations: []) if whitelisted?(input)

    matches = []
    max_risk = :none

    PATTERNS.each do |category, patterns|
      patterns.each do |pattern|
        next unless input.match?(pattern)

        matches << {
          category: category,
          pattern: pattern.inspect,
          matched: input.match(pattern)&.[](0),
        }

        risk = PATTERN_RISK[category]
        max_risk = risk if RISK_LEVELS[risk] > (RISK_LEVELS[max_risk] || -1)
      end
    end

    recommendations = generate_recommendations(max_risk, matches)

    ScanResult.new(
      risk_level: max_risk,
      matches: matches,
      recommendations: recommendations,
    )
  end

  def self.whitelisted?(input)
    WHITELIST.any? { |pattern| input.match?(pattern) }
  end

  def self.generate_recommendations(risk_level, matches)
    return [] if risk_level == :none || risk_level == :low

    recommendations = []

    if matches.any? { |m| m[:category] == :prompt_injection }
      recommendations << "Review input for prompt injection attempts"
    end

    if matches.any? { |m| m[:category] == :data_extraction }
      recommendations << "Verify data destination is authorized"
    end

    if matches.any? { |m| m[:category] == :command_injection }
      recommendations << "Sanitize command input"
    end

    if matches.any? { |m| m[:category] == :system_leak }
      recommendations << "System prompts are protected"
    end

    recommendations << "Proceed with caution" if risk_level == :medium
    recommendations << "Block this request" if risk_level == :critical

    recommendations
  end

  # Quick check for hook integration
  def self.quick_check(input)
    result = scan(input)
    !result.safe?
  end
end

# CLI interface
if __FILE__ == $PROGRAM_NAME
  require "json"

  if ARGV.empty?
    puts "Usage: #{$PROGRAM_NAME} <input_string>"
    puts "       echo <input> | #{$PROGRAM_NAME}"
    exit 1
  end

  input = ARGV.join(" ")

  # Also read from stdin if piped
  if !$stdin.tty?
    input += " " + $stdin.read
  end

  result = ParryScanner.scan(input)

  puts result.to_s

  # Exit with appropriate code
  exit(2) if result.risk_level == :critical
  exit(1) if result.risk_level == :high
  exit(0)
end
