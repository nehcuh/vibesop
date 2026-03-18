# VibeSOP 2026 Q2 路线图

**基于 everything-claude-code 生态研究的优化方案**

---

## 执行摘要

通过对 Claude Code 生态系统的深入研究（awesome-claude-code 社区资源 + everything-claude-code 获奖项目），我们识别出 VibeSOP 的关键差距和改进方向。本路线图聚焦于**吸收社区最佳实践**，同时**保持 VibeSOP 的架构优势**（可移植核心、轻量级、多平台）。

**研究来源**:
- **awesome-claude-code**: 社区精选工作流和工具（RIPER、parry、TDD Guard、AB Method 等）
- **everything-claude-code**: Anthropic Hackathon 获奖项目（50K+ stars，Instinct 学习系统）

---

## Phase 1: Instinct 学习系统（P0，4-6 周）

### 目标
实现自动化的模式学习系统，从静态记忆升级到智能学习。

### 当前差距
- **VibeSOP**: 静态 3 层记忆（session.md / project-knowledge.md / overview.md），手动维护
- **everything-claude-code**: 自动从 session 提取模式 → 置信度评分 → 可复用 instinct

### 实施计划

**Week 1-2: 架构设计**
- [ ] 设计 Instinct 数据结构
  ```yaml
  instinct:
    id: uuid
    pattern: "描述"
    confidence: 0.0-1.0
    source_sessions: [session_ids]
    usage_count: int
    success_rate: float
    created_at: timestamp
    tags: [domain, language, framework]
  ```
- [ ] 设计存储格式（YAML vs SQLite）
- [ ] 设计 API 接口（learn, eval, export, import, evolve）

**Week 3-4: 核心实现**
- [ ] 实现 `/learn` 命令
  - 分析当前 session 的 tool calls
  - 提取成功的模式（连续成功 > 3 次）
  - 生成 instinct 候选
- [ ] 实现 `/learn-eval` 命令
  - 评估 instinct 质量
  - 计算置信度（基于成功率、使用频率）
  - 用户确认后保存
- [ ] 实现 `/instinct-status` 命令
  - 列出所有 instinct + 置信度
  - 按 domain/tag 分组

**Week 5-6: 高级功能**
- [ ] 实现 `/instinct-export` 和 `/instinct-import`
  - 团队共享 instinct
  - 版本控制和冲突解决
- [ ] 实现 `/evolve` 命令
  - 聚合相关 instinct 成正式 skill
  - 自动生成 skill markdown
- [ ] 集成到现有 memory 系统
  - instinct 自动加载到 session context
  - 高置信度 instinct 优先

**交付物**
- `lib/vibe/instinct_manager.rb` - 核心逻辑
- `skills/instinct-learning/` - 技能定义
- `memory/instincts.yaml` - 存储文件
- 测试覆盖 > 80%

---

## Phase 2: Token 优化策略（P1，2-3 周）

### 目标
减少 token 消耗，提升响应速度和成本效率。

### 实施计划

**Week 1: System Prompt 精简**
- [ ] 分析当前 system prompt 的 token 占用
- [ ] 识别冗余内容（重复说明、过度解释）
- [ ] 实现动态 prompt 加载
  - 按需加载 rules（不是全部加载）
  - 基于任务类型选择相关 docs
- [ ] 实现 prompt 压缩技术
  - 移除多余空格和换行
  - 使用缩写（在不影响理解的前提下）

**Week 2: 模型选择策略**
- [ ] 实现任务复杂度评估
  - 简单任务 → Haiku
  - 中等任务 → Sonnet
  - 复杂任务 → Opus
- [ ] 实现自动降级机制
  - Opus 失败 → 重试 Sonnet
  - 成本预算控制
- [ ] 添加 token 使用统计
  - 每个 session 的 token 消耗
  - 按 skill/command 分组统计

**Week 3: 后台进程管理**
- [ ] 实现长时间运行任务的后台执行
- [ ] 实现进度通知机制
- [ ] 实现任务队列和优先级

**交付物**
- `lib/vibe/token_optimizer.rb`
- `lib/vibe/model_selector.rb`
- Token 使用仪表盘（CLI 输出）

---

## Phase 3: 验证循环增强（P1，2 周）

### 目标
从单次验证升级到持续验证循环，提升代码质量。

### 当前差距
- **VibeSOP**: `verification-before-completion` 技能，单次验证
- **everything-claude-code**: Checkpoint + 持续评估 + pass@k 指标

