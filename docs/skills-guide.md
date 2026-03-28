# Skill Management Guide

Complete guide for discovering, registering, and managing skills in VibeSOP.

## Overview

VibeSOP supports three sources of skills:

| Source | Location | Description |
|--------|----------|-------------|
| **Builtin** | `skills/` in repo | Core skills (debugging, planning, verification) |
| **External Packs** | `~/.config/skills/` | Superpowers, gstack, and custom packs |
| **Project** | `skills/` in project | Project-specific skills |

## Quick Start

### 1. Discover Available Skills

```bash
# Check what skills are available
vibe skills list

# Check for new unregistered skills
vibe skills discover
```

### 2. Register Skills

```bash
# Interactive registration (recommended)
vibe skills register --interactive

# Auto-register all safe skills
vibe skills register --auto
```

### 3. Use Skills

Once registered, skills are automatically matched to your requests:

```bash
# Test skill routing
vibe route "帮我评审代码"
```

## Skill Discovery

### How Discovery Works

VibeSOP scans these directories for skills:

```
~/.config/skills/           # External skill packs
├── superpowers/           # Design, TDD, debugging skills
├── gstack/               # Virtual engineering team
└── personal/             # Your custom skills

./skills/                  # Project-specific skills
```

### Discover Command

```bash
vibe skills discover
```

Output shows:
- Total discovered skills
- Already registered skills
- Unregistered skills with security audit results

Example:
```
🔍 扫描技能目录...
项目: /Users/me/my-project
已发现技能: 35
已注册: 32
未注册: 3

发现 3 个未注册技能:

[1] my-custom-debug
    ID: project/my-custom-debug
    安全: ✅ 通过

[2] dangerous-skill
    ID: project/dangerous-skill
    安全: ⚠️ 风险 high
      • Dynamic code execution (eval)
```

## Skill Registration

### Security-First Registration

Every skill is automatically audited before registration:

| Risk Level | Action |
|------------|--------|
| Low | Auto-register with `--auto` |
| Medium | Interactive confirmation |
| High/Critical | Must explicitly confirm |

### Registration Modes

```bash
# Interactive (default)
vibe skills register --interactive

# Auto-register only safe skills
vibe skills register --auto

# Check status without registering
vibe skills register
```

### Project-Level Registration

Skills are registered to `.vibe/skill-routing.yaml`:

```yaml
schema_version: 1

routing_rules:
  - scenario: code_review
    primary:
      skill: /review
      source: gstack

exclusive_skills:
  - scenario: my_custom_debug
    skill: project/my-debug
    source: project
```

Benefits:
- ✅ Isolated per project
- ✅ Version controllable
- ✅ Team shareable
- ✅ Easy to migrate

## Managing Skills

### List Skills

```bash
vibe skills list
```

Shows:
- Mandatory skills (always active)
- Suggest skills (recommended when relevant)
- Skipped skills (not applicable)
- Available but not adapted

### Adapt a Skill

Change how a skill is triggered:

```bash
# Make skill mandatory
vibe skills adapt superpowers/tdd mandatory

# Set to suggest mode (default)
vibe skills adapt superpowers/tdd suggest

# Skip a skill
vibe skills skip superpowers/optimize
```

### View Skill Documentation

```bash
vibe skills docs superpowers/tdd
```

## Smart Skill Routing

### How It Works

The router uses three layers:

1. **Explicit Override**: User says "用 gstack"
2. **Scenario Matching**: Matches "评审代码" → code_review scenario
3. **Semantic Matching**: Compares request to skill intents

### Conflict Resolution

When multiple sources have matching skills:

| Scenario | Default | Override |
|----------|---------|----------|
| Debugging | builtin systematic-debugging | "用 gstack" → /investigate |
| Code Review | gstack /review | "用 superpowers" → /receiving-code-review |
| Planning | builtin planning-with-files | "用 gstack" → /plan-* |

### Test Routing

```bash
vibe route "帮我评审代码"
vibe route "这个 bug 很奇怪"
vibe route "准备发布"
```

## Installing External Skill Packs

### Superpowers

```bash
# Install
git clone https://github.com/obra/superpowers.git ~/.config/skills/superpowers

# Discover and register
vibe skills discover
vibe skills register --interactive
```

Skills included:
- `/test-driven-development` - TDD workflow
- `/refactor` - Safe refactoring
- `/brainstorm` - Design exploration
- `/review` - Code review
- `/optimize` - Performance optimization

### gstack

```bash
# Install
git clone https://github.com/garrytan/gstack.git ~/.config/skills/gstack

# Discover and register
vibe skills discover
vibe skills register --interactive
```

Skills included:
- `/review` - Pre-landing code review
- `/qa` - Browser testing
- `/ship` - Release workflow
- `/office-hours` - Product brainstorming
- `/plan-*` - Planning reviews (CEO/eng/design)

### Custom Skill Packs

```bash
# Create directory
mkdir ~/.config/skills/my-company

# Add skills (each in SKILL.md format)
mkdir ~/.config/skills/my-company/onboarding
cat > ~/.config/skills/my-company/onboarding/SKILL.md << 'EOF'
---
name: Company Onboarding
description: Onboarding workflow for new team members
---

# Company Onboarding

## When to Use

When a new engineer joins the team...
EOF

# Register
vibe skills discover
vibe skills register
```

## Creating Project Skills

Create skills specific to your project:

```bash
mkdir -p skills/company-specific
cat > skills/company-specific/SKILL.md << 'EOF'
---
name: Company Deployment
description: Deploy to company infrastructure
---

# Company Deployment

## Steps

1. Run pre-deploy checks
2. Update CHANGELOG
3. Create git tag
4. Deploy to staging
5. Deploy to production
EOF
```

The skill will be discovered automatically:

```bash
vibe skills discover
# Shows: project/company-specific

vibe skills register
# Registers to .vibe/skill-routing.yaml
```

## Best Practices

### 1. Start with Builtin

Begin with builtin skills, add external packs as needed.

### 2. Project-Level First

Register skills at project level for isolation.

### 3. Review Security Audit

Always check security audit before registering skills from unknown sources.

### 4. Use Semantic Triggers

The router works best with clear intent:

- ✅ "帮我调试这个错误" → debugging
- ✅ "评审这段代码" → code_review
- ⚠️ "检查一下" → ambiguous

### 5. Clean Up Unused Skills

```bash
# Skip skills you don't use
vibe skills skip superpowers/optimize
```

## Troubleshooting

### Skill Not Found

```bash
# Check if discovered
vibe skills discover

# Check if registered
vibe skills list

# Test routing
vibe route "你的请求"
```

### Registration Fails

1. Check security audit: Red flags block auto-registration
2. Manual review: Use `--interactive` mode
3. Check YAML syntax in `.vibe/skill-routing.yaml`

### Routing Not Working

1. Verify skill is registered: `vibe skills list`
2. Check scenario keywords in `.vibe/skill-routing.yaml`
3. Test with explicit route: `vibe route "你的请求"`

## See Also

- [Skill Routing](claude/skills/routing.md) - How routing works
- [Security Policy](../core/security/policy.yaml) - Skill security levels
- [Skill Registry](../core/skills/registry.yaml) - Builtin skill definitions
