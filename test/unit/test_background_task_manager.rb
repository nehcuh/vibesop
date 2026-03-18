# frozen_string_literal: true

require "minitest/autorun"
require "fileutils"
require "tmpdir"
require_relative "../../lib/vibe/background_task_manager"

class TestBackgroundTaskManager < Minitest::Test
  def setup
    @temp_dir = Dir.mktmpdir
    @storage_path = File.join(@temp_dir, "tasks.yaml")
    @manager = Vibe::BackgroundTaskManager.new(@storage_path)
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
    assert_equal "pending", task["status"]
    assert_equal "Test task", task["description"]
  end

  def test_submit_with_priority
    task_id = @manager.submit("echo 'high priority'", priority: :high)

    task = @manager.status(task_id)
    assert_equal Vibe::BackgroundTaskManager::PRIORITY[:high], task["priority"]
  end

  def test_task_execution
    task_id = @manager.submit("echo 'hello world'")

    # Wait for task to complete
    sleep 0.5

    task = @manager.status(task_id)
    assert_includes ["completed", "running"], task["status"]
  end

  def test_task_failure
    task_id = @manager.submit("exit 1")

    # Wait for task to complete
    sleep 0.5

    task = @manager.status(task_id)
    assert_equal "failed", task["status"]
    assert_equal 1, task["exit_code"]
  end

  def test_cancel_pending_task
    task_id = @manager.submit("sleep 10")
    result = @manager.cancel(task_id)

    assert result, "Should successfully cancel pending task"

    task = @manager.status(task_id)
    assert_equal "cancelled", task["status"]
  end

  def test_cannot_cancel_completed_task
    task_id = @manager.submit("echo 'done'")

    # Wait for completion
    sleep 0.5

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
    task1 = @manager.submit("echo 'test'")
    task2 = @manager.submit("sleep 10")
    @manager.cancel(task2)

    completed_tasks = @manager.list(status: "cancelled")
    assert_equal 1, completed_tasks.size
    assert_equal task2, completed_tasks.first["id"]
  end

  def test_list_with_priority_filter
    @manager.submit("echo 'low'", priority: :low)
    @manager.submit("echo 'high'", priority: :high)

    high_priority = @manager.list(priority: Vibe::BackgroundTaskManager::PRIORITY[:normal])
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
    # Create an old completed task
    task_id = @manager.submit("echo 'old'")
    sleep 0.5

    task = @manager.status(task_id)
    task["created_at"] = (Time.now - 100000).iso8601
    task["status"] = "completed"

    removed = @manager.cleanup(86400)
    assert_equal 1, removed

    assert_nil @manager.status(task_id)
  end

  def test_cleanup_keeps_recent_tasks
    task_id = @manager.submit("echo 'recent'")
    sleep 0.5

    removed = @manager.cleanup(86400)
    assert_equal 0, removed

    refute_nil @manager.status(task_id)
  end

  def test_persistence
    task_id = @manager.submit("echo 'persist'")

    # Create new manager instance
    manager2 = Vibe::BackgroundTaskManager.new(@storage_path)
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
    assert_nil task["started_at"]
    assert_nil task["completed_at"]

    sleep 0.5

    task = @manager.status(task_id)
    refute_nil task["started_at"] if task["status"] != "pending"
  end
end
