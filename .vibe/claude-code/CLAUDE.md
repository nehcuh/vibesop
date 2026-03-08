# Project: Claude Code Workflow

> This project relies on the Global Profile in `~/.claude/CLAUDE.md`.
> Below are **project-specific** overrides and configurations.

## Project Context
- **Objective**: Manage the core AI governance framework `claude-code-workflow`.
- **Architecture**: Portable Core + Target Rendering.

## Memory Write Routing (Project Specific)
- All system evolution logs map strictly to:
  - `session.md` (active tasks and session progress)
  - `project-knowledge.md` (technical pitfalls, patterns, project domain knowledge)
  - `overview.md` (high-level goals, infrastructure)

## Delivery Standards
- Run automated validation pipelines before completion (`make validate`).
- Ensure generated targets like `AGENTS.md` exactly mirror `core/` state.
- Do not commit local `.vibe-target.json`.

# See ~/.claude/CLAUDE.md for base routing, capabilities, and safety definitions.
