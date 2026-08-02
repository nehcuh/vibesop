# frozen_string_literal: true

require 'yaml'
require 'securerandom'
require 'time'
require 'set'
require 'open3'
require 'shellwords'

module Vibe
  # Executes tasks respecting a dependency graph.
  # Independent tasks run in parallel; dependent tasks wait for their prerequisites.
  #
  # Usage:
  #   executor = CascadeExecutor.new
  #   executor.add("lint",  command: "rubocop lib/")
  #   executor.add("test",  command: "ruby test/unit/test_*.rb", depends_on: ["lint"])
  #   executor.add("build", command: "rake build",               depends_on: ["test"])
  #   result = executor.run
  class CascadeExecutor
    # Task status values
    STATUS = {
      pending: 'pending',
      running: 'running',
      completed: 'completed',
      failed: 'failed',
      skipped: 'skipped' # skipped because a dependency failed
    }.freeze

    attr_reader :tasks

    def initialize
      @tasks = {} # id => task hash
      @mutex = Mutex.new
    end

    # Register a task in the graph
    # @param id [String] Unique task identifier
    # @param options [Hash]
    #   - :command [String]        Shell command to run
    #   - :depends_on [Array]      IDs of tasks that must complete first
    #   - :description [String]    Human-readable label
    #   - :working_dir [String]    Working directory for the command
    # @return [self] for chaining
    def add(id, options = {})
      raise ArgumentError, "Duplicate task id: #{id}" if @tasks.key?(id)

      @tasks[id] = {
        'id' => id,
        'command' => options[:command],
        'description' => options[:description] || id,
        'depends_on' => Array(options[:depends_on]),
        'working_dir' => options[:working_dir],
        'status' => STATUS[:pending],
        'output' => nil,
        'exit_code' => nil,
        'started_at' => nil,
        'finished_at' => nil
      }
      self
    end

    # Execute the task graph
    # @param options [Hash]
    #   - :max_parallel [Integer] Max concurrent tasks (default: unbounded)
    #   - :stop_on_failure [Boolean] Skip remaining tasks when one fails (default: true)
    # @return [Hash] Execution summary
    def run(options = {})
      validate_graph!

      stop_on_failure = options.fetch(:stop_on_failure, true)
      max_parallel    = options[:max_parallel]

      threads = []
      slot_mutex = max_parallel ? Mutex.new : nil
      slot_cv    = max_parallel ? ConditionVariable.new : nil
      slots      = max_parallel

      loop do
        ready = ready_tasks
        break if ready.empty? && threads.none?(&:alive?)

        ready.each do |task|
          # Wait for a slot if concurrency is capped
          slot_mutex&.synchronize do
            slot_cv.wait(slot_mutex) while slots <= 0
            slots -= 1
          end

          mark_running(task['id'])

          thread = Thread.new(task) do |tsk|
            execute_task(tsk)
            slot_mutex&.synchronize do
              slots += 1
              slot_cv.signal
            end

            # If this task failed and stop_on_failure, skip everything downstream
            if tsk['status'] == STATUS[:failed] && stop_on_failure
              skip_downstream(tsk['id'])
            end
          end

          threads << thread
        end

        # Yield the GIL so worker threads can make progress
        sleep 0.05
        threads.reject! { |t| t.join(0) }
      end

      threads.each(&:join)
      build_summary
    end

    # Validate the graph has no cycles and all dependency IDs exist
    def validate_graph!
      @tasks.each do |id, task|
        task['depends_on'].each do |dep|
          unless @tasks.key?(dep)
            raise ArgumentError,
                  "Task '#{id}' depends on unknown task '#{dep}'"
          end
        end
      end

      raise ArgumentError, 'Circular dependency detected' if cyclic?
    end

    # Return a topological ordering of task IDs
    def topological_order
      visited = Set.new
      order   = []

      visit = lambda do |id|
        return if visited.include?(id)

        visited.add(id)
        @tasks[id]['depends_on'].each { |dep| visit.call(dep) }
        order << id
      end

      @tasks.each_key { |id| visit.call(id) }
      order
    end

    private

    # Tasks whose dependencies are all completed and that are still pending
    def ready_tasks
      @mutex.synchronize do
        @tasks.values.select do |task|
          task['status'] == STATUS[:pending] &&
            task['depends_on'].all? { |dep| @tasks[dep]['status'] == STATUS[:completed] }
        end
      end
    end

    def mark_running(id)
      @mutex.synchronize do
        @tasks[id]['status']     = STATUS[:running]
        @tasks[id]['started_at'] = Time.now.iso8601
      end
    end

    def execute_task(task)
      cmd = task['command']
      dir = task['working_dir']
      sh_args = ['/bin/sh', '-c', cmd]

      output, status = if dir
                         Open3.capture2e(*sh_args, chdir: dir)
                       else
                         Open3.capture2e(*sh_args)
                       end
      exit_code = status.exitstatus

      @mutex.synchronize do
        task['output']      = output
        task['exit_code']   = exit_code
        task['finished_at'] = Time.now.iso8601
        task['status']      = exit_code.zero? ? STATUS[:completed] : STATUS[:failed]
      end
    rescue StandardError => e
      @mutex.synchronize do
        task['output']      = e.message
        task['exit_code']   = -1
        task['finished_at'] = Time.now.iso8601
        task['status']      = STATUS[:failed]
      end
    end

    # Mark all tasks that (transitively) depend on failed_id as skipped
    def skip_downstream(failed_id)
      to_recurse = []
      @mutex.synchronize do
        @tasks.each_value do |t|
          next unless t['depends_on'].include?(failed_id)
          next unless t['status'] == STATUS[:pending]

          t['status'] = STATUS[:skipped]
          to_recurse << t['id']
        end
      end
      to_recurse.each { |id| skip_downstream(id) }
    end

    def build_summary
      all     = @tasks.values
      passed  = all.count { |t| t['status'] == STATUS[:completed] }
      failed  = all.count { |t| t['status'] == STATUS[:failed] }
      skipped = all.count { |t| t['status'] == STATUS[:skipped] }

      {
        total: all.size,
        passed: passed,
        failed: failed,
        skipped: skipped,
        success: failed.zero?,
        tasks: @tasks
      }
    end

    # Detect cycles via DFS
    def cyclic?
      state = {}   # :unvisited | :visiting | :visited

      visit = lambda do |id|
        return false if state[id] == :visited
        return true  if state[id] == :visiting

        state[id] = :visiting
        result = @tasks[id]['depends_on'].any? { |dep| visit.call(dep) }
        state[id] = :visited
        result
      end

      @tasks.each_key.any? { |id| visit.call(id) }
    end
  end
end
