# Vibe workflow for VS Code

Generated from the portable `core/` spec with profile `vscode-default`.## Optional Integrations

### Superpowers Skill Pack

**Status**: ❌ Not installed

Superpowers provides advanced skills for design refinement, TDD, debugging, and more.

**Installation for VS Code**:
```bash
Clone the repository
git clone https://github.com/obra/superpowers ~/superpowers

# For VS Code, manually register the skills in your tool's skill system
# or use the skill files from ~/superpowers/skills/
```

**Available skills**:
- `superpowers/tdd` — Test-driven development workflow
- `superpowers/brainstorm` — Structured brainstorming
- `superpowers/refactor` — Systematic refactoring
- `superpowers/debug` — Advanced debugging
- `superpowers/architect` — Architecture design
- `superpowers/review` — Code review workflow
- `superpowers/optimize` — Performance optimization


### RTK Token Optimizer

**Status**: ❌ Not installed

RTK is a CLI proxy that reduces LLM token consumption by 60-90% on common development commands.

**Installation**:
```bash
# macOS/Linux with Homebrew
brew install rtk

# Or build from source
cargo install --git https://github.com/rtk-ai/rtk

# Then configure
rtk init --global
```


**Note**: RTK works best with Claude Code. For VS Code, you may need to manually prefix commands with `rtk`.

Applied overlay: `none`

VS Code (Copilot Chat) instructions use these generated guidelines as the baseline.

## Non-negotiable rules

- `ssot-first` (`mandatory`) — Keep repository files as the single source of truth; tool-managed memory is cache.
- `verify-before-claim` (`mandatory`) — Never claim completion without fresh verification evidence.
- `capability-tier-routing` (`mandatory`) — Route by capability tier first, then resolve through the active provider profile.
- `reversible-small-batches` (`recommended`) — Prefer small, reversible, single-purpose changes over large mixed batches.
- `root-cause-debugging` (`mandatory`) — Investigate root cause before attempting fixes and reassess after repeated failures.
- `security-escalation` (`mandatory`) — Treat destructive commands, network egress, secret access, and obfuscation as security-sensitive actions.
- `record-reusable-learning` (`recommended`) — Record user corrections, repeated failures, and counter-intuitive discoveries for reuse.

## Capability routing

- `critical_reasoner` → `copilot.primary-model`
- `workhorse_coder` → `copilot.default-agent-model`
- `fast_router` → `copilot.fast-model`
- `independent_verifier` → `second-model.or.manual-review`
- `cheap_local` → `local.external-runner`

## Mandatory portable skills

- `systematic-debugging` (`P0`, `mandatory`) — Find root cause before attempting fixes.
- `verification-before-completion` (`P0`, `mandatory`) — Require fresh verification evidence before claiming completion.
- `session-end` (`P0`, `mandatory`) — Capture handoff, memory, and wrap-up state before ending a session.



## Safety floor

- `P0` — Surface as a strict system block in workspace settings or Copilot rules.
- `P1` — Require manual review or user confirmation in Copilot Chat.
- `P2` — Warn in Copilot Chat and continue.
