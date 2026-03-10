# frozen_string_literal: true

require_relative "platform_utils"
require_relative "user_interaction"

module Vibe
  # Integration detection and management.
  #
  # Host requirements:
  #   @repo_root [String] — absolute path to the workflow repository root
  #
  # Dependencies:
  #   - Vibe::PlatformUtils — for platform-related utilities
  #   - Vibe::UserInteraction — for user prompts
  #   - Vibe::ExternalTools — for integration detection methods
  module IntegrationManager
    include PlatformUtils
    include UserInteraction

    # Check and suggest optional integrations after installation
    # @param platform [String] Platform name
    def check_and_suggest_integrations(platform)
      @target_platform = platform
      status = integration_status

      missing = []
      pending = []

      status.each do |name, info|
        if !info[:installed]
          missing << name
        elsif !info[:ready]
          pending << name
        end
      end

      return if missing.empty? && pending.empty?

      puts
      puts "📦 Optional Integrations"
      puts "=" * 50

      if missing.include?(:superpowers)
        puts
        puts "⚠️  Superpowers Skill Pack not detected"
        puts "   Superpowers provides advanced workflows like TDD, debugging, and code review."
        puts
        puts "   To install:"
        puts "   1. Visit: https://github.com/anthropics/superpowers"
        puts "   2. Follow installation instructions for #{platform_label(platform)}"
        puts

        if ask_yes_no("Would you like to open the installation page now?")
          open_url("https://github.com/anthropics/superpowers")
        end
      end

      if missing.include?(:rtk)
        puts
        puts "⚠️  RTK Token Optimizer not detected"
        puts "   RTK reduces token consumption by 60-90% on common commands."
        puts
        puts "   To install:"
        puts "   brew install rtk  # or download from https://github.com/runesleo/rtk"
        puts

        if ask_yes_no("Would you like to install RTK now? (requires Homebrew)")
          if install_rtk_interactive
            # Refresh status after installation
            status = integration_status
            pending << :rtk if status[:rtk][:installed] && !status[:rtk][:ready]
          end
        end
      end

      if pending.include?(:rtk)
        rtk_status = status[:rtk] || integration_status[:rtk]
        if rtk_status[:installed] && !rtk_status[:hook_configured]
          puts
          puts "⚠️  RTK is installed but hook not configured"
          puts "   To enable RTK optimization, run: rtk init --global"
          puts

          if ask_yes_no("Would you like to configure RTK hook now?")
            configure_rtk_hook
          end
        end
      end

      puts
    end

    # Check environment and display integration status
    def check_environment
      puts "Checking your environment..."
      puts

      # Show target platform
      if @target_platform
        puts "✓ Target platform: #{platform_label(@target_platform)}"
      else
        puts "⚠ No target platform specified"
      end

      # Check global config directory
      claude_dir = File.expand_path("~/.claude")
      if Dir.exist?(claude_dir)
        puts "✓ Claude Code directory found at #{claude_dir}"
      else
        puts "⚠ Claude Code directory not found at #{claude_dir}"
        puts "  This workflow is designed for Claude Code."
        puts "  Run: bin/vibe init --platform claude-code"
      end

      puts

      # Check current target
      marker_file = File.join(Dir.pwd, ".vibe-target.json")
      if File.exist?(marker_file)
        marker = JSON.parse(File.read(marker_file))
        puts "✓ Current target: #{marker['target']}"
      else
        puts "⚠ No target marker found in current directory"
      end

      puts
    end
  end
end
