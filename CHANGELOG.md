# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Fixed
- **grader: `determine_grade` Symbol/String type mismatch** — `linter` and `security` warning grades never triggered because `TYPES[type]` (String) was compared against `type` (Symbol) in the `case` statement; fix passes `TYPES[type]` to `determine_grade`, making warning paths reachable for the first time
- **grader: `@language` instance variable coupling** — `write_temp_candidate` depended on hidden `@language` state set by `pass_at_k`; refactored to explicit parameter, eliminating the implicit coupling
- **grader: `pass_rate` denominator excluded skipped candidates** — skipped candidates no longer counted as failures in `pass_at_k` pass rate calculation
- **context_optimizer: CJK token estimate 3× too low** — `TOKENS_PER_WORD_ZH = 0.5` (2 chars per token) underestimated Claude's tokenizer by 3×; corrected to `TOKENS_PER_ZH_CHAR = 1.5` (conservative safe estimate); constant renamed to reflect actual semantics
- **skill_manager: `**info` splat raises `TypeError` on non-Hash entries** — `load_project_skills` crashed when `adapted_skills` entries were `nil` or a non-Hash value; guarded with `info.is_a?(Hash) ? info : {}`
- **trigger_manager: `state_file` not injectable for testing** — constructor now accepts `'state_file'` key in config hash, enabling isolated tests without writing to `~/.claude/`

### Added
- **740 tests (+149 from prior session)** — new `test/unit/test_trigger_manager.rb` (33 cases, 97% line coverage); extended `test_instinct_manager`, `test_grader`, `test_cascade_executor`, `test_checkpoint_manager`, `test_skill_management`, `test_vibe_external_tools`, `test_session_analyzer`, `test_platform_utils`, `test_config_driven_renderers`, `test_superpowers_installer`
- **OnboardRunner test coverage** — 15 cases covering 5-step guided onboarding flow
- **Guided Onboarding** (`vibe onboard [--skip-deploy]`) — 5-step interactive setup that deploys config, records user role, runs doctor check, previews the P0 systematic-debugging skill, and shows next steps
- **SessionAnalyzer format versioning** — `detect_format()` with `SUPPORTED_FORMATS` (v1: `### S\d+` headers, v2: ISO-date `## Session YYYY-MM-DD` headers); unknown formats warn and return `[]` instead of silently producing wrong results
- **Configurable instinct confidence weights** — `InstinctManager` accepts `config: { weights: { success_rate:, usage_frequency:, source_diversity: } }`; `DEFAULT_WEIGHTS` constant exposes the 60/30/10 defaults; fully backward-compatible
- **Grader token budget** — `pass_at_k` supports `:token_budget` (chars/4 estimate); over-budget candidates are marked `grade: :skipped` with `reason: 'exceeds_token_budget'`; result includes `budget_exceeded_count` field; no-op when unset

- **Skill Craft System** (2026-03-20)
  - `skills/skill-craft/SKILL.md` — craft personal skills from session history
  - Multi-trigger mechanism: project completion, session accumulation, periodic review
  - Pattern detection: scan → identify → cluster → rank workflow
  - Personal skill generation with preview and auto-registration
  - `config/skill-craft.example.yml` — user configuration template
  - **Phase 7 Core Implementation** (2026-03-20)
  - `lib/vibe/session_analyzer.rb` — session history analyzer (195 lines)
  - `lib/vibe/skill_generator.rb` — skill generator from patterns (159 lines)
  - `lib/vibe/trigger_manager.rb` — trigger mechanism manager (160 lines)
- **Security & Quality Hooks** (2026-03-20)
  - `hooks/parry-scan.rb` — prompt injection and security risk detector
    - 6 threat categories: prompt_injection, system_leak, data_extraction, command_injection, filesystem_danger, obfuscation
    - Risk levels: critical, high, medium, low
    - Whitelist support for safe patterns
  - `hooks/tdd-guard.rb` — test-driven development enforcement
    - Source-to-test file mapping
    - Coverage threshold checking
    - Strict/loose mode configuration
  - `config/tdd-guard.example.yml` — TDD guard configuration template
