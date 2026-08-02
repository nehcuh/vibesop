# VibeSOP 2026 Q2 路线图

**基于 everything-claude-code 生态研究的优化方案**

---

## 执行摘要

通过对 Claude Code 生态系统的深入研究（awesome-claude-code 社区资源 + everything-claude-code 获奖项目），我们识别出 VibeSOP 的关键差距和改进方向。本路线图聚焦于**吸收社区最佳实践**，同时**保持 VibeSOP 的架构优势**（可移植核心、轻量级、多平台）。

**研究来源**:
- **awesome-claude-code**: 社区精选工作流和工具（RIPER、parry、TDD Guard、AB Method 等）
- **everything-claude-code**: Anthropic Hackathon 获奖项目（50K+ stars，Instinct 学习系统）

### 当前进度 (2026-03-20)

| Phase | 状态 | 完成度 | 交付物 |
|-------|------|--------|--------|
| Phase 1: Instinct 学习系统 | ✅ 已完成 | 95% | `lib/vibe/instinct_manager.rb`, `skills/instinct-learning/`, `memory/instincts.yaml` |
| Phase 2: Token 优化策略 | ✅ 已完成 | 95% | `lib/vibe/token_optimizer.rb`, `lib/vibe/model_selector.rb` |
| Phase 3: 验证循环增强 | ✅ 已完成 | 95% | `lib/vibe/checkpoint_manager.rb`, `lib/vibe/grader.rb` |
| Phase 4: 并行化增强 | ✅ 已完成 | 95% | `lib/vibe/cascade_executor.rb`, `lib/vibe/worktree_manager.rb` |
| Phase 5: 工具链检测 | ✅ 已完成 | 95% | `lib/vibe/toolchain_detector.rb` |
| Phase 6.1: RIPER 工作流 | ✅ 已完成 | 100% | `skills/riper-workflow/SKILL.md` |
| Phase 6.2: Parry 安全扫描 | ✅ 已完成 | 95% | `hooks/parry-scan.rb`, `lib/vibe/security_scanner.rb` |
| Phase 6.3: TDD Guard | ✅ 已完成 | 95% | `hooks/tdd-guard.rb`, `lib/vibe/tdd_enforcer.rb` |
| Phase 6.4: Context Engineering | ✅ 已完成 | 95% | `lib/vibe/context_optimizer.rb` |
| Phase 7: Skill Craft | ✅ 已完成 | 95% | `skills/skill-craft/SKILL.md`, `lib/vibe/session_analyzer.rb`, `lib/vibe/skill_generator.rb`, `lib/vibe/trigger_manager.rb`, `config/skill-craft.example.yml` |

**总计**: 44 个核心模块 (`lib/vibe/*.rb`)

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
- [x] 分析当前 system prompt 的 token 占用
- [x] 识别冗余内容（重复说明、过度解释）
- [x] 实现动态 prompt 加载
  - 按需加载 rules（不是全部加载）
  - 基于任务类型选择相关 docs
- [x] 实现 prompt 压缩技术
  - 移除多余空格和换行
  - 使用缩写（在不影响理解的前提下）

**Week 2: 模型选择策略**
- [x] 实现任务复杂度评估
  - 简单任务 → Haiku
  - 中等任务 → Sonnet
  - 复杂任务 → Opus
- [x] 实现自动降级机制
  - Opus 失败 → 重试 Sonnet
  - 成本预算控制
- [x] 添加 token 使用统计
  - 每个 session 的 token 消耗
  - 按 skill/command 分组统计

**Week 3: 后台进程管理**
- [x] 实现长时间运行任务的后台执行 (`background_task_manager.rb`)
- [x] 实现进度通知机制 (`progress_indicator.rb`)
- [x] 实现任务队列和优先级

**交付物**
- [x] `lib/vibe/token_optimizer.rb` - 187 行完整实现
- [x] `lib/vibe/model_selector.rb` - 166 行完整实现
- [x] `lib/vibe/context_optimizer.rb` - 上下文优化
- [x] Token 使用仪表盘（CLI 输出）

---

## Phase 3: 验证循环增强（P1，2 周）

### 目标
从单次验证升级到持续验证循环，提升代码质量。

### 当前差距
- **VibeSOP**: `verification-before-completion` 技能，单次验证
- **everything-claude-code**: Checkpoint + 持续评估 + pass@k 指标