### 实施计划

**Week 1: Checkpoint 系统**
- [ ] 实现代码 checkpoint 机制
  - 每次重要变更自动创建 checkpoint
  - 支持回滚到任意 checkpoint
- [ ] 实现 checkpoint 对比
  - 显示两个 checkpoint 之间的差异
  - 评估质量变化

**Week 2: 持续评估**
- [ ] 实现 pass@k 指标
  - 生成 k 个候选解决方案
  - 运行测试，计算通过率
- [ ] 实现 Grader 类型
  - Unit test grader
  - Integration test grader
  - Linter grader
  - Security scanner grader
- [ ] 集成到 CI/CD

**交付物**
- `lib/vibe/checkpoint_manager.rb`
- `lib/vibe/grader.rb`
- 更新 `verification-before-completion` 技能

---

## Phase 4: 并行化增强（P2，2 周）

### 目标
提升多任务处理能力，缩短开发周期。

### 实施计划

**Week 1: Git Worktrees 集成**
- [ ] 增强现有 `using-git-worktrees` 技能
- [ ] 实现自动 worktree 创建
  - 为每个独立任务创建 worktree
  - 自动清理完成的 worktree
- [ ] 实现 worktree 状态监控

**Week 2: Cascade 方法**
- [ ] 实现任务依赖图
- [ ] 实现 cascade 执行
  - 任务 A 完成 → 自动触发任务 B
  - 并行执行无依赖任务
- [ ] 集成到 `dispatching-parallel-agents` 技能

**交付物**
- 增强的 `using-git-worktrees` 技能
- `lib/vibe/cascade_executor.rb`

---

## Phase 5: 跨平台工具链检测（P2，1 周）

### 目标
自动识别项目使用的工具链，提供更精准的建议。

### 实施计划

- [ ] 实现包管理器检测
  - npm, pnpm, yarn, bun (Node.js)
  - pip, poetry, pipenv (Python)
  - cargo (Rust)
  - go mod (Go)
- [ ] 实现构建工具检测
  - webpack, vite, rollup
  - gradle, maven
  - make, cmake
- [ ] 集成到 `platform_utils.rb`
- [ ] 更新相关技能使用检测结果

**交付物**
- `lib/vibe/toolchain_detector.rb`
- 更新 `platform_utils.rb`

---

## Phase 6: 社区最佳实践集成（P2，3-4 周）

### 目标
吸收 awesome-claude-code 社区的优秀工作流和工具。

### 6.1 RIPER 工作流（1 周）

**来源**: awesome-claude-code
**描述**: Research → Innovate → Plan → Execute → Review 五阶段工作流

**实施计划**:
- [ ] 创建 `skills/riper-workflow/` 技能
- [ ] 实现 5 个阶段的 prompt 模板
  - Research: 深度调研，收集信息
  - Innovate: 头脑风暴，生成创意
  - Plan: 制定详细计划
  - Execute: 执行实施
  - Review: 回顾总结
- [ ] 集成到 session 生命周期
- [ ] 添加阶段切换命令 `/riper-next`

**交付物**:
- `skills/riper-workflow/riper-workflow.md`
- `lib/vibe/riper_manager.rb`

### 6.2 Parry 安全扫描（1 周）

**来源**: awesome-claude-code
**描述**: Prompt injection 检测 hook，防止恶意输入

**实施计划**:
- [ ] 集成 parry 库（或实现简化版）
- [ ] 创建 `hooks/parry-scan.rb`
- [ ] 实现检测规则
  - 系统 prompt 泄露尝试
  - 角色劫持攻击
  - 指令注入模式
- [ ] 添加白名单机制
- [ ] 集成到 pre-session-start hook

**交付物**:
- `hooks/parry-scan.rb`
- `lib/vibe/security_scanner.rb`
- 安全规则配置文件

### 6.3 TDD Guard（1 周）

**来源**: awesome-claude-code
**描述**: Hooks 驱动的 TDD 强制执行

**实施计划**:
- [ ] 创建 `hooks/tdd-guard.rb`
- [ ] 实现规则
  - 代码变更必须有对应测试
  - 测试必须先于实现（可选）
  - 测试覆盖率阈值检查
- [ ] 集成到 pre-commit hook
- [ ] 添加配置选项（严格模式 vs 宽松模式）

**交付物**:
- `hooks/tdd-guard.rb`
- `lib/vibe/tdd_enforcer.rb`

### 6.4 Context Engineering Kit（可选，1 周）

