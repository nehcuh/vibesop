# External Tool Integrations

This document explains how the vibesop integrates with external tools and skill packs to enhance your development experience.

## Overview

The workflow supports three types of integrations:

1. **Skill Packs** - Collections of reusable skills (e.g., Superpowers)
2. **CLI Tools** - Command-line utilities that enhance workflow (e.g., RTK)
3. **Built-in Learning** - Automatic pattern extraction and knowledge management (Instinct Learning)

All integrations are defined in `core/integrations/` as YAML configuration files.

## Built-in Integrations

### Instinct Learning System

**Purpose**: Automatic pattern extraction from sessions with confidence scoring and team sharing.

**Status**: Built-in (no installation required)

**Commands**:
- `vibe instinct learn` — Extract or manually create reusable patterns
- `vibe instinct learn-eval` — Evaluate instinct quality and confidence
- `vibe instinct status` — View all instincts grouped by confidence level
- `vibe instinct export <file>` — Export instincts for team sharing
- `vibe instinct import <file>` — Import instincts with merge strategies
- `vibe instinct evolve <id>` — Upgrade high-quality instincts to formal skills

**Storage**: `memory/instincts.yaml`

**Integration with session-end**: Automatically extracts patterns at session end (Step 6).

**Documentation**: See `skills/instinct-learning/SKILL.md` and `docs/instinct-learning-design.md`.

## External Integrations

## Supported Integrations

### Superpowers Skill Pack

**Purpose**: Advanced skill pack providing design refinement, TDD enforcement, systematic debugging, and more.

**Installation**:
- Claude Code: `/plugin marketplace add obra/superpowers-marketplace` then `/plugin install superpowers@superpowers-marketplace`
- Cursor: `/plugin-add superpowers`
- Manual: Clone and symlink to your tool's skills directory
**Portable skill IDs exposed by this workflow**:
- `superpowers/brainstorm` - Structured brainstorming and ideation sessions
- `superpowers/tdd` - Test-driven development workflow with red-green-refactor
- `superpowers/refactor` - Systematic refactoring guidance
- `superpowers/debug` - Advanced debugging workflow
- `superpowers/architect` - Architecture design and documentation
- `superpowers/review` - Code review workflow
- `superpowers/optimize` - Performance optimization guidance

The installed Superpowers pack may use different native skill names such as `brainstorming` or `test-driven-development`. Generated target files use the portable IDs from `core/skills/registry.yaml` as the SSOT.

**Configuration**: `core/integrations/superpowers.yaml`

### RTK (Token Optimizer)

**Purpose**: CLI proxy tool that reduces LLM token consumption by 60-90% on common development commands.

