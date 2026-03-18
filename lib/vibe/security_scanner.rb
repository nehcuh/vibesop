# frozen_string_literal: true

module Vibe
  # Lightweight prompt-injection and jailbreak scanner.
  # Inspired by the "parry" project from awesome-claude-code.
  #
  # Usage:
  #   scanner = SecurityScanner.new
  #   result  = scanner.scan(user_input)
  #   puts result[:safe]      # => false
  #   puts result[:threats]   # => [{ rule: :role_hijack, severity: :high, ... }]
  class SecurityScanner
    RULES = [
      {
        id:       :system_prompt_leak,
        severity: :critical,
        patterns: [
          /ignore (all |previous |your |the )?(previous |prior |above |system |all )?instructions/i,
          /disregard (your |all |previous |the )?instructions/i,
          /forget (everything|all|your instructions)/i,
          /reveal (your |the )?(system |hidden |secret |full )?prompt/i,
          /print (your |the )?(system |full |entire )?prompt/i,
          /show me (your |the )?(system |full |entire )?prompt/i,
          /what (are|were) (your|the) (original |system )?instructions/i
        ],
        description: "Attempt to extract or override system prompt"
      },
      {
        id:       :role_hijack,
        severity: :high,
        patterns: [
          /you are now (a |an )?(different|new|another|evil|unrestricted)/i,
          /act as (a |an )?(different|new|jailbroken|unrestricted|evil|DAN)/i,
          /pretend (you are|to be) (a |an )?(different|unrestricted|evil)/i,
          /from now on (you are|act as|behave as)/i,
          /your (new |true |real )?persona is/i,
          /switch (to |into )?(developer|admin|god|DAN|jailbreak) mode/i
        ],
        description: "Attempt to hijack AI identity or role"
      },
      {
        id:       :instruction_injection,
        severity: :high,
        patterns: [
          /\[INST\]|\[\/INST\]/i,
          /<\|im_start\|>|<\|im_end\|>/,
          /###\s*(Human|Assistant|System)\s*:/,
          /\[SYSTEM\]|\[USER\]|\[ASSISTANT\]/i,
          /<<SYS>>|<\/SYS>/
        ],
        description: "Injection of model-specific control tokens"
      },
      {
        id:       :privilege_escalation,
        severity: :high,
        patterns: [
          /i am (a |an )?(developer|admin|administrator|anthropic|openai|engineer)/i,
          /this is (a |an )?(test|debug|maintenance|admin) mode/i,
          /you have (been granted|special|elevated|admin) (access|permissions|privileges)/i,
          /override (safety|content|ethical) (filter|policy|guideline)/i
        ],
        description: "Claim of elevated privileges to bypass restrictions"
      },
      {
        id:       :indirect_injection,
        severity: :medium,
        patterns: [
          /when (you|the AI) (read|process|see) this/i,
          /hidden (instruction|command|directive)/i,
          /<!-- .*instruction.* -->/i,
          /\[hidden\]|\[invisible\]|\[secret\]/i
        ],
        description: "Indirect or hidden instruction injection"
      }
    ].freeze

    # Scan text for prompt injection threats
    # @param text [String] Input to scan
    # @return [Hash] { safe: Boolean, threats: Array, risk_level: Symbol }
    def scan(text)
      return { safe: true, threats: [], risk_level: :none } if text.nil? || text.strip.empty?

      threats = RULES.flat_map do |rule|
        rule[:patterns].map do |pattern|
          match = text.match(pattern)
          next unless match

          {
            rule:        rule[:id],
            severity:    rule[:severity],
            description: rule[:description],
            matched:     match[0]
          }
        end.compact
      end

      # Deduplicate by rule id (keep highest severity match per rule)
      threats = threats
        .group_by { |t| t[:rule] }
        .map { |_, group| group.first }

      risk_level = calculate_risk(threats)

      {
        safe:       threats.empty?,
        threats:    threats,
        risk_level: risk_level
      }
    end

    # Convenience: raise if unsafe
    def scan!(text)
      result = scan(text)
      unless result[:safe]
        threat_summary = result[:threats].map { |t| "#{t[:rule]} (#{t[:severity]})" }.join(", ")
        raise SecurityError, "Potential prompt injection detected: #{threat_summary}"
      end

      result
    end

    private

    def calculate_risk(threats)
      return :none if threats.empty?

      severities = threats.map { |t| t[:severity] }
      return :critical if severities.include?(:critical)
      return :high     if severities.include?(:high)
      return :medium   if severities.include?(:medium)

      :low
    end
  end
end
