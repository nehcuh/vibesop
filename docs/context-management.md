# Context Management Guide

## Overview

This document explains how the workflow keeps Claude Code effective across long conversations, multi-file tasks, and multi-day work.

The key distinction is:

- **Repo-local hot state** lives in files such as `memory/today.md`, `memory/active-tasks.json`, `memory/goals.md`, and `memory/projects.md`
- **Project-specific durable memory** may live in a routed `MEMORY.md` or `PROJECT_CONTEXT.md`, depending on how `CLAUDE.md` is configured

The goal is to preserve the right information in the right layer instead of loading everything into context at once.

## Understanding Context Compression

### What is Context Compression?

Claude Code automatically compresses earlier conversation turns as the session grows. In practice, that means:

- **Recent work stays available**
- **Older turns are summarized** to free space
- **Current file context is more likely to survive than old exploration**
- **You can keep working** without manually restarting the session

### When Does Compression Happen?

Compression is triggered by the system when the session becomes large enough that keeping the full raw history is inefficient.

**You cannot manually trigger compression**. The workflow should be resilient to it.

### What Tends to Survive?

After compression, Claude usually retains:

- Recent messages
- System and project instructions
- The current task framing
- Files that are still active in the working set

Details that are easier to lose:

- Earlier exploratory reads
- Long command outputs
- Intermediate debugging branches that no longer look active
- Older decisions that were never written back to repo files

## Layered Loading Architecture

The workflow uses layered loading so that only the minimum necessary context is active at any time.

### Layer 0: Entry Rules (`CLAUDE.md` + `rules/`)

Always loaded or assumed as the behavioral baseline:

- `CLAUDE.md` — entrypoint, SSOT table, loading index, memory routing
- `rules/behaviors.md` — core operating rules
- `rules/skill-triggers.md` — when to invoke reusable skills
- `rules/memory-flush.md` — auto-save and session-end behavior

This layer should stay compact and stable.

### Layer 1: Reference Docs (`docs/`)

Loaded on demand for a specific task:

- `docs/agents.md` — multi-model collaboration
- `docs/content-safety.md` — attribution and critical-content safeguards
- `docs/task-routing.md` — routing by capability and task complexity
- `docs/scaffolding-checkpoint.md` — stack and setup decisions
- `docs/behaviors-reference.md` — extended behavior details
- `docs/context-management.md` — compression recovery and memory strategy

This layer is where detail belongs. It should not all be loaded at once.

### Layer 2: Working State (`memory/` + project memory)

Updated frequently as work progresses:

- `memory/today.md` — daily progress and handoff
- `memory/active-tasks.json` — in-flight task registry
- `memory/goals.md` — cross-session goals
- `memory/projects.md` — cross-project summaries and pointers
- `patterns.md` — reusable lessons and pitfalls
- Optional project memory such as `PROJECT_CONTEXT.md` or routed `MEMORY.md`

This layer is the recovery surface after compression.

### Why This Matters

Without layering, every task pays the cost of loading rules, reference material, and historical state whether it is needed or not.

With layering:

- More room is left for the active task
- File reads are more targeted
- Recovery after compression is cheaper
- Long sessions degrade more gracefully

## RTK Integration: Command Output Compression

### What RTK Does

RTK (Reduce Toolkit) compresses **command outputs**, not the conversation itself.

Typical examples:

- `git status`, `git log`, `git diff`
- `npm test`, `pytest`, `cargo build`
- other long CLI outputs that would otherwise consume many tokens

### What RTK Does Not Do

RTK does **not**:

- replace Claude's own context compression
- compress file contents
- preserve lost reasoning automatically
- act as a memory system

Use RTK to reduce command-output cost, not as a substitute for writing decisions back to repo files.

## Post-Compression Recovery

### When to Recover

Recover context only when the current task becomes fuzzy. Signs include:

- You no longer remember why a file was opened
- A previous decision matters but is not in active context
- You know the work happened earlier in the session but cannot restate it confidently

### Recovery Ladder

#### Step 1: Search current task keywords

Use search first because it is the cheapest recovery method.

- `grep` exact names, errors, or symbols
- `file_glob` to find likely files
- read only the files that the search identifies

#### Step 2: Read `memory/today.md`

Use `memory/today.md` to recover:

- what was done in this session or day
- important decisions
- current blockers
- next steps

#### Step 3: Read the smallest durable state file that matches the need

Choose the narrowest durable source:

- `memory/projects.md` for cross-project overview and pointers
- `PROJECT_CONTEXT.md` for project-level status and architecture state
- routed project `MEMORY.md` when you need durable technical details, pitfalls, or file-location notes
- `patterns.md` for reusable lessons that apply across tasks

#### Step 4: Re-open only the specific files you still need

Once the narrative is recovered, go back to precise file reads instead of broad reloads.

### When Not to Recover

Do not spend tokens recovering context if:

- the task is self-contained
- the user already gave exact instructions
- the needed files are already open and sufficient
- the new request is unrelated to earlier work

