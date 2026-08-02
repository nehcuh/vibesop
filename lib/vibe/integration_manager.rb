# frozen_string_literal: true

require_relative 'platform_utils'
require_relative 'user_interaction'
require_relative 'superpowers_installer'
require_relative 'gstack_installer'

module Vibe
  # Orchestrates detection and setup of optional integrations (superpowers, gstack).
  module IntegrationManager
    include PlatformUtils
    include UserInteraction

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
      puts '📦 Optional Integrations'
      puts '=' * 50

      interactive = $stdin.respond_to?(:tty?) && $stdin.tty?

      if missing.include?(:superpowers)
        puts
        puts '⚠️  Superpowers Skill Pack not detected'
        puts '   Superpowers provides advanced workflows like TDD, ' \
             'debugging, and code review.'
        puts
        puts '   Repository: https://github.com/obra/superpowers'
        puts

        if interactive
          if ask_yes_no('Would you like to install Superpowers now?')
            success = install_superpowers_auto(platform)
            if success
              puts '   ✓ Superpowers installed successfully!'
              puts
              verify_superpowers_install(platform)
            else
              puts '   ❌ Installation failed'
            end
          end
        else
          puts '   (Run in an interactive terminal to install automatically)'
        end
      end

      if pending.include?(:superpowers)
        puts
        puts '⚠️  Superpowers is cloned but not linked to this platform'
        puts '   Skills are available at ~/.config/skills/superpowers ' \
             "but not linked for #{platform}."
        puts

        if interactive
          if ask_yes_no('Would you like to link Superpowers skills now?')
            success = install_superpowers_auto(platform)
            if success
              puts '   ✓ Superpowers skills linked successfully!'
              puts
              verify_superpowers_install(platform)
            else
              puts '   ❌ Linking failed'
            end
          end
        else
          puts '   (Run in an interactive terminal to link automatically)'
        end
      end

      if missing.include?(:rtk)
        puts
        puts '⚠️  RTK Token Optimizer not detected'
        puts '   RTK reduces token consumption by 60-90% on common commands.'
        puts
        puts '   To install:'
        puts '   brew install rtk  # or download from https://github.com/runesleo/rtk'
        puts

        if interactive
          should_install_rtk = ask_yes_no(
            'Would you like to install RTK now? (requires Homebrew)'
          )
          if should_install_rtk && install_rtk_interactive
            status = integration_status
            pending << :rtk if status[:rtk][:installed] && !status[:rtk][:ready]
          end
        else
          puts '   (Run in an interactive terminal to install automatically)'
        end
      end

      if pending.include?(:rtk)
        rtk_status = status[:rtk] || integration_status[:rtk]
        if rtk_status[:installed] && !rtk_status[:hook_configured]
          puts
          puts '⚠️  RTK is installed but hook not configured'
          puts '   To enable RTK optimization, run: rtk init --global'
          puts

          if $stdin.respond_to?(:tty?) && $stdin.tty?
            configure_rtk_hook if ask_yes_no('Would you like to configure RTK hook now?')
          else
            puts '   (Run in an interactive terminal to configure automatically)'
          end
        end
      end

      if missing.include?(:gstack)
        puts
        puts '⚠️  gstack Skill Pack not detected'
        puts '   gstack provides a virtual engineering team: product ' \
             'thinking, code review,'
        puts '   browser QA, release automation, and safety guardrails.'
        puts
        puts '   Repository: https://github.com/garrytan/gstack'
        puts

        if interactive
          if ask_yes_no('Would you like to install gstack now?')
            success = install_gstack_auto(platform)
            if success
              puts
              verify_gstack_install(platform)
            else
              puts '   ❌ Installation failed'
            end
          end
        else
          puts '   (Run in an interactive terminal to install automatically)'
          puts '   Manual: git clone https://github.com/garrytan/gstack.git ' \
               '~/.claude/skills/gstack'
          puts '           cd ~/.claude/skills/gstack && ./setup'
        end
      end

      puts
    end

    def check_environment(target_platform = nil)
      current_platform = defined?(@target_platform) ? @target_platform : nil
      platform = target_platform || current_platform

      puts 'Checking your environment...'
      puts

      if platform
        puts "✓ Target platform: #{platform_label(platform)}"
      else
        puts '⚠ No target platform specified'
      end

      claude_dir = File.expand_path('~/.claude')
      if Dir.exist?(claude_dir)
        puts "✓ Claude Code directory found at #{claude_dir}"
      else
        puts "⚠ Claude Code directory not found at #{claude_dir}"
        puts '  This workflow is designed for Claude Code.'
        puts '  Run: bin/vibe init --platform claude-code'
      end

      puts

      marker_file = File.join(Dir.pwd, '.vibe-target.json')
      if File.exist?(marker_file)
        marker = JSON.parse(File.read(marker_file))
        puts "✓ Current target: #{marker['target']}"
      else
        puts '⚠ No target marker found in current directory'
      end

      puts
    end

    private

    def install_superpowers_auto(platform)
      SuperpowersInstaller.install_superpowers(platform)
    end

    def verify_superpowers_install(platform)
      result = SuperpowersInstaller.verify_installation(platform)
      if result[:success]
        puts '   ✓ Verification passed'
        puts "   Location: #{result[:location]}"
        puts "   Skills: #{result[:skills_count]} found"
      else
        puts '   ⚠ Verification issues:'
        result[:issues].each { |issue| puts "     - #{issue}" }
      end
    end

    def install_gstack_auto(platform)
      GstackInstaller.install_gstack(platform)
    end

    def verify_gstack_install(platform)
      result = GstackInstaller.verify_installation(platform)
      if result[:success]
        puts '   ✓ Verification passed'
        puts "   Location: #{result[:location]}"
        puts "   Version: #{result[:version]}"
        puts "   Skills: #{result[:skills_count]} found"
        browser_status = if result[:browse_ready]
                           'Ready'
                         else
                           'Not built (run setup with Bun)'
                         end
        puts "   Browser: #{browser_status}"
      else
        puts '   ⚠ Verification issues:'
        result[:issues].each { |issue| puts "     - #{issue}" }
      end
    end

    def platform_label(platform)
      case platform
      when 'claude-code' then 'Claude Code'
      when 'opencode' then 'OpenCode'
      else
        platform.to_s.split('-').map(&:capitalize).join(' ')
      end
    end
  end
end
