# frozen_string_literal: true

require_relative 'skill_router'
require_relative 'user_interaction'

module Vibe
  # CLI commands for intelligent skill routing
  module SkillRouterCommands
    include UserInteraction

    # Route user input and display result
    def cmd_route(argv)
      if argv.empty?
        puts 'Usage: vibe route "<user request>"'
        puts '       vibe route --interactive'
        puts
        puts 'Examples:'
        puts '  vibe route "帮我评审代码"'
        puts '  vibe route "这个 bug 很奇怪"'
        puts '  vibe route "准备发布新版本"'
        return 1
      end

      if argv.first == '--interactive'
        return interactive_route
      end

      user_input = argv.join(' ')
      route_and_display(user_input)
      0
    end

    # Analyze current directory and suggest skills
    def cmd_route_context
      router = SkillRouter.new

      puts '🔍 分析当前项目上下文...'
      puts

      # Detect project type
      project_type = detect_project_type
      puts "项目类型: #{project_type}"

      # Check for common scenarios
      suggestions = []

      if File.exist?('test') || Dir.glob('*_test.rb').any? || Dir.glob('*.spec.js').any?
        suggestions << {
          scenario: 'test_driven_development',
          skill: '/test-driven-development',
          source: 'superpowers',
          reason: '检测到测试文件'
        }
      end

      if Dir.glob('app/views/**/*.erb').any? || Dir.glob('src/**/*.tsx').any?
        suggestions << {
          scenario: 'browser_qa',
          skill: '/qa',
          source: 'gstack',
          reason: '检测到前端代码'
        }
      end

      if File.exist?('.git') && git_uncommitted_changes?
        suggestions << {
          scenario: 'shipping',
          skill: '/ship',
          source: 'gstack',
          reason: '有未提交更改'
        }
      end

      if suggestions.any?
        puts
        puts '💡 建议使用的技能:'
        suggestions.each do |s|
          puts "  • #{s[:skill]} (#{s[:source]}) - #{s[:reason]}"
        end
      else
        puts
        puts 'ℹ️  未检测到特定场景'
        puts '   使用 `vibe route "你的需求"` 来获取技能建议'
      end

      0
    end

    private

    def interactive_route
      puts '🎯 智能 Skill 路由'
      puts '=' * 40
      puts
      puts '请输入你的需求 (或按 Enter 退出):'

      loop do
        print '> '
        input = $stdin.gets&.chomp
        break if input.nil? || input.empty?

        route_and_display(input)
        puts
      end

      puts
      puts '再见! 👋'
      0
    end

    def route_and_display(user_input)
      router = SkillRouter.new
      result = router.route(user_input)

      puts
      puts "📥 输入: #{user_input}"
      puts '-' * 40

      if result[:matched]
        display_match(result)
      else
        display_no_match(result)
      end
    end

    def display_match(result)
      confidence_emoji = case result[:confidence]
                         when :very_high then '🔥'
                         when :high then '✅'
                         when :medium then '👍'
                         else '🤔'
                         end

      puts "#{confidence_emoji} 匹配到技能: #{result[:skill]}"
      puts "   来源: #{result[:source]}"
      puts "   场景: #{result[:scenario]}" if result[:scenario]
      puts "   原因: #{result[:reason]}"

      if result[:alternatives]&.any?
        puts
        puts '💡 替代方案:'
        result[:alternatives].first(3).each do |alt|
          puts "   • #{alt[:skill]} (#{alt[:source]}) - #{alt[:trigger]}"
        end
      end

      puts
      puts '🚀 执行建议:'
      puts "   1. 加载技能: read #{skill_path(result[:skill])}"
      puts "   2. 遵循技能中的步骤执行"
      puts "   3. 完成后运行验证"
    end

    def display_no_match(result)
      puts '🤷 未找到匹配的技能'
      puts "   原因: #{result[:reason]}"

      if result[:suggestions]&.any?
        puts
        puts '💡 你可能想试试:'
        result[:suggestions].each { |s| puts "   • #{s}" }
      end

      puts
      puts '可用命令:'
      puts '   vibe skills list    - 列出所有技能'
      puts '   vibe route-context  - 基于项目上下文推荐'
    end

    def skill_path(skill_name)
      # Determine path based on skill name
      if skill_name.start_with?('/')
        # External skill (gstack, superpowers)
        "~/.config/skills/#{skill_name.sub(%r{^/}, '')}/SKILL.md"
      else
        # Builtin skill
        "skills/#{skill_name}/SKILL.md"
      end
    end

    def detect_project_type
      return 'Ruby' if File.exist?('Gemfile')
      return 'Node.js' if File.exist?('package.json')
      return 'Python' if File.exist?('requirements.txt') || File.exist?('pyproject.toml')
      return 'Go' if File.exist?('go.mod')
      return 'Rust' if File.exist?('Cargo.toml')

      'Unknown'
    end

    def git_uncommitted_changes?
      return false unless File.exist?('.git')

      system('git diff-index --quiet HEAD -- 2>/dev/null')
      !$?.success?
    end
  end
end