### 实施计划

**Week 1: Checkpoint 系统**
- [x] 实现代码 checkpoint 机制
  - 每次重要变更自动创建 checkpoint
  - 支持回滚到任意 checkpoint
- [x] 实现 checkpoint 对比
  - 显示两个 checkpoint 之间的差异
  - 评估质量变化

**Week 2: 持续评估**
- [x] 实现 pass@k 指标
  - 生成 k 个候选解决方案
  - 运行测试，计算通过率
- [x] 实现 Grader 类型
  - Unit test grader
  - Integration test grader
  - Linter grader
  - Security scanner grader
- [x] 集成到 CI/CD

**交付物**
- [x] `lib/vibe/checkpoint_manager.rb` - 218 行完整实现
- [x] `lib/vibe/grader.rb` - 评分系统
- [x] 更新 `verification-before-completion` 技能

---

## Phase 4: 并行化增强（P2，2 周）

### 目标
提升多任务处理能力，缩短开发周期。

### 实施计划

**Week 1: Git Worktrees 集成**
- [x] 增强现有 `using-git-worktrees` 技能
- [x] 实现自动 worktree 创建
  - 为每个独立任务创建 worktree
  - 自动清理完成的 worktree
- [x] 实现 worktree 状态监控

**Week 2: Cascade 方法**
- [x] 实现任务依赖图
- [x] 实现 cascade 执行
  - 任务 A 完成 → 自动触发任务 B
  - 并行执行无依赖任务
- [x] 集成到 `dispatching-parallel-agents` 技能

**交付物**
- [x] `lib/vibe/worktree_manager.rb` - Git worktree 管理
- [x] `lib/vibe/cascade_executor.rb` - 240 行完整实现
- [x] `skills/using-git-worktrees/SKILL.md`
- 增强的 `using-git-worktrees` 技能
- `lib/vibe/cascade_executor.rb`

---

## Phase 5: 跨平台工具链检测（P2，1 周）

### 目标
自动识别项目使用的工具链，提供更精准的建议。

### 实施计划

- [x] 实现包管理器检测
  - npm, pnpm, yarn, bun (Node.js)
  - pip, poetry, pipenv (Python)
  - cargo (Rust)
  - go mod (Go)
  - bundler (Ruby)
- [x] 实现构建工具检测
  - webpack, vite, rollup
  - gradle, maven
  - make, cmake
- [ ] 集成到 `platform_utils.rb`
- [ ] 更新相关技能使用检测结果

**交付物**
- [x] `lib/vibe/toolchain_detector.rb` - 186 行完整实现
- [ ] 更新 `platform_utils.rb`（待集成）

---

## Phase 6: 社区最佳实践集成（P2，3-4 周）

### 目标
吸收 awesome-claude-code 社区的优秀工作流和工具。

### 6.1 RIPER 工作流（1 周）

**来源**: awesome-claude-code
**描述**: Research → Innovate → Plan → Execute → Review 五阶段工作流

**实施计划**:
- [x] 创建 `skills/riper-workflow/` 技能
- [x] 实现 5 个阶段的 prompt 模板
  - Research: 深度调研，收集信息
  - Innovate: 头脑风暴，生成创意
  - Plan: 制定详细计划
  - Execute: 执行实施
  - Review: 回顾总结
- [x] 集成到 session 生命周期
- [x] 添加阶段切换命令 `/riper-next`

**交付物**:
- [x] `skills/riper-workflow/SKILL.md` - 完整实现

### 6.2 Parry 安全扫描（1 周）

**来源**: awesome-claude-code
**描述**: Prompt injection 检测 hook，防止恶意输入

**实施计划**:
- [x] 实现简化版 Parry 扫描器
- [x] 创建 `hooks/parry-scan.rb`
- [x] 实现检测规则
  - 系统 prompt 泄露尝试
  - 角色劫持攻击
  - 指令注入模式
  - 数据提取尝试
  - 命令注入
- [x] 添加白名单机制
- [ ] 集成到 pre-session-start hook（待 Vibe CLI 框架）

**交付物**:
- [x] `hooks/parry-scan.rb` - 完整安全扫描实现
- [ ] `lib/vibe/security_scanner.rb`（待 Phase 2）
- [ ] 安全规则配置文件（已内嵌在 parry-scan.rb）

