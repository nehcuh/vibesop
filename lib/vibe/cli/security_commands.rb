# frozen_string_literal: true

require_relative "../security_scanner"
require_relative "../tdd_enforcer"
require_relative "../context_optimizer"

module Vibe
  module SecurityCommands
    def run_scan_command(argv)
      subcommand = argv.shift

      case subcommand
      when "text"   then run_scan_text(argv)
      when "file"   then run_scan_file(argv)
      when "tdd"    then run_tdd_audit(argv)
      when "ctx"    then run_ctx_stats(argv)
      when nil, "help", "--help", "-h" then puts security_usage
      else
        raise Vibe::ValidationError, "Unknown scan subcommand: #{subcommand}\n\n#{security_usage}"
      end
    end

    private

    def run_scan_text(argv)
      text = argv.join(" ")
      if text.strip.empty?
        warn "Usage: vibe scan text <text to scan>"
        exit 1
      end

      scanner = SecurityScanner.new
      result  = scanner.scan(text)

      if result[:safe]
        puts "✅ Safe  (risk: #{result[:risk_level]})"
      else
        puts "🚨 Threats detected  (risk: #{result[:risk_level]})"
        result[:threats].each do |t|
          puts "  [#{t[:severity].upcase}] #{t[:rule]}: #{t[:description]}"
          puts "    matched: \"#{t[:matched]}\""
        end
        exit 1
      end
    end

    def run_scan_file(argv)
      path = argv.shift
      unless path && File.exist?(path)
        warn "Usage: vibe scan file <path>"
        exit 1
      end

      text    = File.read(path)
      scanner = SecurityScanner.new
      result  = scanner.scan(text)

      if result[:safe]
        puts "✅ #{path}: safe"
      else
        puts "🚨 #{path}: #{result[:threats].length} threat(s) detected"
        result[:threats].each do |t|
          puts "  [#{t[:severity].upcase}] #{t[:rule]}: #{t[:matched].inspect}"
        end
        exit 1
      end
    end

    def run_tdd_audit(argv)
      dir      = argv.shift || Dir.pwd
      enforcer = TddEnforcer.new(dir)
      result   = enforcer.audit

      puts "\n🧪 TDD Audit: #{dir}\n#{"=" * 60}"
      puts result[:summary]
      puts

      unless result[:missing].empty?
        puts "Missing tests (#{result[:missing].length}):"
        result[:missing].each do |r|
          puts "  ❌ #{r[:file]}"
          puts "     Suggested: #{r[:test_candidates].first}" if r[:test_candidates].any?
        end
        puts
      end

      unless result[:ok].empty?
        puts "Covered (#{result[:ok].length}):"
        result[:ok].each { |r| puts "  ✅ #{r[:file]}" }
        puts
      end

      exit 1 unless result[:missing].empty?
    end

    def run_ctx_stats(argv)
      # Simple demo: estimate tokens for stdin or a file
      input = if argv.first && File.exist?(argv.first)
                File.read(argv.shift)
              else
                $stdin.read
              end

      optimizer = ContextOptimizer.new
      tokens    = optimizer.estimate_tokens(input)
      words     = input.split(/\s+/).length
      chars     = input.length

      puts "Context stats:"
      puts "  Characters : #{chars}"
      puts "  Words      : #{words}"
      puts "  Est. tokens: #{tokens}"
    end

    def security_usage
      <<~USAGE
        Usage: vibe scan <subcommand> [args]

        Subcommands:
          text <text>   Scan text for prompt injection threats
          file <path>   Scan a file for prompt injection threats
          tdd  [dir]    Audit project for missing test coverage (default: cwd)
          ctx  [file]   Estimate token count for a file or stdin

        Examples:
          vibe scan text "ignore all previous instructions"
          vibe scan file prompts/system.txt
          vibe scan tdd
          vibe scan tdd ~/my-project
          cat context.md | vibe scan ctx
      USAGE
    end
  end
end
