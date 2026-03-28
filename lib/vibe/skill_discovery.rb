# frozen_string_literal: true

require 'yaml'
require 'fileutils'
require_relative 'security_scanner'

module Vibe
  # Unified skill discovery - scans filesystem and registry
  # Scans: ~/.config/skills/, project/skills/, core/skills/registry.yaml
  class SkillDiscovery
    SKILL_DIRS = [
      '~/.config/skills/personal',
      '~/.config/skills/superpowers',
      '~/.config/skills/gstack',
      'skills'
    ].freeze

    SKILL_FILE = 'SKILL.md'
    SKILL_REGISTRY_PATH = 'core/skills/registry.yaml'

    attr_reader :found_skills, :security_scanner, :repo_root, :project_root

    def initialize(repo_root = nil, project_root = Dir.pwd)
      @repo_root = repo_root || find_repo_root || Dir.pwd
      @project_root = project_root
      @security_scanner = SecurityScanner.new
      @found_skills = []
      @skills_cache = nil
      @cache_timestamp = nil
    end

    # Scan all skill directories and registry, discover new skills
    # Uses caching for better performance - call invalidate_cache if skills change
    # @return [Array<Hash>] List of discovered skills with metadata
    def discover_all
      # Return cached result if available and fresh (< 5 seconds old)
      if @skills_cache && @cache_timestamp && (Time.now - @cache_timestamp) < 5
        return @skills_cache
      end

      @found_skills = []

      # First load from registry (core/skills/registry.yaml)
      load_registry_skills

      # Then scan filesystem for additional skills
      SKILL_DIRS.each do |dir|
        discover_in_directory(File.expand_path(dir))
      end

      # Also check project-local skills
      project_skills_dir = File.join(@project_root, 'skills')
      discover_in_directory(project_skills_dir) if File.exist?(project_skills_dir)

      # Cache the result
      @skills_cache = @found_skills
      @cache_timestamp = Time.now

      @found_skills
    end

    # Invalidate the skills cache
    # Call this when skills are added/removed/modified
    def invalidate_cache
      @skills_cache = nil
      @cache_timestamp = nil
    end

    # Discover skills in a specific directory
    # @param directory [String] Directory to scan
    # @return [Array<Hash>] Skills found in this directory
    def discover_in_directory(directory)
      return [] unless File.directory?(directory)

      Dir.children(directory).each do |entry|
        skill_path = File.join(directory, entry)
        next unless File.directory?(skill_path)

        skill_file = File.join(skill_path, SKILL_FILE)
        next unless File.exist?(skill_file)

        skill = extract_skill_metadata(skill_path, entry)
        @found_skills << skill if skill
      end

      @found_skills
    end

    # Check if a skill is already registered in routing config
    # @param skill_id [String] Skill identifier
    # @return [Boolean]
    def registered?(skill_id)
      routing_config = load_project_routing
      return false unless routing_config

      # Check in routing rules
      rules = routing_config['routing_rules'] || []
      return true if rules.any? { |r| r['primary']&.dig('skill') == skill_id }
      return true if rules.any? { |r| r['alternatives']&.any? { |a| a['skill'] == skill_id } }

      # Check in exclusive skills
      exclusive = routing_config['exclusive_skills'] || []
      return true if exclusive.any? { |e| e['skill'] == skill_id }

      false
    end

    # Find unregistered skills (newly discovered)
    # @return [Array<Hash>] Skills not yet in routing
    def unregistered_skills
      discover_all.reject { |skill| registered?(skill[:id]) }
    end

    # Perform security audit on skill content
    # @param skill_path [String] Path to skill directory
    # @return [Hash] Security scan result
    def security_audit(skill_path)
      skill_file = File.join(skill_path, SKILL_FILE)
      return { safe: false, error: 'Skill file not found' } unless File.exist?(skill_file)

      content = File.read(skill_file)

      # Run security scanner
      scan_result = @security_scanner.scan(content)

      # Additional skill-specific checks
      red_flags = extract_red_flags(content)

      {
        safe: scan_result[:safe] && red_flags.empty?,
        threats: scan_result[:threats],
        red_flags: red_flags,
        risk_level: calculate_risk_level(scan_result, red_flags)
      }
    end

    # Get detailed info about a specific skill (API compatibility with SkillDetector)
    # @param skill_id [String] Skill identifier (e.g., "superpowers/tdd")
    # @return [Hash, nil] Skill metadata or nil if not found
    def get_skill_info(skill_id)
      # Build a hash map for O(1) lookup if not already built
      unless @skills_by_id
        all_skills = discover_all
        @skills_by_id = {}
        all_skills.each { |s| @skills_by_id[s[:id]] = s }
      end
      @skills_by_id[skill_id]
    end

    # List all available skills (API compatibility with SkillDetector)
    # @return [Array<Hash>] All available skills
    def list_available_skills
      discover_all
    end

    # Invalidate cache when skills change
    def invalidate_skill_cache
      @skills_by_id = nil
      invalidate_cache
    end

    private

    def extract_skill_metadata(skill_path, skill_name)
      skill_file = File.join(skill_path, SKILL_FILE)
      content = File.read(skill_file)

      # Parse YAML frontmatter
      metadata = parse_frontmatter(content)
      return nil unless metadata

      # Determine namespace from path
      namespace = determine_namespace(skill_path)

      # Extract keywords from content (simple approach)
      keywords = extract_keywords(content)

      {
        id: skill_id(namespace, skill_name),
        name: skill_name,
        namespace: namespace,
        display_name: metadata['name'] || skill_name,
        description: metadata['description'] || '',
        intent: metadata['intent'] || infer_intent(content),
        entrypoint: skill_file,
        allowed_tools: metadata['allowed_tools'] || metadata['tools'] || [],
        trigger_mode: metadata['trigger_mode'] || 'suggest',
        priority: metadata['priority'] || 'P2',
        keywords: keywords,
        path: skill_path,
        raw_metadata: metadata
      }
    rescue StandardError => e
      puts "Warning: Failed to parse skill at #{skill_path}: #{e.message}"
      nil
    end

    def parse_frontmatter(content)
      return nil unless content.start_with?('---')

      # Extract YAML frontmatter
      match = content.match(/\A---\s*\n(.*?)\n---\s*\n/m)
      return nil unless match

      YAML.safe_load(match[1], aliases: true) || {}
    rescue StandardError
      {}
    end

    def determine_namespace(skill_path)
      case skill_path
      when %r{/superpowers/} then 'superpowers'
      when %r{/gstack/} then 'gstack'
      when %r{/personal/} then 'project'
      else
        # Check if it's in project directory
        if skill_path.start_with?(@project_root)
          'project'
        else
          'external'
        end
      end
    end

    def skill_id(namespace, name)
      case namespace
      when 'project' then name
      else "#{namespace}/#{name}"
      end
    end

    def infer_intent(content)
      # Extract first paragraph after frontmatter as intent
      body = content.sub(/\A---\s*\n.*?\n---\s*\n/m, '')
      first_para = body.split(/\n\n/).first || ''
      first_para.strip.gsub(/\s+/, ' ').truncate(100)
    end

    def extract_keywords(content)
      # Simple keyword extraction based on common patterns
      keywords = []

      # Extract words from headers
      content.scan(/^#+\s+(.+)$/).flatten.each do |header|
        keywords.concat(header.downcase.split)
      end

      # Look for "when to use" section
      if content =~ /when to use/i
        section = content[content =~ /when to use/i..].split(/\n#/).first
        keywords.concat(section.downcase.scan(/\b\w{4,}\b/)) if section
      end

      keywords.uniq.first(10)
    end

    def extract_red_flags(content)
      flags = []

      # Check for potentially dangerous patterns (from SKILL-INJECT paper)
      dangerous_patterns = {
        /eval\s*\(/ => 'Dynamic code execution (eval)',
        /exec\s*\(/ => 'Dynamic code execution (exec)',
        /system\s*\(/ => 'System command execution',
        /`[^`]+`/ => 'Shell command execution (backticks)',
        /base64\.decode/i => 'Base64 decoding (potential obfuscation)',
        /http:\/\// => 'Insecure HTTP URL',
        /\.post\s*\(/ => 'HTTP POST request',
        /fetch\s*\(/ => 'Network fetch request',
        /curl\s+/ => 'curl network request',
        /rm\s+-rf/ => 'Recursive delete command',
        /upload/i => 'File upload operation',
        /backup.*to/i => 'External backup operation'
      }

      dangerous_patterns.each do |pattern, description|
        flags << description if content.match?(pattern)
      end

      # Check for compliance language (red flag per SKILL-INJECT)
      compliance_phrases = [
        /authorized backup/i,
        /compliance requirement/i,
        /mandatory security/i,
        /official policy/i
      ]

      compliance_phrases.each do |phrase|
        flags << "Compliance language (potential legitimizing): #{phrase.source}" if content.match?(phrase)
      end

      flags
    end

    def calculate_risk_level(scan_result, red_flags)
      return :critical if scan_result[:threats].any? { |t| t[:severity] == :critical }
      return :high if scan_result[:threats].any? { |t| t[:severity] == :high }
      return :high if red_flags.size >= 3
      return :medium if red_flags.any? || scan_result[:threats].any?

      :low
    end

    # Load skills from core registry (replaces SkillDetector functionality)
    def load_registry_skills
      registry_path = File.join(@repo_root, SKILL_REGISTRY_PATH)
      return unless File.exist?(registry_path)

      doc = YAML.safe_load(File.read(registry_path), aliases: true)
      return unless doc && doc['skills']

      doc['skills'].each do |skill|
        # Skip if already found (filesystem takes precedence for metadata)
        next if @found_skills.any? { |s| s[:id] == skill['id'] }

        @found_skills << {
          id: skill['id'],
          namespace: skill['namespace'],
          name: skill['id'].split('/').last,
          display_name: skill['name'] || skill['id'].split('/').last,
          description: skill['description'] || '',
          intent: skill['intent'] || '',
          trigger_mode: skill['trigger_mode'] || 'suggest',
          priority: skill['priority'] || 'P2',
          requires_tools: skill['requires_tools'] || [],
          supported_targets: skill['supported_targets'] || {},
          entrypoint: skill['entrypoint'],
          safety_level: skill['safety_level'],
          keywords: [],
          path: nil,
          raw_metadata: skill,
          source: 'registry'
        }
      end
    end

    # Find repo root (helper method)
    def find_repo_root
      dir = Dir.pwd
      loop do
        return dir if File.exist?(File.join(dir, 'core', 'skills', 'registry.yaml'))
        parent = File.dirname(dir)
        return nil if parent == dir
        dir = parent
      end
    end

    def load_project_routing
      routing_path = File.join(@project_root, '.vibe', 'skill-routing.yaml')
      return nil unless File.exist?(routing_path)

      YAML.safe_load(File.read(routing_path), aliases: true)
    rescue StandardError
      nil
    end
  end
end

# String extension for truncate
class String
  def truncate(n)
    length > n ? "#{self[0..n-3]}..." : self
  end
end
