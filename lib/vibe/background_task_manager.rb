# frozen_string_literal: true

require "yaml"
require "securerandom"
require "time"
require "thread"

module Vibe
  # Background task manager for long-running operations
  class BackgroundTaskManager
    attr_reader :tasks, :storage_path

    # Task status values
    STATUS = {
      pending: "pending",
      running: "running",
      completed: "completed",
      failed: "failed",
      cancelled: "cancelled"
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
      @worker_thread = nil
      @mutex = Mutex.new
      @queue = []
    end

    # Submit a new background task
    # @param command [String] Command to execute
    # @param options [Hash] Task options
    #   - :priority [Symbol] Task priority (:low, :normal, :high, :critical)
    #   - :description [String] Human-readable description
    #   - :timeout [Integer] Timeout in seconds
    # @return [String] Task ID
    def submit(command, options = {})
      task_id = SecureRandom.uuid

      task = {
        "id" => task_id,
        "command" => command,
        "description" => options[:description] || command,
        "status" => STATUS[:pending],
        "priority" => PRIORITY[options[:priority] || :normal],
        "timeout" => options[:timeout],
        "created_at" => Time.now.iso8601,
        "started_at" => nil,
        "completed_at" => nil,
        "output" => nil,
        "error" => nil,
        "exit_code" => nil
      }

      @mutex.synchronize do
        @tasks[task_id] = task
        @queue << task_id
        @queue.sort_by! { |id| -@tasks[id]["priority"] }
        save_tasks
      end

      start_worker unless worker_running?

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

        results = results.select { |t| t["status"] == filters[:status] } if filters[:status]
        results = results.select { |t| t["priority"] >= filters[:priority] } if filters[:priority]

        results.sort_by { |t| [-t["priority"], t["created_at"]] }
      end
    end

    # Cancel a pending or running task
    # @param task_id [String] Task ID
    # @return [Boolean] True if cancelled, false otherwise
    def cancel(task_id)
      @mutex.synchronize do
        task = @tasks[task_id]
        return false unless task
        return false if [STATUS[:completed], STATUS[:failed], STATUS[:cancelled]].include?(task["status"])

        task["status"] = STATUS[:cancelled]
        task["completed_at"] = Time.now.iso8601
        @queue.delete(task_id)
        save_tasks
        true
      end
    end

    # Clean up completed/failed/cancelled tasks
    # @param older_than [Integer] Remove tasks older than N seconds (default: 24 hours)
    # @return [Integer] Number of tasks removed
    def cleanup(older_than = 86400)
      cutoff_time = Time.now - older_than
      removed = 0

      @mutex.synchronize do
        @tasks.delete_if do |_id, task|
          completed = [STATUS[:completed], STATUS[:failed], STATUS[:cancelled]].include?(task["status"])
          old = Time.parse(task["created_at"]) < cutoff_time

          if completed && old
            removed += 1
            true
          else
            false
          end
        end

        save_tasks if removed > 0
      end

      removed
    end

    # Stop the worker thread
    def stop_worker
      @worker_thread&.kill
      @worker_thread = nil
    end

    private

    def default_storage_path
      File.join(Dir.home, ".claude", "projects", "-Users-huchen-Projects-claude-code-workflow", "memory", "background_tasks.yaml")
    end

    def load_tasks
      return {} unless File.exist?(@storage_path)

      YAML.safe_load(File.read(@storage_path), permitted_classes: [Time, Symbol], aliases: true) || {}
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

    def worker_running?
      @worker_thread&.alive?
    end

    def start_worker
      return if worker_running?

      @worker_thread = Thread.new { worker_loop }
    end

    def worker_loop
      loop do
        task_id = next_task
        break unless task_id

        execute_task(task_id)
      end
    end

    def next_task
      @mutex.synchronize do
        @queue.shift
      end
    end

    def execute_task(task_id)
      task = nil

      @mutex.synchronize do
        task = @tasks[task_id]
        return unless task

        task["status"] = STATUS[:running]
        task["started_at"] = Time.now.iso8601
        save_tasks
      end

      begin
        output = `#{task["command"]} 2>&1`
        exit_code = $?.exitstatus

        @mutex.synchronize do
          task["status"] = exit_code.zero? ? STATUS[:completed] : STATUS[:failed]
          task["output"] = output
          task["exit_code"] = exit_code
          task["completed_at"] = Time.now.iso8601
          save_tasks
        end
      rescue StandardError => e
        @mutex.synchronize do
          task["status"] = STATUS[:failed]
          task["error"] = e.message
          task["completed_at"] = Time.now.iso8601
          save_tasks
        end
      end
    end
  end
end
