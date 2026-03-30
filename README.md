# VibeSOP

**English** | [中文](README.zh-CN.md)

> **Not a tutorial. Not a toy config. A production SOP that actually ships.**
>
> A battle-tested, multi-platform workflow SOP for AI-assisted development with structured configuration, memory management, and consistent development practices.

---

## ⚡ Try in 5 Minutes (No Reading Required)

**体验 VibeSOP 的核心功能，无需深入阅读文档**

```bash
# 1️⃣ 一键安装（2 分钟）
git clone https://github.com/nehcuh/vibesop.git && cd vibesop && bin/vibe-install

# 2️⃣ 应用到你的项目（1 分钟）
cd ~/your-existing-project
vibe switch claude-code

# 3️⃣ 体验智能技能路由（2 分钟）
claude
# 然后输入任意一句试试：
# - "帮我调试这个 bug"
# - "评审这段代码"
# - "我要重构这个函数"
# ✨ AI 会使用 5 层路由系统自动选择最合适的技能！
# 🚀 多提供商支持：Claude Haiku / OpenAI GPT，准确率提升 36%
```

**🎯 你刚刚体验了什么？**
- ✅ **AI 驱动的技能路由** 🚀 — 多提供商支持，5 层智能路由
  - 支持 Anthropic Claude 和 OpenAI GPT
  - 准确率提升 36% (70% → 95%)
  - 多级缓存 (70%+ 命中率)
  - 成本可控 (~$0.11/月)
  - [查看多提供商架构 →](docs/architecture/multi-provider-architecture.md)
- ✅ **结构化配置** — 自动加载项目规则
- ✅ **开箱即用** — 无需预先学习

