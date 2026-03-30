# Project Context

## Session Handoff

<!-- handoff:start -->
### 2026-03-30 晚上 [项目深入审查 + AI 路由优化 + 环境检测 + 经验反思]

**本次会话主要成果**:

### 1. 项目深入审查 ✅
- 确认 Claude Code 和 OpenCode 双平台支持已实现
- 发现并修复 5 个 AI 路由相关问题
- 创建了经验反思文档和实施检查清单

### 2. AI 路由功能优化 ✅
- **措辞修复**: CLAUDE.md 从 "When uncertain" 改为 "MANDATORY: ALWAYS"
- **用户选择模式**: AI 建议，用户决定（`vibe skills use <id>`）
- **环境智能检测**: Claude Code 内部禁用外部 API，使用内置推理
- **自动路由 Hook**: `hooks/pre-tool-use-auto-route.sh`
- **可观测性**: `vibe route --stats` 命令

### 3. 文档与反思 ✅
- `docs/architecture/ai-routing-retrospective.md`: AI 路由反复修改的经验教训
- `docs/implementation-checklist.md`: 避免再犯的检查清单
- `docs/architecture/ai-triage-environment-detection.md`: 环境检测架构文档
- P020: 记录到 `memory/project-knowledge.md`

### 关键教训 (P020)
1. 需求分析不足 — 没有定义所有运行环境场景
2. 过度承诺 — README 与实际不符
3. 边界条件滞后 — "无匹配"场景事后补充
4. 错误心智模型 — AI 决定而非建议
5. 环境盲点 — 未检查已有能力
6. 补丁式迭代 — 3+ 次修改同一区域

### 待观察项
- 观察环境检测在生产环境的表现
- 用户对"用户选择模式"的反馈

<!-- handoff:end -->
