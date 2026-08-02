# frozen_string_literal: true

require 'yaml'
require 'json'
require 'set'

module Vibe
  # Session history analyzer for pattern detection
  class SessionAnalyzer
    attr_reader :sessions, :patterns, :config

    # Supported session file formats.
    # v1: "### S1 (14:35)" headers (current Claude Code memory format)
    # v2: "## Session 2026-03-22" headers (ISO date format, future-compatible)
    SUPPORTED_FORMATS = {
      'v1' => /^### S\d+ \(\d{2}:\d{2}/,
      'v2' => /^## Session \d{4}-\d{2}-\d{2}/
    }.freeze

    def initialize(config = {})
      @config = default_config.merge(config)
      @sessions = []
      @patterns = []
    end

    def default_config
      {
        min_occurrences: 3,
        min_success_rate: 0.7,
        min_sequence_length: 3,
        scan_recent_sessions: 20,
        pattern_types: %i[tool_sequence error_recovery workflow checklist]
      }
    end

    # Load session history from memory
    def load_sessions(path = nil)
      path ||= File.expand_path('~/.claude/memory/session.md')
      return [] unless File.exist?(path)

      content = File.read(path)
      return [] if content.strip.empty?

      format = detect_format(content)
      if format.nil?
        warn "session-analyzer: unknown session format in #{path}, skipping analysis"
        return []
      end

      @sessions = parse_sessions(content, format)
      @sessions
    rescue Errno::EACCES, Errno::ENOENT => e
      warn "skill-craft: could not read session file (#{e.message})"
      []
    end

    # Analyze loaded sessions for patterns
    def analyze
      return [] if @sessions.empty?

      @patterns = []

      # Detect different pattern types
      @config[:pattern_types].each do |type|
        case type
        when :tool_sequence
          @patterns.concat(detect_tool_sequences)
        when :error_recovery
          @patterns.concat(detect_error_recovery_patterns)
        when :workflow
          @patterns.concat(detect_workflow_patterns)
        when :checklist
          @patterns.concat(detect_checklist_patterns)
        end
      end

      # Rank and filter patterns
      @patterns = rank_patterns(@patterns)
      @patterns = filter_patterns(@patterns)

      @patterns
    end

    # Get pattern summary
    def summary
      return 'No patterns detected' if @patterns.empty?

      <<~SUMMARY
        Session Analysis Summary
        ────────────────────────
        Sessions analyzed: #{@sessions.size}
        Patterns found: #{@patterns.size}

        By type:
        #{pattern_type_summary}

        Top patterns:
        #{top_patterns_summary(5)}
      SUMMARY
    end

    private

    # Detect the format version of a session file by scanning for header patterns.
    # @return [String, nil] 'v1', 'v2', or nil if unknown
    def detect_format(content)
      SUPPORTED_FORMATS.each do |version, pattern|
        return version if content.match?(pattern)
      end
      nil
    end

    def parse_sessions(content, format = 'v1')
      case format
      when 'v2'
        parse_sessions_v2(content)
      else
        parse_sessions_v1(content)
      end
    end

    def parse_sessions_v1(content)
      sessions = []
      current_session = nil

      content.split("\n").each do |line|
        if (m = line.match(/^### S\d+ \((\d{2}:\d{2})/))
          sessions << current_session if current_session
          current_session = {
            id: "session-#{sessions.size + 1}",
            time: m[1],
            content: '',
            tool_calls: [],
            tags: []
          }
        elsif current_session
          current_session[:content] += "#{line}\n"

          # Extract tool calls
          if (m = line.match(/(Bash|Edit|Write|Read|Glob|Grep):\s*(.+)/))
            current_session[:tool_calls] << {
              tool: m[1],
              command: m[2].strip,
              success: !line.include?('→ Failed')
            }
          end

          # Extract tags
          current_session[:tags].concat(extract_tags(line))
        end
      end

      sessions << current_session if current_session
      sessions
    end

    def parse_sessions_v2(content)
      sessions = []
      current_session = nil

      content.split("\n").each do |line|
        if (m = line.match(/^## Session (\d{4}-\d{2}-\d{2})/))
          sessions << current_session if current_session
          current_session = {
            id: "session-#{sessions.size + 1}",
            time: m[1],
            content: '',
            tool_calls: [],
            tags: []
          }
        elsif current_session
          current_session[:content] += "#{line}\n"

          if (m = line.match(/(Bash|Edit|Write|Read|Glob|Grep):\s*(.+)/))
            current_session[:tool_calls] << {
              tool: m[1],
              command: m[2].strip,
              success: !line.include?('→ Failed')
            }
          end

          current_session[:tags].concat(extract_tags(line))
        end
      end

      sessions << current_session if current_session
      sessions
    end

    def extract_tags(line)
      tags = []

      # Language tags
      %w[ruby python javascript typescript go rust].each do |lang|
        tags << lang if line.downcase.include?(lang)
      end

      # Domain tags
      %w[debugging testing refactoring deployment security performance].each do |domain|
        tags << domain if line.downcase.include?(domain)
      end

      tags.uniq
    end

    def detect_tool_sequences
      patterns = []
      sequence_counts = Hash.new(0)
      sequence_success = Hash.new(0)

      @sessions.each do |session|
        next if session[:tool_calls].size < @config[:min_sequence_length]

        # Extract sequences of consecutive tool calls
        sequences = session[:tool_calls].each_cons(3).to_a
        sequences.each do |seq|
          key = seq.map { |c| c[:tool] }.join(' → ')
          sequence_counts[key] += 1
          sequence_success[key] += 1 if seq.all? { |c| c[:success] }
        end
      end

      sequence_counts.each do |sequence, count|
        next unless count >= @config[:min_occurrences]

        success_rate = sequence_success[sequence].to_f / count
        next unless success_rate >= @config[:min_success_rate]

        patterns << {
          type: :tool_sequence,
          pattern: sequence,
          occurrences: count,
          success_rate: success_rate,
          confidence: calculate_confidence(count, success_rate),
          tags: extract_sequence_tags(sequence)
        }
      end

      patterns
    end

    def detect_error_recovery_patterns
      patterns = []
      recovery_sequences = []

      @sessions.each do |session|
        calls = session[:tool_calls]
        next if calls.size < 2

        calls.each_with_index do |call, i|
          next if call[:success] # Only look at failures
          next if i + 1 >= calls.size

          # Look at what happened after the failure
          recovery = calls[(i + 1)..(i + 3)]
          next unless recovery&.any? { |c| c[:success] }

          recovery_sequences << {
            error: call[:command],
            recovery: recovery.map { |c| c[:tool] }.join(' → '),
            session: session[:id],
            recovered: recovery.any? { |c| c[:success] }
          }
        end
      end

      # Cluster similar recovery patterns
      recovery_groups = recovery_sequences.group_by { |r| r[:recovery] }

      recovery_groups.each do |recovery, group|
        next unless group.size >= @config[:min_occurrences]

        patterns << {
          type: :error_recovery,
          pattern: "Error → #{recovery}",
          occurrences: group.size,
          success_rate: group.count { |g| g[:recovered] }.to_f / group.size,
          confidence: calculate_confidence(group.size, 0.8),
          tags: %w[error-handling recovery],
          examples: group.take(3).map { |g| g[:error] }
        }
      end

      patterns
    end

    def detect_workflow_patterns
      patterns = []

      # Common workflow patterns to detect
      workflow_templates = {
        'pre-commit' => %w[lint test commit],
        'feature-implementation' => %w[plan implement test],
        'bug-fix' => %w[reproduce fix verify],
        'refactor' => %w[analyze change test]
      }

      @sessions.each do |session|
        content = session[:content].downcase

        workflow_templates.each do |name, steps|
          match_count = steps.count { |step| content.include?(step) }
          next unless match_count >= steps.size * 0.7

          patterns << {
            type: :workflow,
            pattern: name,
            occurrences: 1,
            success_rate: 1.0,
            confidence: 0.7,
            tags: [name],
            session: session[:id]
          }
        end
      end

      # Aggregate by workflow name
      patterns.group_by { |p| p[:pattern] }.map do |name, group|
        {
          type: :workflow,
          pattern: name,
          occurrences: group.size,
          success_rate: 1.0,
          confidence: calculate_confidence(group.size, 1.0),
          tags: [name]
        }
      end
    end

    def detect_checklist_patterns
      patterns = []
      checklist_keywords = %w[always before after must should check verify]

      @sessions.each do |session|
        content = session[:content]

        checklist_keywords.each do |keyword|
          matches = content.scan(/#{Regexp.escape(keyword)}\s+(.+?)[.\n]/i)
          matches.each do |match|
            patterns << {
              type: :checklist,
              pattern: "#{keyword.capitalize}: #{match.first}",
              occurrences: 1,
              success_rate: 1.0,
              confidence: 0.5,
              tags: %w[checklist],
              session: session[:id]
            }
          end
        end
      end

      # Deduplicate and count
      aggregated = patterns.group_by { |p| p[:pattern] }.map do |pattern, group|
        {
          type: :checklist,
          pattern: pattern,
          occurrences: group.size,
          success_rate: 1.0,
          confidence: calculate_confidence(group.size, 1.0),
          tags: %w[checklist]
        }
      end
      aggregated.select { |p| p[:occurrences] >= @config[:min_occurrences] }
    end

    def calculate_confidence(occurrences, success_rate)
      # Confidence = frequency_score * 0.3 + success_rate * 0.4 + diversity * 0.3
      frequency_score = [occurrences.to_f / 10, 1.0].min
      diversity_score = 0.5 # Default diversity

      (frequency_score * 0.3 + success_rate * 0.4 + diversity_score * 0.3).round(2)
    end

    def extract_sequence_tags(sequence)
      tags = []
      tags << 'debugging' if sequence.include?('Bash')
      tags << 'editing' if sequence.include?('Edit')
      tags << 'exploration' if sequence.include?('Glob') || sequence.include?('Grep')
      tags
    end

    def rank_patterns(patterns)
      patterns.sort_by { |p| p[:confidence] }.reverse
    end

    def filter_patterns(patterns)
      patterns.select do |p|
        p[:occurrences] >= @config[:min_occurrences] &&
          p[:success_rate] >= @config[:min_success_rate]
      end
    end

    def pattern_type_summary
      by_type = @patterns.group_by { |p| p[:type] }
      by_type.map { |type, patterns| "  #{type}: #{patterns.size}" }.join("\n")
    end

    def top_patterns_summary(limit)
      @patterns.take(limit).each_with_index.map do |p, i|
        "  #{i + 1}. #{p[:pattern]} (#{p[:confidence]} confidence, #{p[:occurrences]}x)"
      end.join("\n")
    end
  end
end
