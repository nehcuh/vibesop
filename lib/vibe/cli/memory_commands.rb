# frozen_string_literal: true

# CLI commands for memory trigger subsystem
# These methods are included in VibeCLI class

require_relative '../memory_trigger'

module Vibe
  # CLI commands for the memory trigger subsystem, included in VibeCLI.
  module MemoryCommands
    # Main entry point for 'vibe memory' subcommand
    def run_memory_command(argv)
      subcommand = argv.shift

      case subcommand
      when 'record'
        run_memory_record(argv)
      when 'stats'
        run_memory_stats
      when 'enable'
        run_memory_enable
      when 'disable'
        run_memory_disable
      when 'status'
        run_memory_status
      when 'autoload'
        run_memory_autoload(argv)
      when nil, 'help', '--help', '-h'
        puts memory_usage
      else
        raise Vibe::ValidationError,
              "Unknown memory subcommand: #{subcommand}\n\n#{memory_usage}"
      end
    end

    # vibe memory record - Record an error manually
    def run_memory_record(argv)
      options = parse_memory_record_options(argv)

      if options[:problem].nil? || options[:solution].nil?
        puts '❌ Error: --problem and --solution are required'
        puts memory_usage
        exit 1
      end

      trigger = MemoryTrigger.new

      error_info = {
        command: options[:command] || 'manual',
        problem: options[:problem],
        solution: options[:solution],
        scenario: options[:scenario],
        files: options[:files]&.split(',') || []
      }

      # Use force_record to bypass threshold
      trigger.force_record(error_info)
      puts '✅ Error recorded to memory/project-knowledge.md'
    end

    # vibe memory stats - Show statistics
    def run_memory_stats
      trigger = MemoryTrigger.new
      stats = trigger.stats

      puts '📊 Memory Trigger Statistics'
      puts
      puts "Total errors tracked: #{stats[:total_errors]}"
      puts "Recorded errors: #{stats[:recorded_errors]}"
      puts

      if stats[:top_errors].any?
        puts 'Top errors:'
        stats[:top_errors].each_with_index do |error, i|
          puts "  #{i + 1}. #{error[:signature]} (#{error[:count]} occurrences)"
        end
      else
        puts 'No errors tracked yet'
      end
    end

    # vibe memory enable - Enable auto trigger
    def run_memory_enable
      config_path = File.join(Dir.pwd, '.vibe', 'memory-trigger.yaml')
      FileUtils.mkdir_p(File.dirname(config_path))

      config = {
        'enabled' => true,
        'auto_record' => true,
        'min_occurrences' => 2
      }

      File.write(config_path, YAML.dump(config))
      puts '✅ Auto memory trigger enabled'
      puts "   Config: #{config_path}"
    end

    # vibe memory disable - Disable auto trigger
    def run_memory_disable
      config_path = File.join(Dir.pwd, '.vibe', 'memory-trigger.yaml')

      if File.exist?(config_path)
        config = YAML.safe_load(File.read(config_path), aliases: true) || {}
        config['enabled'] = false
        File.write(config_path, YAML.dump(config))
        puts '✅ Auto memory trigger disabled'
      else
        puts '⚠️  No config found (already disabled)'
      end
    end

    # vibe memory status - Show current status
    def run_memory_status
      config_path = File.join(Dir.pwd, '.vibe', 'memory-trigger.yaml')

      if File.exist?(config_path)
        config = YAML.safe_load(File.read(config_path), aliases: true) || {}
        enabled = config['enabled']
        auto_record = config['auto_record']
        min_occurrences = config['min_occurrences']

        puts '📋 Memory Trigger Status'
        puts
        puts "Enabled: #{enabled ? '✅ Yes' : '❌ No'}"
        puts "Auto-record: #{auto_record ? '✅ Yes' : '❌ No'}"
        puts "Min occurrences: #{min_occurrences}"
      else
        puts '📋 Memory Trigger Status: ❌ Not configured'
        puts
        puts 'Run `vibe memory enable` to enable auto memory trigger'
      end
    end

    # vibe memory autoload - Manage memory auto-load configuration
    def run_memory_autoload(argv)
      action = argv.shift

      case action
      when 'enable'
        enable_memory_autoload
      when 'disable'
        disable_memory_autoload
      when 'status', nil
        show_memory_autoload_status
      else
        raise Vibe::ValidationError,
              "Unknown autoload action: #{action}\n\n#{memory_autoload_usage}"
      end
    end

    private

    def enable_memory_autoload
      puts '📋 Enabling memory auto-load...'
      puts

      detection = detect_memory_files(Dir.pwd)
      unless detection[:found]
        puts '❌ No memory files found in this project'
        puts '   Expected: memory/session.md, memory/project-knowledge.md, memory/overview.md'
        exit 1
      end

      puts 'Detected memory files:'
      detection[:files].each do |file|
        size = File.size(File.join(Dir.pwd, file))
        puts "  ✓ #{file} (#{format_bytes(size)})"
      end
      puts

      puts 'Select platforms to enable:'
      puts '  [1] Claude Code only'
      puts '  [2] OpenCode only'
      puts '  [3] Both platforms'
      puts '  [0] Cancel'

      choice = ask_choice('Enter choice (0-3)', %w[0 1 2 3])

      if choice == '0'
        puts 'Cancelled'
        return
      end

      platforms = case choice
                  when '1' then ['claude-code']
                  when '2' then ['opencode']
                  when '3' then %w[claude-code opencode]
                  end

      config = { enabled: true, platforms: platforms }
      configure_memory_autoload(config, Dir.pwd, 'manual')

      puts
      puts "✅ Memory auto-load enabled for: #{platforms.join(', ')}"
    end

    def disable_memory_autoload
      config_path = File.join(Dir.pwd, '.vibe', 'config.yaml')

      if File.exist?(config_path)
        config = YAML.safe_load(File.read(config_path), permitted_classes: [Date, Time]) || {}
        if config['memory_autoload']
          config['memory_autoload']['enabled'] = false
          File.write(config_path, YAML.dump(config))
          puts '✅ Memory auto-load disabled'
        else
          puts '⚠️  Memory auto-load was not configured'
        end
      else
        puts '⚠️  No configuration found'
      end

      # Also remove from Claude Code settings
      settings_path = File.join(ENV['HOME'] || Dir.home, '.claude', 'settings.json')
      if File.exist?(settings_path)
        settings = JSON.parse(File.read(settings_path))
        if settings['hooks'] && settings['hooks']['preCommand']
          settings['hooks']['preCommand'].delete_if do |cmd|
            cmd.include?('memory/session.md') ||
              cmd.include?('memory/project-knowledge.md') ||
              cmd.include?('memory/overview.md')
          end
          File.write(settings_path, JSON.pretty_generate(settings))
          puts '   Removed from Claude Code settings'
        end
      end

      # Remove from OpenCode configurations
      remove_opencode_autoload(File.join(Dir.pwd, 'opencode.json'))
      remove_opencode_autoload(File.join(ENV['HOME'] || Dir.home, '.config', 'opencode', 'opencode.json'))
    end

    def remove_opencode_autoload(opencode_json_path)
      return unless File.exist?(opencode_json_path)

      config = JSON.parse(File.read(opencode_json_path))
      return unless config['instructions']

      memory_instruction = '.vibe/opencode/memory-context.md'
      if config['instructions'].include?(memory_instruction)
        config['instructions'].delete(memory_instruction)
        File.write(opencode_json_path, JSON.pretty_generate(config))
        puts "   Removed from #{opencode_json_path}"
      end
    rescue StandardError => e
      puts "   ⚠️  Failed to update #{opencode_json_path}: #{e.message}"
    end

    def show_memory_autoload_status
      config = existing_autoload_config(Dir.pwd)

      puts '📋 Memory Auto-Load Status'
      puts

      if config && config['enabled']
        puts 'Status: ✅ Enabled'
        puts "Platforms: #{config['platforms'].join(', ')}"
        puts "Configured at: #{config['configured_at']}"
      else
        puts 'Status: ❌ Disabled'
        puts
        puts 'Run `vibe memory autoload enable` to enable'
      end

      detection = detect_memory_files(Dir.pwd)
      return unless detection[:found]

      puts
      puts 'Memory files detected:'
      detection[:files].each do |file|
        size = File.size(File.join(Dir.pwd, file))
        puts "  ✓ #{file} (#{format_bytes(size)})"
      end
    end

    def memory_autoload_usage
      <<~USAGE
        Usage: vibe memory autoload <action>

        Actions:
          enable   Enable memory auto-load for this project
          disable  Disable memory auto-load
          status   Show current status

        Examples:
          vibe memory autoload enable
          vibe memory autoload disable
          vibe memory autoload status
      USAGE
    end

    def parse_memory_record_options(argv)
      options = {}
      i = 0
      while i < argv.length
        case argv[i]
        when '--problem'
          raise Vibe::ValidationError, '--problem requires a value' if argv[i + 1].nil?

          options[:problem] = argv[i + 1]
          i += 2
        when '--solution'
          raise Vibe::ValidationError, '--solution requires a value' if argv[i + 1].nil?

          options[:solution] = argv[i + 1]
          i += 2
        when '--scenario'
          raise Vibe::ValidationError, '--scenario requires a value' if argv[i + 1].nil?

          options[:scenario] = argv[i + 1]
          i += 2
        when '--command'
          raise Vibe::ValidationError, '--command requires a value' if argv[i + 1].nil?

          options[:command] = argv[i + 1]
          i += 2
        when '--files'
          raise Vibe::ValidationError, '--files requires a value' if argv[i + 1].nil?

          options[:files] = argv[i + 1]
          i += 2
        else
          i += 1
        end
      end
      options
    end

    def memory_usage
      <<~USAGE
        Usage: vibe memory <command> [options]

        Commands:
          record    Record an error manually
          stats     Show memory trigger statistics
          enable    Enable auto memory trigger
          disable   Disable auto memory trigger
          status    Show current status
          autoload  Manage memory auto-load configuration

        Examples:
          vibe memory record --problem "Test failed" --solution "Fix assertion"
          vibe memory stats
          vibe memory enable
          vibe memory autoload enable
      USAGE
    end
  end
end
