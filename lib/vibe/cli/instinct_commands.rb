# frozen_string_literal: true

# CLI commands for instinct learning system
# These methods are included in VibeCLI class

require_relative "../instinct_manager"

module Vibe
  module InstinctCommands
    # Main entry point for 'vibe instinct' subcommand
    def run_instinct_command(argv)
      subcommand = argv.shift

      case subcommand
      when "learn"
        run_instinct_learn(argv)
      when "learn-eval"
        run_instinct_learn_eval(argv)
      when "status"
        run_instinct_status(argv)
      when "export"
        run_instinct_export(argv)
      when "import"
        run_instinct_import(argv)
      when "evolve"
        run_instinct_evolve(argv)
      when nil, "help", "--help", "-h"
        puts instinct_usage
      else
        raise Vibe::ValidationError, "Unknown instinct subcommand: #{subcommand}\n\n#{instinct_usage}"
      end
    end

    # vibe instinct learn - Extract patterns from current session
    def run_instinct_learn(argv)
      puts "\n🧠 Instinct Learning - Pattern Extraction\n"
      puts "=" * 60
      puts

      # TODO: Implement session analysis
      # For now, show a placeholder message
      puts "⚠️  Session analysis not yet implemented"
      puts
      puts "This command will:"
      puts "  1. Analyze tool call history from current session"
      puts "  2. Identify successful sequences (3+ consecutive successes)"
      puts "  3. Generate pattern descriptions"
      puts "  4. Create instinct candidates for review"
      puts
      puts "Coming soon in Phase 1 Week 3-4!"
    end

    # vibe instinct learn-eval - Evaluate and save instinct candidates
    def run_instinct_learn_eval(argv)
      instinct_id = argv.shift

      if instinct_id.nil?
        puts "Usage: vibe instinct learn-eval <instinct_id>"
        return
      end

      puts "\n📊 Evaluating Instinct Candidate\n"
      puts "=" * 60
      puts

      # TODO: Implement evaluation logic
      puts "⚠️  Instinct evaluation not yet implemented"
      puts
      puts "This command will:"
      puts "  1. Calculate confidence score"
      puts "  2. Show usage statistics"
      puts "  3. Ask for user confirmation"
      puts "  4. Save to memory/instincts.yaml"
      puts
      puts "Coming soon in Phase 1 Week 3-4!"
    end

    # vibe instinct status - View all instincts
    def run_instinct_status(argv)
      options = parse_instinct_status_options(argv)
      manager = InstinctManager.new

      filters = {}
      filters[:tags] = [options[:tag]] if options[:tag]
      filters[:min_confidence] = options[:min_confidence] if options[:min_confidence]
      filters[:status] = options[:all] ? nil : "active"
      filters[:sort_by] = :confidence
      filters[:ascending] = false

      instincts = manager.list(filters)

      puts "\n📋 Instinct Status\n"
      puts "=" * 60
      puts

      if instincts.empty?
        puts "No instincts found."
        puts
        puts "💡 Use 'vibe instinct learn' to extract patterns from your sessions."
        return
      end

      # Group by confidence level
      high = instincts.select { |i| i["confidence"] >= 0.8 }
      medium = instincts.select { |i| i["confidence"] >= 0.6 && i["confidence"] < 0.8 }
      low = instincts.select { |i| i["confidence"] < 0.6 }

      puts "Total: #{instincts.size} instincts\n\n"

      if high.any?
        puts "High Confidence (≥ 0.8):"
        high.each_with_index do |instinct, idx|
          print_instinct_summary(instinct, idx + 1)
        end
        puts
      end

      if medium.any?
        puts "Medium Confidence (0.6-0.8):"
        medium.each_with_index do |instinct, idx|
          print_instinct_summary(instinct, high.size + idx + 1)
        end
        puts
      end

      if low.any?
        puts "Low Confidence (< 0.6):"
        low.each_with_index do |instinct, idx|
          print_instinct_summary(instinct, high.size + medium.size + idx + 1)
        end
        puts
      end
    end

    # vibe instinct export - Export instincts to file
    def run_instinct_export(argv)
      file_path = argv.shift

      if file_path.nil?
        puts "Usage: vibe instinct export <file_path> [options]"
        puts
        puts "Options:"
        puts "  --tag TAG              Export instincts with specific tag"
        puts "  --min-confidence NUM   Export instincts with confidence >= NUM"
        return
      end

      options = parse_instinct_export_options(argv)
      manager = InstinctManager.new

      filters = {}
      filters[:tags] = [options[:tag]] if options[:tag]
      filters[:min_confidence] = options[:min_confidence] if options[:min_confidence]

      count = manager.export(file_path, filters)

      puts "\n✓ Exported #{count} instincts to #{file_path}"
      puts
      puts "Share this file with your team!"
    rescue StandardError => e
      puts "\n✗ Export failed: #{e.message}"
      exit 1
    end

    # vibe instinct import - Import instincts from file
    def run_instinct_import(argv)
      file_path = argv.shift

      if file_path.nil?
        puts "Usage: vibe instinct import <file_path> [options]"
        puts
        puts "Options:"
        puts "  --overwrite   Overwrite existing instincts"
        puts "  --merge       Merge usage statistics"
        return
      end

      unless File.exist?(file_path)
        puts "\n✗ File not found: #{file_path}"
        exit 1
      end

      options = parse_instinct_import_options(argv)
      manager = InstinctManager.new

      merge_strategy = :skip
      merge_strategy = :overwrite if options[:overwrite]
      merge_strategy = :merge if options[:merge]

      stats = manager.import(file_path, merge_strategy)

      puts "\n📥 Import Results\n"
      puts "=" * 60
      puts
      puts "  ✓ Imported: #{stats[:imported]} new instincts"
      puts "  ⊘ Skipped: #{stats[:skipped]} duplicates" if stats[:skipped] > 0
      puts "  🔀 Merged: #{stats[:merged]} instincts" if stats[:merged] > 0
      puts "  ⚠ Errors: #{stats[:errors]}" if stats[:errors] > 0
      puts
    rescue StandardError => e
      puts "\n✗ Import failed: #{e.message}"
      exit 1
    end

    # vibe instinct evolve - Upgrade instinct to skill
    def run_instinct_evolve(argv)
      instinct_id = argv.shift
      skill_name = argv.shift

      if instinct_id.nil?
        puts "Usage: vibe instinct evolve <instinct_id> [skill_name]"
        return
      end

      puts "\n🚀 Evolving Instinct to Skill\n"
      puts "=" * 60
      puts

      # TODO: Implement evolution logic
      puts "⚠️  Instinct evolution not yet implemented"
      puts
      puts "This command will:"
      puts "  1. Aggregate related instincts"
      puts "  2. Generate skill markdown file"
      puts "  3. Save to skills/ directory"
      puts "  4. Mark instinct as 'evolved'"
      puts
      puts "Coming soon in Phase 1 Week 5-6!"
    end

    private

    def print_instinct_summary(instinct, number)
      confidence = instinct["confidence"].round(2)
      tags = instinct["tags"].join(", ")
      puts "  #{number}. #{instinct['pattern']} (#{confidence})"
      puts "     Tags: [#{tags}]" unless tags.empty?
      puts "     Usage: #{instinct['usage_count']} times, Success: #{(instinct['success_rate'] * 100).round}%"
    end

    def parse_instinct_status_options(argv)
      options = { all: false, tag: nil, min_confidence: nil }

      while (arg = argv.shift)
        case arg
        when "--all"
          options[:all] = true
        when "--tag"
          options[:tag] = argv.shift
        when "--min-confidence"
          options[:min_confidence] = argv.shift.to_f
        end
      end

      options
    end

    def parse_instinct_export_options(argv)
      options = { tag: nil, min_confidence: nil }

      while (arg = argv.shift)
        case arg
        when "--tag"
          options[:tag] = argv.shift
        when "--min-confidence"
          options[:min_confidence] = argv.shift.to_f
        end
      end

      options
    end

    def parse_instinct_import_options(argv)
      options = { overwrite: false, merge: false }

      while (arg = argv.shift)
        case arg
        when "--overwrite"
          options[:overwrite] = true
        when "--merge"
          options[:merge] = true
        end
      end

      options
    end

    def instinct_usage
      <<~USAGE
        Usage: vibe instinct <command> [options]

        Commands:
          learn                    Extract patterns from current session
          learn-eval <id>          Evaluate and save instinct candidate
          status                   View all instincts
          export <file>            Export instincts to file
          import <file>            Import instincts from file
          evolve <id> [name]       Upgrade instinct to skill

        Examples:
          vibe instinct status
          vibe instinct status --tag ruby --min-confidence 0.8
          vibe instinct export team-patterns.yaml --min-confidence 0.8
          vibe instinct import shared-patterns.yaml --merge

        For more information, see: skills/instinct-learning/SKILL.md
      USAGE
    end
  end
end
