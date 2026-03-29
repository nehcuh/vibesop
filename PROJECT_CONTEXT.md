# Project Context

## Session Handoff

<!-- handoff:start -->
### 2026-03-29 Bug 修复 + Instinct Skills 移植 — ✅ 1 commit

- **Bug 修复** (3 个 `vibe` 命令运行时错误):
  1. `skills list` TypeError — YAML string key 与 symbol key 混合 splat
  2. `route "帮我评审代码"` 无匹配 — 关键词缺少"评审"（只有"审查"）
  3. `skills check` NoMethodError — 重构后遗留 `manager.detector` 过期引用
- **Instinct Skills 移植**: `/learn`, `/learn-eval`, `/instinct-status`, `/instinct-export`, `/instinct-import`, `/evolve` 从文档落地为独立 Claude Code skills
- **多平台**: Skills 统一存放 `~/.config/skills/`，Claude Code 和 OpenCode 通过 symlink 共用
- **Commit**: 464af01, 已推送 origin/main

### 2026-03-28 VibeSOP 全面评审 + 修复 — ✅ 10 commits

- 修复套件全绿，拆分 3 个大类为 18 个子模块，72% coverage
- 详见 git log

<!-- handoff:end -->

## Project Overview

VibeSOP - AI 原生开发工作流编排系统
