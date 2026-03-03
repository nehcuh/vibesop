# Memory Flush

> Don't rely on user triggers — auto-save. User might close the window at any time.

## Trigger Conditions

- **Non-trivial task starts** → Immediately write today.md session header: `### SN (~HH:MM) [project] Working on XXX...` (crash recovery anchor, fill in details after completion)
- Each task completed → Update today.md
- Each code commit → Update PROJECT_CONTEXT.md
- Architecture/strategy decision → Immediately record in today.md
- Important external model analysis received → Record in patterns.md

## Exit Signals (Execute full Flush immediately)

"That's all for now" / "Done for today" / "I'm heading out" / "Going out" / "Talk later" / "Closing window" → Immediately run session-end

Banned: Waiting for /session-end to save / Batching saves / Assuming user will end normally
