# Claude Code 生态研究

**研究日期**: 2026-03-18

## 发现的项目

### 1. awesome-claude-code (hesreallyhim)
- **定位**: 社区资源目录（Awesome List）
- **内容**: 收录生态里的工具、技能包、hooks、命令等
- **价值**: 发现社区最佳实践

### 2. everything-claude-code (affaan-m)
- **定位**: 生产级性能优化框架
- **荣誉**: Anthropic Hackathon 获奖项目，50K+ stars
- **支持平台**: Claude Code, Cursor, OpenCode, Codex

---

## everything-claude-code 核心能力

### 规模
- **25 个专门化 Agent**
- **108+ 技能**（按领域组织）
- **57 个命令**（快速执行）
- **Hook 系统**（自动化）

### 关键特性

**1. Token 优化**
- 模型选择策略
- System prompt 精简
- 后台进程管理

**2. 记忆持久化**
- Hooks 自动保存/加载上下文
- 跨 session 连续性

**3. 持续学习**
- 从 session 中提取模式到可复用 instincts
- 置信度评分

**4. 验证循环**
- Checkpoint vs 持续评估
- Grader 类型
- pass@k 指标

**5. 并行化**
- Git worktrees
- Cascade 方法
- 多实例扩展

**6. 跨平台**
- Windows, macOS, Linux
- 自动包管理器检测（npm, pnpm, yarn, bun）

---

## 与 VibeSOP 的对比

| 维度 | everything-claude-code | VibeSOP |
|------|------------------------|---------|
| 定位 | 性能优化框架 | 多平台工作流 SOP |
| Agent 数量 | 25 个专门化 | 3 个内置（可扩展） |
| 技能数量 | 108+ | ~15 核心技能 |
| 命令数量 | 57 | ~8 CLI 命令 |
| 平台支持 | 4 个（Claude Code/Cursor/OpenCode/Codex） | 2 个（Claude Code/OpenCode，可扩展） |
| 架构 | 单体框架 | 可移植核心 + 生成器 |
| Windows 支持 | 有 | 原生 cmd.exe |
| 测试覆盖 | 未知 | 289 tests |
| 学习系统 | Instinct 提取 + 置信度 | 3 层记忆（session/knowledge/overview） |

---

## 值得吸收的能力

### 高优先级

**1. Instinct 学习系统**
- 从 session 中自动提取可复用模式
- 置信度评分机制
- 比我们的静态 memory 更智能

**2. Token 优化策略**
- System prompt 精简技术
- 模型选择策略
- 后台进程管理

**3. 验证循环系统**
- Checkpoint vs 持续评估
- pass@k 指标
- Grader 类型分类

**4. 并行化方法**
- Git worktrees 集成
- Cascade 方法
- 多实例扩展

### 中优先级

**5. 跨平台包管理器检测**
- 自动识别 npm/pnpm/yarn/bun
- 我们目前只有平台检测，没有工具链检测

**6. 专门化 Agent 库**
- 25 个 agent 可以参考其设计模式
- 但不需要全部照搬

---

## 最终判断

**everything-claude-code 的优势**：
- 更成熟（10+ 月迭代）
- 更大规模（108+ 技能）
- 更智能的学习系统（Instinct）
- 更完善的验证循环

**VibeSOP 的优势**：
- 更清晰的架构（可移植核心）
- 更好的测试覆盖
- 更灵活的平台扩展
- 原生 Windows 支持

**建议吸收方向**：
1. **Instinct 学习系统** — 这是最大的差距，应该优先实现
2. **Token 优化策略** — 实用性强
3. **验证循环系统** — 补充我们的 verification-before-completion
4. **并行化方法** — 补充我们的 dispatching-parallel-agents

**不建议照搬**：
- 108+ 技能太多，维护成本高
- 57 个命令过于碎片化
- 我们的 overlay 系统更灵活

---

## 下一步行动

1. 深入研究 Instinct 学习系统的实现
2. 设计 VibeSOP 的 Instinct 集成方案
3. 实现 Token 优化策略
4. 增强验证循环系统