- **Session-End Enhancement** (2026-03-20)
  - Added Step 8: Skill Craft Trigger in `skills/session-end/SKILL.md`
  - Automatic skill crafting prompts based on triggers
- **gstack Skill Pack Integration**
  - `core/integrations/gstack.yaml` — full skill pack definition with 21 skills across 7 sprint phases
  - `gstack` namespace in `core/skills/registry.yaml` with trigger modes (suggest/manual)
  - `GstackInstaller` — auto-clone from GitHub (Gitee mirror fallback), run setup, verify installation
  - Detection logic in `lib/vibe/external_tools.rb` — checks `~/.claude/skills/gstack`, `.claude/skills/gstack`, and `~/.config/opencode/skills/gstack`
  - Integration manager auto-installs gstack during `vibe init` (interactive clone + setup + verification)
  - Integration verifier displays gstack status (version, location, skills count, browse readiness with Bun check)
  - Trigger rules in `rules/skill-triggers.md` with overlap documentation for builtin skills
  - 18 integration tests with 320 assertions
  - Sprint pipeline coverage: Think → Plan → Build → Review → Test → Ship → Reflect
  - Complements builtin skills (memory, verification, session-end) with product thinking, browser QA, and release automation
- **Community Best Practices Integration** (Phase 6)
  - `SecurityScanner` — lightweight prompt-injection and jailbreak detector
    - 5 rule categories: system_prompt_leak (critical), role_hijack, instruction_injection, privilege_escalation (high), indirect_injection (medium)
    - `scan(text)` returns `{ safe:, threats:, risk_level: }`; `scan!` raises `SecurityError`
    - Deduplication by rule ID; risk level derived from highest-severity threat
    - 20 unit tests
  - `TddEnforcer` — test-first development enforcement
    - Detects implementation files missing corresponding test coverage
    - Supports Ruby (minitest/rspec), Python (pytest), JS/TS (jest/vitest) conventions
    - `check(file)`, `check_many(files)`, `audit` (full project scan)
    - Excludes vendor/ and node_modules/ from audits
    - 14 unit tests
  - `ContextOptimizer` — context window engineering kit
    - Token estimation for English/Chinese mixed text
    - Priority-based context packaging within a token budget
    - Filler phrase compression
    - `build_package(budget:, required_ids:)` for structured context assembly
    - 16 unit tests
  - New skill: `skills/riper-workflow/SKILL.md` — structured 5-phase workflow (Research → Innovate → Plan → Execute → Review)
  - CLI command: `vibe scan text/file/tdd/ctx` — security scanning and TDD audit
  - Registered `riper-workflow` and `using-git-worktrees` skills in `core/skills/registry.yaml`
- **Toolchain Detection** (Phase 5)
  - `ToolchainDetector` — detects package managers, build tools, and test frameworks
    - 10 package managers: bun, pnpm, yarn, npm, poetry, pipenv, pip, cargo, gomod, bundler
    - 9 build tools: vite, webpack, rollup, esbuild, gradle, maven, cmake, make, rake
    - 7 test frameworks: vitest, jest, pytest, rspec, minitest, cargo_test, go_test
    - Primary language detection by ecosystem frequency
    - Suggested commands for install/test/build
    - 27 unit tests
  - CLI commands: `vibe toolchain detect/suggest`

  - `WorktreeManager` — automated worktree lifecycle management
    - Create isolated worktrees per task with auto-generated branches
    - Finish / remove / cleanup lifecycle commands
    - Status summary (active vs finished counts)
    - 16 unit tests
  - `CascadeExecutor` — dependency-aware parallel task runner
    - DAG-based task graph with cycle detection
    - Independent tasks run in parallel; dependents wait automatically
    - Failed tasks skip all downstream dependents
    - Configurable concurrency cap (`max_parallel`)
    - 17 unit tests
  - CLI commands: `vibe worktree` (create/list/finish/remove/cleanup/status)
  - CLI commands: `vibe cascade` (run/plan) with YAML config format
  - New skill: `skills/using-git-worktrees/SKILL.md`
- **CLI Integration**: New commands for Phase 2-3 modules
  - `vibe token analyze/optimize/stats` — Token optimization commands
  - `vibe checkpoint create/list/rollback/compare/delete/cleanup` — Code snapshot commands
  - `vibe grade run/pass-at-k/summary` — Code evaluation commands
  - `vibe tasks submit/list/status/cancel/cleanup` — Background task commands
