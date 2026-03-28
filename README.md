# VibeSOP

**English** | [中文](README.zh-CN.md)

> **Not a tutorial. Not a toy config. A production SOP that actually ships.**
>
> A battle-tested, multi-platform workflow SOP for AI-assisted development with structured configuration, memory management, and consistent development practices.

```
┌─────────────────────────────────────────────────────────────┐
│  Portable Core (provider-neutral)                           │
│  core/  →  models, skills, policies, security               │
├─────────────────────────────────────────────────────────────┤
│  Target Adapters                                            │
│  Claude Code ✅ | OpenCode ✅ | Cursor | VS Code | ...     │
├─────────────────────────────────────────────────────────────┤
│  Project Overlay (.vibe/overlay.yaml)                       │
│  Your custom rules and preferences                          │
└─────────────────────────────────────────────────────────────┘
```

---

## 🚀 30-Second Quick Start

```bash
# 1. Clone and install
git clone https://github.com/nehcuh/vibesop.git && cd vibesop
bin/vibe-install          # macOS/Linux
# bin\vibe-install.bat    # Windows

# 2. Set up your AI tool (choose one)
vibe onboard                        # Recommended: 5-step guided setup
# OR: vibe quickstart              # One-command setup
# OR: vibe init --platform claude-code

# 3. Apply to your project
cd ~/my-project
vibe switch --platform claude-code

# 4. Start coding
claude    # AI loads your config automatically
```

**Verify installation:**
```bash
vibe doctor      # Check environment
vibe --version   # Show version
```

---

## 📋 Architecture in 60 Seconds

### Three-Layer Runtime

| Layer | What | Loaded | Location |
|-------|------|--------|----------|
| **0: Rules** | Core behavior rules | Always | `~/.claude/rules/` |
| **1: Docs** | Reference guides | On demand | `~/.claude/docs/` |
| **2: Memory** | Your project state | Session start | `memory/*.md` |

### Key Concepts

- **Portable Core** (`core/`): Provider-neutral workflow semantics. Add a new AI platform by writing an adapter, not rewriting rules.
- **Overlay System**: Project-specific customizations in `.vibe/overlay.yaml`. Keep your tweaks while upgrading the base.
- **Smart Skill Routing**: Say "帮我评审代码" → AI automatically selects the best skill from builtin/superpowers/gstack.

> **📖 Philosophy**: Read [PRINCIPLES.md](PRINCIPLES.md) — Production-First, Structure > Prompting, Memory > Intelligence, Verification > Confidence, Portable > Specific.

---

## 🎯 Common Tasks

### Setup

