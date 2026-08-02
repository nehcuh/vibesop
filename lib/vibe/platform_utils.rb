# frozen_string_literal: true

require 'rbconfig'

module Vibe
  # Platform-related utility methods.
  #
  # Host requirements:
  #   None (self-contained utilities)
  module PlatformUtils
    # Detect current operating system
    # @return [Symbol] :windows, :macos, :linux, or :unknown
    def detect_os
      case RbConfig::CONFIG['host_os']
      when /mswin|msys|mingw|cygwin|bccwin|wince|emc/
        :windows
      when /darwin|mac os/
        :macos
      when /linux/
        :linux
      else
        :unknown
      end
    end

    # Check if running on Windows
    # @return [Boolean]
    def windows?
      detect_os == :windows
    end

    # Focused on Claude Code and OpenCode
    VALID_TARGETS = %w[claude-code opencode].freeze

    TARGET_ALIAS_MAP = {
      'claude' => 'claude-code',
      'claude-code' => 'claude-code',
      'opencode' => 'opencode'
    }.freeze

    # Normalize platform name to internal target name.
    # Handles aliases, underscores, and validates against known targets.
    # @param platform [String, nil] Platform name (e.g., "claude", "claude_code")
    # @param strict [Boolean] If true, raises on unknown platform.
    #   If false, returns input downcased.
    # @return [String] Normalized platform name
    # @raise [Vibe::ValidationError] if strict and platform is unknown
    def normalize_target(platform, strict: false)
      normalized = platform.to_s.downcase.gsub('_', '-')
      resolved = TARGET_ALIAS_MAP[normalized]

      if resolved
        resolved
      elsif strict
        raise Vibe::ValidationError,
              "Unsupported platform: #{platform}. Valid options: " \
              "#{VALID_TARGETS.join(', ')}"
      else
        normalized
      end
    end

    # Get human-readable platform label
    # @param platform [String] Platform name
    # @return [String] Human-readable label
    def platform_label(platform)
      case normalize_target(platform)
      when 'claude-code'
        'Claude Code'
      when 'opencode'
        'OpenCode'
      else
        platform.to_s.capitalize
      end
    end

    # Get default global destination directory for a target
    # @param target [String] Target name
    # @return [String] Absolute path to global config directory
    def default_global_destination(target)
      base_path = if windows?
                    # Windows: Use %USERPROFILE% for config
                    ENV['USERPROFILE'] || ENV['HOME']
                  else
                    # Unix: Use ~ for config
                    ENV['HOME']
                  end

      case target
      when 'claude-code'
        File.join(base_path, '.claude')
      when 'opencode'
        # OpenCode uses XDG config directory per official docs
        # https://github.com/opencode-ai/opencode
        if windows?
          File.join(base_path, '.config', 'opencode')
        else
          File.expand_path('~/.config/opencode')
        end
      else
        File.join(base_path, ".#{target}")
      end
    end

    # Get config entrypoint filename for a target
    # @param target [String] Target name
    # @return [String] Entrypoint filename
    def config_entrypoint(target)
      case target
      when 'claude-code'
        'CLAUDE.md'
      when 'opencode'
        'opencode.json'
      else
        'config.md'
      end
    end

    # Get platform-specific command name
    # @param platform [String] Platform name
    # @return [String] Command name
    def platform_command(platform)
      case normalize_target(platform)
      when 'claude-code' then 'claude'
      else normalize_target(platform)
      end
    end
  end
end
