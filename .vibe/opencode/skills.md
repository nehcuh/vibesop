# Portable skills

Generated target: `opencode`
Applied overlay: `none`

- `systematic-debugging` (`builtin`, `P0`, `mandatory`, support: `native-skill`) — Find root cause before attempting fixes.
- `verification-before-completion` (`builtin`, `P0`, `mandatory`, support: `native-skill`) — Require fresh verification evidence before claiming completion.
- `session-end` (`builtin`, `P0`, `mandatory`, support: `native-skill`) — Capture handoff, memory, and wrap-up state before ending a session.
- `planning-with-files` (`builtin`, `P1`, `suggest`, support: `native-skill`) — Use persistent files as working memory for complex multi-step tasks.
- `experience-evolution` (`builtin`, `P1`, `suggest`, support: `native-skill`) — Capture reusable lessons and patterns from repeated work.
- `instinct-learning` (`builtin`, `P1`, `suggest`, support: `native-skill`) — Automatic pattern extraction from sessions, build personal knowledge base.
- `skill-craft` (`builtin`, `P2`, `manual`, support: `native-skill`) — Craft personal skills from session history - transform successful workflows into reusable skills.
- `superpowers/tdd` (`superpowers`, `P2`, `suggest`, support: `external-skill`) — Test-driven development workflow with red-green-refactor cycle.
- `superpowers/brainstorm` (`superpowers`, `P2`, `manual`, support: `external-skill`) — Structured brainstorming and ideation sessions.
- `superpowers/refactor` (`superpowers`, `P2`, `suggest`, support: `external-skill`) — Systematic code refactoring with safety checks.
- `superpowers/debug` (`superpowers`, `P2`, `suggest`, support: `external-skill`) — Advanced debugging workflows beyond systematic-debugging.
- `superpowers/architect` (`superpowers`, `P2`, `manual`, support: `external-skill`) — System architecture design and documentation.
- `superpowers/review` (`superpowers`, `P2`, `suggest`, support: `external-skill`) — Code review with comprehensive quality checks.
- `superpowers/optimize` (`superpowers`, `P2`, `manual`, support: `external-skill`) — Performance optimization and profiling guidance.


## When to Use External Skills

The following external skills are automatically suggested in relevant scenarios:

| Scenario | Skill | Notes |
|----------|-------|-------|
| When implementing new functionality | `superpowers/tdd` | Auto-suggested when applicable |
| When refactoring code for better structure or maintainability | `superpowers/refactor` | Auto-suggested when applicable |
| When encountering bugs (note - builtin equivalent exists) | `superpowers/debug` | Auto-suggested when applicable |
| Before creating pull requests | `superpowers/review` | Auto-suggested when applicable |
| After accumulating 10+ sessions | `skill-craft` | Prompted to extract personal skills |
| After completing a project/feature | `skill-craft` | Prompted to review and formalize workflows |
| Weekly review time | `skill-craft` | Periodic reminder to craft skills |
