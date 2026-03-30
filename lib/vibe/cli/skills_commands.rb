# frozen_string_literal: true

# CLI commands for skill management
# These methods are included in VibeCLI class

require_relative '../skill_manager'
require_relative '../skill_installer'
require_relative '../skill_adapter'
require_relative '../skill_discovery'
require_relative '../skill_registration'

module Vibe
  # CLI commands for skill management, included in VibeCLI.
  module SkillsCommands
    # Main entry point for 'vibe skills' subcommand
    def run_skills_command(argv)
      subcommand = argv.shift

      case subcommand
      when 'check'
        run_skills_check(argv)
      when 'list'
        run_skills_list(argv)
      when 'use'
        run_skills_use(argv)
      when 'adapt'
        run_skills_adapt(argv)
      when 'skip'
        run_skills_skip(argv)
      when 'docs'
        run_skills_docs(argv)
      when 'install'
        run_skills_install(argv)
      when 'discover'
        run_skills_discover(argv)
      when 'register'
        run_skills_register(argv)
      when nil, 'help', '--help', '-h'
        puts skills_usage
      else
        raise Vibe::ValidationError,
              "Unknown skills subcommand: #{subcommand}\n\n#{skills_usage}"
      end
    end

    # vibe skills check - Check for new skills
    def run_skills_check(argv)
      options = parse_skills_check_options(argv)

      manager = SkillManager.new(@repo_root, Dir.pwd)

      if options[:update_timestamp]
        manager.update_check_timestamp
        puts '✓ Updated last check timestamp'
        return
      end

      changes = manager.check_skill_changes

      if changes[:new_skills].empty? && changes[:new_packs].empty?
        puts "\n✓ No new skills found."
        puts
        puts "Your project has #{manager.list_skills[:adapted].length} adapted skills."
        puts "Last checked: #{changes[:last_checked]}"
        puts
        puts "💡 Run 'vibe skills list' to see all adapted skills."
        return
      end

      # Show detection results
      if options[:auto_adapt]
        manager.check_and_prompt(auto_adapt: true)
      else
        manager.check_and_prompt(auto_adapt: false)
      end
    end

    # vibe skills list - List all skills
    def run_skills_list(_argv)
      manager = SkillManager.new(@repo_root, Dir.pwd)
      skills = manager.list_skills

      puts "\n📋 Skill Status"
      puts '=' * 60
      puts

      # Mandatory skills
      mandatory = skills[:adapted].select { |s| s[:mode] == 'mandatory' }
      if mandatory.any?
        puts "🔒 Mandatory Skills (#{mandatory.length}):"
        mandatory.each do |skill|
          puts "  • #{skill[:id]}"
          puts "    Adapted: #{time_ago(skill[:adapted_at])}" if skill[:adapted_at]
        end
        puts
      end

      # Suggest skills
      suggest = skills[:adapted].select { |s| s[:mode] == 'suggest' }
      if suggest.any?
        puts "💡 Suggest Skills (#{suggest.length}):"
        suggest.each do |skill|
          puts "  • #{skill[:id]}"
        end
        puts
      end

      # Not adapted skills
      if skills[:not_adapted].any?
        puts "⏳ Available but Not Adapted (#{skills[:not_adapted].length}):"
        skills[:not_adapted].first(10).each do |skill|
          puts "  • #{skill[:id]}"
        end
        puts "    ... and #{skills[:not_adapted].length - 10} more" if skills[:not_adapted].length > 10
        puts "   Run 'vibe skills check' to adapt these skills"
        puts
      end

      # Skipped skills
      if skills[:skipped].any?
        puts "⏸️  Skipped Skills (#{skills[:skipped].length}):"
        skills[:skipped].each do |skill|
          puts "  • #{skill[:id]}"
        end
        puts
      end

      # Summary
      total_active = mandatory.length + suggest.length
      puts(
        "📊 Summary: #{total_active} active, " \
          "#{skills[:skipped].length} skipped, " \
          "#{skills[:not_adapted].length} available"
      )
      puts
    end

    # vibe skills adapt <id> - Adapt a specific skill
    def run_skills_adapt(argv)
      skill_id = argv.shift

      unless skill_id
        raise Vibe::ValidationError,
              "Missing skill ID\n\nUsage: vibe skills adapt <skill-id> [mode]"
      end

      mode = argv.shift || 'suggest'
      mode = mode.to_sym

      unless %i[suggest mandatory skip].include?(mode)
        raise Vibe::ValidationError,
              "Invalid mode: #{mode}\n\nValid modes: suggest, mandatory, skip"
      end

      manager = SkillManager.new(@repo_root, Dir.pwd)

      if manager.adapt_skill(skill_id, mode)
        puts "✅ Skill '#{skill_id}' adapted as #{mode}"
      else
        puts "❌ Failed to adapt skill '#{skill_id}'"
        exit 1
      end
    end

    # vibe skills skip <id> - Skip a skill
    def run_skills_skip(argv)
      skill_id = argv.shift

      unless skill_id
        raise Vibe::ValidationError,
              "Missing skill ID\n\nUsage: vibe skills skip <skill-id>"
      end

      manager = SkillManager.new(@repo_root, Dir.pwd)

      if manager.skip_skill(skill_id)
        puts "⏸️  Skill '#{skill_id}' skipped"
        puts "   You can adapt it later with: vibe skills adapt #{skill_id}"
      else
        puts "❌ Failed to skip skill '#{skill_id}'"
        exit 1
      end
    end

    # vibe skills docs <id> - Show skill documentation
    def run_skills_docs(argv)
      skill_id = argv.shift

      unless skill_id
        raise Vibe::ValidationError,
              "Missing skill ID\n\nUsage: vibe skills docs <skill-id>"
      end

      manager = SkillManager.new(@repo_root, Dir.pwd)
      skill = manager.skill_info(skill_id)

      unless skill
        puts "❌ Skill not found: #{skill_id}"
        puts "   Run 'vibe skills list' to see available skills"
        exit 1
      end

      puts "\n📚 Skill Documentation: #{skill_id}"
      puts '=' * 60
      puts
      puts "ID: #{skill[:id]}"
      puts "Namespace: #{skill[:namespace]}"
      puts "Intent: #{skill[:intent]}"
      puts "Priority: #{skill[:priority]}"
      puts "Safety Level: #{skill[:safety_level]}"
      puts "Adaptation Status: #{skill[:adaptation_status]}"
      puts "Adaptation Mode: #{skill[:adaptation_mode]}" if skill[:adaptation_mode]
      puts

      if skill[:requires_tools]&.any?
        puts 'Required Tools:'
        skill[:requires_tools].each { |tool| puts "  • #{tool}" }
        puts
      end

      if skill[:supported_targets]&.any?
        puts 'Supported Targets:'
        skill[:supported_targets].each do |target, mode|
          puts "  • #{target}: #{mode}"
        end
        puts
      end

      if skill[:entrypoint]
        entry_path = File.join(@repo_root, skill[:entrypoint])
        if File.exist?(entry_path)
          puts 'Documentation:'
          puts '-' * 60
          content = File.read(entry_path)
          content.lines.first(50).each { |line| puts line }
          if content.lines.count > 50
            puts '...'
            puts "(See full documentation at: #{skill[:entrypoint]})"
          end
        end
      end

      puts
    end

    # vibe skills discover - Discover unregistered skills
    def run_skills_discover(_argv)
      puts '🔍 扫描技能目录...'
      puts

      discovery = SkillDiscovery.new(@repo_root)
      registration = SkillRegistration.new(@repo_root)

      # Show status
      status = registration.status
      puts "项目: #{@repo_root}"
      puts "已发现技能: #{status[:total_discovered]}"
      puts "已注册: #{status[:registered]}"
      puts "未注册: #{status[:unregistered]}"
      puts

      # Discover unregistered skills
      unregistered = discovery.unregistered_skills

      if unregistered.empty?
        puts '✅ 没有发现新的未注册技能'
        puts
        puts '所有已安装技能都已注册到路由配置中。'
        return
      end

      puts "发现 #{unregistered.size} 个未注册技能:"
      puts

      unregistered.each_with_index do |skill, index|
        puts "[#{index + 1}] #{skill[:display_name]}"
        puts "    ID: #{skill[:id]}"
        puts "    来源: #{skill[:namespace]}"
        puts "    描述: #{skill[:description]}"
        puts "    路径: #{skill[:path]}"

        # Security audit
        audit = discovery.security_audit(skill[:path])
        if audit[:safe]
          puts "    安全: ✅ 通过"
        else
          puts "    安全: ⚠️  风险 #{audit[:risk_level]}"
          audit[:red_flags].first(3).each do |flag|
            puts "      • #{flag}"
          end
        end
        puts
      end

      puts '💡 使用 `vibe skills register` 注册这些技能'
      puts
    end

    # vibe skills register - Register skills to project routing
    def run_skills_register(argv)
      options = parse_skills_register_options(argv)

      registration = SkillRegistration.new(@repo_root)

      if options[:interactive]
        registration.interactive_register
      elsif options[:auto]
        puts '🤖 自动注册模式 (仅注册通过安全审查的技能)...'
        puts

        result = registration.register_new_skills(
          auto_register: true,
          interactive: false,
          default_namespace: 'project'
        )

        puts "注册结果:"
        puts "  发现: #{result[:discovered]}"
        puts "  成功: #{result[:registered]}"
        puts "  跳过: #{result[:skipped]}"
        puts "  失败: #{result[:failed]}"
        puts

        if result[:skills].any? { |s| s[:status] == :failed }
          puts '失败的技能:'
          result[:skills].select { |s| s[:status] == :failed }.each do |s|
            puts "  • #{s[:skill]}: #{s[:reason]}"
          end
          puts
        end
      else
        # Default: show status and suggest interactive
        status = registration.status

        puts '📊 技能注册状态'
        puts '=' * 40
        puts
        puts "配置文件: #{status[:project_file]}"
        puts "  存在: #{status[:project_file_exists] ? '✅' : '❌'}"
        puts
        puts "技能统计:"
        puts "  发现: #{status[:total_discovered]}"
        puts "  注册: #{status[:registered]}"
        puts "  未注册: #{status[:unregistered]}"
        puts

        if status[:unregistered] > 0
          puts '💡 发现未注册技能!'
          puts
          puts '运行以下命令进行注册:'
          puts '  vibe skills register --interactive  # 交互式注册'
          puts '  vibe skills register --auto         # 自动注册 (安全技能)'
          puts
        end
      end
    end

    # vibe skills install <pack> - Install a skill pack
    def run_skills_install(argv)
      pack_name = argv.shift

      unless pack_name
        raise Vibe::ValidationError,
              "Missing skill pack name\n\nUsage: vibe skills install <pack-name>"
      end

      options = parse_skills_install_options(argv)

      installer = SkillInstaller.new(@repo_root, Dir.pwd)

      if options[:dry_run]
        installer.preview_installation(pack_name, platform: options[:platform])
      else
        success = installer.install(pack_name,
                                    platform: options[:platform],
                                    auto_adapt: options[:auto_adapt])
        exit 1 unless success
      end
    end

    private

    def skills_usage
      <<~HELP
        Usage: vibe skills <subcommand> [options]

        Manage skill adaptation for your project.

        Subcommands:
          check              Check for new skills and adapt them
          list               List all skills and their status
          use <id>           Directly use a skill (bypass AI routing)
          adapt <id>         Adapt a specific skill
          skip <id>          Skip a skill (mark as not applicable)
          docs <id>          Show skill documentation
          install <pack>     Install a skill pack
          discover           Discover unregistered skills with security audit
          register           Register skills to project routing

        Options for check:
          --auto-adapt       Automatically adapt all as suggest
          --update-timestamp Just update last check time

        Options for install:
          --platform P       Target platform (claude-code, opencode, etc.)
          --auto-adapt       Auto-adapt skills after installation
          --dry-run          Preview installation without making changes

        Options for register:
          --interactive      Interactive registration wizard (default)
          --auto             Auto-register safe skills only

        Examples:
          vibe skills check                    # Check for new skills
          vibe skills check --auto-adapt       # Auto-adapt all new skills
          vibe skills list                     # List all skills
          vibe skills adapt superpowers/tdd    # Adapt TDD skill
          vibe skills adapt superpowers/tdd mandatory  # As mandatory
          vibe skills skip superpowers/optimize # Skip optimization skill
          vibe skills docs superpowers/tdd     # View TDD documentation
          vibe skills install superpowers      # Install superpowers pack
          vibe skills discover                 # Discover unregistered skills
          vibe skills register --interactive   # Interactive registration
          vibe skills register --auto          # Auto-register safe skills

        See docs/design-skill-adaptation.md for detailed documentation.
      HELP
    end

    def parse_skills_check_options(argv)
      options = { auto_adapt: false, update_timestamp: false }

      argv.each do |arg|
        case arg
        when '--auto-adapt'
          options[:auto_adapt] = true
        when '--update-timestamp'
          options[:update_timestamp] = true
        end
      end

      options
    end

    def parse_skills_install_options(argv)
      options = { platform: nil, auto_adapt: false, dry_run: false }

      i = 0
      while i < argv.length
        arg = argv[i]
        case arg
        when '--platform'
          i += 1
          options[:platform] = argv[i]
        when '--auto-adapt'
          options[:auto_adapt] = true
        when '--dry-run'
          options[:dry_run] = true
        end
        i += 1
      end

      options
    end

    def parse_skills_register_options(argv)
      options = { interactive: false, auto: false }

      argv.each do |arg|
        case arg
        when '--interactive'
          options[:interactive] = true
        when '--auto'
          options[:auto] = true
        end
      end

      # Default to interactive if no option specified
      options[:interactive] = true unless options[:auto]

      options
    end

    # vibe skills use <skill-id> - Directly use a skill
    def run_skills_use(argv)
      if argv.empty?
        puts 'Usage: vibe skills use <skill-id>'
        puts
        puts 'Examples:'
        puts '  vibe skills use riper-workflow'
        puts '  vibe skills use gstack/office-hours'
        puts '  vibe skills use superpowers/tdd'
        puts
        puts 'This command loads and displays a skill for direct use,'
        puts 'bypassing the AI routing recommendation.'
        return 1
      end

      skill_id = argv.first

      # Determine skill file path
      skill_file = determine_skill_file(skill_id)

      # Display skill information
      puts "🎯 Loading skill: #{skill_id}"
      puts "=" * 50
      puts

      if skill_file && File.exist?(skill_file)
        # Read skill intent from file
        intent = extract_skill_intent(skill_file)
        puts "📋 #{intent || 'Development skill'}"
        puts
        puts "📄 Skill file: #{skill_file}"
        puts
        puts "=" * 50
        puts
        puts '💡 Next steps:'
        puts "   1. Read the skill: read #{skill_file}"
        puts '   2. Follow the steps defined in the skill'
        puts '   3. Run any verification commands specified'
      else
        puts '⚠️  Skill file not found on disk.'
        puts '   This may be an external skill or needs to be registered.'
        puts
        puts 'Try: vibe skills discover'
      end

      0
    end

    # Extract skill intent from SKILL.md file
    def extract_skill_intent(skill_file)
      return nil unless File.exist?(skill_file)

      content = File.read(skill_file)

      # Look for intent in frontmatter or first heading
      if content =~ /^intent:\s*(.+)$/i
        $1.strip
      elsif content =~ /^#\s*(.+)$/m
        $1.strip
      else
        nil
      end
    rescue StandardError
      nil
    end

    # Determine the file path for a skill
    def determine_skill_file(skill_id)
      # Check builtin skills first
      builtin_path = File.join(@repo_root, 'skills', skill_id, 'SKILL.md')
      return builtin_path if File.exist?(builtin_path)

      # Check project-local skills
      project_path = File.join(Dir.pwd, 'skills', skill_id, 'SKILL.md')
      return project_path if File.exist?(project_path)

      # Check external skill packs
      if skill_id.include?('/')
        parts = skill_id.split('/')
        pack = parts[0]
        name = parts[1] || parts[0]

        # Check common external skill locations
        external_paths = [
          File.expand_path("~/.config/skills/#{pack}/skills/#{name}/SKILL.md"),
          File.expand_path("~/.config/skills/#{pack}/#{name}.md"),
          File.expand_path("~/.claude/skills/#{pack}/skills/#{name}/SKILL.md")
        ]

        external_paths.each do |path|
          return path if File.exist?(path)
        end
      end

      nil
    end

    def time_ago(timestamp)
      return 'unknown' unless timestamp

      time = Time.parse(timestamp)
      diff = Time.now - time

      case diff
      when 0..60
        'just now'
      when 60..3600
        "#{diff / 60} minutes ago"
      when 3600..86_400
        "#{diff / 3600} hours ago"
      when 86_400..604_800
        "#{diff / 86_400} days ago"
      else
        time.strftime('%Y-%m-%d')
      end
    rescue StandardError
      'unknown'
    end
  end
end
