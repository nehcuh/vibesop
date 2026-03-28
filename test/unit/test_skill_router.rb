# frozen_string_literal: true

require_relative '../test_helper'
require_relative '../../lib/vibe/skill_router'
require 'tmpdir'
require 'fileutils'

class TestSkillRouter < Minitest::Test
  def setup
    @test_dir = Dir.mktmpdir('skill-router-test')
    create_test_config_files
    @router = Vibe::SkillRouter.new(@test_dir)
  end

  def teardown
    FileUtils.rm_rf(@test_dir) if @test_dir && File.exist?(@test_dir)
  end

  def test_route_code_review_scenario
    result = @router.route('帮我评审下代码')

    assert result[:matched]
    assert_equal '/review', result[:skill]
    assert_equal 'gstack', result[:source]
    assert_equal 'code_review', result[:scenario]
  end

  def test_route_debugging_scenario
    result = @router.route('这个 bug 很奇怪')

    assert result[:matched]
    assert_equal 'systematic-debugging', result[:skill]
    assert_equal 'builtin', result[:source]
  end

  def test_route_planning_scenario
    result = @router.route('这是一个复杂的重构任务')

    assert result[:matched]
    assert_equal 'planning-with-files', result[:skill]
  end

  def test_route_shipping_scenario
    result = @router.route('准备发布新版本')

    assert result[:matched]
    assert_equal '/ship', result[:skill]
    assert_equal 'gstack', result[:source]
  end

  def test_route_qa_scenario
    result = @router.route('帮我测试网站')

    assert result[:matched]
    assert_equal '/qa', result[:skill]
    assert_equal 'browser_qa', result[:scenario]
  end

  def test_explicit_override
    result = @router.route('用 superpowers 评审代码')

    assert result[:matched]
    assert result[:override]
    assert_equal 'superpowers', result[:source]
  end

  def test_no_match
    result = @router.route('今天天气怎么样')

    refute result[:matched]
    assert_nil result[:skill]
  end

  def test_skills_for_scenario
    skills = @router.skills_for_scenario('code_review')

    assert skills.any? { |s| s[:skill] == '/review' }
    assert skills.any? { |s| s[:source] == 'gstack' }
  end

  def test_should_route_positive
    assert @router.should_route?('帮我评审代码')
    assert @router.should_route?('有个 bug 需要调试')
  end

  def test_should_route_negative
    refute @router.should_route?('你好')
    refute @router.should_route?('今天几号')
  end

  def test_confidence_calculation
    # Single keyword match — "review" matches 1/3 code_review keywords (score ≈ 0.33 → :low)
    result = @router.route('review')
    assert_includes [:low, :medium, :high], result[:confidence]

    # Multiple keywords match (if input contains multiple keywords from the rule)
    result = @router.route('帮我评审代码 review')
    assert_includes [:high, :very_high, :absolute], result[:confidence]
  end

  private

  def create_test_config_files
    # Create skill-routing.yaml
    vibe_dir = File.join(@test_dir, '.vibe')
    FileUtils.mkdir_p(vibe_dir)

    routing_config = {
      'routing_rules' => [
        {
          'scenario' => 'code_review',
          'primary' => {
            'skill' => '/review',
            'source' => 'gstack',
            'reason' => 'Pre-landing code review'
          },
          'keywords' => ['评审', 'review', '代码审查']
        },
        {
          'scenario' => 'debugging',
          'primary' => {
            'skill' => 'systematic-debugging',
            'source' => 'builtin',
            'reason' => 'Find root cause'
          },
          'keywords' => ['bug', '错误', '调试', 'debug']
        },
        {
          'scenario' => 'planning',
          'primary' => {
            'skill' => 'planning-with-files',
            'source' => 'builtin',
            'reason' => 'Complex task planning'
          },
          'keywords' => ['规划', '计划', '复杂']
        }
      ],
      'exclusive_skills' => [
        {
          'scenario' => 'browser_qa',
          'skill' => '/qa',
          'source' => 'gstack',
          'reason' => 'Browser testing',
          'keywords' => ['测试网站', 'QA', '端到端']
        },
        {
          'scenario' => 'shipping',
          'skill' => '/ship',
          'source' => 'gstack',
          'reason' => 'Release workflow',
          'keywords' => ['发布', 'ship', '新版本']
        }
      ],
      'user_override' => {
        'enabled' => true,
        'keywords' => {
          '用 gstack' => '切换到 gstack',
          '用 superpowers' => '切换到 superpowers'
        }
      }
    }

    File.write(File.join(vibe_dir, 'skill-routing.yaml'), YAML.dump(routing_config))

    # Create registry.yaml
    core_dir = File.join(@test_dir, 'core', 'skills')
    FileUtils.mkdir_p(core_dir)

    registry = {
      'skills' => [
        {
          'id' => 'systematic-debugging',
          'namespace' => 'builtin',
          'intent' => 'Find root cause before attempting fixes'
        },
        {
          'id' => 'planning-with-files',
          'namespace' => 'builtin',
          'intent' => 'Use persistent files as working memory'
        }
      ]
    }

    File.write(File.join(core_dir, 'registry.yaml'), YAML.dump(registry))
  end
end
