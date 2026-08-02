# frozen_string_literal: true

require 'fileutils'
require 'json'
require_relative 'platform_utils'
require_relative 'user_interaction'

module Vibe
  # Hook installation logic for Claude Code.
  #
  # Host requirements:
  #   @repo_root [String] — absolute path to the workflow repository root
  #
  # Dependencies:
  #   - Vibe::PlatformUtils — for platform-related utilities
  #   - Vibe::UserInteraction — for user prompts
  module HookInstaller
    include PlatformUtils
    include UserInteraction

    # Install pre-session-end hook for Claude Code
    # @param destination_root [String] Claude Code config directory (e.g., ~/.claude)
    # @param force [Boolean] Force overwrite if hook exists
    # @return [Boolean] true if installed successfully
    def install_pre_session_end_hook(destination_root:, force: false)
      hook_source = File.join(@repo_root, 'hooks', 'pre-session-end.sh')
      hooks_dir = File.join(destination_root, 'hooks')
      hook_dest = File.join(hooks_dir, 'pre-session-end.sh')
      settings_file = File.join(destination_root, 'settings.json')

      # Check if hook source exists
      unless File.exist?(hook_source)
        puts "   ⚠️  Hook script not found at #{hook_source}"
        return false
      end

      # Create hooks directory
      FileUtils.mkdir_p(hooks_dir)

      # Check if hook already exists
      if File.exist?(hook_dest) && !force
        puts "   ℹ️  Hook already installed at #{hook_dest}"
        return true
      end

      # Copy hook script
      FileUtils.cp(hook_source, hook_dest)
      FileUtils.chmod(0o755, hook_dest)

      # Configure in settings.json
      configure_hook_in_settings(settings_file, hook_dest)

      puts '   ✅ Pre-session-end hook installed'
      puts "      Location: #{hook_dest}"
      puts '      Behavior: Prompts to save progress before /exit'
      true
    rescue StandardError => e
      puts "   ❌ Failed to install hook: #{e.message}"
      false
    end

    # Verify if pre-session-end hook is installed
    # @param destination_root [String] Claude Code config directory
    # @return [Hash] Status information
    def verify_pre_session_end_hook(destination_root:)
      hooks_dir = File.join(destination_root, 'hooks')
      hook_path = File.join(hooks_dir, 'pre-session-end.sh')
      settings_file = File.join(destination_root, 'settings.json')

      hook_exists = File.exist?(hook_path)
      hook_executable = hook_exists && File.executable?(hook_path)
      hook_configured = hook_configured_in_settings?(settings_file)

      {
        installed: hook_exists,
        executable: hook_executable,
        configured: hook_configured,
        ready: hook_exists && hook_executable && hook_configured,
        path: hook_path
      }
    end

    private

    # Configure hook in settings.json
    def configure_hook_in_settings(settings_file, hook_path)
      settings = if File.exist?(settings_file)
                   JSON.parse(File.read(settings_file))
                 else
                   {}
                 end

      # Initialize hooks structure if needed
      settings['hooks'] ||= {}

      # Check if Stop hook already configured
      if settings['hooks']['Stop']
        # Check if our hook is already in the list
        existing = settings['hooks']['Stop']
        our_hook = existing.any? do |matcher_group|
          matcher_group['hooks']&.any? do |h|
            h['command']&.include?('pre-session-end.sh')
          end
        end
        return if our_hook # Already configured
      end

      # Add our hook with correct nested structure
      settings['hooks']['Stop'] ||= []
      settings['hooks']['Stop'] << {
        'hooks' => [
          {
            'type' => 'command',
            'command' => hook_path
          }
        ]
      }

      # Write back to settings.json
      File.write(settings_file, JSON.pretty_generate(settings))
    end

    # Check if hook is configured in settings.json
    def hook_configured_in_settings?(settings_file)
      return false unless File.exist?(settings_file)

      settings = JSON.parse(File.read(settings_file))
      hooks = settings.dig('hooks', 'Stop')
      return false unless hooks

      hooks.any? do |matcher_group|
        matcher_group['hooks']&.any? { |h| h['command']&.include?('pre-session-end.sh') }
      end
    rescue JSON::ParserError
      false
    end
  end
end
