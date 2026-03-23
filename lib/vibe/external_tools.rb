# frozen_string_literal: true

require 'json'
require 'yaml'
require 'open3'
require 'pathname'
require 'rbconfig'
require_relative 'errors'

module Vibe
  # External tool detection and integration support.
  #
  # Host requirements:
  #   @repo_root [String] — absolute path to the workflow repository root
  module ExternalTools
    # Cross-platform command existence check.
    # Uses 'where' on Windows, 'which' on Unix.
    def cmd_exist?(cmd)
      finder = if RbConfig::CONFIG['host_os'] =~ /mswin|msys|mingw|cygwin/i
                 'where'
               else
                 'which'
               end
      system(finder, cmd, out: File::NULL, err: File::NULL)
    end

    # Load integration config for a specific tool
    def load_integration_config(tool_name)
      config_path = File.join(@repo_root, "core/integrations/#{tool_name}.yaml")
      return nil unless File.exist?(config_path)

      YAML.safe_load(File.read(config_path), aliases: true)
    rescue StandardError => e
      warn "Failed to load integration config for #{tool_name}: #{e.message}"
      nil
    end

    # Get all available integration configs
    def list_integrations
      integrations_dir = File.join(@repo_root, 'core/integrations')
      return [] unless Dir.exist?(integrations_dir)

      names = Dir.glob(File.join(integrations_dir, '*.yaml')).map do |path|
        File.basename(path, '.yaml')
      end
      names.reject { |name| name == 'README' }
    end

    # --- Superpowers Detection ---

    # Platform-specific superpowers paths.
    # skills_dir: directory where individual skill symlinks are created.
    # skills_source: the superpowers skills source directory that symlinks point into.
    SUPERPOWERS_PLATFORM_PATHS = {
      'claude-code' => {
        plugin: '~/.claude/plugins/superpowers',
        skills_dir: '~/.claude/skills',
        skills_source: '~/.config/skills/superpowers/skills'
      },
      'opencode' => {
        plugin: '~/.config/opencode/plugins/superpowers.js',
        skills_dir: '~/.config/opencode/skills',
        skills_source: '~/.config/skills/superpowers/skills'
      }
    }.freeze

    def detect_superpowers(target_platform = nil)
      skip_integrations = defined?(@skip_integrations) ? @skip_integrations : false
      return :not_installed if skip_integrations

      current_platform = defined?(@target_platform) ? @target_platform : nil
      platform = target_platform || current_platform

      # Platform-specific detection
      if platform && SUPERPOWERS_PLATFORM_PATHS[platform]
        paths = SUPERPOWERS_PLATFORM_PATHS[platform]

        if paths[:plugin]
          expanded = File.expand_path(paths[:plugin])
          return :platform_plugin if File.exist?(expanded) || Dir.exist?(expanded)
        end

        if paths[:skills_dir] && paths[:skills_source]
          skills_dir = File.expand_path(paths[:skills_dir])
          source_dir = File.expand_path(paths[:skills_source])
          if Dir.exist?(skills_dir) && superpowers_symlinks_in(skills_dir,
                                                               source_dir).any?
            return :platform_skills
          end
        end
      end

      # Cross-platform fallback: check common locations
      claude_plugins = File.expand_path('~/.claude/plugins/superpowers')
      return :claude_plugin if Dir.exist?(claude_plugins)

      # Check XDG-compliant shared location
      shared_clone = File.expand_path('~/.config/skills/superpowers')
      return :shared_clone if Dir.exist?(shared_clone)

      local_clone = File.expand_path('~/superpowers')
      return :local_clone if Dir.exist?(local_clone)

      :not_installed
    end

    def superpowers_location(target_platform = nil)
      current_platform = defined?(@target_platform) ? @target_platform : nil
      platform = target_platform || current_platform

      case detect_superpowers(platform)
      when :platform_plugin
        paths = SUPERPOWERS_PLATFORM_PATHS[platform]
        File.expand_path(paths[:plugin]) if paths
      when :platform_skills
        paths = SUPERPOWERS_PLATFORM_PATHS[platform]
        File.expand_path(paths[:skills_dir]) if paths
      when :claude_plugin
        File.expand_path('~/.claude/plugins/superpowers')
      when :shared_clone
        File.expand_path('~/.config/skills/superpowers')
      when :local_clone
        File.expand_path('~/superpowers')
      end
    end

    def superpowers_skills_count(target_platform = nil)
      current_platform = defined?(@target_platform) ? @target_platform : nil
      platform = target_platform || current_platform

      if platform && SUPERPOWERS_PLATFORM_PATHS[platform]
        paths = SUPERPOWERS_PLATFORM_PATHS[platform]
        if paths[:skills_dir] && paths[:skills_source]
          skills_dir = File.expand_path(paths[:skills_dir])
          source_dir = File.expand_path(paths[:skills_source])
          links = superpowers_symlinks_in(skills_dir, source_dir)
          return links.size if links.any?
        end
      end

      # Fallback: count skills in the shared clone
      shared_skills = File.expand_path('~/.config/skills/superpowers/skills')
      return Dir.children(shared_skills).size if Dir.exist?(shared_skills)

      0
    end

    # Returns entries in skills_dir whose symlink targets are inside source_dir.
    # Handles both relative and absolute symlink paths, and skips broken symlinks.
    def superpowers_symlinks_in(skills_dir, source_dir)
      return [] unless Dir.exist?(skills_dir)

      normalized_source = File.expand_path(source_dir)

      Dir.children(skills_dir).select do |entry|
        link_path = File.join(skills_dir, entry)
        next false unless File.symlink?(link_path)

        begin
          # Resolve symlink target to absolute path
          target = File.readlink(link_path)
          # Handle relative symlinks by resolving from the link's directory
          absolute_target = if Pathname.new(target).absolute?
                              target
                            else
                              File.expand_path(
                                target, skills_dir
                              )
                            end

          # Check if target is inside source_dir
          absolute_target.start_with?(normalized_source)
        rescue Errno::ENOENT, Errno::ELOOP
          # Skip broken or circular symlinks
          warn "Warning: Broken symlink detected: #{link_path}" if ENV['VIBE_DEBUG']
          false
        end
      end
    end

    # --- RTK Detection ---

    def detect_rtk
      skip_integrations = defined?(@skip_integrations) ? @skip_integrations : false
      return :not_installed if skip_integrations

      # Method 1: Check if rtk binary is in PATH
      return :installed if cmd_exist?('rtk')

      # Method 2: Check Claude settings.json for hook
      return :hook_configured if rtk_hook_configured?

      :not_installed
    end

    def rtk_version
      return nil unless detect_rtk == :installed

      version_output, status = Open3.capture2('rtk', '--version', err: File::NULL)
      status.success? && !version_output.strip.empty? ? version_output.strip : nil
    rescue StandardError => e
      warn "Warning: Failed to get RTK version: #{e.message}" if ENV['VIBE_DEBUG']
      nil
    end

    def rtk_binary_path
      return nil unless detect_rtk == :installed

      finder = if RbConfig::CONFIG['host_os'] =~ /mswin|msys|mingw|cygwin/i
                 'where'
               else
                 'which'
               end
      path_output, status = Open3.capture2(finder, 'rtk', err: File::NULL)
      status.success? ? path_output.strip : nil
    rescue StandardError => e
      warn "Warning: Failed to get RTK binary path: #{e.message}" if ENV['VIBE_DEBUG']
      nil
    end

    def rtk_hook_configured?
      settings_path = File.expand_path('~/.claude/settings.json')
      return false unless File.exist?(settings_path)

      begin
        settings = JSON.parse(File.read(settings_path))

        # Check new PreToolUse hook format (RTK 0.27+)
        pre_tool_use = settings.dig('hooks', 'PreToolUse')
        if pre_tool_use.is_a?(Array)
          pre_tool_use.each do |hook_config|
            next unless hook_config['matcher'] == 'Bash'

            hooks = hook_config['hooks']
            next unless hooks.is_a?(Array)

            hooks.each do |h|
              return true if h['command']&.include?('rtk')
            end
          end
        end

        # Fallback: check old bashCommandPrepare format
        hook = settings.dig('hooks', 'bashCommandPrepare')
        hook.is_a?(String) && hook.include?('rtk')
      rescue JSON::ParserError
        false
      end
    end

    # --- Installation Helpers ---

    def install_rtk_via_homebrew
      return false unless cmd_exist?('brew')

      puts 'Installing RTK via Homebrew...'
      system('brew', 'install', 'rtk')
    end

    def configure_rtk_hook
      return false unless detect_rtk == :installed

      puts 'Configuring RTK hook...'
      system('rtk', 'init', '--global')
    end

    # --- gstack Detection ---

    GSTACK_DETECTION_PATHS = [
      '~/.claude/skills/gstack',
      '~/.config/opencode/skills/gstack'
    ].freeze

    GSTACK_MARKER_FILES = %w[SKILL.md VERSION setup].freeze

    def detect_gstack
      skip_integrations = defined?(@skip_integrations) ? @skip_integrations : false
      return :not_installed if skip_integrations

      GSTACK_DETECTION_PATHS.each do |path|
        expanded = File.expand_path(path)
        return :installed if Dir.exist?(expanded) && gstack_markers_present?(expanded)
      end

      :not_installed
    end

    def gstack_location
      GSTACK_DETECTION_PATHS.each do |path|
        expanded = File.expand_path(path)
        return expanded if Dir.exist?(expanded) && gstack_markers_present?(expanded)
      end
      nil
    end

    def gstack_skills_count
      location = gstack_location
      return 0 unless location

      # Count subdirectories that contain a SKILL.md
      Dir.children(location).count do |entry|
        skill_path = File.join(location, entry, 'SKILL.md')
        File.directory?(File.join(location, entry)) && File.exist?(skill_path)
      end
    end

    def gstack_version
      location = gstack_location
      return nil unless location

      version_file = File.join(location, 'VERSION')
      return nil unless File.exist?(version_file)

      File.read(version_file).strip
    rescue StandardError
      nil
    end

    def verify_gstack(_target_platform = nil)
      status = detect_gstack
      return { installed: false, ready: false } if status == :not_installed

      location = gstack_location
      browse_ready = bun_available?

      {
        installed: true,
        ready: true,
        location: location,
        version: gstack_version,
        skills_count: gstack_skills_count,
        browse_ready: browse_ready
      }
    end

    private

    def bun_available?
      cmd_exist?('bun')
    end

    def gstack_markers_present?(dir)
      GSTACK_MARKER_FILES.all? { |f| File.exist?(File.join(dir, f)) }
    end

    public

    # --- Verification ---

    def verify_superpowers(target_platform = nil)
      current_platform = defined?(@target_platform) ? @target_platform : nil
      platform = target_platform || current_platform

      status = detect_superpowers(platform)
      return { installed: false } if status == :not_installed

      location = superpowers_location(platform)

      # For platform-specific detection, it's both installed and ready
      if %i[platform_plugin platform_skills].include?(status)
        return {
          installed: true,
          ready: true,
          method: status,
          location: location,
          skills_count: superpowers_skills_count(platform)
        }
      end

      # For fallback detection (shared_clone, local_clone, etc.):
      # platform is "ready" only if we can confirm platform-specific integration exists.
      # Unknown platforms (no entry in SUPERPOWERS_PLATFORM_PATHS) are assumed ready.
      platform_ready = platform.nil? || !SUPERPOWERS_PLATFORM_PATHS.key?(platform)

      # If platform has specific paths, check if they're actually configured
      if platform && SUPERPOWERS_PLATFORM_PATHS.key?(platform)
        paths = SUPERPOWERS_PLATFORM_PATHS[platform]
        if paths[:plugin]
          expanded = File.expand_path(paths[:plugin])
          platform_ready = true if File.exist?(expanded) || Dir.exist?(expanded)
        end
        if !platform_ready && paths[:skills_dir] && paths[:skills_source]
          skills_dir = File.expand_path(paths[:skills_dir])
          source_dir = File.expand_path(paths[:skills_source])
          platform_ready = true if superpowers_symlinks_in(skills_dir, source_dir).any?
        end
      end

      {
        installed: true,
        ready: platform_ready,
        method: status,
        location: location,
        skills_count: superpowers_skills_count(platform),
        platform_configured: platform_ready
      }
    end

    def verify_rtk(target_platform = nil)
      current_platform = defined?(@target_platform) ? @target_platform : nil
      platform = target_platform || current_platform

      status = detect_rtk
      hook_configured = rtk_hook_configured?
      binary_installed = (status == :installed)

      # For non-claude-code platforms, hook is not required
      rtk_needs_hook = platform.nil? || platform == 'claude-code'
      ready = binary_installed && (rtk_needs_hook ? hook_configured : true)

      {
        installed: binary_installed,
        ready: ready,
        status: status,
        binary: binary_installed ? rtk_binary_path : nil,
        version: binary_installed ? rtk_version : nil,
        hook_configured: hook_configured
      }
    end

    # --- Modern CLI Tools Detection ---

    # Detect all modern CLI tools defined in modern-cli.yaml
    # @return [Array<Hash>] Array of tool detection results
    def detect_modern_cli_tools
      config = load_integration_config('modern-cli')
      return [] unless config

      tools = config['tools'] || []
      tools.map { |tool| detect_single_modern_tool(tool) }.compact
    end

    # Detect a single modern CLI tool, checking primary binary then alternatives
    # @param tool_def [Hash] Tool definition from YAML
    # @return [Hash] Detection result
    def detect_single_modern_tool(tool_def)
      binary = tool_def.dig('detection', 'binary')
      alternatives = tool_def.dig('detection', 'alternatives') || []

      found_binary = if cmd_exist?(binary)
                       binary
                     else
                       alternatives.find { |alt| cmd_exist?(alt) }
                     end

      build_modern_tool_result(tool_def, found_binary || binary, !found_binary.nil?)
    end

    # Build structured detection result for a tool
    # @param tool_def [Hash] Tool definition from YAML
    # @param binary [String] Binary name that was found (or primary if not found)
    # @param available [Boolean] Whether the tool was found in PATH
    # @return [Hash] Detection result
    def build_modern_tool_result(tool_def, binary, available)
      result = {
        traditional: tool_def['traditional'],
        modern: tool_def['modern'],
        category: tool_def['category'],
        available: available,
        binary: binary,
        usage_notes: tool_def['usage_notes'],
        use_cases: tool_def['use_cases'] || []
      }
      result[:path] = which_tool(binary) if available
      result
    end

    # Locate a command binary by scanning PATH entries directly (no subprocess).
    # Works on Windows (checks PATHEXT extensions) and Unix.
    # @param cmd [String] Command name
    # @return [String, nil] Full path to binary, or nil if not found
    def which_tool(cmd)
      exts = if RbConfig::CONFIG['host_os'] =~ /mswin|msys|mingw|cygwin/i
               (ENV['PATHEXT'] || '.exe;.bat;.cmd').split(';')
             else
               ['']
             end

      ENV['PATH'].split(File::PATH_SEPARATOR).each do |dir|
        exts.each do |ext|
          exe = File.join(dir, "#{cmd}#{ext}")
          return exe if File.executable?(exe) && File.file?(exe)
        end
      end
      nil
    rescue StandardError
      nil
    end

    # Verify modern CLI tools status for a given platform
    # @return [Hash] Verification result with available/unavailable breakdown
    def verify_modern_cli_tools(_target_platform = nil)
      detected = detect_modern_cli_tools
      available = detected.select { |t| t[:available] }

      {
        installed: available.any?,
        ready: available.any?,
        available_tools: available,
        unavailable_tools: detected.reject { |t| t[:available] },
        total_count: detected.size,
        available_count: available.size
      }
    end

    # --- Integration Status Summary ---

    def integration_status
      @integration_status ||= {
        superpowers: verify_superpowers,
        rtk: verify_rtk,
        gstack: verify_gstack
      }
    end

    # Clear cached integration status (call after install/configure actions)
    def reset_integration_status!
      @integration_status = nil
    end

    def all_integrations_installed?
      status = integration_status
      status.values.all? { |s| s[:installed] }
    end

    def missing_integrations
      status = integration_status
      status.reject { |_name, s| s[:installed] }.keys
    end

    def pending_integrations
      status = integration_status
      status.reject { |_name, s| s[:ready] }.keys
    end

    def all_integrations_ready?
      status = integration_status
      status.values.all? { |s| s[:ready] }
    end
  end
end
