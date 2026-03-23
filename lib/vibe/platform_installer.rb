# frozen_string_literal: true

require_relative 'platform_utils'
require_relative 'user_interaction'
require_relative 'hook_installer'
require_relative 'external_tools'

module Vibe
  # Platform installation logic.
  #
  # Host requirements:
  #   @repo_root [String] — absolute path to the workflow repository root
  #
  # Dependencies:
  #   - Vibe::PlatformUtils — for platform-related utilities
  #   - Vibe::UserInteraction — for user prompts
  #   - Vibe::HookInstaller — for hook installation
  #   - Vibe::ExternalTools — for modern CLI tool detection
  module PlatformInstaller
    include PlatformUtils
    include UserInteraction
    include HookInstaller
    include ExternalTools

    # Build, copy, and write marker for a target to a destination.
    # Shared core used by install_global_config and quickstart.
    # @param target [String] Normalized target name
    # @param destination_root [String] Absolute path to destination
    # @param mode [String] Marker mode ("init", "quickstart", etc.)
    # @param project_level [Boolean] Whether this is project-level config
    # @return [Hash] The generated manifest
    def build_and_deploy_target(target:, destination_root:, mode:, project_level: false)
      profile_name, profile = resolve_profile(target, nil)
      output_root = resolve_output_root_for_use(
        target: target,
        destination_root: destination_root,
        explicit_output: nil
      )
      overlay = resolve_overlay(explicit_path: nil,
                                search_roots: [
                                  destination_root, @repo_root
                                ])

      # Detect modern CLI tools (only for global init)
      enable_tools = if !project_level && mode == 'init'
                       detect_and_enable_modern_cli_tools(target)
                     else
                       true
                     end

      manifest = build_target(
        target: target,
        profile_name: profile_name,
        profile: profile,
        output_root: output_root,
        overlay: overlay,
        project_level: project_level
      )

      # Remove TOOLS.md if user opted out
      unless enable_tools
        tools_md = File.join(output_root, 'TOOLS.md')
        FileUtils.rm(tools_md) if File.exist?(tools_md)
      end

      FileUtils.mkdir_p(destination_root)
      copy_tree_contents(output_root, destination_root)

      write_marker(
        File.join(destination_root, '.vibe-target.json'),
        destination_root: destination_root,
        manifest: manifest,
        output_root: output_root,
        mode: mode
      )

      manifest
    end

    # Install global configuration for a platform
    # @param platform [String] Platform name
    # @param force [Boolean] Force overwrite if config exists
    def install_global_config(platform:, force:)
      target = normalize_target(platform)
      destination_root = default_global_destination(target)

      is_update = Dir.exist?(destination_root)

      puts "Target platform: #{platform_label(platform)}"
      puts "Install location: #{destination_root}"
      puts

      if is_update && !force
        puts "⚠️  Configuration already exists at #{destination_root}"
        unless ask_yes_no('Overwrite?')
          puts "\nInstallation cancelled."
          return
        end
      end

      puts 'Installing global configuration...'
      puts

      build_and_deploy_target(
        target: target,
        destination_root: destination_root,
        mode: 'init',
        project_level: false
      )

      puts(
        "✅ Success! #{platform_label(platform)} global configuration has been " \
          "#{is_update ? 'updated' : 'installed'}."
      )
      puts
      puts "Configuration location: #{destination_root}"
      puts

      # Install pre-session-end hook for Claude Code
      if target == 'claude-code'
        puts 'Installing session management hook...'
        install_pre_session_end_hook(destination_root: destination_root, force: force)
        puts
      end

      # Check and suggest optional integrations
      check_and_suggest_integrations(platform) unless @skip_integrations

      puts 'Next steps:'
      puts "1. Review and customize #{File.join(destination_root,
                                                config_entrypoint(target))}"
      puts "2. In your project directory, run: vibe switch --platform #{platform}"
      puts
    end

    # Detect modern CLI tools and ask user if they want to enable recommendations
    # @param target [String] Target platform
    # @return [Boolean] Whether tools were enabled
    def detect_and_enable_modern_cli_tools(target)
      puts "\n🔍 Detecting modern CLI tools..."

      detected = detect_modern_cli_tools
      available = detected.select { |t| t[:available] }
      unavailable = detected.reject { |t| t[:available] }

      # Show detection results
      available.each do |tool|
        puts "   Checking #{tool[:modern]}... ✅ found at #{tool[:path]}"
      end

      unavailable.each do |tool|
        puts "   Checking #{tool[:modern]}... ❌ not found"
      end

      puts "\n📊 Found #{available.size} of #{detected.size} modern CLI tools"
      puts

      # Ask user if they want to enable
      if available.empty?
        puts "ℹ️  No modern CLI tools detected. Skipping tool recommendations."
        return false
      end

      puts "📝 Generate tool recommendations for AI?"
      puts "   This will create TOOLS.md and help AI use modern tools automatically."
      print '[Y/n] '
      response = $stdin.gets
      return false if response.nil?

      response.chomp.downcase != 'n'
    end

    # Enable modern CLI tools for all installed platforms
    # @return [void]
    def enable_modern_cli_tools_for_all
      %w[claude-code opencode].each do |target|
        destination = default_global_destination(target)
        next unless Dir.exist?(destination)

        puts "Enabling modern CLI tools for #{platform_label(target)}..."
        build_and_deploy_target(
          target: target,
          destination_root: destination,
          mode: 'tools-enable',
          project_level: false
        )
        puts "  ✅ Updated #{target}"
      end
    end

    # Disable modern CLI tools for all installed platforms
    # @return [void]
    def disable_modern_cli_tools_for_all
      %w[claude-code opencode].each do |target|
        destination = default_global_destination(target)
        next unless Dir.exist?(destination)

        tools_md = File.join(destination, 'TOOLS.md')
        if File.exist?(tools_md)
          FileUtils.rm(tools_md)
          puts "  ✅ Removed TOOLS.md from #{target}"
        end
      end
    end

    # Refresh modern CLI tools documentation for all platforms
    # @return [void]
    def refresh_modern_cli_tools_docs
      %w[claude-code opencode].each do |target|
        destination = default_global_destination(target)
        next unless Dir.exist?(destination)

        # Rebuild with current tool detection
        build_and_deploy_target(
          target: target,
          destination_root: destination,
          mode: 'doctor',
          project_level: false
        )
      end
    end

    # Show modern CLI tools status
    # @return [void]
    def show_modern_cli_tools_status
      puts "\n🔧 Modern CLI Tools Status"
      puts '=' * 40
      detected = detect_modern_cli_tools
      detected.each do |tool|
        icon = tool[:available] ? '✅' : '❌'
        puts "  #{icon} #{tool[:modern].to_s.ljust(10)} (#{tool[:traditional]})"
      end
      puts
      available_count = detected.count { |t| t[:available] }
      puts "  #{available_count}/#{detected.size} tools available"
    end
  end
end
