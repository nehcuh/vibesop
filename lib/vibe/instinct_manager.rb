# frozen_string_literal: true

require 'yaml'
require 'securerandom'
require 'time'
require 'fileutils'

module Vibe
  # Manages instinct learning system - automatic pattern extraction from sessions
  class InstinctManager
    attr_reader :data, :path

    DEFAULT_WEIGHTS = {
      success_rate: 0.6,
      usage_frequency: 0.3,
      source_diversity: 0.1
    }.freeze

    def initialize(storage_path = nil, config: {})
      @path = storage_path || default_storage_path
      @weights = DEFAULT_WEIGHTS.merge(config[:weights] || {})
      @data = load_data
      ensure_storage_directory
    end

    # Load instincts from YAML file
    def load_data
      return default_structure unless File.exist?(@path)

      YAML.safe_load(File.read(@path), permitted_classes: [Time, Symbol],
                                       aliases: true) || default_structure
    rescue StandardError => e
      warn "Failed to load instincts from #{@path}: #{e.message}"
      default_structure
    end

    # Get all instincts
    def all
      @data['instincts'] || []
    end

    # Get single instinct by ID
    def get(instinct_id)
      all.find { |i| i['id'] == instinct_id }
    end

    # List instincts with optional filters
    # @param filters [Hash] Optional filters
    #   - :tags [Array<String>] Filter by tags
    #   - :status [String] Filter by status (active, archived, evolved)
    #   - :min_confidence [Float] Minimum confidence threshold
    #   - :sort_by [Symbol] Sort field (:confidence, :usage_count, :created_at)
    # @return [Array<Hash>] Filtered and sorted instincts
    def list(filters = {})
      results = all.dup

      # Filter by tags
      if filters[:tags]
        tags = Array(filters[:tags])
        results.select! { |i| (i['tags'] & tags).any? }
      end

      # Filter by status
      results.select! { |i| i['status'] == filters[:status] } if filters[:status]

      # Filter by minimum confidence
      if filters[:min_confidence]
        results.select! { |i| i['confidence'] >= filters[:min_confidence] }
      end

      # Sort results
      if filters[:sort_by]
        field = filters[:sort_by].to_s
        results.sort_by! { |i| i[field] || 0 }
        results.reverse! unless filters[:ascending]
      end

      results
    end

    # Create new instinct
    # @param attributes [Hash] Instinct attributes
    # @return [Hash] Created instinct
    def create(attributes)
      instinct = {
        'id' => SecureRandom.uuid,
        'pattern' => attributes[:pattern] || attributes['pattern'],
        'confidence' => attributes[:confidence] || attributes['confidence'] || 0.5,
        'source_sessions' => attributes[:source_sessions] ||
                             attributes['source_sessions'] || [],
        'usage_count' => 0,
        'success_count' => 0,
        'success_rate' => 1.0,
        'created_at' => Time.now.iso8601,
        'updated_at' => Time.now.iso8601,
        'tags' => attributes[:tags] || attributes['tags'] || [],
        'context' => attributes[:context] || attributes['context'],
        'examples' => attributes[:examples] || attributes['examples'] || [],
        'status' => 'active'
      }

      validate_instinct!(instinct)
      @data['instincts'] << instinct
      save
      instinct
    end

    # Update existing instinct
    # @param instinct_id [String] Instinct ID
    # @param attributes [Hash] Attributes to update
    # @return [Hash, nil] Updated instinct or nil if not found
    def update(instinct_id, attributes)
      instinct = get(instinct_id)
      return nil unless instinct

      attributes.each do |key, value|
        instinct[key.to_s] = value unless key.to_s == 'id'
      end

      instinct['updated_at'] = Time.now.iso8601
      validate_instinct!(instinct)
      save
      instinct
    end

    # Delete instinct
    # @param instinct_id [String] Instinct ID
    # @return [Boolean] True if deleted, false if not found
    def delete(instinct_id)
      initial_size = all.size
      @data['instincts'].reject! { |i| i['id'] == instinct_id }
      deleted = all.size < initial_size
      save if deleted
      deleted
    end

    # Record usage of an instinct
    # @param instinct_id [String] Instinct ID
    # @param success [Boolean] Whether the usage was successful
    # @return [Hash, nil] Updated instinct or nil if not found
    def record_usage(instinct_id, success)
      instinct = get(instinct_id)
      return nil unless instinct

      instinct['usage_count'] += 1
      instinct['success_count'] = (instinct['success_count'] || 0) + (success ? 1 : 0)
      instinct['success_rate'] = instinct['success_count'].to_f / instinct['usage_count']
      instinct['confidence'] = calculate_confidence(instinct)
      instinct['updated_at'] = Time.now.iso8601

      save
      instinct
    end

    # Calculate confidence score for an instinct
    # @param instinct [Hash] Instinct object
    # @return [Float] Confidence score (0.0-1.0)
    def calculate_confidence(instinct)
      base_score      = instinct['success_rate'] * @weights[:success_rate]
      usage_score     = [instinct['usage_count'] / 20.0,
                         1.0].min * @weights[:usage_frequency]
      diversity_score = [instinct['source_sessions'].size / 5.0,
                         1.0].min * @weights[:source_diversity]
      [base_score + usage_score + diversity_score, 1.0].min
    end

    # Export instincts to file
    # @param file_path [String] Export file path
    # @param filters [Hash] Optional filters (same as list method)
    # @return [Integer] Number of exported instincts
    def export(file_path, filters = {})
      instincts_to_export = list(filters)
      export_data = {
        'version' => @data['version'],
        'exported_at' => Time.now.iso8601,
        'instincts' => instincts_to_export
      }

      File.write(file_path, YAML.dump(export_data))
      instincts_to_export.size
    end

    # Import instincts from file
    # @param file_path [String] Import file path
    # @param merge_strategy [Symbol] How to handle conflicts
    #   - :skip - Skip existing instincts (default)
    #   - :overwrite - Overwrite existing instincts
    #   - :merge - Merge usage data
    # @return [Hash] Import statistics
    def import(file_path, merge_strategy = :skip)
      import_data = YAML.safe_load(File.read(file_path),
                                   permitted_classes: [Time, Symbol], aliases: true)
      imported_instincts = import_data['instincts'] || []

      stats = { imported: 0, skipped: 0, merged: 0, errors: 0 }

      imported_instincts.each do |instinct|
        existing = get(instinct['id'])

        if existing.nil?
          @data['instincts'] << instinct
          stats[:imported] += 1
        else
          case merge_strategy
          when :skip
            stats[:skipped] += 1
          when :overwrite
            update(instinct['id'], instinct)
            stats[:imported] += 1
          when :merge
            merge_instinct_data(existing, instinct)
            stats[:merged] += 1
          end
        end
      rescue StandardError => e
        warn "Failed to import instinct: #{e.message}"
        stats[:errors] += 1
      end

      save if (stats[:imported] + stats[:merged]).positive?
      stats
    end

    # Evolve an instinct into a reusable skill file
    # @param instinct_id [String] ID of the instinct to evolve
    # @param skill_name [String] Optional custom skill name
    # @param output_dir [String] Directory to write skill file (default: skills/)
    # @return [Hash] Result with :success, :skill_path, :message
    def evolve(instinct_id, skill_name: nil, output_dir: nil)
      instinct = get(instinct_id)
      unless instinct
        return { success: false,
                 message: "Instinct not found: #{instinct_id}" }
      end

      repo_root = find_repo_root || Dir.pwd
      output_dir ||= File.join(repo_root, 'skills')
      FileUtils.mkdir_p(output_dir)

      name = skill_name || instinct['pattern'].downcase.gsub(/[^a-z0-9]+/, '-').gsub(
        /^-|-$/, ''
      )
      skill_dir = File.join(output_dir, name)
      skill_file = File.join(skill_dir, 'SKILL.md')

      if File.exist?(skill_file)
        return { success: false,
                 message: "Skill already exists: #{skill_file}" }
      end

      FileUtils.mkdir_p(skill_dir)

      tags_line = instinct['tags'].any? ? "\nTags: #{instinct['tags'].join(', ')}" : ''
      content = <<~SKILL
        # #{instinct['pattern']}

        Evolved from instinct `#{instinct_id}` (confidence: #{instinct['confidence'].round(2)})#{tags_line}

        ## When to use

        <!-- Describe when this skill should be applied -->

        ## Steps

        <!-- Add step-by-step instructions -->

        ## Notes

        - Usage count: #{instinct['usage_count']}
        - Success rate: #{(instinct['success_rate'] * 100).round}%
        - Source sessions: #{instinct['source_sessions'].join(', ')}
      SKILL

      File.write(skill_file, content)

      update(instinct_id, 'status' => 'evolved')

      { success: true, skill_path: skill_file, message: "Skill created at #{skill_file}" }
    end

    # Load high-confidence instincts to context
    # @param filters [Hash] Optional filters
    # @return [String] Formatted context string
    def load_to_context(filters = {})
      filters[:min_confidence] ||= 0.7
      filters[:status] ||= 'active'
      filters[:sort_by] ||= :confidence

      instincts = list(filters)
      return '' if instincts.empty?

      lines = ["# Learned Instincts\n"]
      instincts.each do |instinct|
        lines << "- **#{instinct['pattern']}** " \
                 "(confidence: #{instinct['confidence'].round(2)})"
        lines << "  Tags: #{instinct['tags'].join(', ')}" if instinct['tags'].any?
        lines << "  Context: #{instinct['context']}" if instinct['context']
      end

      lines.join("\n")
    end

    private

    def default_storage_path
      # Try to find repo root
      repo_root = find_repo_root || Dir.pwd
      File.join(repo_root, 'memory', 'instincts.yaml')
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

    def default_structure
      {
        'version' => '1.0',
        'instincts' => []
      }
    end

    def ensure_storage_directory
      dir = File.dirname(@path)
      FileUtils.mkdir_p(dir) unless Dir.exist?(dir)
    end

    def validate_instinct!(instinct)
      if instinct['pattern'].nil? || instinct['pattern'].empty?
        raise ArgumentError,
              'Pattern is required'
      end
      unless (0.0..1.0).cover?(instinct['confidence'])
        raise ArgumentError,
              'Confidence must be between 0 and 1'
      end
      unless (0.0..1.0).cover?(instinct['success_rate'])
        raise ArgumentError,
              'Success rate must be between 0 and 1'
      end
      # rubocop:disable Style/GuardClause
      if (instinct['usage_count']).negative?
        raise ArgumentError,
              'Usage count must be non-negative'
      end
      # rubocop:enable Style/GuardClause
    end

    def merge_instinct_data(existing, imported)
      # Merge usage statistics
      total_usage = existing['usage_count'] + imported['usage_count']
      total_successes = (existing['success_rate'] * existing['usage_count']) +
                        (imported['success_rate'] * imported['usage_count'])

      existing['usage_count'] = total_usage
      existing['success_rate'] = total_successes / total_usage if total_usage.positive?
      existing['confidence'] = calculate_confidence(existing)

      # Merge source sessions
      existing['source_sessions'] =
        (existing['source_sessions'] + imported['source_sessions']).uniq

      # Merge tags
      existing['tags'] = (existing['tags'] + imported['tags']).uniq

      # Update timestamp
      existing['updated_at'] = Time.now.iso8601
    end

    def save
      tmp = "#{@path}.tmp.#{Process.pid}"
      File.write(tmp, YAML.dump(@data))
      FileUtils.mv(tmp, @path)
    end
  end
end
