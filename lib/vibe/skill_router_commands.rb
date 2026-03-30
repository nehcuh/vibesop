# frozen_string_literal: true

require_relative 'skill_router'
require_relative 'config_loader'
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
        puts '       vibe route --stats'
        puts
        puts 'Examples:'
        puts '  vibe route "帮我评审代码"'
        puts '  vibe route "这个 bug 很奇怪"'
        puts '  vibe route "准备发布新版本"'
        puts '  vibe route --stats'
        return 1
      end

      if argv.first == '--interactive'
        return interactive_route
      end

      if argv.first == '--stats'
        return display_route_stats
      end

      user_input = argv.join(' ')
      route_and_display(user_input)
      0
    end

    # Display route statistics
    def display_route_stats
      router = Vibe::SkillRouter.new
      stats = router.stats

      puts '📊 Skill Routing Statistics'
      puts '=' * 50
      puts

      # AI Triage Layer Stats
      ai_stats = stats[:ai_triage]
      puts '🤖 AI Triage Layer:'
      puts "   Status: #{ai_stats[:enabled] ? '✅ Enabled' : '❌ Disabled'}"
      if ai_stats[:disabled_reason]
        puts "   Reason: #{ai_stats[:disabled_reason]}"
      end
      puts "   Environment: #{ai_stats[:runtime_environment] || :unknown}"
      if ai_stats[:enabled]
        puts "   Model: #{ai_stats[:model] || 'unknown'}"
        puts "   Provider: #{ai_stats[:provider] || 'unknown'}"
        puts "   Circuit: #{ai_stats[:circuit_state] == :open ? '🔴 Open' : '🟢 Closed'}"
      end
      puts

      # Cache Stats
      cache_stats = ai_stats[:cache_stats]
      puts '💾 Cache Layer:'
      puts "   Memory hits: #{cache_stats[:memory_hits] || 0}"
      puts "   File hits: #{cache_stats[:file_hits] || 0}"
      puts "   Misses: #{cache_stats[:misses] || 0}"
      puts "   Hit rate: #{cache_stats[:hit_rate] || 0}%"
      puts

      # Routing Stats
      routing_stats = stats[:routing]
      puts '🔀 Overall Routing:'
      puts "   Total routes: #{routing_stats[:total_routes] || 0}"
      puts "   Layer distribution:"
      routing_stats[:layer_distribution]&.each do |layer, count|
        next if count.zero?
        emoji = case layer
                when :layer_0_ai then '🤖'
                when :layer_1_explicit then '🎯'
                when :layer_2_scenario then '📋'
                when :layer_3_semantic then '🔍'
                when :layer_4_fuzzy then '🔀'
                when :no_match then '❓'
                else '•'
                end
        puts "     #{emoji} #{layer}: #{count}"
      end
      puts

      # Environment info
      puts '🖥️  Runtime Environment:'
      puts "   Claude Code: #{ENV['CLAUDECODE'] == '1' ? '✅ Yes' : '❌ No'}"
      puts "   OpenCode: #{File.exist?('.vibe/opencode/config.json') ? '✅ Yes' : '❌ No'}"
      puts "   Local Model: #{ai_stats[:is_local_model] ? '✅ Yes' : '❌ No'}"

      0
    end

    # Validate skill routing configuration
    def cmd_route_validate(argv)
      puts '🔍 验证技能路由配置...'
      puts

      errors = []
      warnings = []

      # Check selection policy file
      policy_file = File.join(Dir.pwd, 'core/policies/skill-selection.yaml')
      unless File.exist?(policy_file)
        errors << '缺少配置文件: core/policies/skill-selection.yaml'
      else
        policy = ConfigLoader.load_yaml(policy_file, context: 'skill-selection policy')

        # Validate structure
        unless policy['candidate_selection']
          errors << '缺少 candidate_selection 配置'
        end

        unless policy['preference_learning']
          errors << '缺少 preference_learning 配置'
        end

        unless policy['parallel_execution']
          errors << '缺少 parallel_execution 配置'
        end

        # Validate values
        if policy['candidate_selection']
          threshold = policy['candidate_selection']['auto_select_threshold']
          unless threshold.is_a?(Numeric) && threshold >= 0 && threshold <= 1
            errors << "auto_select_threshold 必须在 0-1 之间，当前: #{threshold}"
          end
        end

        # Check weights sum to ~1
        if policy['preference_learning'] && policy['preference_learning']['dimensions']
          weights = policy['preference_learning']['dimensions'].values.map { |d| d['weight'] }.compact
          sum = weights.sum
          unless (sum - 1.0).abs < 0.1
            warnings << "维度权重总和约为 #{sum.round(2)}，建议为 1.0"
          end
        end
      end

      # Check router components
      begin
        require_relative 'skill_router/candidate_selector'
        require_relative 'skill_router/parallel_executor'
        require_relative 'preference_dimension_analyzer'
        puts '✅ 所有路由组件可用'
      rescue LoadError => e
        errors << "缺少路由组件: #{e.message}"
      end

      # Display results
      if errors.empty? && warnings.empty?
        puts
        puts '🎉 配置验证通过！'
        puts
        puts '配置摘要:'
        puts "  • 最大候选数: #{policy['candidate_selection']['max_candidates']}"
        puts "  • 自动选择阈值: #{policy['candidate_selection']['auto_select_threshold']}"
        puts "  • 偏好学习: #{policy['preference_learning']['enabled'] ? '启用' : '禁用'}"
        puts "  • 并行执行: #{policy['parallel_execution']['enabled'] ? '启用' : '禁用'}"
        return 0
      end

      if warnings.any?
        puts '⚠️  警告:'
        warnings.each { |w| puts "   • #{w}" }
        puts
      end

      if errors.any?
        puts '❌ 错误:'
        errors.each { |e| puts "   • #{e}" }
        return 1
      end

      0
    end

    # Select a specific skill (for use after multi-candidate routing)
    def cmd_route_select(argv)
      if argv.empty?
        puts 'Usage: vibe route-select <skill-id>'
        puts
        puts 'Select a skill from multiple candidates.'
        return 1
      end

      skill_id = argv.first
      puts
      puts "✅ 已选择技能: #{skill_id}"
      puts
      puts '🚀 执行建议:'
      puts "   1. 加载技能: read #{skill_path(skill_id)}"
      puts "   2. 遵循技能中的步骤执行"
      puts "   3. 完成后运行验证"
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

      # Handle new multi-candidate decision types
      if result[:requires_user_choice]
        display_user_choice(result)
      elsif result[:status] && result[:status] != :single
        # Parallel execution result
        display_parallel_result(result)
      elsif result[:matched]
        display_match(result)
      else
        display_no_match(result)
      end
    end

    def display_user_choice(result)
      puts '🤔 多个技能匹配你的请求'
      puts
      puts result[:prompt]
      puts
      puts '提示: 使用技能ID执行，例如:'
      result[:candidates].each_with_index do |c, i|
        puts "   vibe route-select #{c[:skill]}"
      end
    end

    def display_parallel_result(result)
      status_emoji = case result[:status]
                     when :consensus then '🎯'
                     when :majority then '📊'
                     when :merged then '🔀'
                     when :all then '📋'
                     else '✅'
                     end

      puts "#{status_emoji} 并行执行结果"
      puts "   状态: #{result[:status]}"
      puts "   参与者: #{result[:participants]}" if result[:participants]

      if result[:message]
        puts "   说明: #{result[:message]}"
      end

      if result[:consensus_rate]
        puts "   一致性: #{(result[:consensus_rate] * 100).round(1)}%"
      end

      if result[:insights]&.any?
        puts
        puts '💡 综合洞察:'
        result[:insights].each do |insight|
          puts "   • #{insight}"
        end
      end

      if result[:recommendations]&.any?
        puts
        puts '📌 建议:'
        result[:recommendations].each_with_index do |rec, i|
          puts "   #{i + 1}. #{rec}"
        end
      end

      if result[:best_match]
        puts
        puts '🏆 最佳匹配:'
        best = result[:best_match]
        puts "   技能: #{best[:candidate][:skill]}"
        puts "   评分: #{best[:score].round(2)}"
      end

      if result[:failed]&.positive?
        puts
        puts "⚠️  #{result[:failed]} 个执行失败"
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
      puts '🤷 未找到直接匹配的技能'
      puts "   原因: #{result[:reason]}"
      puts
      puts '💡 你仍然可以选择使用某个技能：'

      # Show top skills that could still be useful
      show_alternative_skills(result)

      puts
      puts '💭 用户选择模式：'
      puts '   技能路由提供 AI 建议，但你始终有最终决定权。'
      puts '   即使 AI 认为不匹配，你仍然可以使用任何技能。'
      puts
      puts '可用命令:'
      puts '   vibe skills list           - 列出所有可用技能'
      puts '   vibe skills use <skill-id> - 直接使用指定技能'
      puts '   vibe route-context         - 基于项目上下文推荐'
    end

    # Show alternative skills even for non-matches
    def show_alternative_skills(result)
      # Get a few generally useful skills to suggest
      fallback_skills = [
        { id: 'riper-workflow', name: 'RIPER 工作流', desc: '通用 5 阶段开发流程' },
        { id: 'systematic-debugging', name: '系统化调试', desc: '问题排查方法论' },
        { id: 'planning-with-files', name: '文件化规划', desc: '复杂任务规划' },
        { id: 'verification-before-completion', name: '完成前验证', desc: '质量检查' }
      ]

      puts
      puts '   🔧 通用技能（可能仍然有用）：'
      fallback_skills.each do |s|
        puts "      • #{s[:id]} — #{s[:desc]}"
      end

      # Show external skill packs if available
      if superpowers_installed?
        puts
        puts '   📦 外部技能包：'
        puts '      • gstack/office-hours — 产品头脑风暴'
        puts '      • superpowers/brainstorm — 结构化思考'
      end
    end

    # Check if Superpowers is installed
    def superpowers_installed?
      File.directory?(File.expand_path('~/.config/skills/superpowers'))
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
