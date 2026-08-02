# frozen_string_literal: true

# CLI commands for background task management
# These methods are included in VibeCLI class

require_relative '../background_task_manager'

module Vibe
  # CLI commands for background task management, included in VibeCLI.
  module TaskCommands
    # Main entry point for 'vibe tasks' subcommand
    def run_tasks_command(argv)
      subcommand = argv.shift

      case subcommand
      when 'submit'
        run_tasks_submit(argv)
      when 'list'
        run_tasks_list(argv)
      when 'status'
        run_tasks_status(argv)
      when 'cancel'
        run_tasks_cancel(argv)
      when 'cleanup'
        run_tasks_cleanup(argv)
      when nil, 'help', '--help', '-h'
        puts tasks_usage
      else
        raise Vibe::ValidationError,
              "Unknown tasks subcommand: #{subcommand}\n\n#{tasks_usage}"
      end
    end

    # vibe tasks submit - Submit a background task
    def run_tasks_submit(argv)
      options = parse_tasks_submit_options(argv)

      unless options[:command]
        puts 'Error: Command required'
        puts
        puts tasks_usage
        exit 1
      end

      manager = Vibe::TaskRunner.new
      task_id = manager.submit(options[:command],
                               priority: options[:priority],
                               description: options[:description],
                               timeout: options[:timeout])

      puts "\n✅ Task submitted: #{task_id}\n"
      puts '=' * 60
      puts
      puts "Command: #{options[:command]}"
      puts "Priority: #{options[:priority]}"
      puts "Description: #{options[:description]}" if options[:description]
      puts
      puts "Use 'vibe tasks status #{task_id}' to check progress"
      puts
    end

    # vibe tasks list - List all tasks
    def run_tasks_list(argv)
      options = parse_tasks_list_options(argv)
      manager = Vibe::TaskRunner.new

      filters = {}
      filters[:status] = options[:status] if options[:status]
      if options[:priority]
        filters[:priority] =
          Vibe::TaskRunner::PRIORITY[options[:priority]]
      end

      tasks = manager.list(filters)

      puts "\n📋 Background Tasks\n"
      puts '=' * 60
      puts

      if tasks.empty?
        puts 'No tasks found.'
        puts
        return
      end

      tasks.each do |task|
        status_icon = case task['status']
                      when 'pending' then '⏳'
                      when 'running' then '🔄'
                      when 'completed' then '✅'
                      when 'failed' then '❌'
                      when 'cancelled' then '🚫'
                      else '❓'
                      end

        puts "#{status_icon} #{task['id'][0..7]}... - #{task['description']}"
        status_line = "   Status: #{task['status']} | " \
                      "Priority: #{task['priority']} | " \
                      "Created: #{task['created_at']}"
        puts status_line
        puts
      end

      puts "Total: #{tasks.size} task(s)"
      puts
    end

    # vibe tasks status - Get task status
    def run_tasks_status(argv)
      task_id = argv.shift

      unless task_id
        puts 'Error: Task ID required'
        puts
        puts tasks_usage
        exit 1
      end

      manager = Vibe::TaskRunner.new
      task = manager.status(task_id)

      unless task
        puts "Error: Task not found: #{task_id}"
        exit 1
      end

      puts "\n📊 Task Status\n"
      puts '=' * 60
      puts
      puts "ID: #{task['id']}"
      puts "Command: #{task['command']}"
      puts "Description: #{task['description']}"
      puts "Status: #{task['status']}"
      puts "Priority: #{task['priority']}"
      puts "Created: #{task['created_at']}"
      puts "Started: #{task['started_at']}" if task['started_at']
      puts "Completed: #{task['completed_at']}" if task['completed_at']
      puts "Exit code: #{task['exit_code']}" if task['exit_code']
      puts

      if task['output'] && !task['output'].empty?
        puts 'Output:'
        puts task['output']
        puts
      end

      return unless task['error']

      puts "Error: #{task['error']}"
      puts
    end

    # vibe tasks cancel - Cancel a task
    def run_tasks_cancel(argv)
      task_id = argv.shift

      unless task_id
        puts 'Error: Task ID required'
        puts
        puts tasks_usage
        exit 1
      end

      manager = Vibe::TaskRunner.new

      if manager.cancel(task_id)
        puts "\n✅ Task cancelled: #{task_id}\n"
      else
        puts 'Error: Cannot cancel task (not found or already completed)'
        exit 1
      end
    end

    # vibe tasks cleanup - Clean up old tasks
    def run_tasks_cleanup(argv)
      older_than = argv.shift&.to_i || 86_400

      manager = Vibe::TaskRunner.new
      removed = manager.cleanup(older_than)

      puts "\n🧹 Task Cleanup\n"
      puts '=' * 60
      puts
      puts "Removed: #{removed} task(s)"
      puts "Older than: #{older_than / 3600} hours"
      puts
    end

    private

    def parse_tasks_submit_options(argv)
      options = {
        command: nil,
        priority: :normal,
        description: nil,
        timeout: nil
      }

      while (arg = argv.shift)
        case arg
        when '--priority', '-p'
          options[:priority] = argv.shift&.to_sym || :normal
        when '--desc', '-d'
          options[:description] = argv.shift
        when '--timeout', '-t'
          options[:timeout] = argv.shift&.to_i
        else
          options[:command] = arg
        end
      end

      options
    end

    def parse_tasks_list_options(argv)
      options = { status: nil, priority: nil }

      while (arg = argv.shift)
        case arg
        when '--status', '-s'
          options[:status] = argv.shift
        when '--priority', '-p'
          options[:priority] = argv.shift&.to_sym
        end
      end

      options
    end

    def tasks_usage
      <<~USAGE
        Usage: vibe tasks <subcommand> [options]

        Subcommands:
          submit <command> [options]  Submit a background task
          list [options]              List all tasks
          status <id>                 Get task status
          cancel <id>                 Cancel a task
          cleanup [seconds]           Clean up old tasks (default: 24h)

        Options for 'submit':
          -p, --priority <level>      Priority (low, normal, high, critical)
          -d, --desc <text>           Description
          -t, --timeout <seconds>     Timeout

        Options for 'list':
          -s, --status <status>       Filter by status
          -p, --priority <level>      Filter by minimum priority

        Examples:
          vibe tasks submit "bundle exec rake test" --priority high
          vibe tasks list --status running
          vibe tasks status abc123
          vibe tasks cancel abc123
          vibe tasks cleanup 3600
      USAGE
    end
  end
end
