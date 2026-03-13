# Session Management Hook

## Overview

The pre-session-end hook automatically prompts you to save your session progress before exiting Claude Code, preventing accidental loss of work.

## Features

- **Automatic Trigger**: Activates when you type `/exit` in Claude Code
- **Smart Prompts**: Detects uncommitted changes and reminds you to save
- **Three Options**:
  - **[y] Yes** - Save session progress, then exit
  - **[n] No** - Exit without saving (⚠️ progress may be lost)
  - **[c] Cancel** - Cancel exit and continue working

## What Gets Saved

When you choose to save, the hook triggers the `session-end` skill which:

1. Updates `memory/session.md` with current progress
2. Records lessons learned in `memory/project-knowledge.md` (if any)
3. Updates `PROJECT_CONTEXT.md` handoff block (if file exists - optional)
4. Commits changes to git (if applicable)

## Installation

### Automatic Installation (Recommended)

The hook is automatically installed when you run:

```bash
vibe init --platform claude-code
```

### Manual Installation

If you need to install the hook manually:

```bash
# Run the installation script
./hooks/install.sh

# Or copy manually
mkdir -p ~/.claude/hooks
cp hooks/pre-session-end.sh ~/.claude/hooks/
chmod +x ~/.claude/hooks/pre-session-end.sh
```

Then add to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PreSessionEnd": [
      {
        "type": "command",
        "command": "~/.claude/hooks/pre-session-end.sh"
      }
    ]
  }
}
```

## Usage Example

```
You: /exit

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  Session End Detected
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

⚠️  You have uncommitted changes.

Would you like to save your session progress?

This will:
  • Update memory/session.md with current progress
  • Record any lessons learned in memory/project-knowledge.md
  • Update PROJECT_CONTEXT.md (if exists)

Options:
  [y] Yes, save session progress (recommended)
  [n] No, exit without saving
  [c] Cancel exit, continue working

Your choice [y/n/c]: y

✓ Triggering session-end...

[Claude Code executes session-end skill]
[Then exits]
```

## Verification

Check if the hook is installed:

```bash
# Check if hook file exists
ls -l ~/.claude/hooks/pre-session-end.sh

# Check if hook is configured
cat ~/.claude/settings.json | grep -A 5 "PreSessionEnd"

# Test the hook manually
~/.claude/hooks/pre-session-end.sh
```

## Troubleshooting

### Hook doesn't trigger on /exit

1. Verify hook is configured in settings.json
2. Check hook file permissions (should be executable)
3. Try running the hook manually to test

### Hook triggers but doesn't save

The hook returns exit code 42 to signal that session-end should be triggered. If Claude Code doesn't recognize this, you may need to manually call `/session-end` before `/exit`.

### Hook shows "Not in a git repository"

The hook checks if you're in a git repository. If not, it skips the save prompt. This is by design to avoid errors in non-git directories.

## Technical Details

### Exit Codes

- `0` - Allow exit (user chose "No")
- `1` - Cancel exit (user chose "Cancel" or invalid input)
- `42` - Trigger session-end before exit (user chose "Yes")

### Hook Location

- **Global**: `~/.claude/hooks/pre-session-end.sh`
- **Source**: `hooks/pre-session-end.sh` in this repository

### Configuration

The hook is configured in `~/.claude/settings.json` under the `hooks.PreSessionEnd` section.

## Related Documentation

- [Session End Skill](../skills/session-end/SKILL.md)
- [Memory Management](../rules/memory-flush.md)
- [Claude Code Hooks Documentation](https://docs.anthropic.com/en/docs/claude-code/hooks)

## Benefits

1. **Prevents Data Loss**: Never lose work by accidentally exiting
2. **Consistent Workflow**: Enforces good habits of saving progress
3. **Smart Defaults**: Recommends saving but allows flexibility
4. **Non-Intrusive**: Only triggers on explicit exit command
5. **Git-Aware**: Detects uncommitted changes and warns you

## Comparison with Manual Workflow

### Before (Manual)

```
You: "保存一下"
Claude: [Executes session-end]
You: /exit
```

### After (Automatic)

```
You: /exit
Hook: [Prompts to save]
You: y
Hook: [Triggers session-end automatically]
[Exits]
```

The hook saves you from having to remember to save before exiting!
