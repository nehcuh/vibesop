# frozen_string_literal: true

require 'fileutils'
require 'rbconfig'

module Vibe
  # Cross-platform path management for VibeSOP.
  #
  # Provides unified path handling across Windows, macOS, and Linux.
  # Avoids File.expand_path('~') due to P011 (doesn't respect ENV['HOME'] changes).
  #
  # Architecture:
  # - VibeSOP config: ~/.vibe/ (all platforms shared)
  # - Platform-specific data: ~/.vibe/platforms/{platform}/
  # - Target platform configs: ~/.claude/, ~/.opencode/, etc.
  #
  module PlatformPaths
    class << self
      # VibeSOP project root directory (cross-platform)
      #
      # Priority:
      # 1. VIBE_HOME environment variable
      # 2. ~/.vibe/ (Unix) or %USERPROFILE%\.vibe (Windows)
      #
      # @return [String] absolute path to VibeSOP root
      def vibe_root
        @vibe_root ||= begin
          if ENV['VIBE_HOME'] && !ENV['VIBE_HOME'].empty?
            ENV['VIBE_HOME']
          else
            join_home('.vibe')
          end
        end
      end

      # VibeSOP unified config directory
      # @return [String] path to config directory
      def config_dir
        File.join(vibe_root, 'config')
      end

      # VibeSOP unified preference file (shared across all platforms)
      # @return [String] path to skill-preferences.yaml
      def preference_file
        File.join(config_dir, 'skill-preferences.yaml')
      end

      # VibeSOP cache directory
      # @return [String] path to cache directory
      def cache_dir
        File.join(vibe_root, 'cache')
      end

      # Platform-specific data directory (for isolated platform data)
      # @param platform [Symbol] :claude_code, :opencode, :cursor, etc.
      # @return [String] path to platform-specific data directory
      def platform_data_dir(platform)
        normalized_platform = normalize_platform_name(platform)
        File.join(vibe_root, 'platforms', normalized_platform.to_s)
      end

      # Get target platform's config directory (for generating config)
      #
      # Examples:
      #   claude_code → ~/.claude/
      #   opencode   → ~/.opencode/
      #   cursor     → ~/.cursor/
      #
      # @param platform [Symbol] target platform
      # @return [String] path to target platform's config directory
      def target_config_dir(platform)
        case platform.to_sym
        when :claude_code
          join_home('.claude')
        when :opencode
          join_home('.opencode')
        when :cursor
          join_home('.cursor')
        when :vscode
          join_home('.vscode')
        when :warp
          join_home('.warp')
        else
          # Fallback for unknown platforms
          join_home(".#{platform}")
        end
      end

      # Get target platform's CLAUDE.md equivalent file
      # @param platform [Symbol] target platform
      # @return [String, nil] path to main config file, or nil if unknown
      def target_config_file(platform)
        case platform.to_sym
        when :claude_code
          File.join(target_config_dir(platform), 'CLAUDE.md')
        when :opencode
          File.join(target_config_dir(platform), 'config.yaml')
        when :cursor
          File.join(target_config_dir(platform), 'settings.json')
        when :vscode
          File.join(target_config_dir(platform), 'settings.json')
        else
          nil
        end
      end

      # Normalize path separators to forward slashes (for comparison)
      # @param path [String] path to normalize
      # @return [String] path with forward slashes
      def norm_sep(path)
        path.tr('\\', '/')
      end

      # Check if path is a filesystem root
      # @param path [String] path to check
      # @return [Boolean] true if path is a root
      def root_path?(path)
        return true if path == '/'

        # Windows root: C:\ or C:/ format
        # Match: single letter, colon, optional single slash (forward or back)
        path.match?(/\A[A-Za-z]:[\\\/]?\z/)
      end

      # Ensure all VibeSOP directories exist
      # @return [void]
      def ensure_directories_exist
        dirs = [
          config_dir,
          cache_dir,
          File.join(vibe_root, 'platforms')
        ]

        dirs.each do |dir|
          FileUtils.mkdir_p(dir) unless File.exist?(dir)
        end
      end

      # Get platform name as symbol
      # @param platform [String, Symbol] platform identifier
      # @return [Symbol] normalized platform name
      def normalize_platform_name(platform)
        platform_str = platform.to_s
        case platform_str
        when 'claude_code', 'claude-code', 'claude', 'claudecode'
          :claude_code
        when 'opencode'
          :opencode
        when 'cursor'
          :cursor
        when 'vscode'
          :vscode
        when 'warp'
          :warp
        else
          platform.to_sym
        end
      end

      # Detect current host OS
      # @return [Symbol] :windows, :macos, or :linux
      def host_os
        @host_os ||= begin
          os = RbConfig::CONFIG['host_os']
          if os =~ /mswin|msys|mingw|cygwin/
            :windows
          elsif os =~ /darwin/
            :macos
          else
            :linux
          end
        end
      end

      # Check if running on Windows
      # @return [Boolean] true if Windows
      def windows?
        host_os == :windows
      end

      private

      # Join paths with home directory (avoids File.expand_path('~') issue - P011)
      #
      # Uses ENV['HOME'] or ENV['USERPROFILE'] or Dir.home as fallback
      #
      # @param paths [Array<String>] path components to join
      # @return [String] absolute path
      def join_home(*paths)
        home = detect_home_directory
        File.join(home, *paths)
      end

      # Detect home directory (cross-platform)
      #
      # Priority:
      # 1. ENV['HOME'] (Unix, including Git Bash on Windows)
      # 2. ENV['USERPROFILE'] (Windows cmd.exe)
      # 3. Dir.home (Ruby fallback)
      #
      # @return [String] home directory path
      def detect_home_directory
        ENV['HOME'] || ENV['USERPROFILE'] || Dir.home
      end
    end
  end
end
