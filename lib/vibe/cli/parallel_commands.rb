# frozen_string_literal: true

# CLI commands for parallel execution (worktrees + cascade)
# These methods are included in VibeCLI class

require_relative '../worktree_manager'
require_relative '../cascade_executor'

module Vibe
  # CLI commands for parallel execution (worktrees and cascade), included in VibeCLI.
  module ParallelCommands
    # ── vibe worktree ────────────────────────────────────────────────────────

    def run_worktree_command(argv)
      subcommand = argv.shift

      case subcommand
      when 'create'   then run_worktree_create(argv)
      when 'list'     then run_worktree_list(argv)
      when 'finish'   then run_worktree_finish(argv)
      when 'remove'   then run_worktree_remove(argv)
      when 'cleanup'  then run_worktree_cleanup(argv)
      when 'status'   then run_worktree_status(argv)
      when nil, 'help', '--help', '-h' then puts worktree_usage
      else
        raise Vibe::ValidationError,
              "Unknown worktree subcommand: #{subcommand}\n\n#{worktree_usage}"
      end
    end

    def run_worktree_create(argv)
      options = {}
      name_parts = []

      argv.each do |arg|
        case arg
        when /^--branch=(.+)$/
          options[:branch] = ::Regexp.last_match(1)
        when /^--branch$/
          # handled by next iteration — but we use = form in usage
          next
        else
          name_parts << arg
        end
      end

      task_name = name_parts.join(' ')
      if task_name.empty?
        puts "Error: task name required\n\n#{worktree_usage}"
        exit 1
      end

      manager = WorktreeManager.new
      info = manager.create(task_name, options)

      puts "\nWorktree created"
      puts '=' * 60
      puts "ID:      #{info['id']}"
      puts "Branch:  #{info['branch']}"
      puts "Path:    #{info['path']}"
      puts "\ncd #{info['path']} to start working"
    end

    def run_worktree_list(argv)
      filters = {}
      filters[:status] = argv.shift if argv.first && !argv.first.start_with?('-')

      manager = WorktreeManager.new
      worktrees = manager.list(filters)

      puts "\n📋 Worktrees\n#{'=' * 60}"

      if worktrees.empty?
        puts 'No worktrees found.'
        return
      end

      worktrees.each do |w|
        icon = w['status'] == 'active' ? '🔄' : '✅'
        puts "#{icon} #{w['id']}  #{w['task_name']}"
        puts "   Branch: #{w['branch']}  |  #{w['status']}  |  #{w['created_at']}"
      end
      puts "\nTotal: #{worktrees.size}"
    end

    def run_worktree_finish(argv)
      id = argv.shift
      unless id
        puts "Error: worktree ID required\n\n#{worktree_usage}"
        exit 1
      end

      manager = WorktreeManager.new
      if manager.finish(id)
        puts "✅ Worktree #{id} marked as finished"
      else
        puts "Error: worktree not found: #{id}"
        exit 1
      end
    end

    def run_worktree_remove(argv)
      id = argv.shift
      unless id
        puts "Error: worktree ID required\n\n#{worktree_usage}"
        exit 1
      end

      keep_branch = argv.include?('--keep-branch')
      manager = WorktreeManager.new

      if manager.remove(id, keep_branch: keep_branch)
        puts "✅ Worktree #{id} removed"
      else
        puts "Error: worktree not found: #{id}"
        exit 1
      end
    end

    def run_worktree_cleanup(_argv)
      manager = WorktreeManager.new
      removed = manager.cleanup
      puts "🧹 Removed #{removed} finished worktree(s)"
    end

    def run_worktree_status(_argv)
      manager = WorktreeManager.new
      s = manager.status

      puts "\n📊 Worktree Status\n#{'=' * 60}"
      puts "Total:    #{s[:total]}"
      puts "Active:   #{s[:active]}"
      puts "Finished: #{s[:finished]}"
    end

    # ── vibe cascade ─────────────────────────────────────────────────────────

    def run_cascade_command(argv)
      subcommand = argv.shift

      case subcommand
      when 'run'  then run_cascade_run(argv)
      when 'plan' then run_cascade_plan(argv)
      when nil, 'help', '--help', '-h' then puts cascade_usage
      else
        raise Vibe::ValidationError,
              "Unknown cascade subcommand: #{subcommand}\n\n#{cascade_usage}"
      end
    end

    # vibe cascade run <config.yaml>
    def run_cascade_run(argv)
      config_file = argv.shift

      unless config_file && File.exist?(config_file)
        puts "Error: config file required\n\n#{cascade_usage}"
        exit 1
      end

      config = YAML.safe_load(File.read(config_file), permitted_classes: [Symbol],
                                                      aliases: true)
      executor = build_executor_from_config(config)

      max_parallel = config['max_parallel']
      stop_on_failure = config.fetch('stop_on_failure', true)
      max_parallel_label = max_parallel || 'unlimited'

      puts "\n🚀 Cascade Execution: #{config_file}\n#{'=' * 60}"
      puts "Tasks: #{executor.tasks.size}  |  " \
           "max_parallel: #{max_parallel_label}"
      puts

      result = executor.run(max_parallel: max_parallel, stop_on_failure: stop_on_failure)

      result[:tasks].each_value do |task|
        icon = case task['status']
               when 'completed' then '✅'
               when 'failed'    then '❌'
               when 'skipped'   then '⏭️ '
               else '⏳'
               end
        puts "#{icon} #{task['id']}  (#{task['status']})"
        if task['status'] == 'failed' && task['output']
          task['output'].lines.last(3).each { |l| puts "     #{l.chomp}" }
        end
      end

      puts
      puts "Result: #{result[:passed]} passed, #{result[:failed]} failed, " \
           "#{result[:skipped]} skipped"
      exit 1 unless result[:success]
    end

    # vibe cascade plan <config.yaml>  — dry-run showing execution order
    def run_cascade_plan(argv)
      config_file = argv.shift

      unless config_file && File.exist?(config_file)
        puts "Error: config file required\n\n#{cascade_usage}"
        exit 1
      end

      config = YAML.safe_load(File.read(config_file), permitted_classes: [Symbol],
                                                      aliases: true)
      executor = build_executor_from_config(config)

      puts "\n📋 Cascade Plan: #{config_file}\n#{'=' * 60}"
      executor.topological_order.each_with_index do |id, i|
        task = executor.tasks[id]
        deps = if task['depends_on'].empty?
                 ''
               else
                 " (after: #{task['depends_on'].join(', ')})"
               end
        puts "  #{i + 1}. #{id}#{deps}"
        puts "     $ #{task['command']}"
      end
    end

    private

    def build_executor_from_config(config)
      executor = CascadeExecutor.new
      (config['tasks'] || []).each do |t|
        executor.add(
          t['id'],
          command: t['command'],
          description: t['description'],
          depends_on: Array(t['depends_on']),
          working_dir: t['working_dir']
        )
      end
      executor
    end

    def worktree_usage
      <<~USAGE
        Usage: vibe worktree <subcommand> [options]

        Subcommands:
          create <task name>    Create a new isolated worktree
          list [status]         List worktrees (optionally filter: active|finished)
          finish <id>           Mark a worktree as finished
          remove <id>           Remove a worktree and its branch
          cleanup               Remove all finished worktrees
          status                Show summary counts

        Examples:
          vibe worktree create "add payment feature"
          vibe worktree list active
          vibe worktree finish a1b2c3d4
          vibe worktree remove a1b2c3d4 --keep-branch
          vibe worktree cleanup
      USAGE
    end

    def cascade_usage
      <<~USAGE
        Usage: vibe cascade <subcommand> <config.yaml>

        Subcommands:
          run  <config.yaml>    Execute the task graph
          plan <config.yaml>    Preview execution order (dry-run)

        Config format (YAML):
          max_parallel: 3          # optional concurrency cap
          stop_on_failure: true    # default true
          tasks:
            - id: lint
              command: rubocop lib/
            - id: test
              command: ruby test/unit/test_*.rb
              depends_on: [lint]
            - id: build
              command: rake build
              depends_on: [test]

        Examples:
          vibe cascade plan  ci.yaml
          vibe cascade run   ci.yaml
      USAGE
    end
  end
end