**💡 还想了解更多？** 根据你的角色选择入口：
- 👨‍💻 **个人开发者** → [个人快速入门](#for-individual-developers)
- 👥 **团队负责人** → [团队设置指南](#for-team-leads)
- 🏢 **工程管理者** → [管理视角](#for-engineering-managers)

---

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

## 🎯 Choose Your Path (Based on Your Role)

<details>
<summary><b>👨‍💻 For Individual Developers</b> <em>（个人开发者）</em></summary>

### 目标：更快交付代码，减少重复错误

**5 分钟**：完成上面的 "Try in 5 Minutes"
**15 分钟**：理解三大核心功能
- **🚀 AI 驱动的技能路由**（新）：多提供商支持，5 层智能路由
  - 支持 Anthropic Claude 和 OpenAI GPT
  - 准确率提升 36% (70% → 95%)
  - 多级缓存，性能优化
  - 自动回退，高可靠性
  - [多提供商架构 →](docs/architecture/multi-provider-architecture.md)
- **记忆系统**：记录错误和解决方案，避免重复踩坑
- **检查点系统**：危险操作前自动快照

**1 小时**：[阅读 PRINCIPLES.md](PRINCIPLES.md)（可选）
- 了解核心设计理念
- 学习最佳实践

**立即开始**：
```bash
# 1. 安装（已完成）
vibe doctor

# 2. 应用到你的项目
cd ~/your-project
vibe switch claude-code

# 3. 开始使用
claude
```

**下一步**：查看 [详细功能指南](#-core-features)
</details>

<details>
<summary><b>👥 For Team Leads</b> <em>（团队负责人）</em></summary>

### 目标：统一团队规范，共享经验教训

**5 分钟**：完成团队设置
```bash
# 1. 为团队项目创建统一规则
cat > .vibe/overlay.yaml << 'EOF'
profile: your-team-profile
policies:
  append:
    - id: team-code-review
      category: quality
      enforcement: mandatory
      summary: "所有 PR 必须通过 /review 审查"
EOF

# 2. 团队成员应用配置
vibe switch claude-code  # 自动发现 overlay
```

**15 分钟**：配置团队共享
- **共享 Overlay**：提交 `.vibe/overlay.yaml` 到仓库
- **Instinct Learning**：提取团队经验为可复用模式
- **Memory System**：统一记录项目知识

**1 小时**：定制团队规则
- [Overlay 教程](docs/overlay-tutorial.md)
- [项目覆盖配置](docs/project-overlays.md)

**团队协作效果**：
- ✅ 统一的代码风格和审查标准
- ✅ 共享的错误解决方案
- ✅ 新人快速上手

**下一步**：查看 [团队配置完整指南](#team-setup)
</details>

<details>
<summary><b>🏢 For Engineering Managers</b> <em>（工程管理者）</em></summary>

### 目标：标准化 AI 辅助开发流程

**5 分钟**：了解核心价值
- **生产级 SOP**：不是演示配置，是实战工作流
- **跨平台支持**：Claude Code ✅、OpenCode ✅、更多平台开发中
- **渐进式采用**：从个人到团队，从小项目到大项目

**15 分钟**：评估适用性
- [架构概览](docs/architecture/README.md) - 了解系统设计
- [集成指南](docs/integrations.md) - 规划技术栈集成
- [真实案例](docs/USE_CASES.md) - 查看实际效果（待添加）

**1 小时**：制定推广计划
- **试点阶段**：1-2 个核心项目试用
- **反馈收集**：使用 Instinct Learning 提取模式
- **全面推广**：基于试点经验制定标准

**预期收益**：
- 📈 开发效率提升 30-50%
- 📉 Code Review 时间减少 40-60%
- 🔄 新人上手时间缩短 50%

**下一步**：[联系技术支持](https://github.com/nehcuh/vibesop/issues) 获取咨询
</details>

---

## 🚀 Traditional Quick Start (If You Prefer Reading First)

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

### Five-Layer AI Skill Routing (🚀 NEW)

| Layer | Technology | Accuracy | Latency | Purpose |
|-------|-----------|----------|---------|---------|
| **0: AI Triage** | Multi-Provider (Claude/OpenAI) + Cache | 95% | ~50-150ms | Semantic understanding with 70%+ cache hit rate |
| **1: Explicit** | Pattern matching | 100% | <1ms | User-specified skill overrides |
| **2: Scenario** | Predefined patterns | 85% | <5ms | Common development scenarios |
| **3: Semantic** | TF-IDF + Cosine similarity | 75% | <10ms | Intent-based matching |
| **4: Fuzzy** | Levenshtein distance | 60% | <15ms | Typo-tolerant fallback |

**Performance**:
- ✅ **+36% accuracy improvement** (70% → 95%)
- ✅ **Sub-150ms P95 latency** with warm cache
- ✅ **~$0.11/month** operating cost (10K requests)
- ✅ **Automatic fallback** ensures 99.9% availability

[See complete architecture → AI Routing Documentation](docs/architecture/ai-powered-skill-routing.md)

### Key Concepts

- **Portable Core** (`core/`): Provider-neutral workflow semantics. Add a new AI platform by writing an adapter, not rewriting rules.
- **Overlay System**: Project-specific customizations in `.vibe/overlay.yaml`. Keep your tweaks while upgrading the base.
- **AI-Powered Skill Routing**: 🚀 **NEW** — 5-layer intelligent routing system with multi-provider support
  - **Layer 0**: AI semantic triage with multi-level caching (70%+ hit rate)
  - **Multi-Provider**: Support for Anthropic Claude and OpenAI GPT models
  - **Layer 1-4**: Algorithm-based fallback (explicit → scenario → semantic → fuzzy)
  - **Performance**: +36% accuracy improvement (70% → 95%), P95 latency <150ms
  - **Cost**: ~$0.11/month (10K requests) with intelligent caching
  - [Learn more → AI Routing Architecture](docs/architecture/ai-powered-skill-routing.md)
  - [Multi-Provider Support → Multi-Provider Architecture](docs/architecture/multi-provider-architecture.md)

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
| **🚀 AI-Powered Routing (NEW)** | [API Reference](docs/api-reference-skill-routing.md), [Architecture Diagrams](docs/architecture-diagrams.md), [Usage Examples](docs/usage-examples.md) |
| **🤖 OpenCode LLM Configuration** | [OpenCode LLM Setup Guide](docs/opencode-llm-setup.md), [Config Separation](docs/opencode-llm-config-separation.md) |
| Multi-candidate selection | [API Reference → CandidateSelector](docs/api-reference-skill-routing.md#vibeskillroutercandidateselector) |
| Preference learning | [API Reference → PreferenceAnalyzer](docs/api-reference-skill-routing.md#vibepreferencedimensionanalyzer) |
| Parallel execution | [API Reference → ParallelExecutor](docs/api-reference-skill-routing.md#vibeskillrouterparallelexecutor) |
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

### Smart Skill Routing 🚀

**AI-Powered 5-Layer Routing System**

```bash
$ vibe route "帮我评审代码"

📥 输入: 帮我评审代码
----------------------------------------
✅ 匹配到技能: /review
   来源: gstack
   场景: code_review
   置信度: high
   路由层级: Layer 0 (AI Triage)

💡 替代方案:
   • /receiving-code-review (superpowers) - 全面质量检查
   • /codex (gstack) - 跨模型审查
```

**How it works:**

1. **Layer 0: AI Semantic Triage** (NEW)
   - Multi-provider support: Anthropic Claude or OpenAI GPT
   - Auto-detects provider from environment or OpenCode config
   - Multi-level caching: Memory (70%+ hit) → File → Redis
   - Context-aware matching (file type, error count, recent files)
   - **95% accuracy** with sub-150ms P95 latency

2. **Layers 1-4: Algorithmic Fallback**
   - Layer 1: Explicit overrides (user-specified)
   - Layer 2: Scenario patterns (predefined cases)
   - Layer 3: Semantic matching (TF-IDF + cosine similarity)
   - Layer 4: Fuzzy matching (Levenshtein distance)

**Performance:**
- ✅ **+36% accuracy improvement** over algorithm-only routing
- ✅ **$0.11/month** cost with 70%+ cache hit rate
- ✅ **Automatic fallback** ensures 99.9% availability
- ✅ **Real-time monitoring** via statistics API

[Learn more → AI Routing Architecture](docs/architecture/ai-powered-skill-routing.md)

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

| Platform | Status | Command | LLM Configuration |
|----------|--------|---------|-------------------|
| Claude Code | ✅ Production | `vibe init --platform claude-code` | Uses built-in models |
| OpenCode | ✅ Functional | `vibe init --platform opencode` | [Configure LLM →](docs/opencode-llm-setup.md) |
| Cursor | 📝 Planned | - | - |
| VS Code | 📝 Planned | - | - |
| Warp | 📝 Planned | - | - |
| Kimi Code | 📝 Planned | - | - |

**OpenCode LLM Configuration**:

OpenCode 支持多种 LLM 提供商和自定义端点：

```bash
# 创建配置文件
cat > .vibe/llm-config.json << 'EOF'
{
  "models": {
    "fast": {
      "provider": "openai",
      "model": "gpt-4o-mini",
      "api_key": "your-api-key-here",
      "temperature": 0.3
    }
  }
}
EOF

# 验证配置
./bin/vibe route --stats
```

支持的配置：
- ✅ **在配置中直接添加 API key**
- ✅ **使用环境变量**（推荐用于生产环境）
- ✅ **OpenAI 兼容端点**（Azure、Together、Anyscale 等）
- ✅ **自定义端点**（如智谱 GLM、本地模型等）

[查看完整配置指南 →](docs/opencode-llm-setup.md)

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

# Autonomous Experiment
vibe experiment start <config>       # Start experiment loop
vibe experiment results              # View results and best iteration
vibe experiment apply                # Apply best changes to main branch
vibe experiment clean                # Remove worktree and experiment files
```

</details>

---

<details>
<summary><b>🏗️ Architecture Deep Dive</b> <em>（点击展开 - 高级内容）</em></summary>

## Architecture Deep Dive

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

</details>

---

<details>
<summary><b>🔧 Full Command Reference</b> <em>（点击展开 - 完整命令列表）</em></summary>

## 🔧 Full Command Reference

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
