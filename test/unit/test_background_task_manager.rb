# frozen_string_literal: true

require "minitest/autorun"
require "fileutils"
require "tmpdir"
require_relative "../../lib/vibe/background_task_manager"

class TestTaskRunner < Minitest::Test
  def setup
    @temp_dir = Dir.mktmpdir
    @storage_path = File.join(@temp_dir, "tasks.yaml")
    @manager = Vibe::TaskRunner.new(@storage_path)
  end

  def teardown
    @manager.stop_worker
    FileUtils.rm_rf(@temp_dir)
  end

  def test_submit_task
    task_id = @manager.submit("echo 'test'", description: "Test task")

    refute_nil task_id
    assert task_id.length > 0

    task = @manager.status(task_id)
    # Tasks execute synchronously, so status is completed after submit
    assert_equal "completed", task["status"]
    assert_equal "Test task", task["description"]
  end

  def test_submit_with_priority
    task_id = @manager.submit("echo 'high priority'", priority: :high)

    task = @manager.status(task_id)
    assert_equal Vibe::TaskRunner::PRIORITY[:high], task["priority"]
  end

  def test_task_execution
    task_id = @manager.submit("echo 'hello world'")

    task = @manager.status(task_id)
    assert_equal "completed", task["status"]
    assert_includes task["output"], "hello world"
  end

  def test_task_failure
    task_id = @manager.submit("exit 1")

    task = @manager.status(task_id)
    assert_equal "failed", task["status"]
    assert_equal 1, task["exit_code"]
  end

  def test_cannot_cancel_completed_task
    task_id = @manager.submit("echo 'done'")

    result = @manager.cancel(task_id)
    refute result, "Should not cancel completed task"
  end

  def test_list_all_tasks
    @manager.submit("echo 'task1'")
    @manager.submit("echo 'task2'")

    tasks = @manager.list
    assert_equal 2, tasks.size
  end

  def test_list_with_status_filter
    @manager.submit("echo 'test'")
    @manager.submit("exit 1")

    failed_tasks = @manager.list(status: "failed")
    assert_equal 1, failed_tasks.size
  end

  def test_list_with_priority_filter
    @manager.submit("echo 'low'", priority: :low)
    @manager.submit("echo 'high'", priority: :high)

    high_priority = @manager.list(priority: Vibe::TaskRunner::PRIORITY[:normal])
    assert_equal 1, high_priority.size
  end

  def test_priority_ordering
    low_id = @manager.submit("echo 'low'", priority: :low)
    high_id = @manager.submit("echo 'high'", priority: :high)
    normal_id = @manager.submit("echo 'normal'", priority: :normal)

    tasks = @manager.list
    # Should be ordered by priority (high to low)
    assert_equal high_id, tasks[0]["id"]
    assert_equal normal_id, tasks[1]["id"]
    assert_equal low_id, tasks[2]["id"]
  end

  def test_cleanup_old_tasks
    task_id = @manager.submit("echo 'old'")

    task = @manager.status(task_id)
    task["created_at"] = (Time.now - 100000).iso8601

    removed = @manager.cleanup(86400)
    assert_equal 1, removed

    assert_nil @manager.status(task_id)
  end

  def test_cleanup_keeps_recent_tasks
    task_id = @manager.submit("echo 'recent'")

    removed = @manager.cleanup(86400)
    assert_equal 0, removed

    refute_nil @manager.status(task_id)
  end

  def test_persistence
    task_id = @manager.submit("echo 'persist'")

    # Create new manager instance
    manager2 = Vibe::TaskRunner.new(@storage_path)
    task = manager2.status(task_id)

    refute_nil task
    assert_equal task_id, task["id"]

    manager2.stop_worker
  end

  def test_status_nonexistent_task
    result = @manager.status("nonexistent-id")
    assert_nil result
  end

  def test_task_timestamps
    task_id = @manager.submit("echo 'test'")

    task = @manager.status(task_id)
    refute_nil task["created_at"]
    # Synchronous execution means timestamps are set immediately
    refute_nil task["started_at"]
    refute_nil task["completed_at"]
  end
end