| Task | Command | See Also |
|------|---------|----------|
| First-time setup | `vibe onboard` | [Install Guide](#installation) |
| Add another platform | `vibe init --platform opencode` | [Platform Support](#platform-support) |
| Apply to project | `vibe switch claude-code` | [Project Setup](#project-setup) |
| Check status | `vibe doctor` | [Troubleshooting](#troubleshooting) |

### Daily Development

| Task | Command | See Also |
|------|---------|----------|
| Record an error | `vibe memory record` | [Memory System](#memory-system) |
| Learn from session | `vibe instinct learn` | [Instinct Learning](#instinct-learning) |
| Create checkpoint | `vibe checkpoint create pre-refactor` | [Checkpoints](#code-checkpoints) |
| Route request to skill | `vibe route "帮我评审代码"` | [Smart Routing](#smart-routing) |

### Skill Management

| Task | Command | See Also |
|------|---------|----------|
| Discover new skills | `vibe skills discover` | [Skills Guide](docs/skills-guide.md) |
| Register skills | `vibe skills register --interactive` | [Skill Registration](#skill-management) |
| List skills | `vibe skills list` | - |
| Adapt a skill | `vibe skills adapt superpowers/tdd` | - |

---

## 📚 Documentation Map

### Essential Reading

| Document | Purpose | Read When |
|----------|---------|-----------|
| [PRINCIPLES.md](PRINCIPLES.md) | Core philosophy | **Before using** |
| [Quick Start Guide](#quick-start-detailed) | Step-by-step setup | First-time setup |
| [Architecture Overview](docs/architecture/README.md) | How it works | Understanding internals |

### By Task

| Task | Documentation |
|------|---------------|
| Customize for your project | [Project Overlays](docs/project-overlays.md), [Overlay Tutorial](docs/overlay-tutorial.md) |
| Understand skill routing | [Skill Routing](docs/claude/skills/routing.md), [Task Routing](docs/task-routing.md) |
| Add a new platform | [Target Adapters](targets/README.md) |
| Integrate external tools | [Integrations](docs/integrations.md) |
| Troubleshoot issues | [Troubleshooting](docs/troubleshooting.md) |

### Reference

| Topic | Location |
|-------|----------|
| All CLI commands | [Full Command Reference](#full-command-reference) below |
| Model tiers & routing | [Model Configuration](#model-configuration-guide) |
| Security policies | [Security Policy](core/security/policy.yaml) |
| Skill registry | [Skill Registry](core/skills/registry.yaml) |

---

## 🛠️ Installation

### Requirements

- **Ruby** >= 2.6.0 (for CLI generator)
  - macOS: Pre-installed
  - Linux: `sudo apt install ruby-full`
  - Windows: [RubyInstaller](https://rubyinstaller.org/)
- **AI Tool**: Claude Code, OpenCode, or other supported platform

### Platform-Specific Install

```bash
# macOS/Linux
git clone https://github.com/nehcuh/vibesop.git && cd vibesop
bin/vibe-install

# Windows (cmd.exe - no admin needed)
git clone https://github.com/nehcuh/vibesop.git && cd vibesop
bin\vibe-install.bat
```

See [Windows Installation Guide](docs/windows-installation.md) for details.

---

## 🎨 Core Features

### Smart Skill Routing

```bash
$ vibe route "帮我评审代码"

📥 输入: 帮我评审代码
----------------------------------------
✅ 匹配到技能: /review
   来源: gstack
   场景: code_review
   置信度: high

💡 替代方案:
   • /receiving-code-review (superpowers) - 全面质量检查
   • /codex (gstack) - 跨模型审查
```

The router matches your request against scenarios and selects the best skill from available sources (builtin, superpowers, gstack).

### Memory System

Three-tier memory architecture:

```
memory/
├── session.md           # Hot: Daily progress, active tasks
├── project-knowledge.md # Warm: Technical pitfalls, patterns
└── overview.md          # Cold: Goals, infrastructure
```

Record errors automatically or manually:
```bash
vibe memory enable              # Auto-record
vibe memory record              # Manual record
vibe memory stats               # View statistics
```

### Skill Discovery & Registration

```bash
# 1. Install new skill pack
git clone https://github.com/example/skills ~/.config/skills/custom

# 2. Discover and audit
vibe skills discover

# 3. Register (with security check)
vibe skills register --interactive
```

Skills are registered project-level in `.vibe/skill-routing.yaml` — isolated and version-controllable.

---

## 📖 Detailed Guides

### Quick Start (Detailed)

**Scenario 1: First-time Setup**
```bash
vibe onboard                    # Interactive 5-step setup
# Or: vibe quickstart          # Non-interactive

# Verify
cd ~/my-project
vibe switch claude-code
claude
```

**Scenario 2: Multiple Platforms**
```bash
vibe init --platform claude-code
vibe init --platform opencode

cd ~/project-a && vibe switch claude-code
cd ~/project-b && vibe switch opencode
```

**Scenario 3: Team Project with Custom Rules**
```bash
# Create overlay
cat > .vibe/overlay.yaml << 'EOF'
profile: node-fullstack
policies:
  test_command: "npm test"
  lint_command: "npm run lint"
EOF

# Apply with overlay
vibe switch claude-code   # Auto-discovers overlay
```

### Project Setup

Apply workflow to existing projects:

```bash
cd /path/to/project
vibe apply claude-code    # Or: vibe switch claude-code

# With custom overlay
vibe apply claude-code --overlay ./my-overlay.yaml
```

### Platform Support

| Platform | Status | Command |
|----------|--------|---------|
| Claude Code | ✅ Production | `vibe init --platform claude-code` |
| OpenCode | ✅ Functional | `vibe init --platform opencode` |
| Cursor | 📝 Planned | - |
| VS Code | 📝 Planned | - |
| Warp | 📝 Planned | - |
| Kimi Code | 📝 Planned | - |

---

## 🔧 Full Command Reference

### Setup & Configuration

```bash
vibe init --platform <platform>     # Install global config
vibe quickstart                      # One-command setup
vibe onboard                         # Guided 5-step setup
vibe doctor                          # Check environment
vibe targets                         # List platforms
```

### Project Operations

```bash
vibe build <target>                  # Generate config from core/
vibe use <target> <dir>             # Deploy to global config dir
vibe switch <target>                # Apply to current project
vibe apply <target>                 # Same as switch
vibe inspect                         # Show project/target state
```

### Skill Management

```bash
vibe skills check                    # Check for new skills
vibe skills list                     # List all skills
vibe skills discover                 # Discover unregistered skills
vibe skills register                 # Register skills (interactive/auto)
vibe skills adapt <id>               # Adapt specific skill
vibe skills skip <id>                # Skip a skill
vibe skills docs <id>                # View skill docs
vibe skills install <pack>           # Install skill pack
vibe route "<request>"               # Smart skill routing
```

### Advanced Features

```bash
# Instinct Learning
vibe instinct learn                  # Create from session
vibe instinct status                 # View patterns
vibe instinct export <file>          # Export for team
vibe instinct import <file>          # Import patterns

# Memory Management
vibe memory record                   # Record error/solution
vibe memory stats                    # View stats
vibe memory enable/disable           # Toggle auto-record

# Code Checkpoints
vibe checkpoint create <name>        # Create snapshot
vibe checkpoint list                 # List checkpoints
vibe checkpoint rollback <name>      # Restore snapshot

# Parallel Development
vibe worktree create <branch>        # Create isolated worktree
vibe worktree list                   # List worktrees
vibe cascade run <config.yaml>       # Run parallel pipeline

# Security & Quality
vibe scan file <file>                # Security scan
```

---

## 🏗️ Architecture Deep Dive

### Portable Core

The `core/` directory contains provider-neutral workflow semantics:

```
core/
├── models/
│   ├── tiers.yaml          # Capability tiers (critical_reasoner, workhorse_coder...)
│   └── providers.yaml      # Platform mappings
├── skills/
│   └── registry.yaml       # Portable skill definitions
├── security/
│   └── policy.yaml         # P0/P1/P2 severity semantics
└── policies/
    ├── behaviors.yaml      # Behavior policy schema
    ├── task-routing.yaml   # Task complexity rules
    └── test-standards.yaml # Testing requirements
```

### Directory Structure

```
vibesop/
├── bin/
│   ├── vibe                # Main CLI
│   ├── vibe-install        # Install script
│   └── vibe-smoke          # Smoke tests
├── lib/vibe/               # 50+ Ruby modules
│   ├── skill_router.rb     # Smart routing
│   ├── skill_discovery.rb  # Skill scanning
│   └── ...
├── core/                   # Portable SSOT
├── targets/                # Platform adapters
├── skills/                 # Builtin skills
├── rules/                  # Core behavior rules
├── docs/                   # Reference guides
├── examples/               # Overlay examples
└── test/                   # Test suite
```

See [Architecture Overview](docs/architecture/README.md) for details.

---

## 🤝 Contributing & Credits

### Original vs Fork

- **Original**: [runesleo/claude-code-workflow](https://github.com/runesleo/claude-code-workflow) by [@runes_leo](https://x.com/runes_leo)
- **This Fork**: Extended to multi-platform with portable core, 50+ modules, 1400+ tests

If you only need Claude Code support and prefer a simpler setup, the original project may be a better fit.

### Integrated Projects

- **[Superpowers](https://github.com/obra/superpowers)** - Advanced skill pack (TDD, debugging)
- **[RTK](https://github.com/rtk-ai/rtk)** - Token optimizer (60-90% savings)
- **[everything-claude-code](https://github.com/affaan-m/everything-claude-code)** - Inspiration for instinct learning

### License

MIT — Use it, fork it, make it yours.

Original work Copyright (c) 2024 runes_leo
Modified work Copyright (c) 2026 nehcuh

---

**Quick Links**: [Principles](PRINCIPLES.md) | [Full Docs](docs/README.md) | [Issues](https://github.com/nehcuh/vibesop/issues) | [Telegram](https://t.me/runesgang)
