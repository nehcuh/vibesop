# frozen_string_literal: true

require "json"
require "yaml"

module Vibe
  # Initialization and setup support for external integrations.
  #
  # Host requirements:
  #   @repo_root [String] — absolute path to the workflow repository root
  module InitSupport
    # Main initialization flow
    def run_init(verify_only: false)
      puts "\n🚀 Claude Code Workflow Initialization"
      puts "=" * 50
      puts

      check_environment

      if verify_only
        verify_integrations
      else
        setup_integrations
      end
    end

    private

    def check_environment
      puts "Checking your environment..."
      puts

      # Check Claude Code
      claude_dir = File.expand_path("~/.claude")
      if Dir.exist?(claude_dir)
        puts "✓ Claude Code detected at ~/.claude"
      else
        puts "⚠ Claude Code directory not found at ~/.claude"
        puts "  This workflow is designed for Claude Code."
        puts
      end

      # Detect current target (if in a repo with .vibe-target.json)
      if File.exist?(".vibe-target.json")
        target_info = JSON.parse(File.read(".vibe-target.json"))
        puts "✓ Current target: #{target_info['target']}"
      end

      puts
    end

    def setup_integrations
      puts "Checking external integrations..."
      puts

      integrations = [
        { name: "superpowers", label: "Superpowers Skill Pack", order: 1 },
        { name: "rtk", label: "RTK (Token Optimizer)", order: 2 }
      ]

      integrations.each do |integration|
        setup_integration(integration[:name], integration[:label], integration[:order], integrations.size)
      end

      puts
      puts "Configuration Summary"
      puts "=" * 50
      puts

      display_summary

      puts
      puts "Next steps:"
      if missing_integrations.any?
        puts "1. Complete the installation steps above"
        puts "2. Run: bin/vibe init --verify"
      else
        puts "1. Run: bin/vibe init --verify"
      end
      puts "2. Start using: claude"
      puts
      puts "For more information: docs/integrations.md"
      puts
    end

    def setup_integration(name, label, order, total)
      puts "[#{order}/#{total}] #{label}"

      config = load_integration_config(name)
      unless config
        puts "   ⚠ Configuration not found"
        puts
        return
      end

      status = send("detect_#{name}")

      if status == :not_installed
        puts "   Status: Not installed"
        puts
        display_integration_description(config)
        puts

        if ask_yes_no("   Would you like to install #{label}?")
          install_integration(name, config)
        else
          puts "   Skipped."
        end
      else
        puts "   Status: Already installed (#{status})"
      end

      puts
    end

    def display_integration_description(config)
      puts "   #{config['description']}"
      puts

      if config['type'] == 'skill_pack' && config['skills']
        puts "   Skills provided:"
        config['skills'].first(3).each do |skill|
          puts "   - #{skill['id']}: #{skill['intent']}"
        end
        if config['skills'].size > 3
          puts "   - ... and #{config['skills'].size - 3} more"
        end
      elsif config['benefits']
        puts "   Benefits:"
        config['benefits'].first(3).each do |benefit|
          puts "   - #{benefit}"
        end
      end
    end

    def install_integration(name, config)
      case name
      when "superpowers"
        install_superpowers(config)
      when "rtk"
        install_rtk(config)
      else
        puts "   ⚠ Installation not implemented for #{name}"
      end
    end

    def install_superpowers(config)
      puts
      puts "   Installation method:"
      puts "   1) Claude Code plugin (recommended)"
      puts "   2) Manual clone and symlink"
      puts

      choice = ask_choice("   Choose [1-2]", ["1", "2"])

      case choice
      when "1"
        install_superpowers_plugin(config)
      when "2"
        install_superpowers_manual(config)
      end
    end

    def install_superpowers_plugin(config)
      puts
      puts "   ℹ️  Run these commands in your Claude Code session:"
      puts

      commands = config.dig("installation_methods", "claude-code", "commands") || []
      commands.each do |cmd|
        puts "      #{cmd}"
      end

      puts
      puts "   After installation, run: bin/vibe init --verify"
    end

    def install_superpowers_manual(config)
      puts
      puts "   Manual installation steps:"
      puts

      steps = config.dig("installation_methods", "manual", "steps") || []
      steps.each_with_index do |step, i|
        puts "   #{i + 1}. #{step}"
      end

      puts
      puts "   After installation, run: bin/vibe init --verify"
    end

    def install_rtk(config)
      puts
      puts "   Installation method:"
      puts "   1) Homebrew (macOS/Linux)"
      puts "   2) Install script"
      puts "   3) Cargo"
      puts

      choice = ask_choice("   Choose [1-3]", ["1", "2", "3"])

      case choice
      when "1"
        install_rtk_homebrew
      when "2"
        install_rtk_script
      when "3"
        install_rtk_cargo
      end
    end

    def install_rtk_homebrew
      puts
      if system("which brew > /dev/null 2>&1")
        if install_rtk_via_homebrew
          puts "   ✓ RTK installed successfully"
          configure_rtk_after_install
        else
          puts "   ✗ Installation failed"
        end
      else
        puts "   ✗ Homebrew not found. Please install Homebrew first or choose another method."
      end
    end

    def install_rtk_script
      puts
      if install_rtk_via_script
        puts "   ✓ RTK installed successfully"
        configure_rtk_after_install
      else
        puts "   ✗ Installation failed"
      end
    end

    def install_rtk_cargo
      puts
      if system("which cargo > /dev/null 2>&1")
        puts "   Installing RTK via Cargo..."
        if system("cargo install --git https://github.com/rtk-ai/rtk")
          puts "   ✓ RTK installed successfully"
          configure_rtk_after_install
        else
          puts "   ✗ Installation failed"
        end
      else
        puts "   ✗ Cargo not found. Please install Rust toolchain first or choose another method."
      end
    end

    def configure_rtk_after_install
      puts
      if ask_yes_no("   Configure RTK hook in ~/.claude/settings.json?")
        if configure_rtk_hook
          puts "   ✓ Hook configured successfully"
        else
          puts "   ✗ Hook configuration failed"
          puts "   You can manually run: rtk init --global"
        end
      else
        puts "   Skipped hook configuration."
        puts "   You can manually run: rtk init --global"
      end
    end

    def verify_integrations
      puts "Verifying integrations..."
      puts

      status = integration_status

      status.each do |name, info|
        verify_integration_display(name, info)
      end

      puts
      if all_integrations_installed?
        puts "All integrations verified successfully! 🎉"
      else
        puts "Some integrations are not installed."
        puts "Run: bin/vibe init (without --verify) to install them."
      end
      puts
    end

    def verify_integration_display(name, info)
      label = case name
              when :superpowers then "Superpowers"
              when :rtk then "RTK"
              else name.to_s.capitalize
              end

      if info[:installed]
        puts "[✓] #{label}"
        case name
        when :superpowers
          puts "    Location: #{info[:location]}"
          puts "    Skills detected: #{info[:skills_count]}"
        when :rtk
          puts "    Binary: #{info[:binary]}"
          puts "    Version: #{info[:version]}"
          puts "    Hook: #{info[:hook_configured] ? 'Configured' : 'Not configured'}"
        end
        puts "    Status: Ready"
      else
        puts "[✗] #{label}"
        puts "    Status: Not installed"
      end
      puts
    end

    def display_summary
      status = integration_status

      status.each do |name, info|
        label = case name
                when :superpowers then "Superpowers"
                when :rtk then "RTK"
                else name.to_s.capitalize
                end

        if info[:installed]
          puts "✓ #{label}: Installed"
        else
          puts "⚠ #{label}: Installation instructions provided"
        end
      end
    end

    # --- User Input Helpers ---

    def ask_yes_no(prompt, default: true)
      suffix = default ? "[Y/n]" : "[y/N]"
      print "#{prompt} #{suffix}: "
      response = $stdin.gets.strip.downcase

      return default if response.empty?
      response.start_with?("y")
    end

    def ask_choice(prompt, valid_choices)
      loop do
        print "#{prompt}: "
        choice = $stdin.gets.strip

        return choice if valid_choices.include?(choice)

        puts "   Invalid choice. Please choose from: #{valid_choices.join(', ')}"
      end
    end
  end
end
