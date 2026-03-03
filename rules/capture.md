# Capture Mechanisms

> Trigger rules. Detailed templates and formats → `Read docs/capture-templates.md`

## Execution Priority (All capture rules' precondition)

**When there's an active task**:
1. Complete current task first
2. Capture actions deferred until task completion
3. Mark with `💡 Note for later: [one line]`

**When no active task**: Trigger all capture rules normally

**Sub-task boundary check**: After resolving a blocking issue (>10min or >3 debug rounds), mark `📝 Record later: [issue summary]` before returning to main task

---

## External Content Processing (Mandatory)

**Trigger**: User shares any URL / screenshot / pasted content

**Flow**: Extract value → Action suggestion → Interaction suggestion

**Output (skip line if no value)**:
```
📌 **Value**: [Core insight]
📝 **Action**: [Specific suggestion]
🐦 **Interact**: [Quote tweet/comment/repost] + comment template
```

**Quote Decision**: Analyze original post metrics + audience match → ✅ Worth quoting / ⏭️ Just absorb
**Upgrade**: User says "detailed analysis" → run deep analysis framework

---

## Other Capture Triggers (signal → one-line prompt)

| Type | Signal | Prompt format |
|------|--------|--------------|
| Tweet seed | Counter-intuitive discovery, tool insight, unique perspective | `💡 Tweet seed: [summary]` |
| Workflow optimization | Repetitive operation, inefficiency, new tool | `⚙️ Workflow optimization: [summary]` |
| Life record | Health/family/finance/life events | `📝 Life record: [summary]` |
| Experience deposit | Stuck >15min, non-obvious choice, cognitive upgrade | `📝 Experience deposit: [summary]` |
| Referral opportunity | New platform signup, tool recommendation | `💰 Referral opportunity: [product name]` |

> Storage locations and detailed templates for each type → `Read docs/capture-templates.md`

---

## Content Platform Guardrails

> Full rules → `Read docs/x-guardrails.md`

- Post contains affiliate link → auto-attach compliance disclosure
- Daily: 3-4 original posts, <3-4 quotes, total ≤8
- Quotes must add independent perspective, only select high-performing content

---

*Compact version | Detailed templates: docs/capture-templates.md*
