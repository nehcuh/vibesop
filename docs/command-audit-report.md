# Vibe CLI Command Audit Report

**Generated**: 2026-03-28

---

## Summary

| Category | Count |
|----------|-------|
| Total Commands | 24 |
| Documented in README | 11 |
| Missing Documentation | 13 |
| Implemented | 24 |
| Not Implemented | 0 |

---

## Main Commands

| Command | Status | README | Implementation | Notes |
|---------|--------|--------|----------------|-------|
| `build` | ✅ | ✅ | ✅ | Generate config from portable spec |
| `use` | ✅ | ✅ | ✅ | Deploy to global config dir |
| `deploy` | ✅ | ✅ | ✅ | Alias for `use` |
| `switch` | ✅ | ✅ | ✅ | Alias for `apply` |
| `apply` | ✅ | ✅ | ✅ | Apply to current project |
| `inspect` | ✅ | ✅ | ✅ | Inspect project/target state |
| `init` | ✅ | ✅ | ✅ | Install global config |
| `quickstart` | ✅ | ✅ | ✅ | One-command setup |
| `onboard` | ✅ | ✅ | ✅ | 5-step guided setup |
| `targets` | ✅ | ✅ | ✅ | List supported targets |
| `doctor` | ✅ | ✅ | ✅ | Check environment |
| `skills` | ✅ | ⚠️ Partial | ✅ | Has subcommands, docs incomplete |
| `instinct` | ✅ | ❌ | ✅ | Instinct learning system |
| `token` | ✅ | ❌ | ✅ | Token optimization |
| `checkpoint` | ✅ | ❌ | ✅ | Code checkpoints |
| `grade` | ✅ | ❌ | ✅ | Code grading |
| `tasks` | ✅ | ❌ | ✅ | Background tasks |
| `worktree` | ✅ | ❌ | ✅ | Git worktree management |
| `cascade` | ✅ | ❌ | ✅ | Parallel task execution |
| `toolchain` | ✅ | ❌ | ✅ | Toolchain detection |
| `scan` | ✅ | ❌ | ✅ | Security scanning |
| `skill-craft` | ✅ | ❌ | ✅ | Create personal skills |
| `tools` | ✅ | ⚠️ Partial | ✅ | Modern CLI tools (in init) |
| `memory` | ✅ | ❌ | ✅ | Memory commands |

---

## Missing Documentation in README

### High Priority (Core Features)

1. **`instinct` - Instinct Learning System**
   - Subcommands: `learn`, `status`, `export`, `import`, `evolve`
   - Purpose: Extract reusable patterns from sessions
   - Usage: `vibe instinct learn`, `vibe instinct status`

2. **`memory` - Memory Management**
   - Subcommands: `record`, `stats`, `enable`, `disable`, `status`, `autoload`
   - Purpose: Record errors and project knowledge
   - Usage: `vibe memory record`, `vibe memory stats`

3. **`checkpoint` - Code Checkpoints**
   - Subcommands: `create`, `list`, `compare`, `rollback`, `delete`, `cleanup`
   - Purpose: Snapshot and rollback system
   - Usage: `vibe checkpoint create`, `vibe checkpoint rollback`

### Medium Priority (Advanced Features)

4. **`token` - Token Optimization**
   - Subcommands: `analyze`, `optimize`, `stats`
   - Purpose: Analyze and optimize token usage
   - Usage: `vibe token analyze file.rb`

5. **`worktree` / `cascade` - Parallel Development**
   - Worktree subcommands: `create`, `list`, `finish`, `remove`, `cleanup`, `status`
   - Cascade subcommands: `run`, `plan`
   - Purpose: Parallel task execution with git worktrees
   - Usage: `vibe worktree create feature-branch`, `vibe cascade run config.yaml`

6. **`scan` - Security Scanning**
   - Subcommands: `file`, `text`, `ctx-stats`, `tdd-audit`
   - Purpose: Security scanning and TDD audit
   - Usage: `vibe scan file skill.md`

### Lower Priority (Specialized)

7. **`grade` - Code Grading**
   - Subcommands: `run`, `summary`, `pass-at-k`
   - Purpose: Evaluate code quality
   - Usage: `vibe grade run`

8. **`tasks` - Background Tasks**
   - Subcommands: `submit`, `list`, `status`, `cancel`, `cleanup`
   - Purpose: Manage background tasks
   - Usage: `vibe tasks submit 'echo hello'`

9. **`toolchain` - Toolchain Detection**
   - Subcommands: `detect`, `suggest`
   - Purpose: Detect and suggest toolchains
   - Usage: `vibe toolchain detect`

10. **`skill-craft` - Personal Skill Creation**
    - Subcommands: `analyze`, `generate`, `interactive`, `status`, `triggers`
    - Purpose: Create personal skills from session history
    - Usage: `vibe skill-craft analyze`

---

## Skills Command Subcommands (Documentation Gaps)

Current README mentions:
- `vibe skills discover` ✅
- `vibe skills register` ✅

Missing from README:
- `vibe skills check` - Check for new skills
- `vibe skills list` - List all skills
- `vibe skills adapt <id>` - Adapt a specific skill
- `vibe skills skip <id>` - Skip a skill
- `vibe skills docs <id>` - Show skill documentation
- `vibe skills install <pack>` - Install a skill pack

---

## Recommendations

### Option 1: Add All Missing Commands to README (Recommended)

Add a comprehensive "Advanced Commands" section to README.md with all 13 missing commands grouped by category.

### Option 2: Create Separate CLI Reference Document

Keep README focused on essential commands, create `docs/cli-reference.md` with complete command documentation.

### Option 3: Simplify Command Set

Consider removing or consolidating less-used commands:
- Merge `grade` into `checkpoint` workflow
- Merge `tasks` into existing task management
- Make `toolchain` part of `doctor`

---

## Implementation Status

All 24 commands are **fully implemented**. The only issue is missing documentation in README.md.

---

## Commands Not in COMMAND_REGISTRY

The following commands exist in code but are not registered in COMMAND_REGISTRY:

1. **`route`** - Smart skill routing
   - File: `lib/vibe/skill_router_commands.rb`
   - Usage: `vibe route "帮我评审代码"`
   - Status: ❌ Not integrated into main CLI

---

## Action Items

1. [ ] Add missing commands to README.md or create CLI reference doc
2. [ ] Integrate `route` command into main CLI
3. [ ] Add examples for each command
4. [ ] Consider command consolidation for simpler UX
