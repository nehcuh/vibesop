# Project Claude Code Configuration

Generated from the portable `core/` spec with profile `claude-code-default`.
Applied overlay: `none`

Global workflow rules are loaded from `~/.claude/`. This file adds project-specific context only.

## Project Context

<!-- Describe your project: tech stack, architecture, key constraints -->

## Project-specific rules

<!-- Add rules that apply only to this project -->

## Skill Selection Guide

When multiple skills can handle the same task, follow this priority order:

### Naming Convention
- **gstack skills**: Use short names like `/review`, `/office-hours`, `/qa`
- **superpowers skills**: Use full names like `/brainstorming`, `/test-driven-development`
- **builtin skills**: Use names like `systematic-debugging`, `planning-with-files`

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

### Exclusive Skills (no conflicts)
- **Browser QA**: `/qa` (gstack) — real Chromium testing
- **Release automation**: `/ship` (gstack) — sync, test, push, open PR
- **Max safety**: `/guard` (gstack) — careful + freeze combined
- **Team retro**: `/retro` (gstack) — weekly team retrospective
- **Design system**: `/design-consultation` (gstack)
- **Visual audit**: `/design-review` (gstack)
- **Subagent parallel**: `/subagent-driven-development` (superpowers)
- **Git worktrees**: `/using-git-worktrees` (superpowers)
- **Skill writing**: `/writing-skills` (superpowers)

### Override Keywords
- Say "用 gstack" to use gstack version
- Say "用 superpowers" to use superpowers version
- Say "用 builtin" to use builtin version

## Reference docs

Supporting notes are under `.vibe/claude-code/`:
- `behavior-policies.md` — portable behavior baseline
- `safety.md` — safety policy
- `routing.md` — capability tier routing
- `task-routing.md` — task complexity routing
- `tools.md` — available modern CLI tools
- `skill-routing.yaml` — skill selection and conflict resolution
