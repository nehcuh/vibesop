# frozen_string_literal: true

# CLI commands for instinct learning subsystem
# These methods are included in VibeCLI class

require_relative '../instinct_manager'

module Vibe
  # CLI commands for the instinct learning subsystem, included in VibeCLI.
  module InstinctCommands
    # Main entry point for 'vibe instinct' subcommand
    def run_instinct_command(argv)
      subcommand = argv.shift

      case subcommand
      when 'learn'
        run_instinct_learn(argv)
      when 'learn-eval'
        run_instinct_learn_eval(argv)
      when 'status'
        run_instinct_status(argv)
      when 'export'
        run_instinct_export(argv)
      when 'import'
        run_instinct_import(argv)
      when 'evolve'
        run_instinct_evolve(argv)
      when nil, 'help', '--help', '-h'
        puts instinct_usage
      else
        raise Vibe::ValidationError,
              "Unknown instinct subcommand: #{subcommand}\n\n#{instinct_usage}"
      end
    end

    # vibe instinct learn - Extract patterns from current session
    def run_instinct_learn(argv)
      options = parse_instinct_learn_options(argv)
      manager = InstinctManager.new

      puts "\n🧠 Instinct Learning - Pattern Extraction\n"
      puts '=' * 60
      puts

      # Load session data from file or stdin
      session_data = load_session_data(options[:file])

      if session_data.nil? || session_data.empty?
        puts 'No session data provided.'
        puts
        puts 'Usage:'
        puts '  vibe instinct learn --file session-log.yaml'
        puts "  echo '<yaml>' | vibe instinct learn --stdin"
        puts
        puts 'Or manually create an instinct:'
        puts '  vibe instinct learn --pattern ' \
             "'Run tests before committing' --tags ruby,testing"
        puts

        # Manual mode: create instinct directly
        if options[:pattern]
          instinct = manager.create(
            pattern: options[:pattern],
            tags: options[:tags] || [],
            context: options[:context],
            source_sessions: [Time.now.strftime('session-%Y-%m-%d')]
          )
          puts "✓ Created instinct: #{instinct['pattern']}"
          puts "  ID: #{instinct['id']}"
          puts "  Confidence: #{instinct['confidence']}"
          puts "  Tags: #{instinct['tags'].join(', ')}"
        end
        return
      end

      # Extract patterns from session data
      candidates = extract_patterns(session_data)

      if candidates.empty?
        puts 'No patterns found in session data.'
        return
      end

      puts "Found #{candidates.size} pattern candidate(s):\n\n"

      candidates.each_with_index do |candidate, idx|
        puts "  #{idx + 1}. #{candidate[:pattern]}"
        puts "     Tags: #{candidate[:tags].join(', ')}"
        puts "     Confidence: #{candidate[:confidence]}"
        puts
      end

      puts "Use 'vibe instinct learn-eval' to review and save these patterns."
      puts "Or use 'vibe instinct learn --pattern \\\"...\\\" --tags " \
           "tag1,tag2' to create manually."
    end

    # vibe instinct learn-eval - Evaluate and save instinct candidates
    def run_instinct_learn_eval(argv)
      manager = InstinctManager.new

      # If ID provided, evaluate specific instinct
      instinct_id = argv.first unless argv.first&.start_with?('--')

      if instinct_id
        instinct = manager.get(instinct_id)
        unless instinct
          puts "Instinct not found: #{instinct_id}"
          return
        end

        puts "\n📊 Evaluating Instinct\n"
        puts '=' * 60
        puts
        puts "Pattern: #{instinct['pattern']}"
        puts "Confidence: #{instinct['confidence'].round(2)}"
        puts "  - Success rate: #{instinct['success_rate'].round(2)} (60% weight)"
        puts "  - Usage count: #{instinct['usage_count']} (30% weight)"
        puts "  - Source sessions: #{instinct['source_sessions'].size} (10% weight)"
        puts
        puts "Tags: #{instinct['tags'].join(', ')}"
        puts "Status: #{instinct['status']}"
        puts "Created: #{instinct['created_at']}"
        return
      end

      # List all active instincts for evaluation
      instincts = manager.list(status: 'active', sort_by: :confidence)

      if instincts.empty?
        puts "No instincts to evaluate. Use 'vibe instinct learn' first."
        return
      end

      puts "\n📊 Instinct Evaluation\n"
      puts '=' * 60
      puts

      instincts.each_with_index do |entry, idx|
        confidence = entry['confidence'].round(2)
        label = if confidence >= 0.8
                  'High'
                else
                  confidence >= 0.6 ? 'Medium' : 'Low'
                end
        puts "  #{idx + 1}. [#{label}] #{entry['pattern']} (#{confidence})"
        puts "     Uses: #{entry['usage_count']} | " \
             "Success: #{(entry['success_rate'] * 100).round}%"
        puts
      end
    end

    # vibe instinct status - View all instincts
    def run_instinct_status(argv)
      options = parse_instinct_status_options(argv)
      manager = InstinctManager.new

      filters = {}
      filters[:tags] = [options[:tag]] if options[:tag]
      filters[:min_confidence] = options[:min_confidence] if options[:min_confidence]
      filters[:status] = options[:all] ? nil : 'active'
      filters[:sort_by] = :confidence
      filters[:ascending] = false

      instincts = manager.list(filters)

      puts "\n📋 Instinct Status\n"
      puts '=' * 60
      puts

      if instincts.empty?
        puts 'No instincts found.'
        puts
        puts "💡 Use 'vibe instinct learn' to extract patterns from your sessions."
        return
      end

      # Group by confidence level
      high = instincts.select { |i| i['confidence'] >= 0.8 }
      medium = instincts.select { |i| i['confidence'] >= 0.6 && i['confidence'] < 0.8 }
      low = instincts.select { |i| i['confidence'] < 0.6 }

      puts "Total: #{instincts.size} instincts\n\n"

      if high.any?
        puts 'High Confidence (≥ 0.8):'
        high.each_with_index do |instinct, idx|
          print_instinct_summary(instinct, idx + 1)
        end
        puts
      end

      if medium.any?
        puts 'Medium Confidence (0.6-0.8):'
        medium.each_with_index do |instinct, idx|
          print_instinct_summary(instinct, high.size + idx + 1)
        end
        puts
      end

      return unless low.any?

      puts 'Low Confidence (< 0.6):'
      low.each_with_index do |instinct, idx|
        print_instinct_summary(instinct, high.size + medium.size + idx + 1)
      end
      puts
    end

    # vibe instinct export - Export instincts to file
    def run_instinct_export(argv)
      file_path = argv.shift

      if file_path.nil?
        puts 'Usage: vibe instinct export <file_path> [options]'
        puts
        puts 'Options:'
        puts '  --tag TAG              Export instincts with specific tag'
        puts '  --min-confidence NUM   Export instincts with confidence >= NUM'
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
      puts 'Share this file with your team!'
    rescue StandardError => e
      puts "\n✗ Export failed: #{e.message}"
      exit 1
    end

    # vibe instinct import - Import instincts from file
    def run_instinct_import(argv)
      file_path = argv.shift

      if file_path.nil?
        puts 'Usage: vibe instinct import <file_path> [options]'
        puts
        puts 'Options:'
        puts '  --overwrite   Overwrite existing instincts'
        puts '  --merge       Merge usage statistics'
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
      puts '=' * 60
      puts
      puts "  ✓ Imported: #{stats[:imported]} new instincts"
      puts "  ⊘ Skipped: #{stats[:skipped]} duplicates" if (stats[:skipped]).positive?
      puts "  🔀 Merged: #{stats[:merged]} instincts" if (stats[:merged]).positive?
      puts "  ⚠ Errors: #{stats[:errors]}" if (stats[:errors]).positive?
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
        puts 'Usage: vibe instinct evolve <instinct_id> [skill_name]'
        return
      end

      puts "\n🚀 Evolving Instinct to Skill\n"
      puts '=' * 60
      puts

      manager = InstinctManager.new
      result = manager.evolve(instinct_id, skill_name: skill_name)

      if result[:success]
        puts "✅ #{result[:message]}"
        puts
        puts 'Next steps:'
        puts "  1. Edit #{result[:skill_path]} to add detailed instructions"
        puts '  2. Register in core/skills/registry.yaml if needed'
      else
        puts "✗ #{result[:message]}"
        exit 1
      end
    end

    private

    def print_instinct_summary(instinct, number)
      confidence = instinct['confidence'].round(2)
      tags = instinct['tags'].join(', ')
      puts "  #{number}. #{instinct['pattern']} (#{confidence})"
      puts "     Tags: [#{tags}]" unless tags.empty?
      puts "     Usage: #{instinct['usage_count']} times, " \
           "Success: #{(instinct['success_rate'] * 100).round}%"
    end

    def parse_instinct_status_options(argv)
      options = { all: false, tag: nil, min_confidence: nil }

      while (arg = argv.shift)
        case arg
        when '--all'
          options[:all] = true
        when '--tag'
          options[:tag] = argv.shift
        when '--min-confidence'
          options[:min_confidence] = argv.shift.to_f
        end
      end

      options
    end

    def parse_instinct_export_options(argv)
      options = { tag: nil, min_confidence: nil }

      while (arg = argv.shift)
        case arg
        when '--tag'
          options[:tag] = argv.shift
        when '--min-confidence'
          options[:min_confidence] = argv.shift.to_f
        end
      end

      options
    end

    def parse_instinct_import_options(argv)
      options = { overwrite: false, merge: false }

      while (arg = argv.shift)
        case arg
        when '--overwrite'
          options[:overwrite] = true
        when '--merge'
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
          learn-eval [id]          Evaluate instinct(s)
          status                   View all instincts
          export <file>            Export instincts to file
          import <file>            Import instincts from file
          evolve <id> [name]       Upgrade instinct to skill

        Learn options:
          --pattern "..."          Create instinct manually
          --tags tag1,tag2         Tags for manual instinct
          --context "..."          Context for manual instinct
          --file <path>            Load session data from YAML file
          --stdin                  Read session data from stdin

        Examples:
          vibe instinct learn --pattern "Run tests before commit" --tags ruby,testing
          vibe instinct status --tag ruby --min-confidence 0.8
          vibe instinct export team-patterns.yaml --min-confidence 0.8
          vibe instinct import shared-patterns.yaml --merge

        For more information, see: skills/instinct-learning/SKILL.md
      USAGE
    end

    def parse_instinct_learn_options(argv)
      options = { file: nil, stdin: false, pattern: nil, tags: nil, context: nil }

      while (arg = argv.shift)
        case arg
        when '--file'
          options[:file] = argv.shift
        when '--stdin'
          options[:stdin] = true
        when '--pattern'
          options[:pattern] = argv.shift
        when '--tags'
          options[:tags] = argv.shift&.split(',')&.map(&:strip)
        when '--context'
          options[:context] = argv.shift
        end
      end

      options
    end

    def load_session_data(file_path)
      return nil unless file_path

      unless File.exist?(file_path)
        puts "File not found: #{file_path}"
        return nil
      end

      YAML.safe_load(File.read(file_path), permitted_classes: [Time, Symbol],
                                           aliases: true)
    rescue StandardError => e
      puts "Failed to load session data: #{e.message}"
      nil
    end

    def extract_patterns(session_data)
      candidates = []
      tool_calls = session_data['tool_calls'] || session_data[:tool_calls] || []

      return candidates if tool_calls.size < 3

      # Find consecutive successful sequences
      current_sequence = []

      tool_calls.each do |call|
        success = call['success'] || call[:success]

        if success
          current_sequence << call
        else
          if current_sequence.size >= 3
            candidates << build_candidate(current_sequence, session_data)
          end
          current_sequence = []
        end
      end

      # Check last sequence
      if current_sequence.size >= 3
        candidates << build_candidate(current_sequence, session_data)
      end

      candidates
    end

    def build_candidate(sequence, session_data)
      tools = sequence.map { |c| c['tool'] || c[:tool] }.compact
      commands = sequence.map do |c|
        c['command'] || c[:command] || c['tool'] || c[:tool]
      end.compact

      # Extract tags from context
      context = session_data['context'] || session_data[:context] || {}
      tags = []
      language = context['language'] || context[:language]
      framework = context['framework'] || context[:framework]
      tags << language if language
      tags << framework if framework
      tags.compact!

      {
        pattern: "Workflow: #{commands.join(' → ')}",
        tags: tags,
        confidence: [0.5 + (sequence.size * 0.05), 0.9].min,
        tools: tools,
        sequence_length: sequence.size
      }
    end
  end
end
