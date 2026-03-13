# Session Management for OpenCode

## Current Status

⚠️ **OpenCode does not currently support automatic session-end hooks like Claude Code.**

OpenCode's plugin system provides event listeners, but lacks a dedicated `session.end` or `session.exit` event that would allow us to prompt users before they close the application.

## Why No Automatic Hook?

1. **No Exit Event** - OpenCode doesn't have a `Stop` hook equivalent
2. **Different Architecture** - Uses JavaScript plugins instead of shell hooks
3. **Timing Issues** - `session.deleted` event may fire after the session is already closed

## Recommended Alternatives

### Option 1: Semantic Triggers (Recommended)

The existing semantic trigger system **already works** in OpenCode. Simply express your intent to exit:

```
You: "保存一下，我要走了"
AI: [Automatically triggers session-end]

You: "Save progress, I'm heading out"
AI: [Automatically triggers session-end]
```

**Advantages:**
- ✅ Already implemented
- ✅ No additional setup required
- ✅ Natural language interface
- ✅ Works consistently

### Option 2: Custom Exit Command

Create a custom command for saving before exit.

**Setup:**

Create `.opencode/commands/save-exit.md`:

```markdown
---
description: Save session progress before exiting
---

Please execute the following steps:

1. Trigger the session-end skill to save my progress
2. Update memory/session.md with current work
3. Record any lessons learned
4. Then remind me that I can now safely exit

After completing these steps, tell me: "✅ Session saved. You can now exit safely."
```

**Usage:**

```
You: /save-exit
AI: [Executes session-end workflow]
AI: ✅ Session saved. You can now exit safely.
You: [Close OpenCode]
```

**Advantages:**
- ✅ Simple to implement
- ✅ Explicit and clear
- ✅ No plugin required
- ✅ Easy to customize

### Option 3: Manual Workflow

Simply remember to save before exiting:

```
You: /session-end
AI: [Saves progress]
You: [Close OpenCode]
```

## Comparison with Claude Code

| Feature | Claude Code | OpenCode |
|---------|------------|----------|
| **Automatic Prompt** | ✅ Yes (via hook) | ❌ No |
| **Semantic Trigger** | ✅ Yes | ✅ Yes |
| **Custom Command** | ✅ Yes | ✅ Yes |
| **Manual Trigger** | ✅ Yes | ✅ Yes |

## Future Possibilities

We are monitoring OpenCode's development for:

1. **Dedicated Exit Event** - A proper `session.end` or `session.exit` event
2. **Plugin Maturity** - More stable plugin API
3. **Community Solutions** - Third-party plugins that solve this problem

If OpenCode adds better exit event support in the future, we will implement an automatic hook similar to Claude Code.

## Feedback

If you're an OpenCode user and this feature is important to you:

1. Open an issue in this repository
2. Request exit event support from the OpenCode team
3. Share your use case and workflow needs

Your feedback helps us prioritize future development.

## Related Documentation

- [Session End Skill](../skills/session-end/SKILL.md)
- [Memory Management](../rules/memory-flush.md)
- [OpenCode Commands Documentation](https://opencode.ai/docs/zh-cn/commands)
- [OpenCode Plugins Documentation](https://opencode.ai/docs/zh-cn/plugins)
