# frozen_string_literal: true

require 'fileutils'
require 'open3'
require 'timeout'
require 'rbconfig'
require_relative 'platform_utils'

module Vibe
  # Installer for the gstack skill pack (clones repo and sets up skills directory).
  module GstackInstaller
    include PlatformUtils

    GSTACK_REPO_URLS = [
      'https://github.com/garrytan/gstack.git',
      'https://gitee.com/mirrors/gstack.git' # China mirror
    ].freeze

    GSTACK_PLATFORM_PATHS = {
      'claude-code' => '~/.claude/skills/gstack',
      'opencode' => '~/.config/opencode/skills/gstack'
    }.freeze

    CLONE_TIMEOUT = 60
    MAX_RETRIES = 3

    def self.install_gstack(platform = nil)
      platform ||= 'claude-code'

      unless system('git', '--version', out: File::NULL, err: File::NULL)
        puts
        puts '   ❌ Git is not installed. Please install Git first.'
        return false
      end

      puts
      puts '   Installing gstack Skill Pack...'

      target_dir = File.expand_path(
        GSTACK_PLATFORM_PATHS[platform] || GSTACK_PLATFORM_PATHS['claude-code']
      )

      if Dir.exist?(target_dir) && gstack_markers_present?(target_dir)
        puts "   ✓ gstack already installed at #{target_dir}"
        return run_setup(target_dir)
      end

      parent_dir = File.dirname(target_dir)
      FileUtils.mkdir_p(parent_dir) unless Dir.exist?(parent_dir)

      # Remove incomplete install if present
      if Dir.exist?(target_dir) && !gstack_markers_present?(target_dir)
        puts '   ⚠️  Incomplete installation found, removing...'
        FileUtils.rm_rf(target_dir)
      end

      puts
      puts '   Cloning gstack repository...'
      puts "   Target: #{target_dir}"

      success, used_url = clone_from_mirrors(GSTACK_REPO_URLS, target_dir)
      unless success
        puts '   ❌ Failed to clone from all available sources'
        puts
        puts '   Troubleshooting:'
        puts '   - Check your internet connection'
        puts '   - Check if a firewall is blocking Git'
        puts "   - Try manual clone: git clone #{GSTACK_REPO_URLS.first} #{target_dir}"
        return false
      end

      puts "   ✓ Cloned successfully from #{used_url}"

      run_setup(target_dir)
    rescue StandardError => e
      puts "   ❌ Installation failed: #{e.message}"
      puts "   #{e.backtrace.first(5).join("\n   ")}" if ENV['VIBE_DEBUG']
      false
    end

    def self.run_setup(target_dir)
      setup_script = File.join(target_dir, 'setup')

      unless File.exist?(setup_script)
        puts '   ⚠️  setup script not found, skipping post-install'
        puts '   ✅ gstack cloned but /browse may not work without running setup'
        return true
      end

      puts
      puts "   ⚠️  About to execute: #{setup_script}"
      puts(
        "   Source: #{GSTACK_REPO_URLS.first} " \
          '(floating HEAD — not pinned to a tag or SHA)'
      )
      puts '   The setup script installs Bun dependencies and builds the /browse binary.'
      puts "   Review it at: #{setup_script}"
      puts
      puts '   Running gstack setup...'

      _stdout, stderr, status = Open3.capture3('bash', setup_script, chdir: target_dir)

      if status.success?
        puts '   ✅ gstack installed successfully!'
        puts "   Location: #{target_dir}"
      else
        # Setup failure is non-fatal — skills still work, just /browse won't
        puts '   ⚠️  setup completed with warnings (browse skills may not work)'
        puts "   #{stderr.strip}" unless stderr.empty?
        puts '   Other gstack skills (review, ship, etc.) will work fine.'
        puts "   To fix /browse later: cd #{target_dir} && bun install && bun run build"
      end
      true
    end

    def self.verify_installation(platform = nil)
      platform ||= 'claude-code'
      target_dir = File.expand_path(
        GSTACK_PLATFORM_PATHS[platform] || GSTACK_PLATFORM_PATHS['claude-code']
      )

      issues = []

      unless Dir.exist?(target_dir)
        return { success: false, issues: ["gstack not installed at #{target_dir}"] }
      end

      %w[SKILL.md VERSION setup].each do |marker|
        unless File.exist?(File.join(target_dir, marker))
          issues << "Missing marker file: #{marker}"
        end
      end

      version = nil
      version_file = File.join(target_dir, 'VERSION')
      version = File.read(version_file).strip if File.exist?(version_file)

      skills_count = Dir.children(target_dir).count do |entry|
        File.directory?(File.join(target_dir, entry)) &&
          File.exist?(File.join(target_dir, entry, 'SKILL.md'))
      end

      browse_ready = File.exist?(File.join(target_dir, 'browse', 'dist', 'browse'))

      {
        success: issues.empty?,
        location: target_dir,
        version: version,
        skills_count: skills_count,
        browse_ready: browse_ready,
        issues: issues
      }
    end

    def self.uninstall_gstack(_platform = nil)
      GSTACK_PLATFORM_PATHS.each_value do |path|
        expanded = File.expand_path(path)
        if Dir.exist?(expanded)
          puts "  Removing: #{expanded}"
          FileUtils.rm_rf(expanded)
        end
      end
      puts 'gstack uninstalled.'
    end

    # --- Private helpers ---

    def self.clone_from_mirrors(urls, target)
      urls.each_with_index do |url, index|
        puts "   Trying source #{index + 1}/#{urls.size}: #{url}"

        success = clone_with_retry(url, target)
        return [true, url] if success

        puts "   ✗ Failed to clone from #{url}"
        puts
      end

      [false, nil]
    end

    def self.clone_with_retry(url, target)
      attempt = 0

      while attempt < MAX_RETRIES
        attempt += 1

        begin
          Timeout.timeout(CLONE_TIMEOUT) do
            _stdout, stderr, status = Open3.capture3(
              'git', 'clone', '--depth', '1', url, target
            )

            return true if status.success?

            puts "   ⚠️  Attempt #{attempt}/#{MAX_RETRIES} failed"
            puts "   #{stderr.strip}" unless stderr.empty?
            # Clean up failed clone
            FileUtils.rm_rf(target) if Dir.exist?(target)
          end
        rescue Timeout::Error
          puts(
            "   ⚠️  Attempt #{attempt}/#{MAX_RETRIES} timed out " \
              "after #{CLONE_TIMEOUT}s"
          )
          FileUtils.rm_rf(target) if Dir.exist?(target)
        rescue StandardError => e
          puts "   ⚠️  Attempt #{attempt}/#{MAX_RETRIES} error: #{e.message}"
          FileUtils.rm_rf(target) if Dir.exist?(target)
        end

        next unless attempt < MAX_RETRIES

        sleep_time = attempt * 2
        puts "   Retrying in #{sleep_time} seconds..."
        sleep(sleep_time)
      end

      false
    end

    def self.gstack_markers_present?(dir)
      %w[SKILL.md VERSION setup].all? { |f| File.exist?(File.join(dir, f)) }
    end
  end
end
