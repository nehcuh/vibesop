# frozen_string_literal: true

require_relative '../session_analyzer'
require_relative '../skill_generator'
require_relative '../trigger_manager'

module Vibe
  # CLI commands for the skill-craft generation system, included in VibeCLI.
  module SkillCraftCommands
    def run_skill_craft_command(argv)
      subcommand = argv.shift

      case subcommand
      when 'analyze', nil
        run_skill_craft_analyze(argv)
      when 'generate'
        run_skill_craft_generate(argv)
      when 'triggers'
        run_skill_craft_triggers(argv)
      when 'status'
        run_skill_craft_status(argv)
      when '--help', '-h', 'help'
        puts skill_craft_usage
      else
        # Default: interactive crafting session
        run_skill_craft_interactive(argv)
      end
    end

    def run_skill_craft_analyze(argv)
      options = parse_analyze_options(argv)

      puts '📊 Analyzing session history...'

      analyzer = SessionAnalyzer.new(
        min_occurrences: options[:min_occurrences] || 3,
        min_success_rate: options[:min_success_rate] || 0.7
      )

      sessions = analyzer.load_sessions
      patterns = analyzer.analyze

      puts "\n#{patterns.size} patterns detected from #{sessions.size} sessions"
      puts analyzer.summary
    end

    def run_skill_craft_generate(argv)
      options = parse_generate_options(argv)

      if options[:pattern].nil?
        puts 'Error: No pattern specified'
        puts 'Usage: vibe skill-craft generate --pattern <index>'
        puts "Run 'vibe skill-craft analyze' first to see available patterns."
        return
      end

      # Analyze sessions to get pattern list
      analyzer = SessionAnalyzer.new
      analyzer.load_sessions
      patterns = analyzer.analyze

      if patterns.empty?
        puts "Error: No patterns found. Run 'vibe skill-craft analyze' first."
        return
      end

      # Look up pattern by 1-based index
      index = options[:pattern].to_i - 1
      if index.negative? || index >= patterns.size
        puts "Error: Pattern index #{options[:pattern]} out of range " \
             "(1..#{patterns.size})"
        puts "Run 'vibe skill-craft analyze' to see available patterns."
        return
      end

      pattern = patterns[index]
      generator = SkillGenerator.new(output_dir: options[:output])
      result = generator.generate(pattern, force: options[:force])

      if result[:success]
        puts "Skill generated: #{result[:skill_name]}"
        puts "   Location: #{result[:skill_path]}"
      elsif result[:error] == :exists
        puts "Error: #{result[:message]}"
        puts '   Use --force to overwrite.'
      else
        puts 'Error: Failed to generate skill'
      end
    end

    def run_skill_craft_triggers(_argv)
      puts '🔍 Checking trigger conditions...'

      manager = TriggerManager.new
      triggers = manager.check_triggers

      if triggers.empty?
        puts '✅ No triggers fired'
      else
        puts "\n#{triggers.size} trigger(s) detected:"
        triggers.each do |trigger|
          puts "\n[#{trigger[:type].upcase}]"
          puts trigger[:message]
        end
      end
    end

    def run_skill_craft_status(_argv)
      manager = TriggerManager.new

      puts '📈 Skill Craft Status'
      puts '=' * 40
      puts "Sessions since last review: #{manager.state['session_count'] || 0}"
      puts "Last review: #{manager.state['last_review'] || 'Never'}"
      puts "Accumulation threshold: #{manager.config.dig('triggers',
                                                         'accumulation_threshold')}"
    end

    def run_skill_craft_interactive(_argv)
      puts '🎯 Skill Crafting Session'
      puts '=' * 50

      # Step 1: Analyze
      analyzer = SessionAnalyzer.new
      analyzer.load_sessions
      patterns = analyzer.analyze

      if patterns.empty?
        puts "\n❌ No patterns found in session history"
        return
      end

      puts "\n#{patterns.size} patterns found:"
      patterns.first(10).each_with_index do |pattern, i|
        confidence_filled = (pattern[:confidence] * 10).to_i
        confidence_empty = 10 - confidence_filled
        confidence_bar = ('█' * confidence_filled) + ('░' * confidence_empty)
        puts "  #{i + 1}. [#{pattern[:type]}] #{pattern[:pattern][0..50]}..."
        puts "     #{confidence_bar} #{(pattern[:confidence] * 100).to_i}% " \
             "(#{pattern[:occurrences]}x)"
      end

      puts "\nSelect patterns to craft (comma-separated, 'all', or 'q' to quit):"
      print '> '
      selection = $stdin.gets.chomp

      return if selection == 'q'
      return unless selection && selection != ''

      if selection == 'all'
        selected_patterns = patterns.to_a
      else
        indices = selection.split(',').map(&:strip).map(&:to_i).map { |i| i - 1 }
        selected_patterns = indices.map { |i| patterns[i] }.compact
      end

      # Step 2: Generate
      generator = SkillGenerator.new
      results = generator.generate_batch(selected_patterns)

      puts "\n✅ Generated #{results.size} skills:"
      results.each do |result|
        puts "  • #{result[:skill_name]} → #{result[:skill_path]}"
      end

      # Step 3: Update state
      manager = TriggerManager.new
      manager.record_review

      puts "\n✨ Skill crafting complete!"
      puts 'Skills saved to: ~/.claude/skills/personal/'
    end

    private

    def parse_analyze_options(argv)
      options = { min_occurrences: 3, min_success_rate: 0.7, scan_recent: 20 }

      argv.each do |arg|
        case arg
        when /^--min-occurrences=(\d+)$/
          options[:min_occurrences] = ::Regexp.last_match(1).to_i
        when /^--min-success-rate=([\d.]+)$/
          options[:min_success_rate] = ::Regexp.last_match(1).to_f
        when /^--scan-recent=(\d+)$/
          options[:scan_recent] = ::Regexp.last_match(1).to_i
        end
      end

      options
    end

    def parse_generate_options(argv)
      options = { pattern: nil, output: nil, force: false }

      i = 0
      while i < argv.length
        arg = argv[i]
        case arg
        when '--pattern'
          i += 1
          options[:pattern] = argv[i]
        when '--output'
          i += 1
          options[:output] = argv[i]
        when '--force'
          options[:force] = true
        end
        i += 1
      end

      options
    end

    def skill_craft_usage
      <<~USAGE
        Usage: vibe skill-craft [command] [options]

        Commands:
          analyze              Analyze session history for patterns
          generate              Generate a skill from a pattern
          triggers              Check trigger conditions
          status               Show skill-craft status

        Options for analyze:
          --min-occurrences=N   Minimum pattern occurrences (default: 3)
          --min-success-rate=N  Minimum success rate 0.0-1.0 (default: 0.7)
          --scan-recent=N       Number of recent sessions to scan (default: 20)

        Options for generate:
          --pattern=ID          Pattern ID to generate from
          --output=DIR          Output directory (default: ~/.claude/skills/personal)

        Examples:
          vibe skill-craft                          # Interactive crafting session
          vibe skill-craft analyze                  # Analyze patterns
          vibe skill-craft generate --pattern 1     # Generate skill from pattern #1
          vibe skill-craft triggers                 # Check triggers
          vibe skill-craft status                   # Show status
      USAGE
    end
  end
end
