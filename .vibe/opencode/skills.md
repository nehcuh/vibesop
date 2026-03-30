# Portable skills

Generated target: `opencode`
Applied overlay: `none`

- `systematic-debugging` (`builtin`, `P0`, `mandatory`, support: `native-skill`) — Find root cause before attempting fixes.
- `verification-before-completion` (`builtin`, `P0`, `mandatory`, support: `native-skill`) — Require fresh verification evidence before claiming completion.
- `session-end` (`builtin`, `P0`, `mandatory`, support: `native-skill`) — Capture handoff, memory, and wrap-up state before ending a session.
- `planning-with-files` (`builtin`, `P1`, `suggest`, support: `native-skill`) — Use persistent files as working memory for complex multi-step tasks.
- `experience-evolution` (`builtin`, `P1`, `suggest`, support: `native-skill`) — Capture reusable lessons and patterns from repeated work.
- `instinct-learning` (`builtin`, `P1`, `suggest`, support: `native-skill`) — Automatic pattern extraction from sessions with confidence scoring.
- `superpowers/tdd` (`superpowers`, `P2`, `suggest`, support: `external-skill`) — Test-driven development workflow with red-green-refactor cycle.
- `superpowers/brainstorm` (`superpowers`, `P2`, `manual`, support: `external-skill`) — Structured brainstorming and ideation sessions.
- `superpowers/refactor` (`superpowers`, `P2`, `suggest`, support: `external-skill`) — Systematic code refactoring with safety checks.
- `superpowers/debug` (`superpowers`, `P2`, `suggest`, support: `external-skill`) — Advanced debugging workflows beyond systematic-debugging.
- `superpowers/architect` (`superpowers`, `P2`, `manual`, support: `external-skill`) — System architecture design and documentation.
- `superpowers/review` (`superpowers`, `P2`, `suggest`, support: `external-skill`) — Code review with comprehensive quality checks.
- `superpowers/optimize` (`superpowers`, `P2`, `manual`, support: `external-skill`) — Performance optimization and profiling guidance.
- `gstack/office-hours` (`gstack`, `P2`, `suggest`, support: `external-skill`) — Product brainstorming with forcing questions — reframes problems before code is written.
- `gstack/plan-ceo-review` (`gstack`, `P2`, `suggest`, support: `external-skill`) — CEO/founder perspective review — find the 10-star product hiding in the request.
- `gstack/plan-eng-review` (`gstack`, `P2`, `suggest`, support: `external-skill`) — Engineering architecture review with diagrams, edge cases, and test plans.
- `gstack/plan-design-review` (`gstack`, `P2`, `manual`, support: `external-skill`) — Design review with 0-10 ratings per dimension and AI slop detection.
- `gstack/design-consultation` (`gstack`, `P2`, `manual`, support: `external-skill`) — Build a complete design system — research landscape, propose creative risks, generate mockups.
- `gstack/review` (`gstack`, `P2`, `suggest`, support: `external-skill`) — Pre-landing PR review — SQL safety, LLM trust boundaries, structural issues, auto-fixes.
- `gstack/design-review` (`gstack`, `P2`, `manual`, support: `external-skill`) — Visual design audit with fixes — audits implemented design and applies changes.
- `gstack/codex` (`gstack`, `P2`, `manual`, support: `external-skill`) — Cross-model second opinion via OpenAI Codex CLI — independent review from a different AI.
- `gstack/investigate` (`gstack`, `P2`, `suggest`, support: `external-skill`) — Systematic root-cause debugging with auto-freeze scope boundary.
- `gstack/qa` (`gstack`, `P2`, `suggest`, support: `external-skill`) — Browser QA — test app in real Chromium, find bugs, fix with atomic commits, generate regression tests.
- `gstack/qa-only` (`gstack`, `P2`, `manual`, support: `external-skill`) — QA reporting without code changes — pure bug report from browser testing.
- `gstack/browse` (`gstack`, `P2`, `manual`, support: `external-skill`) — Headless Chromium browser — navigate, click, screenshot, assert element states.
- `gstack/setup-browser-cookies` (`gstack`, `P2`, `manual`, support: `external-skill`) — Import cookies from real browser (Chrome, Arc, Brave, Edge) into headless session.
- `gstack/ship` (`gstack`, `P2`, `suggest`, support: `external-skill`) — Release workflow — sync main, run tests, audit coverage, push, open PR.
- `gstack/document-release` (`gstack`, `P2`, `suggest`, support: `external-skill`) — Auto-update all project docs to match what was just shipped.
- `gstack/retro` (`gstack`, `P2`, `manual`, support: `external-skill`) — Team-aware weekly retrospective with per-person breakdowns and shipping streaks.
- `gstack/careful` (`gstack`, `P2`, `suggest`, support: `external-skill`) — Safety guardrails — warns before destructive commands.
- `gstack/freeze` (`gstack`, `P2`, `manual`, support: `external-skill`) — Edit scope lock — restrict file edits to one directory during debugging.
- `gstack/guard` (`gstack`, `P2`, `manual`, support: `external-skill`) — Maximum safety — careful + freeze combined.
- `gstack/unfreeze` (`gstack`, `P2`, `manual`, support: `external-skill`) — Remove edit scope lock set by /freeze.
- `riper-workflow` (`builtin`, `P1`, `suggest`, support: `native-skill`) — Structured 5-phase development workflow (Research, Innovate, Plan, Execute, Review).
- `using-git-worktrees` (`builtin`, `P1`, `suggest`, support: `native-skill`) — Branch isolation using git worktrees for parallel task execution.
- `autonomous-experiment` (`builtin`, `P1`, `manual`, support: `native-skill`) — Autonomous experiment loop with predict-attribute cycle and multi-dimensional rubric evaluation.
- `skill-craft` (`builtin`, `P2`, `suggest`, support: `native-skill`) — Automatically detect recurring patterns and generate reusable skills.


## When to Use External Skills

The following external skills are automatically suggested in relevant scenarios:

| Scenario | Skill | Notes |
|----------|-------|-------|
| When implementing new functionality | `superpowers/tdd` | Auto-suggested when applicable |
| When refactoring code for better structure or maintainability | `superpowers/refactor` | Auto-suggested when applicable |
| When encountering bugs (note - builtin equivalent exists) | `superpowers/debug` | Auto-suggested when applicable |
| Before creating pull requests | `superpowers/review` | Auto-suggested when applicable |
| See documentation | `gstack/office-hours` | Auto-suggested when applicable |
| See documentation | `gstack/plan-ceo-review` | Auto-suggested when applicable |
| See documentation | `gstack/plan-eng-review` | Auto-suggested when applicable |
| See documentation | `gstack/review` | Auto-suggested when applicable |
| See documentation | `gstack/investigate` | Auto-suggested when applicable |
| See documentation | `gstack/qa` | Auto-suggested when applicable |
| See documentation | `gstack/ship` | Auto-suggested when applicable |
| See documentation | `gstack/document-release` | Auto-suggested when applicable |
| See documentation | `gstack/careful` | Auto-suggested when applicable |
