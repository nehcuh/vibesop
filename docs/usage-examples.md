# Usage Examples

**Version**: 1.0.0  
**Last Updated**: 2026-03-30

---

## Table of Contents

- [Basic Routing](#basic-routing)
- [Multi-Candidate Selection](#multi-candidate-selection)
- [Preference Learning](#preference-learning)
- [Parallel Execution](#parallel-execution)
- [Custom Configuration](#custom-configuration)

---

## Basic Routing

### Simple Request

```ruby
require 'vibe/skill_router'

router = Vibe::SkillRouter.new

# Route a debugging request
result = router.route("这个 bug 很奇怪")

if result[:matched]
  puts "Skill: #{result[:skill]}"
  puts "Source: #{result[:source]}"
  puts "Confidence: #{result[:confidence]}"
  # => Skill: systematic-debugging
  # => Source: builtin
  # => Confidence: :high
end
```

### With Context

```ruby
# Provide additional context for better routing
result = router.route("修复这个问题", {
  current_task: "bug-fix",
  file_type: "ruby",
  recent_files: ["app/models/user.rb", "spec/models/user_spec.rb"],
  error_count: 3
})

# Context helps the router prioritize debugging skills
```

---

## Multi-Candidate Selection

### When Multiple Skills Match

```ruby
result = router.route("重构这个模块")

if result[:requires_user_choice]
  puts "Multiple skills match:"
  result[:candidates].each_with_index do |c, i|
    puts "#{i + 1}. #{c[:skill]} (confidence: #{c[:confidence]})"
  end
  # => Multiple skills match:
  # => 1. planning-with-files (confidence: 0.85)
  # => 2. superpowers/refactor (confidence: 0.82)
end
```

### Manual Selection

```bash
# CLI: User selects from candidates
vibe route-select planning-with-files

# => ✅ 已选择技能: planning-with-files
# => 
# => 🚀 执行建议:
# =>    1. 加载技能: read skills/planning-with-files/SKILL.md
# =>    2. 遵循技能中的步骤执行
# =>    3. 完成后运行验证
```

---

## Preference Learning

### Check Preference Analysis

```ruby
require 'vibe/preference_dimension_analyzer'

analyzer = Vibe::PreferenceDimensionAnalyzer.new(
  config: { 'enabled' => true },
  preference_file: '.vibe/skill-preferences.yaml'
)

candidates = [
  { skill: 'systematic-debugging', confidence: 0.8 },
  { skill: 'gstack/investigate', confidence: 0.75 }
]

# Get preference boost scores
boosts = analyzer.analyze(candidates, {
  file_type: 'ruby',
  current_task: 'debugging'
})

puts boosts
# => { 'systematic-debugging' => 0.35, 'gstack/investigate' => 0.15 }

# Higher score = user prefers this skill for this context
```

### Detailed Analysis

```ruby
# Get detailed breakdown for a specific skill
analysis = analyzer.detailed_analysis('systematic-debugging')

puts analysis
# => {
# =>   consistency: 0.80,
# =>   satisfaction: 0.90,
# =>   context: 0.70,
# =>   recency: 0.60,
# =>   overall: 0.75
# }
```

### Recording User Choice

```ruby
require 'vibe/preference_learner'

learner = Vibe::PreferenceLearner.new('.vibe/skill-preferences.yaml')

# Record user's selection (automatically called by router)
learner.record_selection("调试这个bug", "systematic-debugging", {
  primary: { skill: "systematic-debugging", confidence: 0.9 },
  intent: "debugging"
})

# Record satisfaction (positive feedback)
learner.record_satisfaction("systematic-debugging", true)
```

---

## Parallel Execution

### Configure Parallel Execution

```yaml
# .vibe/overlay.yaml or core/policies/skill-selection.yaml
parallel_execution:
  enabled: true
  max_parallel: 2
  mode: auto
  conditions:
    max_confidence_diff: 0.10  # Run parallel if candidates are close
    min_candidates: 2
    max_candidates: 3
  aggregation:
    method: merged  # consensus, majority, first_success, all, merged
    timeout: 300
```

### Execute in Parallel

```ruby
require 'vibe/skill_router/parallel_executor'

executor = Vibe::SkillRouter::ParallelExecutor.new(
  config: {
    'enabled' => true,
    'max_parallel' => 2,
    'aggregation' => {
      'method' => 'merged',
      'timeout' => 300
    }
  }
)

candidates = [
  { skill: 'skill-a', confidence: 0.85 },
  { skill: 'skill-b', confidence: 0.82 }
]

# Define skill executor
skill_executor = ->(candidate, context) {
  # Execute the skill (in real implementation)
  {
    skill: candidate[:skill],
    insights: ["Insight from #{candidate[:skill]}"],
    recommendation: "Recommendation from #{candidate[:skill]}"
  }
}

# Execute in parallel
result = executor.execute(candidates, executor: skill_executor, context: {})

case result[:status]
when :merged
  puts "Merged insights from #{result[:participants]} skills:"
  result[:insights].each { |i| puts "  - #{i}" }
  puts "Best match: #{result[:best_match][:candidate][:skill]}"
when :consensus
  puts "All #{result[:participants]} skills agreed!"
when :majority
  puts "#{(result[:consensus_rate] * 100).round}% consensus"
end
```

---

## Custom Configuration

### Project-Level Override

```yaml
# .vibe/overlay.yaml
skill_selection:
  candidate_selection:
    auto_select_threshold: 0.20  # More aggressive auto-selection
    max_candidates: 4            # Show more options
  
  preference_learning:
    enabled: true
    dimensions:
      consistency:
        weight: 0.5  # Weight consistency more heavily
        min_samples: 3  # Learn faster
  
  parallel_execution:
    enabled: false  # Disable parallel for this project
    fallback_strategy: ask_user
```

### Platform-Specific Override

```yaml
# core/policies/skill-selection.yaml
platform_overrides:
  claude-code:
    parallel_execution:
      enabled: false  # Claude Code doesn't support true parallelism
      fallback_strategy: ask_user
  
  opencode:
    parallel_execution:
      enabled: true
      max_parallel: 3  # OpenCode can handle more
```

---

## CLI Integration

### Interactive Routing

```bash
# Start interactive routing session
vibe route --interactive

# => 🎯 智能 Skill 路由
# => ========================================
# => 
# => 请输入你的需求 (或按 Enter 退出):
# => > 帮我调试
# => 
# => 📥 输入: 帮我调试
# => ----------------------------------------
# => 🔥 匹配到技能: systematic-debugging
# =>    来源: builtin
# =>    原因: Algorithm match: ...
```

### Validate Configuration

```bash
vibe route-validate

# => 🔍 验证技能路由配置...
# => 
# => ✅ 所有路由组件可用
# => 
# => 🎉 配置验证通过！
# => 
# => 配置摘要:
# =>   • 最大候选数: 3
# =>   • 自动选择阈值: 0.15
# =>   • 偏好学习: 启用
# =>   • 并行执行: 启用
```

---

## Error Handling

### Handle No Match

```ruby
result = router.route("今天天气怎么样")

unless result[:matched]
  puts "No match found: #{result[:reason]}"
  
  if result[:suggestions]
    puts "Suggestions:"
    result[:suggestions].each { |s| puts "  - #{s[:skill]}" }
  end
end
```

### Handle Parallel Timeout

```ruby
result = executor.execute(candidates, executor: skill_executor)

if result[:status] == :merged && result[:failed] > 0
  puts "Warning: #{result[:failed]} skills timed out"
  puts "Partial results returned"
end
```

---

## Best Practices

### 1. Provide Context When Available

```ruby
# Good: With context
result = router.route("优化这个函数", {
  file_type: "ruby",
  recent_files: ["app/services/user_service.rb"]
})

# Less optimal: Without context
result = router.route("优化这个函数")
```

### 2. Record User Satisfaction

```ruby
# After skill execution
begin
  execute_skill(result[:skill])
  learner.record_satisfaction(result[:skill], true)
rescue => e
  learner.record_satisfaction(result[:skill], false)
end
```

### 3. Use Appropriate Aggregation Strategy

```ruby
# For critical decisions: require consensus
config = { 'aggregation' => { 'method' => 'consensus' } }

# For exploration: get all perspectives
config = { 'aggregation' => { 'method' => 'all' } }

# For speed: first successful result
config = { 'aggregation' => { 'method' => 'first_success' } }

# Default: merged insights
config = { 'aggregation' => { 'method' => 'merged' } }
```

---

## Troubleshooting

### Low Routing Accuracy

**Problem**: Skills not matching correctly

**Solutions**:
1. Check AI triage is enabled: `vibe route-validate`
2. Verify skill registry is up to date: `vibe skills discover`
3. Review routing logs in `.vibe/cache/`

### Preference Learning Not Working

**Problem**: Preferences not being applied

**Solutions**:
1. Check preference file exists: `.vibe/skill-preferences.yaml`
2. Verify enough samples exist (min_samples: 5 for consistency)
3. Check enabled: `preference_learning.enabled: true`

### Parallel Execution Issues

**Problem**: Parallel execution timing out

**Solutions**:
1. Increase timeout: `aggregation.timeout: 600`
2. Reduce max_parallel: `max_parallel: 1`
3. Change on_timeout strategy: `on_timeout: return_partial`