- **Verification Loop Enhancement**: Continuous code quality evaluation system
  - `CheckpointManager` class for code snapshots and rollback
    - Create checkpoints with automatic file snapshots
    - Rollback to any checkpoint with dry-run preview
    - Compare two checkpoints for differences
    - Automatic cleanup of old checkpoints
    - Persistent storage with snapshot directories
  - `Grader` class for multi-type code evaluation
    - Four grader types: unit_test, integration_test, linter, security
    - Grade levels: pass, fail, warning, skip
    - pass@k metric for evaluating multiple candidate solutions
    - Statistics tracking and summary reports
  - Design document: `docs/verification-loop-design.md`
  - 34 unit tests for CheckpointManager and Grader
- **Token Optimization System**: Reduce token consumption and improve response speed
  - `TokenOptimizer` class for prompt analysis and optimization
    - Token estimation for English/Chinese mixed text
    - Redundancy detection and removal
    - Whitespace compression
    - Selective section loading
  - `ModelSelector` class for intelligent model selection
    - Task complexity evaluation (simple/medium/complex)
    - Keyword-based scoring system
    - Automatic model recommendation with fallback chain
    - Usage statistics tracking
  - `BackgroundTaskManager` class for long-running operations
    - Priority-based task queue (low/normal/high/critical)
    - Task status tracking (pending/running/completed/failed/cancelled)
    - Task cancellation support
    - Automatic cleanup of old tasks
    - Thread-safe operations with persistent storage
  - Design document: `docs/token-optimization-design.md`
  - 46 unit tests covering all three modules
- **Instinct Learning System**: Automatic pattern extraction from sessions
  - `vibe instinct` command with 6 subcommands (learn, learn-eval, status, export, import, evolve)
  - `InstinctManager` class for pattern CRUD, confidence scoring, and team sharing
  - Confidence algorithm: success rate (60%) + usage frequency (30%) + source diversity (10%)
  - Import/export with 3 merge strategies (skip, overwrite, merge)
  - Integrated into session-end workflow (Step 6: automatic instinct extraction)
  - Skill definition: `skills/instinct-learning/SKILL.md`
  - Design document: `docs/instinct-learning-design.md`
  - 29 unit tests for InstinctManager
  - Registered in `core/skills/registry.yaml` as builtin skill
- **Native Windows Support**: cmd.exe batch scripts for corporate environments
  - `bin/vibe-install.bat` for Windows installation (no admin required)
  - `hooks/install.bat` and `hooks/pre-session-end.bat` for Windows hooks
  - Cross-platform `cmd_exist?` helper replacing Unix-only `which`
  - File copy instead of symlinks for skill installation on Windows
  - Windows path handling in `platform_utils.rb`
  - Comprehensive Windows installation guide: `docs/windows-installation.md`
- **Project Rename**: Renamed from "Claude Code Workflow" to "VibeSOP"
  - Reflects multi-platform scope (Claude Code, OpenCode, future platforms)
  - Updated all references across 21 files
  - Added comparison table with original project in README

### Fixed
- **Hook Configuration Format**: Fixed `vibe init` generating invalid `PreSessionEnd` hook format
  - Changed from `PreSessionEnd` to `Stop` event (correct Claude Code hook name)
  - Fixed data structure to use nested `hooks` array format required by Claude Code
  - Updated `lib/vibe/hook_installer.rb` to generate correct settings.json format
  - Updated all documentation to reflect correct hook configuration
  - All tests passing with new format

### Added
- **Session Management Hook**: Pre-session-end hook for Claude Code that prompts users to save progress before `/exit`
  - Automatically installed during `vibe init --platform claude-code`
  - Detects uncommitted changes and warns users
  - Three options: Save and exit, Exit without saving, or Cancel
  - Configures `~/.claude/settings.json` with Stop hook
  - New module: `lib/vibe/hook_installer.rb` with installation and verification logic
  - New test suite: `test/test_hook_installer.rb` with 6 test cases
  - Documentation: `docs/session-management-hook.md` and `hooks/README.md`