**Installation**:
- macOS/Linux: `brew install rtk`
- Cargo: `cargo install --git https://github.com/rtk-ai/rtk`
- Manual download: [GitHub releases](https://github.com/rtk-ai/rtk/releases)

**Initialization**:
```bash
rtk init --global
```

This configures a hook in `~/.claude/settings.json` to transparently intercept commands.
`bin/vibe init` only automates the Homebrew and Cargo paths; for manual installs it prints release instructions instead of executing a remote install script.

**Verification states**:
- **Ready** - RTK binary is installed and the Claude hook is configured
- **Installed, hook not configured** - RTK is present, but `rtk init --global` still needs to run
- **Hook configured, binary not found** - a stale hook exists in `~/.claude/settings.json`, but the RTK binary is not currently available

**Benefits**:
- 60-90% token reduction on command outputs
- <10ms overhead per command
- Works with git, npm, cargo, pytest, jest, and more
- Zero dependencies, single binary

**Configuration**: `core/integrations/rtk.yaml`

### gstack Skill Pack

**Purpose**: Virtual engineering team as slash commands — product thinking, code review, browser QA, release automation, and safety guardrails. Structured as a sprint pipeline: Think → Plan → Build → Review → Test → Ship → Reflect.

**Author**: Garry Tan (@garrytan) | **License**: MIT

**Installation**:
- Automatic: `bin/vibe init` detects and offers to install gstack (clone + setup + verification)
- Claude Code: `git clone https://github.com/garrytan/gstack.git ~/.claude/skills/gstack && cd ~/.claude/skills/gstack && ./setup`
- Project-level: `cp -Rf ~/.claude/skills/gstack .claude/skills/gstack && cd .claude/skills/gstack && ./setup`
- Requires: Bun v1.0+ (for `/browse` browser skills; other skills work without Bun)
- China mirror: Gitee fallback is used automatically when GitHub is unreachable

**Portable skill IDs exposed by this workflow**:
- `gstack/office-hours` - Product brainstorming with forcing questions
- `gstack/plan-ceo-review` - CEO/founder perspective review
- `gstack/plan-eng-review` - Engineering architecture review
- `gstack/plan-design-review` - Design review with ratings
- `gstack/design-consultation` - Complete design system creation
- `gstack/review` - Pre-landing PR code review with auto-fixes
- `gstack/design-review` - Visual design audit with fixes
- `gstack/codex` - Cross-model second opinion via OpenAI Codex
- `gstack/investigate` - Root-cause debugging with scope freeze
- `gstack/qa` - Browser QA in real Chromium
- `gstack/qa-only` - QA reporting without code changes
- `gstack/browse` - Headless Chromium browser
- `gstack/setup-browser-cookies` - Import cookies from real browser
- `gstack/ship` - Release workflow (tests, PR, push)
- `gstack/document-release` - Auto-update project docs
- `gstack/retro` - Weekly retrospective with shipping stats
- `gstack/careful` - Safety guardrails for destructive commands
- `gstack/freeze` / `gstack/guard` / `gstack/unfreeze` - Edit scope control

**Overlap with builtin skills**:
- `gstack/investigate` overlaps with builtin `systematic-debugging` (P0 mandatory) — builtin takes precedence by default
- `gstack/review` complements `verification-before-completion` — gstack reviews code quality, builtin verifies completion evidence

**Configuration**: `core/integrations/gstack.yaml`

## Integration Architecture

```
core/integrations/
├── superpowers.yaml    # Skill pack integration config
├── gstack.yaml         # gstack skill pack config
├── rtk.yaml            # CLI tool integration config
└── README.md           # This file

Detection & Installation Flow:
1. bin/vibe init [--platform PLATFORM]  # User runs initialization
2. Detect installed tools
3. Distinguish installed vs ready state (platform-aware)
4. Ask user to install or finish configuration
5. Configure hooks/symlinks (platform-specific)
6. Verify installation
```

## Adding a New Integration

### Step 1: Create Configuration File

Create `core/integrations/your-tool.yaml`:

```yaml
schema_version: 1
name: your-tool
type: cli_tool  # or skill_pack
source: https://github.com/author/your-tool
description: Brief description

installation_methods:
  homebrew:
    command: brew install your-tool
    platforms: [macos, linux]

detection:
  binary: your-tool
  version_command: your-tool --version

integration:
  auto_enable: ask_user
  priority: P1

benefits:
  - Benefit 1
  - Benefit 2
```

### Step 2: Implement Detection Logic

Add detection method in `lib/vibe/external_tools.rb`:

```ruby
def detect_your_tool
  return :installed if system("which your-tool > /dev/null 2>&1")
  :not_installed
end
```

### Step 3: Add to Initialization Flow

Update `lib/vibe/init_support.rb` to include your tool in the initialization wizard.

### Step 4: Document Usage

Add usage instructions to this file and update relevant README sections.

## Integration Schema

### Skill Pack Schema

```yaml
schema_version: 1
name: string
type: skill_pack
namespace: string
source: url
description: string

installation_methods:
  <target>:
    preferred: plugin|manual
    commands: [string]
    notes: string

detection:
  paths: [string]
  verification:
    method: string
    sample_skills: [string]

skills:
  - id: string
    intent: string
    trigger_context: string

integration:
  auto_enable: ask_user|always|never
  priority: P0|P1|P2
  fallback_strategy: string
```

### CLI Tool Schema

```yaml
schema_version: 1
name: string
type: cli_tool
source: url
description: string

installation_methods:
  <method>:
    command: string
    platforms: [string]
    notes: string

detection:
  binary: string
  version_command: string
  hook_check:
    file: path
    path: json.path
    contains: string

initialization:
  command: string
  effect: string

integration:
  auto_enable: ask_user|always|never
  priority: P0|P1|P2
  targets:
    <target>:
      method: string
      notes: string

benefits: [string]
```

## Detection Strategy

The workflow uses a multi-level detection strategy:

1. **Binary Check**: Is the tool in PATH?
2. **Config Check**: Is it configured in tool settings?
3. **Path Check**: Does the installation directory exist?
4. **Verification**: Can we invoke a sample command?

## Installation Flow

When `bin/vibe init` is run:

1. **Scan**: Check all integrations in `core/integrations/`
2. **Detect**: Run detection logic for each integration
3. **Report**: Show installation status
4. **Prompt**: Ask user if they want to install missing tools
5. **Install**: Execute installation commands (with user confirmation)
6. **Configure**: Set up hooks, symlinks, or config files
7. **Differentiate**: Report whether each integration is merely installed or fully ready
8. **Verify**: Confirm successful installation

## User Experience

### First-time Setup

```bash
$ bin/vibe init

🚀 VibeSOP Initialization
======================================

Checking your environment...
✓ Claude Code detected at ~/.claude

Checking external integrations...

[1/3] Superpowers Skill Pack
   Status: Not installed
   Would you like to install? [Y/n]: y

   Run these commands in Claude Code:
   /plugin marketplace add obra/superpowers-marketplace
   /plugin install superpowers@superpowers-marketplace

[2/3] RTK (Token Optimizer)
   Status: Not installed
   Would you like to install? [Y/n]: y
   Installing via Homebrew...
   ✓ RTK installed (version 0.x.x)
   ✓ Hook configured

[3/3] gstack Skill Pack
   Status: Not installed
   Would you like to install? [Y/n]: y
   Cloning gstack repository...
   ✓ Cloned successfully from https://github.com/garrytan/gstack.git
   Running gstack setup...
   ✅ gstack installed successfully!
   Location: ~/.claude/skills/gstack

Configuration complete! 🎉
```

If RTK is present but not fully configured, the setup flow now reports that explicitly instead of marking it ready:

```bash
$ bin/vibe init

[2/2] RTK (Token Optimizer)
   Status: Installed, hook not configured
   Binary: /opt/homebrew/bin/rtk
   Hook: Not configured
   Configure RTK hook in ~/.claude/settings.json? [Y/n]:
```

### Verification

```bash
$ bin/vibe init --verify

Verifying integrations...

[✓] Superpowers
    Location: ~/.claude/plugins/superpowers
    Skills: 7 detected
    Status: Ready

[✓] RTK
    Binary: /opt/homebrew/bin/rtk
    Version: 0.x.x
    Hook: Configured
    Status: Ready

[✓] gstack
    Location: ~/.claude/skills/gstack
    Version: 1.1.0
    Skills: 15 detected
    Browser: Ready
    Status: Ready

All integrations verified! 🎉
```

Partial RTK states are also surfaced during verification:

```bash
$ bin/vibe init --verify

[!] RTK
    Binary: Not found
    Hook: Configured
    Status: Hook configured, but RTK binary was not found
```

## Skill Selection Guide

When multiple skill packs provide similar capabilities, use this priority order:

### Review & Verification

| Scenario | Recommended Skill | Why |
|----------|-------------------|-----|
| Before claiming task completion | `verification-before-completion` (builtin) | P0 mandatory — ensures evidence exists |
| Pre-landing PR review | `gstack/review` | Suggest mode — catches security/architecture issues |
| Deep code quality audit | `superpowers/review` | Manual — comprehensive checks when time permits |

**Rule**: Always run verification-before-completion; use gstack/review for PRs; use superpowers/review for major refactors.

### Debugging

| Scenario | Recommended Skill | Why |
|----------|-------------------|-----|
| Root cause analysis | `systematic-debugging` (builtin) | P0 mandatory — structured 5-phase process |
| Quick investigation with scope lock | `gstack/investigate` | Suggest alternative — auto-freeze prevents drift |

**Rule**: Builtin takes precedence; gstack/investigate if you need scope lock.

### Session Management

| Scenario | Recommended Skill | Why |
|----------|-------------------|-----|
| End of session cleanup | `session-end` (builtin) | P0 mandatory — memory flush protocol |
| Weekly team retrospective | `gstack/retro` | Manual — stats and shipping streaks |

**Rule**: These complement — session-end every session, retro weekly.

### Browser QA

| Skill | When to Use | Requirements |
|-------|-------------|--------------|
| `gstack/qa` | End-to-end testing with fixes | Bun installed |
| `gstack/qa-only` | Bug reporting without changes | Bun installed |
| `gstack/browse` | Manual browser inspection | Bun installed |

**Note**: gstack browser skills require Bun v1.0+. If Bun unavailable, use manual testing.

## Troubleshooting

### Superpowers Not Detected

1. Check installation: `ls ~/.claude/plugins/superpowers`
2. Check generated docs/manifest: Superpowers portable IDs only appear after detection succeeds
3. Verify in Claude Code: Try invoking the pack-native command for your installation
4. Reinstall: Follow installation commands again

### RTK Hook Not Working

1. Check settings: `cat ~/.claude/settings.json | grep bashCommandPrepare`
2. Reinitialize: `rtk init --global`
3. Restart Claude Code

### RTK Reports Hook Configured But Binary Missing

1. Check whether RTK is still installed: `which rtk`
2. If missing, reinstall RTK using Homebrew, Cargo, or the GitHub releases page
3. Re-run `bin/vibe init --verify` to confirm the state returns to Ready

### Integration Conflicts

If multiple tools provide similar functionality:
- The workflow will prefer the most specific tool
- You can disable integrations by removing their YAML files
- Check `core/integrations/<tool>.yaml` for conflict resolution strategy

## Best Practices

1. **Always verify after installation**: Run `bin/vibe init --verify`
2. **Keep integrations updated**: Check tool repositories for updates
3. **Document custom integrations**: Add your own YAML files for team tools
4. **Test in isolation**: Verify each integration works independently
5. **Review security**: External tools may require additional permissions

## Hooks

Vibe ships two standalone hook scripts in `hooks/`. They are **not enabled by default** — install them manually based on your needs.

### parry-scan.rb — Claude Code Pre-Tool-Use Hook

Scans user input for prompt injection, system-prompt leakage attempts, and other security patterns before Claude processes them.

**Install as a Claude Code hook:**

Claude Code hooks receive tool input as JSON on stdin. The hook reads from stdin automatically when stdin is not a TTY.

```json
// .claude/settings.json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": "ruby /path/to/vibe/hooks/parry-scan.rb"
          }
        ]
      }
    ]
  }
}
```

**Or call manually:**
```bash
ruby hooks/parry-scan.rb "your input text"
echo "some input" | ruby hooks/parry-scan.rb
```

Exit codes: `0` = safe, `1` = high risk, `2` = critical risk.

---

### tdd-guard.rb — Git Pre-Commit Hook

Checks that source file changes are accompanied by test files. Warns (or blocks in strict mode) commits that lack test coverage.

**Install as a git pre-commit hook:**

```bash
cp hooks/tdd-guard.rb .git/hooks/pre-commit
chmod +x .git/hooks/pre-commit
```

**Configure via `.tdd-guard.yml` in your project root** (see `config/tdd-guard.example.yml`):

```yaml
strict_mode: false    # true = block commit, false = warn only
min_coverage: 80.0
```

**Or call manually:**
```bash
ruby hooks/tdd-guard.rb                     # audit changed files (git diff --cached)
ruby hooks/tdd-guard.rb path/to/file.rb     # check a specific file
```

---

## Security Considerations

- **Skill Packs**: Review skills before enabling auto-triggers
- **CLI Tools**: Prefer package managers or reviewed release binaries over remote install scripts
- **Hooks**: Understand what hooks modify in your config
- **Permissions**: Some tools may require additional access

## Future Integrations

Planned integrations:
- Additional skill packs from the community
- Code quality tools (linters, formatters)
- Deployment automation tools
- Testing frameworks

To request a new integration, open an issue at:
https://github.com/nehcuh/vibesop/issues

---

For more information:
- Superpowers: https://github.com/obra/superpowers
- gstack: https://github.com/garrytan/gstack
- RTK: https://github.com/rtk-ai/rtk
