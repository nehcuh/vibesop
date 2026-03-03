---
name: session-end
description: Session wrap-up - update handoff + commit + auto-record experience
version: 1.0.0
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
---

# Session End — Wrap-up Workflow

> Trigger: `/session-end` or exit signals ("that's all for now" / "heading out")

## Core Steps (5 steps)

### 1. Experience Recording

Review the session for valuable learnings:

**Recording threshold (must meet at least one)**:
- Reusability: Next time encountering similar problem, can look it up directly
- Counter-intuitive: Violates common assumptions
- High cost: Took >10 minutes cumulative

**Don't record**:
- One-shot small fixes
- Project-specific temporary config
- Issues already in patterns.md

### 2. today.md Hot Data Layer

Append to `memory/today.md`:
```markdown
### SN (HH:MM~) [project/topic]
- [1-2 sentences of what was done]
- [Important decisions/discoveries]
- [Next steps]
- [Recorded: yes/no - brief description]
```

### 2.5. goals.md + projects.md Status Refresh

**Identify projects touched in this session** (from today.md, changed files, conversation content).

**goals.md update**:
- **Completed** → Remove entry (today.md already has the record)
- **Progress made** → Update description
- **New important item discovered** → Add to current week (max 5 items)

**projects.md update** (only rows for touched projects):
- Metric changes → Update (e.g. follower count, stars, metrics)
- Status changes → Update (e.g. "not started" → "first version shipped")

### 2.7. active-tasks.json In-flight Task Update

Read `memory/active-tasks.json`, update based on session work:

**Rules**:
- Tasks progressed → Update `context`/`next_action`/`updated`
- New multi-session tasks → Append new entry
- Completed tasks → Remove (today.md has the record)
- Blocker resolved → Change `status` from `blocked` to `active`
- Stale (>14 days no update) → Remind user if still needed

### 3. PROJECT_CONTEXT.md Handoff

Update `<!-- handoff:start/end -->` block.

**Auto-trim (every execution)**:
- Keep only **latest + 1 previous** handoff block within markers
- Delete older handoffs (git history has full record)
- Target: SESSION_HANDOFF section ≤80 lines

### 4. Git Commit (when there are changes)

```bash
git add [specific files]  # Never git add .
git commit -m "[type]: [description]"
```

### 5. Content Mining (Optional)

**Condition**: today.md has ≥3 session records for the day.

Quick scan today.md for 1-2 findings with sharing potential (counter-intuitive / data-driven / pitfall-to-solution).

**Output (when found)**:
```
Content material: Found N shareable discoveries today
  1. [Title] — [one-line angle]
  2. [Title] — [one-line angle]
```

**Nothing found**: Skip silently.

## Output Format

```
Experience: [Recorded N items / None needed]
today.md updated
Task registry: [+N new / ~N updated / -N completed | Total N in-flight]
Handoff updated
Committed [N] files
Content material: [N items / none (<3 sessions)]
```