- Interactive integration suggestions during `init` and `quickstart` commands
- `vibe doctor` command for comprehensive environment diagnostics
- Automatic RTK installation via Homebrew with interactive prompts
- Cross-platform URL opening for Superpowers installation guide
- Integration status display with detailed information (version, location, skills count)
- Installation wrapper scripts (`bin/vibe-install`, `bin/vibe-uninstall`, `bin/vibe-wrapper`)
- Enhanced error handling with context support for better debugging
- Thread-safe YAML loading with mutex protection
- SimpleCov test coverage enforcement (50% threshold)
- Performance benchmarks for critical operations (`test/benchmark/`)
- Command registry pattern for better CLI extensibility
- Cross-module dependency documentation to `lib/vibe/init_support.rb`
- CHANGELOG.md following Keep a Changelog format

### Changed
- Unified platform name normalization into `PlatformUtils::VALID_TARGETS` and `TARGET_ALIAS_MAP` (single source of truth)
- Extracted shared `build_and_deploy_target` method from `platform_installer.rb` and `quickstart_runner.rb`
- Cached `integration_status` results to avoid redundant filesystem probes during init flow
- Updated `lib/vibe/utils.rb` with documented lenient mode for `deep_merge`
- Improved CI workflow with SimpleCov integration and coverage checks
- Updated README files to reflect architecture improvements (English + Chinese)

### Removed
- Removed unused `Container` class (`lib/vibe/container.rb`) and its test file
- Removed deprecated `install_rtk` method and `install_rtk_with_choice` alias
- Removed completed planning documents from project root (`task_plan.md`, `optimization_plan.md`, `progress.md`, `phase2_plan.md`, `REFACTOR_PLAN.md`)

### Fixed
- Fixed `platform_installer.rb` bypassing `ask_yes_no` with raw stdin read
- Fixed `bin/vibe-smoke` missing `kimi-code` target in TARGETS array
- Fixed `test/test_vibe_overlay.rb` missing `antigravity` and `vscode` in SUPPORTED_TARGETS
- Fixed `rtk_hook_configured?` type safety by adding String type guard before `include?` call
- Fixed `validate-schemas` YAML loading to use `YAML.safe_load` with aliases support
- Fixed SimpleCov output format compatibility (support both `line` and `covered_percent` keys)
- Updated model name examples in `doc_rendering.rb` to use current Claude 4.6/4.5 model IDs
- Updated copyright year to 2026 in README files

## Phase 7 — Kimi Code Integration (2026-03)

### Added
- Kimi Code target support with native Chinese documentation
- Comprehensive CI drift protection for all 8 targets
- Parameterized snapshot testing framework
- Integration detection for all targets

### Changed
- Consolidated renderers and implemented quickstart command
- Repaired CI drift protection steps

## Phase 6 — Multi-Target Expansion (2026-02)

### Added
- Antigravity target support
- VS Code target support
- Warp terminal target support
- OpenCode target support
- Cursor target support
- Codex CLI target support

### Changed
- Refactored to portable core + target rendering architecture
- Unified skill registry system across all targets

## Phase 5 — Overlay System (2026-01)

### Added
- Overlay system for project-specific customization
- Profile mapping overrides
- Target-specific permission patches
- Policy append/merge capabilities

## Phase 4 — Skill System (2025-12)

### Added
- Portable skill registry (`core/skills/registry.yaml`)
- Skill security audit framework
- External skill pack integration support
- Namespace support for third-party skills

## Phase 3 — Policy Framework (2025-11)

### Added
- Behavior policy system (`core/policies/behaviors.yaml`)
- Task routing by complexity tiers
- Testing standards by task complexity
- Delivery standards and quality gates

## Phase 2 — Core Architecture (2025-10)

### Added
- Portable core specification under `core/`
- Provider-neutral workflow definitions
- Model tier abstraction layer
- Target adapter pattern

## Phase 1 — Foundation (2025-09)

### Added
- Initial Claude Code workflow template
- Memory system (auto memory + patterns)
- SSOT ownership model
- Basic documentation structure

---

This project is a fork of [@runes_leo](https://x.com/runes_leo)'s original vibesop, enhanced for maintainability and extended to serve Chinese developers.
