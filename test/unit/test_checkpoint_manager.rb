# frozen_string_literal: true

require "minitest/autorun"
require "fileutils"
require "tmpdir"
require_relative "../../lib/vibe/checkpoint_manager"

class TestCheckpointManager < Minitest::Test
  def setup
    @temp_dir = Dir.mktmpdir
    @storage_path = File.join(@temp_dir, "checkpoints.yaml")
    @manager = Vibe::CheckpointManager.new(@storage_path)

    # Create test files
    @test_file1 = File.join(@temp_dir, "test1.txt")
    @test_file2 = File.join(@temp_dir, "test2.txt")
    File.write(@test_file1, "content1")
    File.write(@test_file2, "content2")
  end

  def teardown
    FileUtils.rm_rf(@temp_dir)
  end

  def test_create_checkpoint
    checkpoint_id = @manager.create("Test checkpoint", [@test_file1, @test_file2])

    refute_nil checkpoint_id
    assert checkpoint_id.length > 0

    checkpoint = @manager.get(checkpoint_id)
    assert_equal "Test checkpoint", checkpoint["description"]
    assert_equal 2, checkpoint["files"].size
  end

  def test_create_checkpoint_with_metadata
    checkpoint_id = @manager.create(
      "Test with metadata",
      [@test_file1],
      { metadata: { author: "test", version: "1.0" } }
    )

    checkpoint = @manager.get(checkpoint_id)
    assert_equal "test", checkpoint["metadata"][:author]
    assert_equal "1.0", checkpoint["metadata"][:version]
  end

  def test_get_nonexistent_checkpoint
    result = @manager.get("nonexistent-id")
    assert_nil result
  end

  def test_list_checkpoints
    @manager.create("Checkpoint 1", [@test_file1])
    @manager.create("Checkpoint 2", [@test_file2])

    checkpoints = @manager.list
    assert_equal 2, checkpoints.size
  end

  def test_list_with_limit
    @manager.create("Checkpoint 1", [@test_file1])
    @manager.create("Checkpoint 2", [@test_file2])
    @manager.create("Checkpoint 3", [@test_file1])

    checkpoints = @manager.list(limit: 2)
    assert_equal 2, checkpoints.size
  end

  def test_list_with_time_filter
    cp1_id = @manager.create("Old checkpoint", [@test_file1])

    # Modify timestamp to be old
    cp1 = @manager.get(cp1_id)
    cp1["created_at"] = (Time.now - 3600).iso8601

    sleep 0.1
    @manager.create("New checkpoint", [@test_file2])

    recent = @manager.list(since: Time.now - 60)
    assert_equal 1, recent.size
    assert_equal "New checkpoint", recent.first["description"]
  end

  def test_rollback_checkpoint
    # Create checkpoint
    checkpoint_id = @manager.create("Before change", [@test_file1])

    # Modify file
    File.write(@test_file1, "modified content")
    assert_equal "modified content", File.read(@test_file1)

    # Rollback
    result = @manager.rollback(checkpoint_id)

    assert_equal checkpoint_id, result[:checkpoint_id]
    assert_equal "Before change", result[:description]
    assert_equal 1, result[:changes].size
    assert_equal "restored", result[:changes].first[:action]
    assert_equal "content1", File.read(@test_file1)
  end

  def test_rollback_dry_run
    checkpoint_id = @manager.create("Before change", [@test_file1])
    File.write(@test_file1, "modified content")

    result = @manager.rollback(checkpoint_id, dry_run: true)

    assert result[:dry_run]
    assert_equal "restore", result[:changes].first[:action]
    assert_equal "modified content", File.read(@test_file1)  # File unchanged
  end

  def test_rollback_nonexistent_checkpoint
    assert_raises(RuntimeError) do
      @manager.rollback("nonexistent-id")
    end
  end

  def test_compare_checkpoints
    # Create first checkpoint
    cp1_id = @manager.create("Version 1", [@test_file1])

    # Modify file
    File.write(@test_file1, "modified content with more text")

    # Create second checkpoint
    cp2_id = @manager.create("Version 2", [@test_file1])

    # Compare
    result = @manager.compare(cp1_id, cp2_id)

    assert_equal cp1_id, result[:checkpoint1][:id]
    assert_equal cp2_id, result[:checkpoint2][:id]
    assert result[:total_changes] > 0
  end

  def test_compare_with_added_file
    cp1_id = @manager.create("Version 1", [@test_file1])
    cp2_id = @manager.create("Version 2", [@test_file1, @test_file2])

    result = @manager.compare(cp1_id, cp2_id)

    added_files = result[:differences].select { |d| d[:status] == "added" }
    assert_equal 1, added_files.size
  end

  def test_compare_with_removed_file
    cp1_id = @manager.create("Version 1", [@test_file1, @test_file2])
    cp2_id = @manager.create("Version 2", [@test_file1])

    result = @manager.compare(cp1_id, cp2_id)

    removed_files = result[:differences].select { |d| d[:status] == "removed" }
    assert_equal 1, removed_files.size
  end

  def test_delete_checkpoint
    checkpoint_id = @manager.create("To delete", [@test_file1])

    result = @manager.delete(checkpoint_id)
    assert result

    assert_nil @manager.get(checkpoint_id)
  end

  def test_delete_nonexistent_checkpoint
    result = @manager.delete("nonexistent-id")
    refute result
  end

  def test_cleanup_old_checkpoints
    # Create 15 checkpoints
    15.times do |i|
      @manager.create("Checkpoint #{i}", [@test_file1])
    end

    removed = @manager.cleanup(10)
    assert_equal 5, removed

    remaining = @manager.list
    assert_equal 10, remaining.size
  end

  def test_cleanup_keeps_recent
    @manager.create("Checkpoint 1", [@test_file1])
    @manager.create("Checkpoint 2", [@test_file2])

    removed = @manager.cleanup(10)
    assert_equal 0, removed

    checkpoints = @manager.list
    assert_equal 2, checkpoints.size
  end

  def test_persistence
    checkpoint_id = @manager.create("Persistent", [@test_file1])

    # Create new manager instance
    manager2 = Vibe::CheckpointManager.new(@storage_path)
    checkpoint = manager2.get(checkpoint_id)

    refute_nil checkpoint
    assert_equal "Persistent", checkpoint["description"]
  end

  def test_checkpoint_ordering
    cp1_id = @manager.create("First", [@test_file1])
    sleep 0.1
    cp2_id = @manager.create("Second", [@test_file2])
    sleep 0.1
    cp3_id = @manager.create("Third", [@test_file1])

    checkpoints = @manager.list

    # Should be ordered newest first
    assert_equal cp3_id, checkpoints[0]["id"]
    assert_equal cp2_id, checkpoints[1]["id"]
    assert_equal cp1_id, checkpoints[2]["id"]
  end
end
