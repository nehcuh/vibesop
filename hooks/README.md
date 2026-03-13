# Claude Code Hooks

This directory contains hook scripts that enhance the workflow experience.

## Available Hooks

### `pre-session-end.sh`

**Purpose**: Prompts user to save session progress before exiting Claude Code.

**Trigger**: When user executes `/exit` command

**Behavior**:
1. Detects session end
2. Checks for uncommitted changes
3. Prompts user with three options:
   - **[y] Yes** - Trigger session-end skill to save progress
   - **[n] No** - Exit without saving (⚠️ progress may be lost)
   - **[c] Cancel** - Cancel exit and continue working

**What gets saved**:
- `memory/session.md` - Current session progress
- `memory/project-knowledge.md` - Lessons learned (if any)
- `PROJECT_CONTEXT.md` - Project handoff (if file exists)

## Installation

### Global Installation (Recommended)

Install the hook globally so it works for all projects:

```bash
# 1. Copy hook to Claude Code hooks directory
mkdir -p ~/.claude/hooks
cp hooks/pre-session-end.sh ~/.claude/hooks/

# 2. Make it executable
chmod +x ~/.claude/hooks/pre-session-end.sh

# 3. Configure in ~/.claude/settings.json
```

Add to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "~/.claude/hooks/pre-session-end.sh"
          }
        ]
      }
    ]
  }
}
```

### Project-Level Installation

Install the hook for this project only:

```bash
# 1. Ensure hook is executable
chmod +x hooks/pre-session-end.sh

# 2. Configure in project's .claude/settings.json
```

Add to `.claude/settings.json`:

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "./hooks/pre-session-end.sh"
          }
        ]
      }
    ]
  }
}
```

## Hook Exit Codes

The hook uses special exit codes to control behavior:

- `0` - Allow exit (user chose "No, exit without saving")
- `1` - Cancel exit (user chose "Cancel" or invalid input)
- `42` - Trigger session-end skill before exit (user chose "Yes, save")

## Testing

Test the hook without actually exiting:

```bash
# Run the hook script directly
./hooks/pre-session-end.sh

# Test with different responses
echo "y" | ./hooks/pre-session-end.sh  # Should exit with code 42
echo "n" | ./hooks/pre-session-end.sh  # Should exit with code 0
echo "c" | ./hooks/pre-session-end.sh  # Should exit with code 1
```

## Troubleshooting

### Hook doesn't trigger

1. Check if hook is configured in settings.json:
   ```bash
   cat ~/.claude/settings.json | grep -A 5 "Stop"
   ```

2. Verify hook script is executable:
   ```bash
   ls -l ~/.claude/hooks/pre-session-end.sh
   ```

3. Test hook manually:
   ```bash
   ~/.claude/hooks/pre-session-end.sh
   ```

### Hook triggers but doesn't save

The hook returns exit code 42 to signal that session-end should be triggered. Claude Code should then:
1. Recognize the exit code
2. Invoke the session-end skill
3. Wait for completion
4. Then exit

If this doesn't work, you may need to manually call `/session-end` before `/exit`.

## Related Documentation

- [Claude Code Hooks Documentation](https://docs.anthropic.com/en/docs/claude-code/hooks)
- [Session End Skill](../skills/session-end/SKILL.md)
- [Memory Management](../rules/memory-flush.md)

## References

- [Auto-Load Context Every Time](https://claudefa.st/blog/tools/hooks/session-lifecycle-hooks)
- [How to Use Claude Code Hooks for Automation](https://inventivehq.com/knowledge-base/claude/how-to-use-hooks-for-automation)
- [Claude Code Hooks · con/serve](https://con.github.io/serve/tools/ai-sessions/claude-code-hooks/)
