# frozen_string_literal: true

require 'yaml'
require 'fileutils'
require_relative 'skill_discovery'

module Vibe
  # Registers discovered skills to project-level routing configuration
  # Default behavior: project-level registration (isolated, non-global)
  class SkillRegistration
    PROJECT_ROUTING_FILE = '.vibe/skill-routing.yaml'
    BACKUP_DIR = '.vibe/backups'

    attr_reader :project_root, :discovery

    def initialize(project_root = Dir.pwd)
      @project_root = project_root
      @discovery = SkillDiscovery.new(project_root)
    end

    # Main entry: discover, audit, and register new skills
    # @param options [Hash] Registration options
    #   - :auto_register [Boolean] Auto-register if audit passes (default: false)
    #   - :default_namespace [String] Default namespace for new skills (default: 'project')
    #   - :interactive [Boolean] Prompt user for confirmation (default: true)
    # @return [Hash] Registration results
    def register_new_skills(options = {})
      options = {
        auto_register: false,
        default_namespace: 'project',
        interactive: true
      }.merge(options)

      results = {
        discovered: 0,
        audited: 0,
        registered: 0,
        failed: 0,
        skipped: 0,
        skills: []
      }

      # Discover unregistered skills
      unregistered = @discovery.unregistered_skills
      results[:discovered] = unregistered.size

      return results if unregistered.empty?

      puts "🔍 发现 #{unregistered.size} 个未注册技能"
      puts

      unregistered.each do |skill|
        result = process_skill(skill, options)
        results[result[:status]] += 1
        results[:skills] << result
      end

      results
    end

    # Register a single skill to project routing
    # @param skill [Hash] Skill metadata from SkillDiscovery
    # @param scenario [String, nil] Optional scenario to assign
    # @param as_alternative [Boolean] Register as alternative to existing primary
    # @return [Hash] Registration result
    def register_skill(skill, scenario: nil, as_alternative: false)
      ensure_project_routing_exists

      # Load current routing
      routing = load_project_routing
      return { success: false, error: 'Failed to load routing config' } unless routing

      # Backup before modification
      backup_routing_config

      # Determine where to register
      if scenario
        # Add to specific scenario
        add_to_scenario(routing, skill, scenario, as_alternative)
      else
        # Add to exclusive skills (project-specific)
        add_to_exclusive_skills(routing, skill)
      end

      # Save updated routing
      save_project_routing(routing)

      {
        success: true,
        skill: skill[:id],
        scenario: scenario || 'exclusive',
        message: "技能已注册到项目级路由"
      }
    rescue StandardError => e
      {
        success: false,
        skill: skill[:id],
        error: e.message
      }
    end

    # Interactive skill registration wizard
    # @return [Integer] Exit code
    def interactive_register
      unregistered = @discovery.unregistered_skills

      if unregistered.empty?
        puts "✅ 没有发现新的未注册技能"
        puts
        puts "所有已安装技能都已注册到路由配置中。"
        return 0
      end

      puts "🎯 技能注册向导"
      puts "=" * 50
      puts
      puts "发现 #{unregistered.size} 个未注册技能:"
      puts

      registered_count = 0

      unregistered.each_with_index do |skill, index|
        puts "[#{index + 1}/#{unregistered.size}] #{skill[:display_name]}"
        puts "   ID: #{skill[:id]}"
        puts "   描述: #{skill[:description]}"
        puts "   意图: #{skill[:intent]}"
        puts "   来源: #{skill[:path]}"
        puts

        # Security audit
        puts "   🔒 安全审查中..."
        audit = @discovery.security_audit(skill[:path])

        if audit[:safe]
          puts "   ✅ 安全检查通过"
        else
          puts "   ⚠️  发现潜在风险:"
          audit[:red_flags].each { |flag| puts "      • #{flag}" }
          audit[:threats].each { |t| puts "      • #{t[:rule]} (#{t[:severity]})" }
        end
        puts

        # Get user decision
        choice_made = false
        until choice_made
          print "注册此技能? [Y/n/s(跳过)/d(详情)] "
          choice = $stdin.gets&.chomp&.downcase || 'n'

          case choice
          when 'y', ''
            # Ask for scenario assignment
            scenario = select_scenario_interactive(skill)

            result = register_skill(skill, scenario: scenario)
            if result[:success]
              puts "   ✅ 已注册#{scenario ? "到场景: #{scenario}" : '为项目专属技能'}"
              registered_count += 1
            else
              puts "   ❌ 注册失败: #{result[:error]}"
            end
            choice_made = true
          when 'd'
            display_skill_details(skill)
            # Show details and ask again
          when 's'
            puts "   ⏭️  已跳过"
            choice_made = true
          else
            puts "   ❌ 已取消"
            choice_made = true
          end
        end

        puts
      end

      puts "=" * 50
      puts "注册完成: #{registered_count}/#{unregistered.size} 个技能已注册"
      puts
      puts "项目级路由配置已更新: #{PROJECT_ROUTING_FILE}"

      0
    end

    # Show registration status
    def status
      all_skills = @discovery.discover_all
      unregistered = @discovery.unregistered_skills

      {
        total_discovered: all_skills.size,
        registered: all_skills.size - unregistered.size,
        unregistered: unregistered.size,
        project_file: File.join(@project_root, PROJECT_ROUTING_FILE),
        project_file_exists: File.exist?(File.join(@project_root, PROJECT_ROUTING_FILE))
      }
    end

    private

    def process_skill(skill, options)
      # Security audit
      audit = @discovery.security_audit(skill[:path])

      unless audit[:safe]
        return {
          status: :failed,
          skill: skill[:id],
          reason: 'Security audit failed',
          red_flags: audit[:red_flags],
          threats: audit[:threats]
        }
      end

      # Interactive confirmation
      if options[:interactive] && !options[:auto_register]
        # Skip in non-interactive mode
        return { status: :skipped, skill: skill[:id] }
      end

      # Auto-register if enabled
      if options[:auto_register]
        result = register_skill(skill)
        return result.merge(status: result[:success] ? :registered : :failed)
      end

      { status: :skipped, skill: skill[:id] }
    end

    def ensure_project_routing_exists
      vibe_dir = File.join(@project_root, '.vibe')
      routing_file = File.join(vibe_dir, 'skill-routing.yaml')

      return if File.exist?(routing_file)

      # Create default project routing
      default_config = {
        'schema_version' => 1,
        'description' => 'Project-specific skill routing configuration',
        'routing_rules' => [],
        'exclusive_skills' => [],
        'project_skills' => []
      }

      FileUtils.mkdir_p(vibe_dir)
      File.write(routing_file, YAML.dump(default_config))
    end

    def load_project_routing
      routing_path = File.join(@project_root, PROJECT_ROUTING_FILE)
      return nil unless File.exist?(routing_path)

      YAML.safe_load(File.read(routing_path), aliases: true)
    rescue StandardError => e
      puts "Error loading routing config: #{e.message}"
      nil
    end

    def save_project_routing(routing)
      routing_path = File.join(@project_root, PROJECT_ROUTING_FILE)
      File.write(routing_path, YAML.dump(routing))
    end

    def backup_routing_config
      routing_path = File.join(@project_root, PROJECT_ROUTING_FILE)
      return unless File.exist?(routing_path)

      backup_dir = File.join(@project_root, BACKUP_DIR)
      FileUtils.mkdir_p(backup_dir)

      timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
      backup_path = File.join(backup_dir, "skill-routing_#{timestamp}.yaml")

      FileUtils.cp(routing_path, backup_path)
    end

    def add_to_scenario(routing, skill, scenario, as_alternative)
      rules = routing['routing_rules'] ||= []
      rule = rules.find { |r| r['scenario'] == scenario }

      skill_entry = {
        'skill' => skill[:id],
        'source' => skill[:namespace],
        'priority' => skill[:priority]
      }

      if rule
        if as_alternative
          rule['alternatives'] ||= []
          rule['alternatives'] << skill_entry.merge('trigger' => skill[:intent])
        else
          # Replace primary (use with caution)
          old_primary = rule['primary']
          rule['alternatives'] ||= []
          rule['alternatives'] << old_primary if old_primary
          rule['primary'] = skill_entry.merge('reason' => skill[:intent])
        end
      else
        # Create new scenario
        rules << {
          'scenario' => scenario,
          'description' => "Auto-generated scenario for #{skill[:display_name]}",
          'primary' => skill_entry.merge('reason' => skill[:intent]),
          'keywords' => skill[:keywords].first(5)
        }
      end
    end

    def add_to_exclusive_skills(routing, skill)
      exclusive = routing['exclusive_skills'] ||= []

      exclusive << {
        'scenario' => "#{skill[:name]}_workflow",
        'skill' => skill[:id],
        'source' => skill[:namespace],
        'reason' => skill[:intent],
        'keywords' => skill[:keywords].first(5)
      }

      # Also track in project_skills for audit
      project_skills = routing['project_skills'] ||= []
      project_skills << {
        'id' => skill[:id],
        'registered_at' => Time.now.iso8601,
        'path' => skill[:path]
      }
    end

    def select_scenario_interactive(skill)
      puts "   选择应用场景:"
      puts "      1. 代码审查 (code_review)"
      puts "      2. 调试 (debugging)"
      puts "      3. 规划 (planning)"
      puts "      4. 重构 (refactoring)"
      puts "      5. TDD (test_driven_development)"
      puts "      6. 产品思考 (product_thinking)"
      puts "      7. 项目专属 (project-specific)"
      puts "      8. 跳过注册"
      print "   选择 [1-8]: "

      choice = $stdin.gets&.chomp

      scenarios = {
        '1' => 'code_review',
        '2' => 'debugging',
        '3' => 'planning',
        '4' => 'refactoring',
        '5' => 'test_driven_development',
        '6' => 'product_thinking'
      }

      return nil if choice == '8' || choice.nil?
      scenarios[choice]
    end

    def display_skill_details(skill)
      puts
      puts "   📄 技能详情:"
      puts "   " + "-" * 40
      puts "   完整元数据:"
      skill[:raw_metadata].each do |key, value|
        puts "      #{key}: #{value}"
      end
      puts "   " + "-" * 40
      puts
    end
  end
end