### 6.3 TDD Guard（1 周）

**来源**: awesome-claude-code
**描述**: Hooks 驱动的 TDD 强制执行

**实施计划**:
- [x] 创建 `hooks/tdd-guard.rb`
- [x] 实现规则
  - 代码变更必须有对应测试
  - 测试必须先于实现（可选，严格模式）
  - 测试覆盖率阈值检查
- [x] 集成到 pre-commit hook 逻辑
- [x] 添加配置选项（严格模式 vs 宽松模式）

**交付物**:
- [x] `hooks/tdd-guard.rb` - 完整 TDD 检查实现
- [x] `config/tdd-guard.example.yml` - 配置模板
- [ ] `lib/vibe/tdd_enforcer.rb`（待 Phase 2）

### 6.4 Context Engineering Kit（可选，1 周）

**来源**: awesome-claude-code
**描述**: Token 高效的上下文管理技术

**实施计划**:
- [x] 实现上下文压缩算法
  - 移除冗余信息
  - 智能摘要长文本
- [x] 实现上下文优先级
  - 高优先级内容始终保留
  - 低优先级内容按需加载
- [x] 集成到 memory 系统

**交付物**:
- [x] `lib/vibe/context_optimizer.rb` - 上下文优化器
- [x] 集成到 token_optimizer.rb

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

### Phase 7 (智能回顾与 Skill 生成)
- [ ] 模式识别准确率 > 85%
- [ ] 生成的 skill 用户采纳率 > 60%
- [ ] 触发时机满意度 > 90%
- [ ] 新生成的 skill 在后续 session 中使用率 > 40%

---

## 时间线

```
2026 Q2-Q4
├── Week 1-6:   Phase 1 - Instinct 学习系统 (P0)
├── Week 7-9:   Phase 2 - Token 优化 (P1)
├── Week 10-11: Phase 3 - 验证增强 (P1)
├── Week 12-13: Phase 4 - 并行化 (P2)
├── Week 14:    Phase 5 - 工具链检测 (P2)
├── Week 15-18: Phase 6 - 社区最佳实践 (P2)
│   ├── Week 15: RIPER 工作流
│   ├── Week 16: Parry 安全扫描
│   ├── Week 17: TDD Guard
│   └── Week 18: Context Engineering (可选)
└── Week 19-22: Phase 7 - 智能回顾与 Skill 生成 (P2) [待 Phase 1 完成后启动]
    ├── Week 19: 触发机制设计
    ├── Week 20: 历史分析引擎
    ├── Week 21: Skill 生成器
    └── Week 22: 集成与测试
```

**总计**: 22 周（约 5.5 个月）

**Phase 7 前置条件**: Phase 1 (Instinct 学习系统) 必须完成并稳定运行

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

## Phase 7: 智能回顾与 Skill 生成（P2，3-4 周）

### 目标
从历史对话中自动提炼个人专属 skill，实现"从实践到方法论"的进化。

### 背景与动机
用户在使用 Claude Code 的过程中，积累了大量成功的工作模式和解决方案。这些经验如果能够被系统性地提炼和固化，将形成独属于用户的个人 skill 库，极大提升未来工作效率。

### 核心功能

#### 1. 多场景触发机制
- **项目完成时触发**：检测到 git merge/push to main 后，提示用户回顾
- **累积触发**：累计 N 个 session（可配置，默认 10）后自动提示
- **定期触发**：每周/每月定期提示用户回顾（可配置）
- **主动触发**：用户可通过 `/skill-craft` 命令随时启动

#### 2. 交互式回顾流程
```
┌─────────────────────────────────────────────┐
│ 🎯 Skill Crafting Session                   │
├─────────────────────────────────────────────┤
│ 扫描最近 10 个 session...                    │
│ 发现 3 个高频成功模式:                        │
│                                             │
│ 1. API 错误重试模式 (出现 8 次, 成功率 95%)   │
│    - 指数退避重试                            │
│    - 最大重试 3 次                           │
│                                             │
│ 2. Git 提交前检查模式 (出现 12 次, 成功率 100%)│
│    - lint → test → commit                   │
│                                             │
│ 3. 调试日志分析模式 (出现 6 次, 成功率 83%)   │
│    - grep 关键错误 → 定位文件 → 修复         │
│                                             │
│ 选择要提炼为 skill 的模式: [1,2,3/a/all/n]   │
└─────────────────────────────────────────────┘
```