**来源**: awesome-claude-code
**描述**: Token 高效的上下文管理技术

**实施计划**:
- [ ] 实现上下文压缩算法
  - 移除冗余信息
  - 智能摘要长文本
- [ ] 实现上下文优先级
  - 高优先级内容始终保留
  - 低优先级内容按需加载
- [ ] 集成到 memory 系统

**交付物**:
- `lib/vibe/context_optimizer.rb`

---

## 不实施的部分（明确排除）

### ❌ 108+ 技能库
**原因**: 维护成本过高，与 VibeSOP 的轻量级理念冲突
**替代方案**: 保持 ~20 个核心技能，通过 overlay 系统让用户自定义

### ❌ 57 个命令
**原因**: 过于碎片化，学习曲线陡峭
**替代方案**: 保持 8-10 个核心 CLI 命令，通过技能系统扩展

### ❌ 25 个专门化 Agent
**原因**: 大部分场景 3-5 个 agent 足够
**替代方案**: 保持 3 个内置 agent，通过 `agents/` 目录让用户自定义

---

## 成功指标

### Phase 1 (Instinct)
- [ ] 能够从 10 个 session 中提取至少 20 个有效 instinct
- [ ] Instinct 置信度评分准确率 > 80%
- [ ] 用户反馈：instinct 建议有用率 > 70%

### Phase 2 (Token)
- [ ] Token 消耗减少 30-50%
- [ ] 响应速度提升 20-30%
- [ ] 成本降低 30-40%

### Phase 3 (验证)
- [ ] pass@3 通过率 > 90%
- [ ] Checkpoint 回滚成功率 100%
- [ ] Bug 逃逸率降低 50%

### Phase 4 (并行)
- [ ] 多任务并行执行时间缩短 40-60%
- [ ] Worktree 自动管理成功率 > 95%

### Phase 5 (工具链)
- [ ] 工具链检测准确率 > 95%
- [ ] 支持 10+ 种主流工具链

### Phase 6 (社区实践)
- [ ] RIPER 工作流完整实现，5 个阶段流畅切换
- [ ] Parry 安全扫描误报率 < 5%
- [ ] TDD Guard 强制执行成功率 > 90%
- [ ] Context 压缩后 token 减少 20-30%

---

## 时间线

```
2026 Q2-Q3
├── Week 1-6:   Phase 1 - Instinct 学习系统 (P0)
├── Week 7-9:   Phase 2 - Token 优化 (P1)
├── Week 10-11: Phase 3 - 验证增强 (P1)
├── Week 12-13: Phase 4 - 并行化 (P2)
├── Week 14:    Phase 5 - 工具链检测 (P2)
└── Week 15-18: Phase 6 - 社区最佳实践 (P2)
    ├── Week 15: RIPER 工作流
    ├── Week 16: Parry 安全扫描
    ├── Week 17: TDD Guard
    └── Week 18: Context Engineering (可选)
```

**总计**: 18 周（约 4.5 个月）

---

## 风险与缓解

### 风险 1: Instinct 学习质量不稳定
**缓解**:
- 实现人工审核机制
- 低置信度 instinct 不自动应用
- 持续收集用户反馈优化算法

### 风险 2: Token 优化影响输出质量
**缓解**:
- A/B 测试优化前后的输出质量
- 保留完整 prompt 作为 fallback
- 用户可配置优化级别

### 风险 3: 并行化导致资源竞争
**缓解**:
- 实现资源限制（最多 N 个并行任务）
- 优先级队列
- 自动降级到串行执行

### 风险 4: 社区工具集成复杂度
**缓解**:
- 优先实现简化版，而非完整移植
- 保持模块化，可独立启用/禁用
- 充分测试后再合并到主分支

---

## 下一步行动

**立即开始**:
1. 创建 `feat/instinct-learning` 分支
2. 设计 Instinct 数据结构和 API
3. 实现 MVP（最小可行产品）
4. 内部测试和迭代

**需要决策**:
- [ ] Instinct 存储格式：YAML vs SQLite？
- [ ] Token 优化目标：30% 还是 50% 减少？
- [ ] 是否需要 Instinct 云同步功能？
- [ ] Phase 6 优先级：RIPER + parry 优先，还是全部实施？
- [ ] TDD Guard 默认模式：严格 vs 宽松？

---

**文档版本**: v1.0
**创建日期**: 2026-03-18
**负责人**: @nehcuh
**审核状态**: 待审核
