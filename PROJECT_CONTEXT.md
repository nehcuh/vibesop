# Project Context

## Session Handoff

<!-- handoff:start -->
### 2026-03-22 下午（本次会话）
- **深度评审 → 优化**: 覆盖率 33.97% → 37.61%（+149 tests，591 → 740 runs），修复 5 个真实 bug
- **关键 bug 修复**: grader `determine_grade` Symbol/String 类型不匹配（warning 分支从未触发）、CJK token 低估 3 倍（0.5 → 1.5）、skill_manager splat TypeError、trigger_manager 状态注入不可测
- **OpenCode 验证**: 6 项对齐测试全通过，与 Claude Code 功能对等
- **文档修复**: 模块数 22→50+、测试数 289/273→740、skills 目录补全 4 项、CHANGELOG 补入 bug 修复
- **当前状态**: main 分支干净，已推送 origin，工作区无遗留
- **Next**: Q2 路线图 Phase 2（Token 优化）或 Phase 6（RIPER/Parry 社区最佳实践）

### 2026-03-22 上午
- 4项评审改进完成：SessionAnalyzer 格式版本检测、InstinctManager 权重可配置、Grader token 预算、vibe onboard 命令
- improve/review-suggestions 已合并，README/CHANGELOG 已同步
<!-- handoff:end -->

### 2026-03-18
- **完成**: Windows 原生支持（cmd.exe 批处理）、项目改名 VibeSOP、Instinct 学习系统（Phase 1）、Quick Start 重写、文档全面同步
- **关键决策**: Instinct 存储用 YAML（Git 友好）、Windows 用文件复制替代 symlink、置信度算法 60/30/10 权重
- **测试状态**: 324 tests, 1001 assertions, 0 failures
- **教训**: 功能开发必须同步更新 7 处文档（已记录到 MEMORY.md）
- **下一步**: 从 docs/roadmap-2026-q2.md 选择 Phase 2（Token 优化）或 Phase 6（RIPER/Parry）开始
- **生态研究**: 已分析 everything-claude-code，结论保存在 memory/ecosystem-research.md