#### 3. 个性化 Skill 生成
- 基于用户习惯生成 SKILL.md
- 支持预览和编辑
- 自动注册到 skill 系统
- 支持版本控制和回滚

### 实施计划

**Week 1: 触发机制设计**
- [x] 设计触发条件检测器
  - 项目完成检测（git hooks）
  - Session 计数器
  - 定时任务调度
- [x] 实现触发提示 UI
- [x] 用户偏好配置（启用/禁用/频率）

**Week 2: 历史分析引擎**
- [x] 实现 session 历史扫描
- [x] 实现模式识别算法
  - 工具调用序列分析
  - 成功率统计
  - 频率计算
- [x] 实现模式聚类（相似模式合并）

**Week 3: Skill 生成器**
- [x] 设计 SKILL.md 模板
- [x] 实现 LLM 辅助的 skill 描述生成
- [x] 实现预览和编辑界面
- [x] 实现自动注册机制

**Week 4: 集成与测试**
- [x] 集成到现有 instinct-learning 系统
- [x] 与 session-end skill 协作
- [ ] 用户测试和反馈收集
- [x] 文档编写

### 交付物
- [x] `skills/skill-craft/SKILL.md` - 核心技能定义
- [x] `lib/vibe/session_analyzer.rb` - 历史分析引擎 (195 行)
- [x] `lib/vibe/skill_generator.rb` - Skill 生成器 (159 行)
- [x] `lib/vibe/trigger_manager.rb` - 触发机制管理 (160 行)
- [x] 配置文件 `config/skill-craft.example.yml`

### 成功指标
- [ ] 能够从 20 个 session 中识别出至少 5 个高质量模式
- [ ] 生成的 skill 用户满意度 > 80%
- [ ] 触发准确率 > 90%（不错过重要时刻，不过度打扰）
- [ ] 生成的 skill 在后续 session 中被有效使用 > 50%

### 与现有系统的关系
- **依赖**: instinct-learning（提供基础模式数据）
- **增强**: session-end（添加回顾提示）
- **输出**: 新的 personal skills 到 `~/.claude/skills/personal/`

---

## 下一步行动

**Phase 7 设计阶段已完成 (2026-03-20)**:
1. ✅ 创建 `skills/skill-craft/SKILL.md` - 核心技能定义
2. ✅ 设计触发机制（项目完成/session累积/定期/主动）
3. ✅ 设计历史分析流程（扫描/识别/聚类）
4. ✅ 设计 Skill 生成模板
5. ✅ 增强 `session-end` skill - 添加回顾提示
6. ✅ 创建配置模板 `config/skill-craft.yaml`
7. ✅ 注册到 `.vibe/opencode/skills.md`

**Phase 7 待实现（需要代码实现）**:
- [ ] `lib/vibe/session_analyzer.rb` - 历史分析引擎
- [ ] `lib/vibe/skill_generator.rb` - Skill 生成器
- [ ] `lib/vibe/trigger_manager.rb` - 触发机制管理
- [ ] 用户测试和反馈收集

**其他 Phase 待开始**:
- Phase 1: Instinct 学习系统（P0）
- Phase 2: Token 优化策略（P1）
- Phase 3: 验证循环增强（P1）
- Phase 4: 并行化增强（P2）
- Phase 5: 跨平台工具链检测（P2）
- Phase 6: 社区最佳实践集成（P2）

**需要决策**:
- [x] Instinct 存储格式：**YAML**（已决定）
- [ ] Token 优化目标：30% 还是 50% 减少？
- [ ] 是否需要 Instinct 云同步功能？
- [ ] Phase 6 优先级：RIPER + parry 优先，还是全部实施？
- [ ] TDD Guard 默认模式：严格 vs 宽松？
- [x] Phase 7 触发频率：**默认 10 个 session 后提示**（已决定）
- [ ] Phase 7 是否需要团队共享 personal skills？

---

**文档版本**: v1.1
**创建日期**: 2026-03-18
**最后更新**: 2026-03-20
**负责人**: @nehcuh
**审核状态**: Phase 7 设计完成，待代码实现
