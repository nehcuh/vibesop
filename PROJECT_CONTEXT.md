# Project Context

## Session Handoff

<!-- handoff:start -->
### 2026-03-23 代码质量改进
- **完成**: 深度审查 + 质量改进全部推送 main（commit 0cc0313）
- **主要改动**:
  - `find_repo_root` 从 3 处重复 → 提取到 `Vibe::Utils` 模块
  - 新增 `test_integration_manager.rb`（31 tests）：覆盖率 24% → 73.53%
  - 新增 `test_skill_adapter.rb`（19 tests）：覆盖率 32% → 57.48%
  - 修复 `bin/vibe-wrapper` lint 问题
- **测试状态**: 1311 runs, 0 failures, 0 errors, 5 skips
- **覆盖率**: 行 76.1% / 分支 60.09%（两项均历史最高）
- **RuboCop**: 149 files, no offenses
- **下一步**: Q2 路线图继续——Phase 2 Token 优化 或 Phase 6 RIPER/Parry

### 2026-03-22 晚上
- 修复 `vibe init` 时只检查 superpowers 遗漏 gstack；integration_manager 始终显示集成状态摘要
- 已合并 improve/review-suggestions 分支；覆盖率 73.78%；1261 tests 全绿
<!-- handoff:end -->

### 2026-03-18
- **完成**: Windows 原生支持（cmd.exe 批处理）、项目改名 VibeSOP、Instinct 学习系统（Phase 1）、Quick Start 重写、文档全面同步
- **关键决策**: Instinct 存储用 YAML（Git 友好）、Windows 用文件复制替代 symlink、置信度算法 60/30/10 权重
- **测试状态**: 324 tests, 1001 assertions, 0 failures
- **教训**: 功能开发必须同步更新 7 处文档（已记录到 MEMORY.md）
- **下一步**: 从 docs/roadmap-2026-q2.md 选择 Phase 2（Token 优化）或 Phase 6（RIPER/Parry）开始
- **生态研究**: 已分析 everything-claude-code，结论保存在 memory/ecosystem-research.md

