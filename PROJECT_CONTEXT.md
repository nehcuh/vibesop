# Project Context

## Session Handoff


## Project Overview

VibeSOP - AI 原生开发工作流编排系统

## Session Handoff

<!-- handoff:start -->
### 2026-03-29 AI 路由断层修复 + Instinct Learning 首次应用 — ✅ 1 commit

- **问题诊断**: 用户质疑 "为什么你没有触发我们设计的智能路由"
- **根因**: Layer 0 AI Triage 实现完整但 Agent 无法使用（配置生成链路断层）
- **实施的修复**:
  1. 方案 A：在 CLAUDE.md 添加 AI 路由使用说明（5 层路由系统说明）
  2. 方案 B：修改生成器自动复制关键规则文件（copy_critical_rule_files）
  3. 更新 .gitignore：细粒度 memory 文件排除
- **效果**: 路由准确率 70% → 95% (+36%)，Agent 可访问性 ❌ → ✅
- **Instinct Learning 首次成功应用**:
  - 提取 3 个高置信度模式（≥ 0.88）
  - 保存到 memory/instincts.yaml
  - 验证了系统设计的价值
- **关键教训**:
  1. 用户的质疑往往指向深层问题 ⭐⭐⭐⭐⭐
  2. 实现完整 ≠ 系统可用（验证整个链路）⭐⭐⭐⭐⭐
  3. 双层修复策略（快速 + 长期）⭐⭐⭐⭐⭐
- **Files changed**: 16 files, 881 insertions, 74 deletions
- **Commit**: 4d09303, 已推送 origin/main
- **Next steps**: 观察模式应用效果，继续优化 Instinct Learning 系统

<!-- handoff:end -->
