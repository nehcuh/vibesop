# Task Routing Detailed Table (Tiers 2-4 + Cost Comparison)

> On-demand loading. Tier 1 (Sonnet evaluates escalation) stays in rules/behaviors.md.

## Tier 2: Opus Exclusive Scenarios

| Task Type | Route | Notes |
|-----------|-------|-------|
| Critical logic/secrets/credentials | **Opus exclusive** | Safety floor, never outsource |
| Data analysis/core metrics/business logic | **Opus exclusive** | Optional: Opus -> Codex verify |
| Critical code review | **Opus lead -> Codex audit** | Multi-model cross-check |
| New feature >50 lines (critical) | **Opus write -> Codex review** | Maker-checker |
| Bug fix (critical) | **Opus fix -> Codex verify** | Prevent regression |

## Tier 3: External Model Assistance

| Task Type | Route | Notes |
|-----------|-------|-------|
| Code review (non-critical) | **Sonnet -> Codex** | Codex deep reasoning |
| Complex refactor/cross-file changes | **Codex** | Suitable for >100 line non-sensitive refactors |
| Cross-verification/second opinion | **Codex** (fallback: alternative) | Different model family, independent verification |
| Simple queries/formatting/search | **Haiku (subagent)** | Fastest, cheapest |
| Batch text analysis/filtering | **Alternative model** | For high-frequency scenarios |

## Tier 4: Local Models — Free Compute Pool (Ollama, fallback)

**Principle: If a $0 model can do it, don't burn premium quota.**

| Task Type | Model | Method | Notes |
|-----------|-------|--------|-------|
| Commit message generation | Local 7B model | `curl localhost:11434/v1/...` | Replace main session generation |
| Simple text formatting/translation | Local 7B model | curl | Replace Haiku subagent |
| Diff classification (critical vs trivial) | Local 7B model | curl | Pre-filter before Codex review |
| Batch/non-critical tasks | Local agent | configured agent | Zero-cost batch processing |
| Offline work | Local model | ollama run | Only option when disconnected |

**Limitations**: 32K context, no MCP, weaker than Haiku. Complex tasks still need cloud models.
**Fallback**: Ollama not running -> `ollama serve &` or fall back to Haiku subagent.

## Model Cost Overview

| Tier | Model | Source | Monthly | Typical Scenario | Method | Status |
|------|-------|--------|---------|-----------------|--------|--------|
| **L1 Top** | Opus | Claude Max | $200-250 | Critical/complex reasoning | Main session | Active |
| **L2 Workhorse** | Sonnet | Claude Max | Included | Daily dev/analysis | Main/subagent | Active |
| **L3 Economy** | Haiku | Claude Max | Included | Simple queries/subagent | `Task(model="haiku")` | Active |
| **L3 Audit** | Codex (GPT) | ChatGPT Plus | $20 | Code review/cross-verify | MCP or CLI | Active |
| **L4 Local** | Ollama 7B | Local | $0 | Offline/simple/fallback | `curl localhost:11434` | Standby |

**Prompt Caching**: Anthropic API auto-enables, cache hits reduce cost 90%. Continuous conversations (<5min gap) work best.

---

*Customize models and costs based on your subscriptions and available tools.*
