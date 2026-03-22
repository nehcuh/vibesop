# Project Context

## Session Handoff

<!-- handoff:start -->
### 2026-03-22 14:22
- **深度评审**: 全面评审 VibeSOP 架构（可移植核心+目标适配器+生成器）、实现质量（22个Ruby模块，289个测试）、技能系统（注册表+适配器+检测器）、文档质量
- **配置验证**: 确认 OpenCode 配置正确加载（AGENTS.md + behavior-policies.md + safety.md），核心规则生效（ssot-first, verify-before-claim, root-cause-debugging）
- **功能分析**: vibe switch 包含技能自动检测（SkillDetector）+ 交互式配置入口（SkillAdapter.adapt_interactively）+ 配置持久化（.vibe/skills.yaml）
- **评审结论**: 生产就绪，架构优秀（4.7/5.0），复杂度有合理的设计考量，铁律文化是核心价值
- **Next**: 继续 Q2 路线图下一个 Phase（Token 优化或社区最佳实践）

### 2026-03-22 上午
- 4项评审改进完成：SessionAnalyzer 格式版本检测、InstinctManager 权重可配置、Grader token 预算、vibe onboard 命令
- 2 commits, +17 tests, README/CHANGELOG 同步
- 分支 improve/review-suggestions 待合并
<!-- handoff:end -->

### 2026-03-18
- **完成**: Windows 原生支持（cmd.exe 批处理）、项目改名 VibeSOP、Instinct 学习系统（Phase 1）、Quick Start 重写、文档全面同步
- **关键决策**: Instinct 存储用 YAML（Git 友好）、Windows 用文件复制替代 symlink、置信度算法 60/30/10 权重
- **测试状态**: 324 tests, 1001 assertions, 0 failures
- **教训**: 功能开发必须同步更新 7 处文档（已记录到 MEMORY.md）
- **下一步**: 从 docs/roadmap-2026-q2.md 选择 Phase 2（Token 优化）或 Phase 6（RIPER/Parry）开始
- **生态研究**: 已分析 everything-claude-code，结论保存在 memory/ecosystem-research.md

