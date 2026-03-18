# frozen_string_literal: true

require "test_helper"
require "vibe/instinct_manager"
require "tmpdir"
require "fileutils"

class InstinctManagerTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir("instinct-test")
    @storage_path = File.join(@tmpdir, "memory", "instincts.yaml")
    @manager = Vibe::InstinctManager.new(@storage_path)
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  # --- Initialization ---

  def test_initialize_creates_default_structure
    assert_equal "1.0", @manager.data["version"]
    assert_equal [], @manager.all
  end

  def test_initialize_creates_storage_directory
    assert Dir.exist?(File.dirname(@storage_path))
  end

  # --- Create ---

  def test_create_instinct
    instinct = @manager.create(
      pattern: "Run tests before committing",
      tags: ["testing", "git"],
      context: "All projects"
    )

    assert instinct["id"]
    assert_equal "Run tests before committing", instinct["pattern"]
    assert_equal 0.5, instinct["confidence"]
    assert_equal ["testing", "git"], instinct["tags"]
    assert_equal "active", instinct["status"]
    assert_equal 0, instinct["usage_count"]
    assert_equal 1.0, instinct["success_rate"]
  end

  def test_create_persists_to_file
    @manager.create(pattern: "Test pattern", tags: [])

    # Reload from file
    reloaded = Vibe::InstinctManager.new(@storage_path)
    assert_equal 1, reloaded.all.size
    assert_equal "Test pattern", reloaded.all.first["pattern"]
  end

  def test_create_requires_pattern
    assert_raises(ArgumentError) do
      @manager.create(pattern: "", tags: [])
    end
  end

  def test_create_validates_confidence
    assert_raises(ArgumentError) do
      @manager.create(pattern: "Test", confidence: 1.5)
    end
  end

  # --- Get ---

  def test_get_existing_instinct
    created = @manager.create(pattern: "Test pattern", tags: [])
    found = @manager.get(created["id"])

    assert_equal created["id"], found["id"]
    assert_equal "Test pattern", found["pattern"]
  end

  def test_get_nonexistent_returns_nil
    assert_nil @manager.get("nonexistent-id")
  end

  # --- List ---

  def test_list_all
    @manager.create(pattern: "Pattern 1", tags: ["ruby"])
    @manager.create(pattern: "Pattern 2", tags: ["python"])

    assert_equal 2, @manager.list.size
  end

  def test_list_filter_by_tags
    @manager.create(pattern: "Ruby pattern", tags: ["ruby"])
    @manager.create(pattern: "Python pattern", tags: ["python"])

    results = @manager.list(tags: ["ruby"])
    assert_equal 1, results.size
    assert_equal "Ruby pattern", results.first["pattern"]
  end

  def test_list_filter_by_status
    i1 = @manager.create(pattern: "Active", tags: [])
    i2 = @manager.create(pattern: "Archived", tags: [])
    @manager.update(i2["id"], "status" => "archived")

    results = @manager.list(status: "active")
    assert_equal 1, results.size
    assert_equal "Active", results.first["pattern"]
  end

  def test_list_filter_by_min_confidence
    @manager.create(pattern: "Low", tags: [], confidence: 0.3)
    @manager.create(pattern: "High", tags: [], confidence: 0.9)

    results = @manager.list(min_confidence: 0.8)
    assert_equal 1, results.size
    assert_equal "High", results.first["pattern"]
  end

  def test_list_sort_by_confidence
    @manager.create(pattern: "Low", tags: [], confidence: 0.3)
    @manager.create(pattern: "High", tags: [], confidence: 0.9)

    results = @manager.list(sort_by: :confidence)
    assert_equal "High", results.first["pattern"]
    assert_equal "Low", results.last["pattern"]
  end

  # --- Update ---

  def test_update_instinct
    created = @manager.create(pattern: "Original", tags: [])
    updated = @manager.update(created["id"], "pattern" => "Updated")

    assert_equal "Updated", updated["pattern"]
    assert_equal created["id"], updated["id"]
  end

  def test_update_nonexistent_returns_nil
    assert_nil @manager.update("nonexistent", "pattern" => "Test")
  end

  def test_update_cannot_change_id
    created = @manager.create(pattern: "Test", tags: [])
    @manager.update(created["id"], "id" => "new-id")

    assert_equal created["id"], @manager.all.first["id"]
  end

  # --- Delete ---

  def test_delete_instinct
    created = @manager.create(pattern: "To delete", tags: [])
    assert @manager.delete(created["id"])
    assert_equal 0, @manager.all.size
  end

  def test_delete_nonexistent_returns_false
    refute @manager.delete("nonexistent")
  end

  # --- Record Usage ---

  def test_record_usage_success
    created = @manager.create(pattern: "Test", tags: [])
    updated = @manager.record_usage(created["id"], true)

    assert_equal 1, updated["usage_count"]
    assert_equal 1.0, updated["success_rate"]
  end

  def test_record_usage_failure
    created = @manager.create(pattern: "Test", tags: [])
    @manager.record_usage(created["id"], true)
    updated = @manager.record_usage(created["id"], false)

    assert_equal 2, updated["usage_count"]
    assert_equal 0.5, updated["success_rate"]
  end

  def test_record_usage_updates_confidence
    created = @manager.create(pattern: "Test", tags: [], source_sessions: ["s1", "s2"])
    initial_confidence = created["confidence"]

    10.times { @manager.record_usage(created["id"], true) }
    updated = @manager.get(created["id"])

    assert updated["confidence"] > initial_confidence
  end

  # --- Confidence Calculation ---

  def test_calculate_confidence
    instinct = {
      "success_rate" => 1.0,
      "usage_count" => 20,
      "source_sessions" => %w[s1 s2 s3 s4 s5]
    }

    confidence = @manager.calculate_confidence(instinct)

    # 1.0 * 0.6 + 1.0 * 0.3 + 1.0 * 0.1 = 1.0
    assert_in_delta 1.0, confidence, 0.001
  end

  def test_calculate_confidence_low
    instinct = {
      "success_rate" => 0.5,
      "usage_count" => 1,
      "source_sessions" => ["s1"]
    }

    confidence = @manager.calculate_confidence(instinct)

    # 0.5 * 0.6 + 0.05 * 0.3 + 0.2 * 0.1 = 0.335
    assert_in_delta 0.335, confidence, 0.01
  end

  # --- Export / Import ---

  def test_export_and_import
    @manager.create(pattern: "Pattern 1", tags: ["ruby"])
    @manager.create(pattern: "Pattern 2", tags: ["python"])

    export_path = File.join(@tmpdir, "export.yaml")
    count = @manager.export(export_path)
    assert_equal 2, count

    # Import into new manager
    new_storage = File.join(@tmpdir, "memory2", "instincts.yaml")
    new_manager = Vibe::InstinctManager.new(new_storage)
    stats = new_manager.import(export_path)

    assert_equal 2, stats[:imported]
    assert_equal 0, stats[:skipped]
    assert_equal 2, new_manager.all.size
  end

  def test_import_skip_strategy
    created = @manager.create(pattern: "Existing", tags: [])

    export_path = File.join(@tmpdir, "export.yaml")
    @manager.export(export_path)

    stats = @manager.import(export_path, :skip)
    assert_equal 0, stats[:imported]
    assert_equal 1, stats[:skipped]
  end

  def test_import_overwrite_strategy
    created = @manager.create(pattern: "Original", tags: [])

    export_path = File.join(@tmpdir, "export.yaml")
    @manager.export(export_path)

    @manager.update(created["id"], "pattern" => "Modified")
    stats = @manager.import(export_path, :overwrite)

    assert_equal 1, stats[:imported]
    assert_equal "Original", @manager.get(created["id"])["pattern"]
  end

  def test_export_with_filters
    @manager.create(pattern: "Ruby", tags: ["ruby"], confidence: 0.9)
    @manager.create(pattern: "Python", tags: ["python"], confidence: 0.3)

    export_path = File.join(@tmpdir, "export.yaml")
    count = @manager.export(export_path, min_confidence: 0.8)

    assert_equal 1, count
  end

  # --- Load to Context ---

  def test_load_to_context_empty
    assert_equal "", @manager.load_to_context
  end

  def test_load_to_context_with_instincts
    @manager.create(pattern: "High confidence", tags: ["ruby"], confidence: 0.9)
    @manager.create(pattern: "Low confidence", tags: ["python"], confidence: 0.3)

    context = @manager.load_to_context
    assert_includes context, "High confidence"
    refute_includes context, "Low confidence"
  end
end
