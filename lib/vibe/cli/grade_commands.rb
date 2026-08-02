# frozen_string_literal: true

# CLI commands for grader system
# These methods are included in VibeCLI class

require_relative '../grader'

module Vibe
  # CLI commands for the grader system, included in VibeCLI.
  module GradeCommands
    # Main entry point for 'vibe grade' subcommand
    def run_grade_command(argv)
      subcommand = argv.shift

      case subcommand
      when 'run'
        run_grade_run(argv)
      when 'pass-at-k'
        run_grade_pass_at_k(argv)
      when 'summary'
        run_grade_summary(argv)
      when nil, 'help', '--help', '-h'
        puts grade_usage
      else
        raise Vibe::ValidationError,
              "Unknown grade subcommand: #{subcommand}\n\n#{grade_usage}"
      end
    end

    # vibe grade run - Run a grader
    def run_grade_run(argv)
      options = parse_grade_run_options(argv)

      unless options[:type] && options[:command]
        puts 'Error: Type and command required'
        puts
        puts grade_usage
        exit 1
      end

      grader = Grader.new
      result = grader.run(options[:type].to_sym, options[:command],
                          description: options[:description],
                          working_dir: options[:working_dir])

      puts "\n🎯 Grade Result\n"
      puts '=' * 60
      puts
      puts "Type: #{result[:type]}"
      puts "Grade: #{colorize_grade(result[:grade])}"
      puts "Duration: #{result[:duration]}s"
      puts "Exit code: #{result[:exit_code]}" if result[:exit_code]
      puts

      if result[:output] && !result[:output].empty?
        puts 'Output:'
        puts result[:output]
        puts
      end

      if result[:error]
        puts "Error: #{result[:error]}"
        puts
      end

      exit 1 if result[:grade] == 'fail'
    end

    # vibe grade pass-at-k - Run pass@k evaluation
    def run_grade_pass_at_k(argv)
      config_file = argv.shift

      unless config_file && File.exist?(config_file)
        puts 'Error: Config file required'
        puts
        puts grade_usage
        exit 1
      end

      config = YAML.safe_load(File.read(config_file), permitted_classes: [Symbol],
                                                      aliases: true)
      candidates = config['candidates'] || []
      grader_config = config['grader'] || {}

      unless candidates.any?
        puts 'Error: No candidates found in config'
        exit 1
      end

      grader = Grader.new
      result = grader.pass_at_k(
        candidates.map { |c| { code: c['code'], description: c['description'] } },
        {
          type: grader_config['type'].to_sym,
          command: grader_config['command'],
          k: grader_config['k']
        }
      )

      puts "\n📊 pass@#{result[:k]} Evaluation\n"
      puts '=' * 60
      puts
      puts "Total candidates: #{result[:total_candidates]}"
      puts "Evaluated: #{result[:evaluated]}"
      puts "Passes: #{result[:passes]}"
      puts "Failures: #{result[:failures]}"
      puts "Pass rate: #{result[:pass_rate]}%"
      puts

      return unless result[:results].any?

      puts 'Results:'
      result[:results].each_with_index do |r, i|
        grade_icon = r[:grade] == 'pass' ? '✅' : '❌'
        puts "  #{i + 1}. #{grade_icon} #{r[:description]} (#{r[:duration]}s)"
      end
      puts
    end

    # vibe grade summary - Show grading summary
    def run_grade_summary(_argv)
      grader = Grader.new
      summary = grader.summary

      puts "\n📈 Grading Summary\n"
      puts '=' * 60
      puts
      puts "Total runs: #{summary[:total_runs]}"
      puts "Passes: #{summary[:passes]}"
      puts "Failures: #{summary[:failures]}"
      puts "Warnings: #{summary[:warnings]}"
      puts "Pass rate: #{summary[:pass_rate]}%"
      puts

      return unless summary[:recent_results].any?

      puts 'Recent results:'
      summary[:recent_results].each do |r|
        grade_icon = case r[:grade]
                     when 'pass' then '✅'
                     when 'fail' then '❌'
                     when 'warning' then '⚠️'
                     else '❓'
                     end
        puts "  #{grade_icon} #{r[:type]} - #{r[:description]}"
      end
      puts
    end

    private

    def parse_grade_run_options(argv)
      options = {
        type: nil,
        command: nil,
        description: nil,
        working_dir: nil
      }

      while (arg = argv.shift)
        case arg
        when '--type', '-t'
          options[:type] = argv.shift
        when '--desc', '-d'
          options[:description] = argv.shift
        when '--dir'
          options[:working_dir] = argv.shift
        else
          options[:command] = arg
        end
      end

      options
    end

    def colorize_grade(grade)
      case grade
      when 'pass' then '✅ PASS'
      when 'fail' then '❌ FAIL'
      when 'warning' then '⚠️  WARNING'
      when 'skip' then '⏭️  SKIP'
      else grade
      end
    end

    def grade_usage
      <<~USAGE
        Usage: vibe grade <subcommand> [options]

        Subcommands:
          run <command> [options]     Run a grader
          pass-at-k <config>          Run pass@k evaluation
          summary                     Show grading summary

        Options for 'run':
          -t, --type <type>           Grader type (unit_test, integration_test, linter, security)
          -d, --desc <text>           Description
          --dir <path>                Working directory

        Examples:
          vibe grade run --type unit_test "ruby test/unit/test_*.rb"
          vibe grade run --type linter "rubocop lib/"
          vibe grade pass-at-k candidates.yaml
          vibe grade summary
      USAGE
    end
  end
end
