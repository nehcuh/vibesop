# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "fileutils"
require_relative "../../lib/vibe/worktree_manager"

class TestWorktreeManager < Minitest::Test
  def setup
    # Create a real bare git repo for testing
    @repo_dir = Dir.mktmpdir
    `git -C #{@repo_dir} init -q`
    `git -C #{@repo_dir} config user.email "test@test.com"`
    `git -C #{@repo_dir} config user.name "Test"`
    # Need at least one commit so we can branch
    File.write(File.join(@repo_dir, "README.md"), "test")
    `git -C #{@repo_dir} add .`
    `git -C #{@repo_dir} commit -q -m "init"`

    @manager = Vibe::WorktreeManager.new(@repo_dir)
  end

  def teardown
    # Force-remove all worktrees before deleting the temp dir
    `git -C #{@repo_dir} worktree list --porcelain 2>/dev/null`
      .scan(/worktree (.+)/).flatten
      .reject { |p| p == @repo_dir }
      .each { |p| `git -C #{@repo_dir} worktree remove --force #{p} 2>/dev/null` }
    FileUtils.rm_rf(@repo_dir)
  end

  # ── create ──────────────────────────────────────────────────────────────────

  def test_create_returns_info_hash
    info = @manager.create("my task")

    assert info["id"]
    assert info["path"]
    assert info["branch"]
    assert_equal "active", info["status"]
    assert_equal "my task", info["task_name"]
  end

  def test_create_makes_directory
    info = @manager.create("dir test")
    assert Dir.exist?(info["path"]), "worktree directory should exist"
  end

  def test_create_uses_custom_branch_name
    info = @manager.create("task", branch: "custom/branch-name")
    assert_equal "custom/branch-name", info["branch"]
  end

  def test_create_slugifies_task_name
    info = @manager.create("My Complex Task Name!")
    assert_match(/my-complex-task-name/, info["branch"])
  end

  # ── list ────────────────────────────────────────────────────────────────────

  def test_list_empty_when_no_worktrees
    assert_equal [], @manager.list
  end

  def test_list_returns_created_worktrees
    @manager.create("task one")
    @manager.create("task two")

    assert_equal 2, @manager.list.size
  end

  def test_list_filters_by_status
    w1 = @manager.create("active task")
    w2 = @manager.create("finished task")
    @manager.finish(w2["id"])

    active = @manager.list(status: "active")
    finished = @manager.list(status: "finished")

    assert_equal 1, active.size
    assert_equal w1["id"], active.first["id"]
    assert_equal 1, finished.size
    assert_equal w2["id"], finished.first["id"]
  end

  # ── get ─────────────────────────────────────────────────────────────────────

  def test_get_returns_nil_for_unknown_id
    assert_nil @manager.get("nonexistent")
  end

  def test_get_returns_worktree_info
    info = @manager.create("get test")
    fetched = @manager.get(info["id"])

    assert_equal info["id"], fetched["id"]
    assert_equal "get test", fetched["task_name"]
  end

  # ── finish ───────────────────────────────────────────────────────────────────

  def test_finish_updates_status
    info = @manager.create("finish me")
    @manager.finish(info["id"])

    updated = @manager.get(info["id"])
    assert_equal "finished", updated["status"]
  end

  def test_finish_returns_false_for_unknown_id
    refute @manager.finish("nonexistent")
  end

  # ── remove ───────────────────────────────────────────────────────────────────

  def test_remove_deletes_directory
    info = @manager.create("remove test")
    path = info["path"]

    @manager.remove(info["id"])

    refute Dir.exist?(path), "worktree directory should be gone"
  end

  def test_remove_returns_false_for_unknown_id
    refute @manager.remove("nonexistent")
  end

  # ── cleanup ──────────────────────────────────────────────────────────────────

  def test_cleanup_removes_finished_worktrees
    w1 = @manager.create("keep me")
    w2 = @manager.create("remove me")
    @manager.finish(w2["id"])

    removed = @manager.cleanup

    assert_equal 1, removed
    assert_equal 1, @manager.list.size
    assert_equal w1["id"], @manager.list.first["id"]
  end

  def test_cleanup_returns_zero_when_nothing_to_clean
    @manager.create("active task")
    assert_equal 0, @manager.cleanup
  end

  # ── status ───────────────────────────────────────────────────────────────────

  def test_status_summary
    w1 = @manager.create("task a")
    w2 = @manager.create("task b")
    @manager.finish(w2["id"])

    s = @manager.status

    assert_equal 2, s[:total]
    assert_equal 1, s[:active]
    assert_equal 1, s[:finished]
  end
end
