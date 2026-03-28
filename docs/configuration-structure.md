# Configuration Structure

## Overview

VibeSOP uses a hierarchical configuration system with clear separation between user-level and project-level settings.

```
~/.config/vibe/                    # User-level configuration
├── instincts.yaml                 # Personal learning patterns (cross-project)
├── settings.yaml                  # Global user preferences (optional)
└── skills/                        # Personal skill packs
    └── personal/

.vibe/                             # Project-level configuration
├── config.yaml                    # Project settings
├── skills.yaml                    # Skill adaptation status
├── skill-routing.yaml             # Skill routing rules
├── manifest.json                  # Build manifest
├── claude-code/                   # Platform-specific configs
├── opencode/
└── ...

memory/                            # Project runtime data
├── session.md                     # Current session state
├── project-knowledge.md           # Technical pitfalls & patterns
├── overview.md                    # High-level project info
└── checkpoints/                   # Code snapshots
```

## User-Level Configuration (~/.config/vibe/)

### instincts.yaml
Personal learning patterns extracted from sessions. Shared across all projects.
- **Purpose**: Store user's coding habits and successful patterns
- **Format**: YAML with instinct records
- **Access**: Via `InstinctManager` class
- **Backup**: Should be version controlled separately (optional)

### settings.yaml (optional)
Global user preferences for VibeSOP CLI.
```yaml
# Example structure (not yet implemented)
default_platform: claude-code
auto_adapt_skills: true
verbose_mode: false
```

## Project-Level Configuration (.vibe/)

### config.yaml
Main project configuration.
```yaml
schema_version: 1
project:
  name: "My Project"
  type: "ruby"
platforms:
  - claude-code
  - opencode
```

### skills.yaml
Tracks which skills have been adapted to this project.
```yaml
schema_version: 1
adapted_skills:
  systematic-debugging:
    mode: mandatory
    adapted_at: "2026-03-28T10:00:00+08:00"
skipped_skills:
  - id: some-skill
    reason: "not relevant"
last_checked: "2026-03-28T10:00:00+08:00"
```

### skill-routing.yaml
Defines when and how skills are triggered.
```yaml
routing_rules:
  - scenario: debugging
    keywords: ["bug", "error", "debug"]
    primary:
      skill: systematic-debugging
      trigger: immediate
```

## Memory Directory (memory/)

Runtime data and session state. Not version controlled.

### session.md
Active session tracking for crash recovery.
- Current tasks
- Progress notes
- Next steps

### project-knowledge.md
Accumulated technical knowledge.
- Pitfalls encountered
- Solutions found
- Architecture decisions (ADRs)

### overview.md
High-level project context.
- Goals
- Infrastructure
- Cross-project references

## Migration Notes

### Completed Migrations

1. **instincts.yaml** → Moved from `memory/instincts.yaml` to `~/.config/vibe/instincts.yaml`
   - Personal patterns should be cross-project
   - Avoids duplication across repositories

### Removed Legacy Files

- `memory/background_tasks.yaml` - TaskRunner removed
- `memory/token-stats.json` - TokenOptimizer removed

## Best Practices

1. **Version Control**:
   - `.vibe/` → Commit to repo
   - `memory/` → Add to .gitignore (except templates)
   - `~/.config/vibe/` → Optional personal backup

2. **Backup**:
   - User config: `cp -r ~/.config/vibe ~/backups/`
   - Project config: Already in git

3. **Migration**:
   - Use `vibe doctor` to check config health
   - Auto-migration on first run after updates
