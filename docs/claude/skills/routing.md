# Skill Selection Guide

This guide helps you select the appropriate skill for different tasks. With the Smart Skill Router, most of this happens automatically, but you can always override the selection.

## Smart Skill Router (Auto)

The system now includes a **three-layer intelligent router** that automatically selects the best skill based on your request.

### How It Works

1. **Layer 1: Explicit Override** (highest priority)
   - You say: "用 gstack 评审代码" → Uses `/review` (gstack)
   - You say: "用 superpowers 调试" → Uses `/systematic-debugging` (superpowers)

2. **Layer 2: Scenario Matching**
   - System matches your request to predefined scenarios
   - Applies conflict resolution strategies
   - Example: "帮我评审" → matches `code_review` scenario → selects `/review` (gstack)

3. **Layer 3: Semantic Matching**
   - Compares your request to skill intents
   - Selects closest semantic match

### Quick Reference Table

| When you say... | Matched Scenario | Primary Skill |
|-----------------|------------------|---------------|
| "评审", "review", "检查代码" | `code_review` | `/review` (gstack) |
| "bug", "错误", "调试", "不工作" | `debugging` | `systematic-debugging` (builtin) |
| "规划", "计划", "复杂任务" | `planning` | `planning-with-files` (builtin) |
| "重构", "refactor" | `refactoring` | `/refactor` (superpowers) |
| "测试网站", "QA", "端到端" | `browser_qa` | `/qa` (gstack) |
| "发布", "ship", "创建 PR" | `shipping` | `/ship` (gstack) |
| "新功能", "新想法", "feature" | `product_thinking` | `/office-hours` (gstack) |

### Conflict Resolution

When multiple skill sources have matching skills:

| Scenario | Default Choice | Override |
|----------|---------------|----------|
| Debugging | `systematic-debugging` (builtin) | Say "用 gstack" for `/investigate` |
| Code Review | `/review` (gstack) | Say "用 superpowers" for `/receiving-code-review` |
| Planning | `planning-with-files` (builtin) | Say "用 gstack" for specific angles |
| Refactoring | `/refactor` (superpowers) | Say "用 gstack" for post-refactor review |
| TDD | `/test-driven-development` (superpowers) | Say "用 gstack" for `/qa` (E2E) |

---

## Manual Skill Selection

If you prefer manual selection or need specific functionality, use these guides:

## Naming Convention

- **gstack skills**: Use short names like `/review`, `/office-hours`, `/qa`
- **superpowers skills**: Use full names like `/brainstorming`, `/test-driven-development`
- **builtin skills**: Use names like `systematic-debugging`, `planning-with-files`

## Flow Charts

### Debugging Flow

1. **Default**: `systematic-debugging` (P0 mandatory, builtin) — find root cause first
2. **Need scope lock**: Consider `/investigate` (gstack) — auto-freezes scope
3. **Advanced workflow**: Consider `/systematic-debugging` (superpowers) — enhanced version

### Code Review Flow

1. **Pre-landing review**: Prefer `/review` (gstack) — SQL safety, LLM boundaries, auto-fixes
2. **Comprehensive check**: Consider `/receiving-code-review` or `/requesting-code-review` (superpowers)
3. **Cross-model review**: Consider `/codex` (gstack) — second opinion via Codex CLI

### Planning Flow

1. **General complex planning**: `planning-with-files` (builtin)
2. **CEO/product angle**: `/plan-ceo-review` (gstack)
3. **Architecture angle**: `/plan-eng-review` (gstack)
4. **Design/UX angle**: `/plan-design-review` (gstack)
5. **Full auto review**: `/autoplan` (gstack) — CEO → design → eng

### Product Thinking Flow

1. **Early ideation**: Prefer `/office-hours` (gstack) — YC-style reframing
2. **Design refinement**: Consider `/brainstorming` (superpowers)

### TDD Flow

1. **Unit testing**: `/test-driven-development` (superpowers) — red-green-refactor
2. **E2E browser testing**: `/qa` (gstack) — real Chromium testing

### Refactoring Flow

1. **Systematic refactoring**: `/refactor` (superpowers) — with safety checks
2. **Post-refactor review**: `/review` (gstack)

### Architecture Flow

1. **System design**: `/writing-plans` (superpowers) — create design docs
2. **Architecture review**: `/plan-eng-review` (gstack)

## Exclusive Skills (No Conflicts)

| Skill | Purpose |
|-------|---------|
| `/qa` | Browser QA in real Chromium |
| `/ship` | Release workflow — sync, test, push, open PR |
| `/guard` | Max safety (careful + freeze) |
| `/retro` | Weekly team retrospective |
| `/design-consultation` | Build design system from scratch |
| `/design-review` | Visual design audit |
| `/subagent-driven-development` | Parallel task execution |
| `/using-git-worktrees` | Branch isolation |
| `/writing-skills` | Craft personal skills |

## Override Keywords

- Say "用 gstack" to use gstack version
- Say "用 superpowers" to use superpowers version
- Say "用 builtin" to use builtin version
