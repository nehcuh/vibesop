# frozen_string_literal: true

require 'json'
require 'yaml'
require_relative 'errors'
require_relative 'user_interaction'

module Vibe
  # Memory auto-load configuration for Claude Code and OpenCode.
  #
  # Detects project memory files and configures automatic loading
  # into AI context via platform-specific mechanisms.
  module MemoryAutoload
    include UserInteraction

    MEMORY_FILES = %w[
      memory/session.md
      memory/project-knowledge.md
      memory/overview.md
    ].freeze

    CONFIG_KEY = 'memory_autoload'

    # Check if memory files exist in the given directory
    # @param destination_root [String] Project root to check
    # @return [Hash] Detection result with :found, :files, :missing
    def detect_memory_files(destination_root)
      files = {}
      MEMORY_FILES.each do |rel_path|
        full_path = File.join(destination_root, rel_path)
        files[rel_path] = File.exist?(full_path) if File.exist?(full_path)
      end

      {
        found: files.any?,
        files: files.keys,
        count: files.size,
        missing: MEMORY_FILES - files.keys
      }
    end

    # Interactive prompt for memory auto-load configuration
    # @param detection [Hash] Result from detect_memory_files
    # @param target [String] Target platform (claude-code, opencode)
    # @param destination_root [String] Project root
    # @return [Hash] User's choices: { enabled: bool, platforms: [] }
    def prompt_memory_autoload(detection, _target, destination_root)
      return { enabled: false, platforms: [] } unless detection[:found]
      return { enabled: false, platforms: [] } unless interactive_terminal?

      puts
      puts '📋 检测到项目记忆文件'
      puts '-' * 40
      detection[:files].each do |file|
        size = File.size(File.join(destination_root, file))
        puts "   ✓ #{file} (#{format_bytes(size)})"
      end
      puts
      puts '这些文件包含项目上下文、技术陷阱和进度记录。'
      puts '启用自动加载可以让 AI 在会话开始时自动读取这些记忆。'
      puts

      # Primary question: enable or not
      enabled = ask_yes_no('是否配置自动加载记忆到 AI 上下文？（推荐）')

      unless enabled
        puts '   ℹ️  已跳过记忆自动加载配置'
        puts '      稍后可通过 `vibe memory autoload --enable` 启用'
        return { enabled: false, platforms: [] }
      end

      # Platform selection
      puts
      puts '选择要启用的平台：'
      puts '   [1] 仅 Claude Code（使用 preCommand hook）'
      puts '   [2] 仅 OpenCode（注入到 instructions）'
      puts '   [3] 两者都启用'
      puts '   [0] 取消'

      choice = ask_choice('请输入选项 (0-3)', %w[0 1 2 3])

      platforms = case choice
                  when '1' then ['claude-code']
                  when '2' then ['opencode']
                  when '3' then %w[claude-code opencode]
                  else
                    puts '   ℹ️  已取消'
                    return { enabled: false, platforms: [] }
                  end

      puts "   ✅ 将为 #{platforms.join(', ')} 配置记忆自动加载"

      { enabled: true, platforms: platforms }
    end

    # Configure memory auto-load for the selected platforms
    # @param config [Hash] User's choices from prompt_memory_autoload
    # @param destination_root [String] Project root
    # @param target [String] Current target being applied
    def configure_memory_autoload(config, destination_root, _target)
      return unless config[:enabled]

      # Save configuration to .vibe/config.yaml
      save_autoload_config(destination_root, config)

      # Apply platform-specific configurations
      config[:platforms].each do |platform|
        case platform
        when 'claude-code'
          configure_claude_autoload(destination_root)
        when 'opencode'
          configure_opencode_autoload(destination_root)
        end
      end

      puts '   ✅ 记忆自动加载配置完成'
    end

    # Check if auto-load is already configured
    # @param destination_root [String] Project root
    # @return [Hash, nil] Existing config or nil
    def existing_autoload_config(destination_root)
      config_path = File.join(destination_root, '.vibe', 'config.yaml')
      return nil unless File.exist?(config_path)

      config = YAML.safe_load(File.read(config_path), permitted_classes: [Date, Time]) || {}
      config[CONFIG_KEY]
    rescue StandardError
      nil
    end

    private

    def claude_settings_path
      # Use ENV['HOME'] directly to allow test isolation via ENV override
      File.join(ENV['HOME'] || Dir.home, '.claude', 'settings.json')
    end

    def interactive_terminal?
      $stdin.respond_to?(:tty?) && $stdin.tty?
    end

    def format_bytes(bytes)
      if bytes < 1024
        "#{bytes}B"
      elsif bytes < 1024 * 1024
        "#{(bytes / 1024.0).round(1)}KB"
      else
        "#{(bytes / (1024.0 * 1024)).round(1)}MB"
      end
    end

    def save_autoload_config(destination_root, config)
      config_dir = File.join(destination_root, '.vibe')
      FileUtils.mkdir_p(config_dir)

      config_path = File.join(config_dir, 'config.yaml')
      existing = if File.exist?(config_path)
                   YAML.safe_load(File.read(config_path), permitted_classes: [Date, Time]) || {}
                 else
                   {}
                 end

      existing[CONFIG_KEY] = {
        'enabled' => config[:enabled],
        'platforms' => config[:platforms],
        'configured_at' => Time.now.iso8601
      }

      File.write(config_path, YAML.dump(existing))
    end

    def configure_claude_autoload(destination_root)
      # Claude Code uses preCommand hook in ~/.claude/settings.json
      # Use Ruby script for cross-platform compatibility instead of shell commands
      settings_path = claude_settings_path

      settings = if File.exist?(settings_path)
                   JSON.parse(File.read(settings_path))
                 else
                   {}
                 end

      settings['hooks'] ||= {}
      settings['hooks']['preCommand'] ||= []

      # Use Ruby one-liner for cross-platform file reading
      # Limit output to control token usage (~2000 tokens max)
      ruby_script = <<~RUBY.gsub(/\n/, ' ')
        ruby -e '
          files = {
            "session" => ["memory/session.md", 50],
            "knowledge" => ["memory/project-knowledge.md", 80],
            "overview" => ["memory/overview.md", 100]
          };
          files.each do |name, (path, lines)|
            next unless File.exist?(path);
            content = File.readlines(path).first(lines).join;
            puts "=== \#{name.upcase} ===";
            puts content;
            puts
          end
        '
      RUBY

      memory_command = "cd \"#{destination_root}\" && #{ruby_script.strip}"

      # Remove existing memory commands to avoid duplicates
      settings['hooks']['preCommand'].delete_if do |cmd|
        cmd_str = cmd.is_a?(Hash) ? cmd['command'] : cmd
        cmd_str.include?('memory/session.md') ||
          cmd_str.include?('memory/project-knowledge.md') ||
          cmd_str.include?('memory/overview.md') ||
          cmd_str.include?('memory_autoload')
      end

      # Add new command (as object with 'command' key, not string)
      settings['hooks']['preCommand'] << { 'command' => memory_command }

      FileUtils.mkdir_p(File.dirname(settings_path))
      File.write(settings_path, JSON.pretty_generate(settings))

      puts "   ✓ Claude Code: 已更新 #{settings_path}"
    rescue StandardError => e
      puts "   ⚠️  Claude Code 配置失败: #{e.message}"
    end

    def configure_opencode_autoload(destination_root)
      # OpenCode: generate memory-context.md and inject to opencode.json
      generate_opencode_memory_context(destination_root)

      # Update opencode.json instructions if it exists
      opencode_json_path = File.join(destination_root, 'opencode.json')
      update_opencode_json_instructions(opencode_json_path) if File.exist?(opencode_json_path)

      # Also check global opencode config
      global_opencode_json = File.join(ENV['HOME'] || Dir.home, '.config', 'opencode', 'opencode.json')
      update_opencode_json_instructions(global_opencode_json) if File.exist?(global_opencode_json)

      puts '   ✓ OpenCode: 已生成 .vibe/opencode/memory-context.md'
    rescue StandardError => e
      puts "   ⚠️  OpenCode 配置失败: #{e.message}"
    end

    def generate_opencode_memory_context(destination_root)
      opencode_dir = File.join(destination_root, '.vibe', 'opencode')
      FileUtils.mkdir_p(opencode_dir)

      content = generate_memory_context_content(destination_root)

      File.write(File.join(opencode_dir, 'memory-context.md'), content)
    end

    def generate_memory_context_content(destination_root)
      lines = ['# Project Memory Context', '']

      MEMORY_FILES.each do |rel_path|
        full_path = File.join(destination_root, rel_path)
        next unless File.exist?(full_path)

        size = File.size(full_path)
        lines << "## #{rel_path} (#{format_bytes(size)})"
        lines << ''

        # Include summary based on file type
        case rel_path
        when 'memory/session.md'
          lines << '_Session log: active tasks, progress, and cross-session state._'
        when 'memory/project-knowledge.md'
          lines << '_Technical pitfalls, reusable patterns, and architecture decisions._'
        when 'memory/overview.md'
          lines << '_High-level goals and project status._'
        end

        lines << ''
        lines << '---'
        lines << ''
      end

      lines.join("\n")
    end

    def update_opencode_json_instructions(opencode_json_path)
      config = JSON.parse(File.read(opencode_json_path))

      config['instructions'] ||= []

      # Add memory-context.md if not present
      memory_instruction = '.vibe/opencode/memory-context.md'
      unless config['instructions'].include?(memory_instruction)
        # Insert after AGENTS.md or at beginning
        idx = config['instructions'].index('AGENTS.md')
        if idx
          config['instructions'].insert(idx + 1, memory_instruction)
        else
          config['instructions'].unshift(memory_instruction)
        end
      end

      File.write(opencode_json_path, JSON.pretty_generate(config))
    end
  end
end
