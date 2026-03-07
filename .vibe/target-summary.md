# Generated target summary

- Target: `kimi-code`
- Profile: `kimi-code-default`
- Profile maturity: `planned`
- Generated at: `2026-03-07T13:42:36Z`
- Applied overlay: `none`

## Capability mapping

- `critical_reasoner` → `kimi.k1.5-class`
- `workhorse_coder` → `kimi.default-class`
- `fast_router` → `kimi.fast-class`
- `independent_verifier` → `second-model.or.manual-review`
- `cheap_local` → `local.ollama-class`

## Overlay

- none

## Behavior policies

- `ssot-first` (`mandatory`) — Keep repository files as the single source of truth; tool-managed memory is cache.
- `verify-before-claim` (`mandatory`) — Never claim completion without fresh verification evidence.
- `capability-tier-routing` (`mandatory`) — Route by capability tier first, then resolve through the active provider profile.
- `reversible-small-batches` (`recommended`) — Prefer small, reversible, single-purpose changes over large mixed batches.
- `root-cause-debugging` (`mandatory`) — Investigate root cause before attempting fixes and reassess after repeated failures.
- `security-escalation` (`mandatory`) — Treat destructive commands, network egress, secret access, and obfuscation as security-sensitive actions.
- `record-reusable-learning` (`recommended`) — Record user corrections, repeated failures, and counter-intuitive discoveries for reuse.
- `sunday-rule` (`recommended`) — Batch workflow or system optimization separately from delivery work unless it blocks production.

## Skills

- `systematic-debugging` (`P0`, `mandatory`) — Find root cause before attempting fixes.
- `verification-before-completion` (`P0`, `mandatory`) — Require fresh verification evidence before claiming completion.
- `session-end` (`P0`, `mandatory`) — Capture handoff, memory, and wrap-up state before ending a session.
- `planning-with-files` (`P1`, `suggest`) — Use persistent files as working memory for complex multi-step tasks.
- `experience-evolution` (`P1`, `suggest`) — Capture reusable lessons and patterns from repeated work.
