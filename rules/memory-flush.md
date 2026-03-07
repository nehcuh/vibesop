# Memory Management

> Optimize token usage by centralizing memory logging. Use 3 core layers.

## Core Memory Layers

1. **`memory/session.md`** (Hot layer: replaces today.md and active-tasks.json)
   - Purpose: Active tasks, progress, crash recovery.
   - Trigger: Non-trivial task starts or is completed. Auto-save frequently.

2. **`memory/project-knowledge.md`** (Warm layer: replaces MEMORY.md and patterns.md)
   - Purpose: Technical pitfalls, cross-project patterns, and project-specific architecture decisions.
   - Trigger: Counter-intuitive discoveries, architecture shifts, important external analysis.

3. **`memory/overview.md`** (Cold layer: replaces projects.md, goals.md, infra.md)
   - Purpose: High-level infrastructure, roadmap goals, and cross-project status.
   - Trigger: Low-frequency manual maintenance or major project milestones.

## Trigger Conditions
- **Non-trivial task starts** → Write to `session.md` immediately.
- Each code commit → Update `session.md` and (if project-level shifts occurred) `project-knowledge.md`.
- Architecture/strategy decision → Immediately record in `project-knowledge.md`.

## Exit Signals (Execute full Flush immediately)

"That's all for now" / "Done for today" / "I'm heading out" / "Going out" / "Talk later" / "Closing window" → Immediately run session-end flush.

Banned: Writing to 7+ splintered files. Keep token usage lean and consistent.
