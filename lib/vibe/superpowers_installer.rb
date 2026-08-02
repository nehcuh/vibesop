# frozen_string_literal: true

require 'fileutils'
require 'open3'
require 'timeout'
require 'rbconfig'
require_relative 'user_interaction'
require_relative 'platform_utils'

module Vibe
  # Installer for the Superpowers skill pack (clones repo and links skills).
  module SuperpowersInstaller
    include UserInteraction
    include PlatformUtils

    # Repository URLs with fallback mirrors
    SUPERPOWERS_REPO_URLS = [
      'https://github.com/obra/superpowers.git',
      'https://gitee.com/mirrors/superpowers.git' # China mirror
    ].freeze
    SUPERPOWERS_DEFAULT_INSTALL_DIR = File.expand_path('~/.config/skills/superpowers')

    # Clone configuration
    CLONE_TIMEOUT = 60 # seconds
    MAX_RETRIES = 3

    # target_dir: the skills directory where individual skill symlinks are created.
    # Each entry in source_subdir gets its own symlink inside target_dir.
    SUPERPOWERS_PLATFORM_SYMLINK_PATHS = {
      'claude-code' => {
        source_subdir: 'skills',
        target_dir: '~/.claude/skills'
      },
      'opencode' => {
        source_subdir: 'skills',
        target_dir: '~/.config/opencode/skills'
      }
    }.freeze

    def self.install_superpowers(platform = nil)
      install_superpowers_for_platform(platform || 'claude-code')
    end

    def self.install_superpowers_for_platform(platform)
      unless system('git', '--version', out: File::NULL, err: File::NULL)
        puts
        puts '   ❌ Git is not installed. Please install Git first.'
        return false
      end

      puts
      puts '   Installing Superpowers Skill Pack...'

      shared_dir = SUPERPOWERS_DEFAULT_INSTALL_DIR
      source_skills_dir = File.join(shared_dir, 'skills')

      unless Dir.exist?(shared_dir)
        puts "   Creating directory: #{shared_dir}"
        FileUtils.mkdir_p(shared_dir)
      end

      if Dir.exist?(source_skills_dir)
        puts "   ✓ Superpowers already cloned at #{shared_dir}"

        unless Dir.exist?(source_skills_dir)
          puts '   ❌ Skills directory not found in cloned repository'
          return false
        end
      else
        puts
        puts '   Cloning Superpowers repository...'
        puts "   Target: #{shared_dir}"

        success, used_url = clone_from_mirrors(SUPERPOWERS_REPO_URLS, shared_dir)
        unless success
          puts '   ❌ Failed to clone from all available sources'
          puts
          puts '   Troubleshooting:'
          puts '   - Check your internet connection'
          puts '   - Check if a firewall is blocking Git'
          puts '   - Try manual clone: git clone ' \
               "#{SUPERPOWERS_REPO_URLS.first} #{shared_dir}"
          return false
        end

        puts "   ✓ Cloned successfully from #{used_url}"
      end

      symlink_config = SUPERPOWERS_PLATFORM_SYMLINK_PATHS[platform]
      unless symlink_config
        supported = SUPERPOWERS_PLATFORM_SYMLINK_PATHS.keys.join(', ')
        puts "   ⚠️  Platform '#{platform}' does not support automatic " \
             'symlink installation'
        puts "   Supported platforms: #{supported}"
        puts
        puts '   Manual installation:'
        puts "   1. Clone: git clone #{SUPERPOWERS_REPO_URLS.first} #{shared_dir}"
        puts "   2. Symlink each skill directory into your platform's skills directory"
        return false
      end

      target_dir = File.expand_path(symlink_config[:target_dir])

      unless Dir.exist?(target_dir)
        puts "   Creating platform skills directory: #{target_dir}"
        FileUtils.mkdir_p(target_dir)
      end

      skill_entries = Dir.children(source_skills_dir).sort
      if skill_entries.empty?
        puts "   ❌ No skills found in #{source_skills_dir}"
        return false
      end

      puts
      puts "   Creating symlinks in #{target_dir}..."

      created = 0
      skipped = 0

      skill_entries.each do |entry|
        source_path = File.join(source_skills_dir, entry)
        link_path = File.join(target_dir, entry)

        if skill_linked?(link_path, source_path)
          skipped += 1
          next
        elsif File.exist?(link_path) || File.symlink?(link_path)
          puts "   ⚠️  Skipping #{entry}: already exists at #{link_path}"
          next
        end

        create_skill_link(source_path, link_path)
        puts "   ✓ #{entry}"
        created += 1
      end

      puts
      puts '   ✅ Superpowers installed successfully!'
      puts "   Location: #{target_dir}"
      puts "   Skills linked: #{created} new, #{skipped} already up to date"

      true
    rescue StandardError => e
      puts "   ❌ Installation failed: #{e.message}"
      puts "   #{e.backtrace.first(5).join("\n   ")}" if ENV['VIBE_DEBUG']
      false
    end

    def self.verify_installation(platform)
      symlink_config = SUPERPOWERS_PLATFORM_SYMLINK_PATHS[platform]

      unless symlink_config
        return {
          success: false,
          issues: ["Platform '#{platform}' does not support automatic installation"]
        }
      end

      issues = []
      shared_dir = SUPERPOWERS_DEFAULT_INSTALL_DIR
      source_skills_dir = File.join(shared_dir, 'skills')
      target_dir = File.expand_path(symlink_config[:target_dir])

      issues << "Superpowers not cloned to #{shared_dir}" unless Dir.exist?(shared_dir)

      unless Dir.exist?(source_skills_dir)
        issues << "Skills directory not found in #{shared_dir}"
      end

      skills_count = 0
      linked_count = 0

      if Dir.exist?(source_skills_dir)
        skill_entries = Dir.children(source_skills_dir)
        skills_count = skill_entries.size

        skill_entries.each do |entry|
          source_path = File.join(source_skills_dir, entry)
          link_path = File.join(target_dir, entry)

          unless skill_linked?(link_path, source_path)
            issues << "Missing or incorrect skill link for: #{entry}"
          end
          linked_count += 1 if skill_linked?(link_path, source_path)
        end
      end

      {
        success: issues.empty?,
        location: target_dir,
        skills_count: skills_count,
        linked_count: linked_count,
        issues: issues
      }
    end

    # Try cloning from multiple mirror URLs
    # @param urls [Array<String>] List of repository URLs to try
    # @param target [String] Target directory
    # @return [Array(Boolean, String)] [success, used_url]
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

    # Clone repository with timeout and retry logic
    # @param url [String] Git repository URL
    # @param target [String] Target directory
    # @return [Boolean] true if successful, false otherwise
    def self.clone_with_retry(url, target)
      attempt = 0

      while attempt < MAX_RETRIES
        attempt += 1

        begin
          # Use Timeout to prevent hanging on network issues
          Timeout.timeout(CLONE_TIMEOUT) do
            _stdout, stderr, status = Open3.capture3(
              'git', 'clone', '--depth', '1', url, target
            )

            return true if status.success?

            puts "   ⚠️  Attempt #{attempt}/#{MAX_RETRIES} failed"
            puts "   #{stderr.strip}" unless stderr.empty?
          end
        rescue Timeout::Error
          puts "   ⚠️  Attempt #{attempt}/#{MAX_RETRIES} timed out after " \
               "#{CLONE_TIMEOUT}s"
        rescue StandardError => e
          puts "   ⚠️  Attempt #{attempt}/#{MAX_RETRIES} error: #{e.message}"
        end

        # Wait before retry (except on last attempt)
        next unless attempt < MAX_RETRIES

        sleep_time = attempt * 2 # Progressive backoff: 2s, 4s
        puts "   Retrying in #{sleep_time} seconds..."
        sleep(sleep_time)
      end

      false
    end

    # Cross-platform: create symlink on Unix, copy on Windows
    def self.create_skill_link(source_path, link_path)
      if windows_os?
        if File.directory?(source_path)
          FileUtils.cp_r(source_path,
                         link_path)
        else
          FileUtils.cp(
            source_path, link_path
          )
        end
      else
        FileUtils.ln_s(source_path, link_path)
      end
    end

    # Cross-platform: check symlink on Unix, check existence on Windows
    def self.skill_linked?(link_path, source_path)
      if windows_os?
        File.exist?(link_path)
      else
        File.symlink?(link_path) && File.readlink(link_path) == source_path
      end
    end

    def self.windows_os?
      RbConfig::CONFIG['host_os'] =~ /mswin|msys|mingw|cygwin/i
    end

    def self.uninstall_superpowers
      shared_dir = SUPERPOWERS_DEFAULT_INSTALL_DIR

      if Dir.exist?(shared_dir)
        puts 'Removing Superpowers installation...'

        SUPERPOWERS_PLATFORM_SYMLINK_PATHS.each_value do |config|
          target_dir = File.expand_path(config[:target_dir])
          next unless Dir.exist?(target_dir)

          Dir.children(target_dir).each do |entry|
            link_path = File.join(target_dir, entry)
            if File.symlink?(link_path) && File.readlink(link_path).include?(shared_dir)
              FileUtils.rm(link_path)
              puts "  Removed symlink: #{link_path}"
            elsif File.exist?(link_path) && !File.symlink?(link_path) && windows_os?
              FileUtils.rm_rf(link_path)
              puts "  Removed copy: #{link_path}"
            end
          end
        end

        FileUtils.rm_rf(shared_dir)
        puts "  Removed: #{shared_dir}"
        puts 'Superpowers uninstalled.'
      else
        puts 'Superpowers is not installed.'
      end
    end
  end
end
