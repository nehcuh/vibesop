# frozen_string_literal: true

require "yaml"
require "securerandom"
require "time"
require "fileutils"

module Vibe
  # Checkpoint manager for code snapshots and rollback
  class CheckpointManager
    attr_reader :checkpoints, :storage_path

    def initialize(storage_path = nil)
      @storage_path = storage_path || default_storage_path
      @checkpoints = load_checkpoints
      @snapshots_dir = File.join(File.dirname(@storage_path), "checkpoints")
      FileUtils.mkdir_p(@snapshots_dir)
    end

    # Create a new checkpoint
    # @param description [String] Checkpoint description
    # @param files [Array<String>] Files to include in checkpoint
    # @param options [Hash] Options including metadata
    # @return [String] Checkpoint ID
    def create(description, files = [], options = {})
      checkpoint_id = SecureRandom.uuid
      timestamp = Time.now

      # Create snapshot directory
      snapshot_dir = File.join(@snapshots_dir, checkpoint_id)
      FileUtils.mkdir_p(snapshot_dir)

      # Copy files to snapshot
      file_snapshots = {}
      files.each do |file_path|
        next unless File.exist?(file_path)

        relative_path = file_path.start_with?("/") ? file_path : File.expand_path(file_path)
        snapshot_path = File.join(snapshot_dir, File.basename(file_path))
        FileUtils.cp(relative_path, snapshot_path)

        file_snapshots[file_path] = {
          "snapshot_path" => snapshot_path,
          "size" => File.size(relative_path),
          "mtime" => File.mtime(relative_path).iso8601
        }
      end

      checkpoint = {
        "id" => checkpoint_id,
        "description" => description,
        "created_at" => timestamp.iso8601,
        "files" => file_snapshots,
        "metadata" => options[:metadata] || {}
      }

      @checkpoints[checkpoint_id] = checkpoint
      save_checkpoints

      checkpoint_id
    end

    # Get checkpoint details
    # @param checkpoint_id [String] Checkpoint ID
    # @return [Hash, nil] Checkpoint details or nil if not found
    def get(checkpoint_id)
      @checkpoints[checkpoint_id]
    end

    # List all checkpoints
    # @param filters [Hash] Filter options
    #   - :since [Time] Only checkpoints after this time
    #   - :limit [Integer] Maximum number of results
    # @return [Array<Hash>] Checkpoints sorted by creation time (newest first)
    def list(filters = {})
      results = @checkpoints.values

      if filters[:since]
        results = results.select { |cp| Time.parse(cp["created_at"]) >= filters[:since] }
      end

      results = results.sort_by { |cp| cp["created_at"] }.reverse

      filters[:limit] ? results.take(filters[:limit]) : results
    end

    # Rollback to a checkpoint
    # @param checkpoint_id [String] Checkpoint ID
    # @param options [Hash] Rollback options
    #   - :dry_run [Boolean] Preview changes without applying
    # @return [Hash] Rollback result with file changes
    def rollback(checkpoint_id, options = {})
      checkpoint = get(checkpoint_id)
      raise "Checkpoint not found: #{checkpoint_id}" unless checkpoint

      changes = []

      checkpoint["files"].each do |original_path, snapshot_info|
        snapshot_path = snapshot_info["snapshot_path"]

        unless File.exist?(snapshot_path)
          changes << { file: original_path, action: "skip", reason: "snapshot missing" }
          next
        end

        if options[:dry_run]
          changes << { file: original_path, action: "restore", size: snapshot_info["size"] }
        else
          FileUtils.cp(snapshot_path, original_path)
          changes << { file: original_path, action: "restored", size: snapshot_info["size"] }
        end
      end

      {
        checkpoint_id: checkpoint_id,
        description: checkpoint["description"],
        changes: changes,
        dry_run: options[:dry_run] || false
      }
    end

    # Compare two checkpoints
    # @param checkpoint_id1 [String] First checkpoint ID
    # @param checkpoint_id2 [String] Second checkpoint ID
    # @return [Hash] Comparison result
    def compare(checkpoint_id1, checkpoint_id2)
      cp1 = get(checkpoint_id1)
      cp2 = get(checkpoint_id2)

      raise "Checkpoint not found: #{checkpoint_id1}" unless cp1
      raise "Checkpoint not found: #{checkpoint_id2}" unless cp2

      all_files = (cp1["files"].keys + cp2["files"].keys).uniq
      differences = []

      all_files.each do |file_path|
        file1 = cp1["files"][file_path]
        file2 = cp2["files"][file_path]

        if file1 && file2
          if file1["size"] != file2["size"] || file1["mtime"] != file2["mtime"]
            differences << {
              file: file_path,
              status: "modified",
              size_change: file2["size"] - file1["size"]
            }
          end
        elsif file1
          differences << { file: file_path, status: "removed" }
        elsif file2
          differences << { file: file_path, status: "added", size: file2["size"] }
        end
      end

      {
        checkpoint1: { id: checkpoint_id1, created_at: cp1["created_at"] },
        checkpoint2: { id: checkpoint_id2, created_at: cp2["created_at"] },
        differences: differences,
        total_changes: differences.size
      }
    end

    # Delete a checkpoint
    # @param checkpoint_id [String] Checkpoint ID
    # @return [Boolean] True if deleted, false if not found
    def delete(checkpoint_id)
      checkpoint = @checkpoints.delete(checkpoint_id)
      return false unless checkpoint

      # Remove snapshot directory
      snapshot_dir = File.join(@snapshots_dir, checkpoint_id)
      FileUtils.rm_rf(snapshot_dir) if File.exist?(snapshot_dir)

      save_checkpoints
      true
    end

    # Clean up old checkpoints
    # @param keep_count [Integer] Number of recent checkpoints to keep
    # @return [Integer] Number of checkpoints removed
    def cleanup(keep_count = 10)
      all_checkpoints = list
      return 0 if all_checkpoints.size <= keep_count

      to_remove = all_checkpoints[keep_count..-1]
      removed = 0

      to_remove.each do |cp|
        delete(cp["id"])
        removed += 1
      end

      removed
    end

    private

    def default_storage_path
      File.join(Dir.home, ".claude", "projects", "-Users-huchen-Projects-claude-code-workflow", "memory", "checkpoints.yaml")
    end

    def load_checkpoints
      return {} unless File.exist?(@storage_path)

      YAML.safe_load(File.read(@storage_path), permitted_classes: [Time, Symbol], aliases: true) || {}
    rescue StandardError => e
      warn "Failed to load checkpoints from #{@storage_path}: #{e.message}"
      {}
    end

    def save_checkpoints
      FileUtils.mkdir_p(File.dirname(@storage_path))
      File.write(@storage_path, YAML.dump(@checkpoints))
    rescue StandardError => e
      warn "Failed to save checkpoints to #{@storage_path}: #{e.message}"
    end
  end
end