**Principle**: recover only the missing piece, not the whole session.

## Best Practices

### For Users

#### 1. Keep each file doing one job

- `today.md` = daily progress and handoff
- `projects.md` = cross-project summaries and pointers
- `PROJECT_CONTEXT.md` = project status and architecture state
- project `MEMORY.md` (if used) = technical pitfalls, conventions, important file locations
- `patterns.md` = reusable lessons across tasks or projects

#### 2. Prefer durable write-back for durable knowledge

If a fact will matter tomorrow, write it to the right repo file instead of assuming the conversation will keep it alive.

#### 3. Let docs load on demand

Do not preload all docs for every task. Load the one document that fits the current question.

#### 4. Keep task boundaries clear

Starting a new topic with a short restatement of goal and constraints reduces future recovery cost.

### For Claude

#### 1. Write to the correct layer

- update `memory/today.md` for progress and handoff
- update `memory/active-tasks.json` for in-flight work
- update `patterns.md` for reusable lessons
- update `PROJECT_CONTEXT.md` or project `MEMORY.md` for project-specific durable context

#### 2. Read efficiently

- search before reading large files
- prefer targeted reads and line ranges
- avoid re-reading unchanged files without a reason

#### 3. Recover cheaply first

Start with search, then `today.md`, then the smallest durable state file that fits the question.

#### 4. Respect layer boundaries

Do not duplicate stable rules into daily memory, and do not turn daily logs into long-term archives.

## Common Scenarios

### Scenario 1: Long Debugging Session

**Problem**: a long debugging thread gets compressed and you lose the earlier branches of investigation.

**Good recovery pattern**:

1. Keep the current debugging trail summarized in `memory/today.md`
2. Move reusable findings into `patterns.md` or project `MEMORY.md`
3. After compression, recover from those notes instead of re-reading every command output

### Scenario 2: Multi-Day Feature Development

**Problem**: a feature spans several sessions and the same context has to be restored repeatedly.

**Good recovery pattern**:

1. End each session with an update to `memory/today.md`
2. Update `PROJECT_CONTEXT.md` when project-level status changes
3. Move stable technical context into routed `MEMORY.md` or `patterns.md` if it will matter again

### Scenario 3: Context-Heavy Code Review

**Problem**: a large diff is too expensive to hold in active context all at once.

**Good recovery pattern**:

1. Use RTK to compress large `git diff` output when available
2. Review files in logical groups
3. Summarize conclusions in `memory/today.md` or the relevant `PROJECT_CONTEXT.md`
4. Recover from those summaries instead of re-reading the full diff

### Scenario 4: Switching Between Projects

**Problem**: you move between multiple repos or sub-projects in one session.

**Good recovery pattern**:

1. Use `memory/projects.md` for the overview
2. Follow `CLAUDE.md` memory routes to the correct project `MEMORY.md` if one is configured
3. Read the relevant `PROJECT_CONTEXT.md` for project state
4. Keep only reusable cross-project lessons in `patterns.md`

## Practical Budgeting

The biggest token costs usually come from:

- always-loaded rules and instructions
- long conversations
- large file reads
- long command outputs

The workflow reduces that cost by:

- keeping Layer 0 compact
- loading reference docs only on demand
- writing durable context back to repo files
- using search before broad file reads

## Memory File Hygiene

Keep the recovery surface tidy:

- `today.md` can grow during the day, but reset it on daily cadence
- `projects.md` should stay summary-only
- project `MEMORY.md` files should be concise and technical
- `PROJECT_CONTEXT.md` should track active project state, not become a dump of every historical detail

If a memory file is getting large, split stable knowledge into better-scoped durable files rather than expanding one hot file forever.

## Troubleshooting

### “I lost context after compression”

Check in this order:

1. Search by task keywords
2. Read `memory/today.md`
3. Read `memory/projects.md`, `PROJECT_CONTEXT.md`, routed `MEMORY.md`, or `patterns.md` as appropriate

### “Claude keeps re-reading the same files”

Common cause:

- the file location or prior decision was never written back to a durable repo file

Fix:

- note key file locations in project memory or `patterns.md`
- summarize task state in `today.md`
- prefer targeted reads instead of broad reloading

### “Memory files are getting too large”

Fix:

1. move summaries to `projects.md`
2. keep `today.md` focused on active work
3. move reusable lessons to `patterns.md`
4. keep project-specific technical context in the project's own durable files

### “RTK is not reducing the cost enough”

Check:

1. whether the output is actually coming from a supported command
2. whether the real problem is conversation history rather than command output
3. whether important conclusions should be written back to repo files instead of repeatedly re-derived

## Related Documentation

- `CLAUDE.md` — loading index, SSOT ownership, memory routing
- `rules/behaviors.md` — core behavior and recovery triggers
- `rules/memory-flush.md` — auto-save triggers
- `docs/agents.md` — multi-model collaboration and project handoff
- `docs/integrations.md` — RTK setup and integration behavior

---

*Last updated: 2026-03-07*
