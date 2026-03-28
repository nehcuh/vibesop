# frozen_string_literal: true

require 'fileutils'
require 'open3'
require 'timeout'
require 'rbconfig'
require_relative 'platform_utils'
require_relative 'defaults'

module Vibe
  # Installer for the gstack skill pack (clones repo and sets up skills directory).
  module GstackInstaller
    include PlatformUtils

    GSTACK_REPO_URLS = [
      'https://github.com/garrytan/gstack.git',
      'https://gitee.com/mirrors/gstack.git' # China mirror
    ].freeze

    GSTACK_PLATFORM_PATHS = {
      'unified' => '~/.config/skills/gstack' # 统一存储位置（优先）
    }.freeze

    # 各平台软链接配置
    # Symlink naming format: {repo}-{skill} (e.g., gstack-autoplan)
    GSTACK_PLATFORM_SYMLINK_PATHS = {
      'claude-code' => '~/.config/claude/skills',
      'opencode' => '~/.config/opencode/skills'
    }.freeze
    GSTACK_REPO_NAME = 'gstack'

    CLONE_TIMEOUT = Defaults::CLONE_TIMEOUT
    MAX_RETRIES = 3

    def self.install_gstack(_platform = nil)
      # 始终使用统一存储位置，然后通过软链接共享
      target_dir = File.expand_path(GSTACK_PLATFORM_PATHS['unified'])

      unless system('git', '--version', out: File::NULL, err: File::NULL)
        puts
        puts '   ❌ Git is not installed. Please install Git first.'
        return false
      end

      puts
      puts '   Installing gstack Skill Pack...'

      # 检查统一位置是否已安装
      if Dir.exist?(target_dir) && gstack_markers_present?(target_dir)
        puts "   ✓ gstack already installed at #{target_dir}"
        create_platform_symlinks(target_dir)
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

      create_platform_symlinks(target_dir)
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

      # 预检查 Bun 环境
      bun_installed = check_bun_installed
      unless bun_installed
        puts
        puts '   ⚠️  Bun is not installed.'
        puts '   gstack skills (review, ship, etc.) will work fine without Bun.'
        puts '   However, browser-based skills (/browse, /qa) require Bun v1.0+.'
        puts
        puts '   To install Bun:'
        puts '   • macOS/Linux: curl -fsSL https://bun.sh/install | bash'
        puts '   • Windows: winget install Oven-sh.Bun'
        puts '   • Or visit: https://bun.sh'
        puts
        puts "   After installing Bun, run: cd #{target_dir} && ./setup"
        puts
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
      unified_dir = File.expand_path(GSTACK_PLATFORM_PATHS['unified'])
      issues = []

      # 验证统一存储位置
      return { success: false, issues: ["gstack not installed at #{unified_dir}"] } unless Dir.exist?(unified_dir)

      %w[SKILL.md VERSION setup].each do |marker|
        issues << "Missing marker file: #{marker}" unless File.exist?(File.join(unified_dir, marker))
      end

      version = nil
      version_file = File.join(unified_dir, 'VERSION')
      version = File.read(version_file).strip if File.exist?(version_file)

      # 统计技能数量
      skill_entries = Dir.children(unified_dir).select do |entry|
        full_path = File.join(unified_dir, entry)
        File.directory?(full_path) && File.exist?(File.join(full_path, 'SKILL.md'))
      end
      skills_count = skill_entries.size

      browse_ready = File.exist?(File.join(unified_dir, 'browse', 'dist', 'browse'))

      # 验证指定平台的软链接
      platform_links = {}
      if platform && platform != 'unified'
        target_dir = File.expand_path(GSTACK_PLATFORM_SYMLINK_PATHS[platform])
        linked_count = 0

        if Dir.exist?(target_dir)
          skill_entries.each do |entry|
            link_name = "#{GSTACK_REPO_NAME}-#{entry}"
            link_path = File.join(target_dir, link_name)
            source_path = File.join(unified_dir, entry)

            if File.symlink?(link_path) && File.readlink(link_path) == source_path
              linked_count += 1
            else
              issues << "Missing or incorrect skill link for: #{link_name}"
            end
          end
        else
          issues << "Platform directory not found: #{target_dir}"
        end

        platform_links[platform] = { linked_count: linked_count, total: skills_count }
      end

      {
        success: issues.empty?,
        location: unified_dir,
        version: version,
        skills_count: skills_count,
        browse_ready: browse_ready,
        platform_links: platform_links,
        issues: issues
      }
    end

    def self.uninstall_gstack(_platform = nil)
      unified_dir = File.expand_path(GSTACK_PLATFORM_PATHS['unified'])

      # 清理各平台的软链接
      GSTACK_PLATFORM_SYMLINK_PATHS.each do |platform, target_dir|
        target_path = File.expand_path(target_dir)
        next unless Dir.exist?(target_path)

        puts "  Cleaning #{platform} symlinks..."
        Dir.children(target_path).each do |entry|
          link_path = File.join(target_path, entry)
          # 只删除指向 gstack 的软链接
          if File.symlink?(link_path) && File.readlink(link_path).start_with?(unified_dir)
            FileUtils.rm(link_path)
            puts "    Removed: #{entry}"
          end
        end
      end

      # 删除统一存储位置
      if Dir.exist?(unified_dir)
        puts "  Removing: #{unified_dir}"
        FileUtils.rm_rf(unified_dir)
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

    # 检查 Bun 是否已安装（v1.0+）
    def self.check_bun_installed
      stdout, _stderr, status = Open3.capture3('bun', '--version')
      return false unless status.success?

      version = stdout.strip
      return false if version.nil? || version.empty?

      # 解析版本号，确保 >= 1.0.0
      begin
        major = version.to_s.match(/v?(\d+)\./)&.captures&.first&.to_i
        major && major >= 1
      rescue StandardError
        false
      end
    end

    # 为各平台创建软链接到统一存储位置
    # 为每个子技能创建单独的软链接，命名格式: gstack-{skill}
    def self.create_platform_symlinks(source_dir)
      puts
      puts '   Creating platform symlinks...'

      # 获取所有子技能目录
      skill_entries = Dir.children(source_dir).select do |entry|
        full_path = File.join(source_dir, entry)
        File.directory?(full_path) && File.exist?(File.join(full_path, 'SKILL.md'))
      end

      if skill_entries.empty?
        puts '   ⚠️  No skills found in gstack directory'
        return
      end

      # 为每个平台创建软链接
      GSTACK_PLATFORM_SYMLINK_PATHS.each do |platform, target_dir|
        target_path = File.expand_path(target_dir)
        FileUtils.mkdir_p(target_path) unless Dir.exist?(target_path)

        created = 0
        skipped = 0

        skill_entries.each do |entry|
          source_path = File.join(source_dir, entry)
          # 使用命名格式: {repo}-{skill} (例如: gstack-autoplan)
          link_name = "#{GSTACK_REPO_NAME}-#{entry}"
          link_path = File.join(target_path, link_name)

          # 检查是否已经正确链接
          if File.symlink?(link_path) && File.readlink(link_path) == source_path
            skipped += 1
            next
          end

          # 如果存在但不是软链接，跳过并警告
          if File.exist?(link_path) && !File.symlink?(link_path)
            puts "   ⚠️  Skipping #{link_name}: already exists at #{link_path}"
            next
          end

          # 如果存在旧的错误软链接，删除它
          FileUtils.rm(link_path) if File.symlink?(link_path)

          # 创建软链接
          begin
            FileUtils.ln_s(source_path, link_path)
            created += 1
          rescue StandardError => e
            puts "   ⚠️  Failed to create #{link_name}: #{e.message}"
          end
        end

        puts "   ✓ #{platform}: #{created} created, #{skipped} up to date"
      end
    end
  end
end
