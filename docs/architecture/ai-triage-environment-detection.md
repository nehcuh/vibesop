# AI Triage Environment Detection

## Overview

The AI Triage Layer now intelligently detects its runtime environment and adjusts its behavior accordingly.

## Runtime Environments

### 1. Claude Code (Internal)

**Detection**: Environment variables `CLAUDECODE=1` or `CLAUDE_CODE_ENTRYPOINT=cli`

**Behavior**: AI Triage is **disabled by default**

```
🤖 AI Triage Layer:
   Status: ❌ Disabled
   Reason: Running inside Claude Code - using built-in reasoning.
```

**Why?**
- Claude Code has powerful built-in reasoning (Opus/Sonnet)
- Using external API adds unnecessary latency and cost
- Algorithm-based routing (Layer 1-4) provides ~70% accuracy
- The AI agent itself can make intelligent routing decisions

**Override**: Set `VIBE_AI_TRIAGE_ENABLED=true` in `settings.json` to enable external AI triage

### 2. OpenCode

**Detection**: `.vibe/opencode/config.json` exists or `OPENCODE=1`

**Behavior**: AI Triage **enabled** (requires external model configuration)

**Why?**
- OpenCode may not have built-in fast models
- External AI provides the semantic understanding needed

### 3. Standalone CLI

**Detection**: No special environment detected

**Behavior**: AI Triage **enabled** (requires `ANTHROPIC_API_KEY` or `OPENAI_API_KEY`)

**Why?**
- No built-in AI available
- External AI is the primary routing mechanism

## Layer Behavior

### When AI Triage is Enabled (OpenCode/Standalone)

```
User Request
    │
    ▼
┌─────────────────────────────────────┐
│ Layer 0: AI Semantic Triage         │ ← External API (Haiku/GPT)
│ - 95% accuracy with AI              │
│ - Multi-level cache (70%+ hit)      │
└─────────────────────────────────────┘
    │
    ▼ (fallback if disabled/failed)
┌─────────────────────────────────────┐
│ Layer 1-4: Algorithm-based Routing  │
│ - Explicit → Scenario → Semantic → Fuzzy
└─────────────────────────────────────┘
```

### When AI Triage is Disabled (Claude Code default)

```
User Request
    │
    ▼
┌─────────────────────────────────────┐
│ Layer 1-4: Algorithm-based Routing  │ ← Pure algorithm, no API call
│ - Explicit → Scenario → Semantic → Fuzzy
│ - ~70% accuracy, <10ms latency      │
└─────────────────────────────────────┘
    │
    ▼
Built-in Claude reasoning can interpret results
```

## Configuration

### Enable AI Triage in Claude Code

Add to `~/.claude/settings.json`:

```json
{
  "env": {
    "VIBE_AI_TRIAGE_ENABLED": "true"
  }
}
```

### Disable AI Triage Globally

```bash
export VIBE_AI_TRIAGE_ENABLED=false
```

### Configure Confidence Threshold

```bash
export VIBE_TRIAGE_CONFIDENCE=0.8  # Higher threshold = stricter matching
```

### Configure Cache TTL

```bash
export VIBE_TRIAGE_CACHE_TTL=86400  # 24 hours (default)
```

## Performance Comparison

| Environment | AI Triage | Latency | Accuracy | Cost |
|-------------|-----------|---------|----------|------|
| Claude Code (default) | ❌ Disabled | ~10ms | ~70% | $0 |
| Claude Code (enabled) | ✅ External | ~150ms | ~95% | ~$0.11/mo |
| OpenCode | ✅ Required | ~150ms | ~95% | ~$0.11/mo |
| Standalone CLI | ✅ Required | ~150ms | ~95% | ~$0.11/mo |

## View Current Status

```bash
$ vibe route --stats

📊 Skill Routing Statistics
==================================================

🤖 AI Triage Layer:
   Status: ❌ Disabled
   Reason: Running inside Claude Code - using built-in reasoning.
   Environment: claude_code

🖥️  Runtime Environment:
   Claude Code: ✅ Yes
   OpenCode: ❌ No
   Local Model: ✅ Yes
```

## Design Philosophy

**AI is a tool, not a requirement.**

The system should:
- ✅ Use external AI when it adds value (OpenCode, standalone CLI)
- ✅ Lean on built-in reasoning when available (Claude Code)
- ✅ Always provide fallback to algorithm-based routing
- ✅ Allow user override via environment variables

## Migration Guide

### For Claude Code Users

No changes needed! The system automatically detects you're in Claude Code and uses algorithm-based routing.

If you want to enable external AI triage:
1. Set `VIBE_AI_TRIAGE_ENABLED=true` in settings.json
2. Configure `ANTHROPIC_API_KEY` or use local model
3. Run `vibe route --stats` to verify

### For OpenCode Users

The system will use external AI by default. Configure:
1. Set `ANTHROPIC_API_KEY` or `OPENAI_API_KEY`
2. Optionally configure `LOCAL_MODEL_URL` for Ollama/LM Studio
3. Run `vibe route --stats` to verify

### For Standalone CLI Users

Same as OpenCode - configure an API key or local model.
