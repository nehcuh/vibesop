# frozen_string_literal: true

require 'yaml'
require 'securerandom'
require 'time'
require 'open3'
require 'shellwords'

module Vibe
  # Synchronous task runner for CLI task management.
  # Note: despite the historical "background" naming, tasks run synchronously.
  # The submit/cancel/stop_worker API reflects a former async design.
  class TaskRunner
    attr_reader :tasks, :storage_path

    # Task status values
    STATUS = {
      pending: 'pending',
      running: 'running',
      completed: 'completed',
      failed: 'failed',
      cancelled: 'cancelled'
    }.freeze

    # Priority levels
    PRIORITY = {
      low: 1,
      normal: 5,
      high: 10,
      critical: 20
    }.freeze

    def initialize(storage_path = nil)
      @storage_path = storage_path || default_storage_path
      @tasks = load_tasks
      @mutex = Mutex.new
    end

    # Submit a new background task and execute it immediately.
    # In CLI mode the process exits after the command returns, so tasks
    # are executed synchronously rather than on a background thread.
    # @param command [String] Command to execute
    # @param options [Hash] Task options
    #   - :priority [Symbol] Task priority (:low, :normal, :high, :critical)
    #   - :description [String] Human-readable description
    #   - :timeout [Integer] Timeout in seconds
    # @return [String] Task ID
    def submit(command, options = {})
      task_id = SecureRandom.uuid

      task = {
        'id' => task_id,
        'command' => command,
        'description' => options[:description] || command,
        'status' => STATUS[:pending],
        'priority' => PRIORITY[options[:priority] || :normal],
        'timeout' => options[:timeout],
        'created_at' => Time.now.iso8601,
        'started_at' => nil,
        'completed_at' => nil,
        'output' => nil,
        'error' => nil,
        'exit_code' => nil
      }

      @mutex.synchronize do
        @tasks[task_id] = task
        save_tasks
      end

      # Execute synchronously so the task completes before the CLI exits
      execute_task(task_id)

      task_id
    end

    # Get task status
    # @param task_id [String] Task ID
    # @return [Hash, nil] Task details or nil if not found
    def status(task_id)
      @mutex.synchronize { @tasks[task_id] }
    end

    # List all tasks with optional filters
    # @param filters [Hash] Filter options
    #   - :status [String] Filter by status
    #   - :priority [Integer] Minimum priority
    # @return [Array<Hash>] Filtered tasks
    def list(filters = {})
      @mutex.synchronize do
        results = @tasks.values

        if filters[:status]
          results = results.select do |t|
            t['status'] == filters[:status]
          end
        end
        if filters[:priority]
          results = results.select do |t|
            t['priority'] >= filters[:priority]
          end
        end

        results.sort_by { |t| [-t['priority'], t['created_at']] }
      end
    end

    # Cancel a pending or running task
    # @param task_id [String] Task ID
    # @return [Boolean] True if cancelled, false otherwise
    def cancel(task_id)
      @mutex.synchronize do
        task = @tasks[task_id]
        return false unless task
        return false if [STATUS[:completed], STATUS[:failed],
                         STATUS[:cancelled]].include?(task['status'])

        task['status'] = STATUS[:cancelled]
        task['completed_at'] = Time.now.iso8601
        save_tasks
        true
      end
    end

    # Clean up completed/failed/cancelled tasks
    # @param older_than [Integer] Remove tasks older than N seconds (default: 24 hours)
    # @return [Integer] Number of tasks removed
    def cleanup(older_than = 86_400)
      cutoff_time = Time.now - older_than
      removed = 0

      @mutex.synchronize do
        @tasks.delete_if do |_id, task|
          completed = [STATUS[:completed], STATUS[:failed],
                       STATUS[:cancelled]].include?(task['status'])
          old = Time.parse(task['created_at']) < cutoff_time

          if completed && old
            removed += 1
            true
          else
            false
          end
        end

        save_tasks if removed.positive?
      end

      removed
    end

    # Stop the worker thread (no-op, kept for API compatibility)
    def stop_worker
      # Tasks now execute synchronously; nothing to stop
    end

    private

    def default_storage_path
      repo_root = find_repo_root || Dir.pwd
      File.join(repo_root, 'memory', 'background_tasks.yaml')
    end

    def find_repo_root
      current = Dir.pwd
      loop do
        return current if File.exist?(File.join(current, '.git'))

        parent = File.dirname(current)
        break if parent == current

        current = parent
      end
      nil
    end

    def load_tasks
      return {} unless File.exist?(@storage_path)

      YAML.safe_load(File.read(@storage_path), permitted_classes: [Time, Symbol],
                                               aliases: true) || {}
    rescue StandardError => e
      warn "Failed to load tasks from #{@storage_path}: #{e.message}"
      {}
    end

    def save_tasks
      FileUtils.mkdir_p(File.dirname(@storage_path))
      File.write(@storage_path, YAML.dump(@tasks))
    rescue StandardError => e
      warn "Failed to save tasks to #{@storage_path}: #{e.message}"
    end

    def execute_task(task_id)
      task = nil

      @mutex.synchronize do
        task = @tasks[task_id]
        return unless task

        task['status'] = STATUS[:running]
        task['started_at'] = Time.now.iso8601
        save_tasks
      end

      begin
        output, status = Open3.capture2e('/bin/sh', '-c', task['command'])
        exit_code = status.exitstatus

        @mutex.synchronize do
          task['status'] = exit_code.zero? ? STATUS[:completed] : STATUS[:failed]
          task['output'] = output
          task['exit_code'] = exit_code
          task['completed_at'] = Time.now.iso8601
          save_tasks
        end
      rescue StandardError => e
        @mutex.synchronize do
          task['status'] = STATUS[:failed]
          task['error'] = e.message
          task['completed_at'] = Time.now.iso8601
          save_tasks
        end
      end
    end
  end
end
