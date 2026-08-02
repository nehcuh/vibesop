# Token 优化策略设计文档

**版本**: v1.0
**创建日期**: 2026-03-18
**状态**: 设计中

---

## 目标

减少 VibeSOP 的 token 消耗 30-50%，提升响应速度和成本效率。

## 背景

基于 everything-claude-code 的研究，token 优化是提升用户体验的关键因素：
- 降低 API 成本
- 加快响应速度
- 支持更长的 session
- 提升多轮对话能力

---

## 架构设计

### 1. TokenOptimizer 模块

**职责**:
- 分析和优化 prompt 内容
- 统计 token 使用情况
- 提供优化建议

**核心方法**:
```ruby
class TokenOptimizer
  # 分析 prompt 的 token 占用
  def analyze(prompt)
    {
      total_tokens: count_tokens(prompt),
      sections: breakdown_by_section(prompt),
      redundancies: detect_redundancies(prompt)
    }
  end

  # 优化 prompt 内容
  def optimize(prompt, options = {})
    prompt = remove_redundancies(prompt) if options[:remove_redundancies]
    prompt = compress_whitespace(prompt) if options[:compress]
    prompt = load_selective_rules(prompt) if options[:selective_rules]
    prompt
  end

  # 统计 session 的 token 使用
  def track_usage(session_id, tokens_used, context = {})
    # 记录到 memory/token_usage.yaml
  end
end
```

### 2. ModelSelector 模块

**职责**:
- 评估任务复杂度
- 选择合适的模型
- 实现自动降级

**任务复杂度评估标准**:
```ruby
COMPLEXITY_RULES = {
  simple: {
    # Haiku 适用场景
    conditions: [
      "单文件读取",
      "简单查询",
      "格式化输出",
      "状态检查"
    ],
    max_files: 3,
    max_lines: 100
  },
  medium: {
    # Sonnet 适用场景
    conditions: [
      "多文件编辑",
      "代码重构",
      "测试编写",
      "文档生成"
    ],
    max_files: 10,
    max_lines: 500
  },
  complex: {
    # Opus 适用场景
    conditions: [
      "架构设计",
      "复杂调试",
      "系统集成",
      "安全审计"
    ],
    max_files: Float::INFINITY,
    max_lines: Float::INFINITY
  }
}
```

**核心方法**:
```ruby
class ModelSelector
  # 评估任务复杂度
  def evaluate_complexity(task_description, context = {})
    score = 0
    score += count_files(context) * 10
    score += count_lines(context) * 0.1
    score += keyword_complexity(task_description)

    case score
    when 0..50 then :simple
    when 51..200 then :medium
    else :complex
    end
  end

  # 选择模型
  def select_model(complexity)
    MODEL_MAP[complexity]
  end

  # 自动降级
  def fallback_model(current_model, reason)
    # Opus -> Sonnet -> Haiku
  end
end
```

### 3. BackgroundTaskManager 模块

**职责**:
- 管理长时间运行的任务
- 提供进度通知
- 实现任务队列

**核心方法**:
```ruby
class BackgroundTaskManager
  # 提交后台任务
  def submit(task_id, command, options = {})
    task = {
      id: task_id,
      command: command,
      status: :pending,
      priority: options[:priority] || :normal,
      created_at: Time.now
    }
    queue.push(task)
    start_worker unless worker_running?
  end

  # 查询任务状态
  def status(task_id)
    tasks[task_id]
  end

  # 取消任务
  def cancel(task_id)
    tasks[task_id][:status] = :cancelled
  end
end
```

---

## 实施计划

### Week 1: System Prompt 精简

**任务**:
1. 实现 `TokenOptimizer` 基础类
2. 分析当前 CLAUDE.md 和 rules/ 的 token 占用
3. 实现动态规则加载（按需加载）
4. 实现 prompt 压缩（移除冗余空格）

**交付物**:
- `lib/vibe/token_optimizer.rb`
- `test/unit/test_token_optimizer.rb`
- Token 分析报告

### Week 2: 模型选择策略

**任务**:
1. 实现 `ModelSelector` 类
2. 定义任务复杂度评估规则
3. 实现自动降级机制
4. 添加 token 使用统计

**交付物**:
- `lib/vibe/model_selector.rb`
- `test/unit/test_model_selector.rb`
- `memory/token_usage.yaml` 格式定义

### Week 3: 后台进程管理

**任务**:
1. 实现 `BackgroundTaskManager` 类
2. 实现任务队列和优先级
3. 实现进度通知机制
4. 集成到现有 CLI

**交付物**:
- `lib/vibe/background_task_manager.rb`
- `test/unit/test_background_task_manager.rb`
- CLI 命令: `vibe tasks list/status/cancel`

---

## Token 统计格式

```yaml
# memory/token_usage.yaml
sessions:
  - id: "session-2026-03-18-001"
    date: 2026-03-18T10:00:00Z
    total_tokens: 15000
    breakdown:
      input: 8000
      output: 7000
    by_skill:
      instinct-learning: 3000
      systematic-debugging: 5000
      verification: 2000
    by_model:
      opus: 10000
      sonnet: 5000
      haiku: 0
    cost_usd: 0.45

statistics:
  total_sessions: 50
  total_tokens: 750000
  average_per_session: 15000
  total_cost_usd: 22.50
  optimization_savings: 35%  # 相比优化前
```

---

## 优化目标

### 短期目标（Week 1-3）
- [ ] 减少 system prompt token 占用 20%
- [ ] 实现基础的模型选择逻辑
- [ ] 实现 token 使用统计

### 中期目标（Month 2-3）
- [ ] 减少总体 token 消耗 30%
- [ ] 自动降级成功率 > 80%
- [ ] 后台任务支持 5+ 并发

### 长期目标（Q2 结束）
- [ ] 减少总体 token 消耗 50%
- [ ] 智能模型选择准确率 > 90%
- [ ] 用户可配置优化策略

---

## 风险和缓解

### 风险 1: 过度优化导致功能受损
**缓解**:
- 保留完整 prompt 作为 fallback
- 用户可配置优化级别（conservative/balanced/aggressive）
- 充分测试每个优化策略

### 风险 2: 模型选择不准确
**缓解**:
- 收集用户反馈，持续优化评估规则
- 允许用户手动指定模型
- 记录选择失败案例，自动学习

### 风险 3: 后台任务管理复杂度
**缓解**:
- 从简单的队列开始，逐步增强
- 限制并发数量，避免资源竞争
- 提供清晰的任务状态反馈

---

## 成功指标

1. **Token 减少率**: 相比优化前减少 30-50%
2. **响应速度**: 平均响应时间减少 20%
3. **成本节省**: API 成本降低 30-40%
4. **用户满意度**: 无功能退化投诉
5. **模型选择准确率**: > 85%

---

## 下一步

1. 创建 `feat/token-optimization` 分支 ✅
2. 实现 `TokenOptimizer` 基础类
3. 分析当前 token 占用情况
4. 开始 Week 1 任务
