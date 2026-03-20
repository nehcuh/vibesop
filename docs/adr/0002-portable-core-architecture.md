# [ADR-0002] Portable Core Architecture

## Status

**Accepted**

Proposed: 2026-03-16  
Accepted: 2026-03-16

## Context

VibeSOP aims to support multiple AI coding tools (Claude Code, OpenCode, Cursor, etc.) with consistent workflow practices. The challenge is:

- Each tool has different configuration formats and locations
- We want to avoid duplicating workflow logic for each tool
- Changes to core policies should apply to all tools
- We need to support tool-specific features without breaking portability

Without a portable architecture, we would need to maintain separate configuration sets for each tool, leading to drift and inconsistency.

## Decision

We will implement a **Portable Core Architecture** with three layers:

1. **`core/`** - Platform-agnostic semantic layer (YAML)
   - Defines intent and policy, not tool-specific syntax
   - Single source of truth for all tools
   
2. **`targets/`** - Platform adapters (Markdown contracts)
   - Documents how each tool should interpret the core
   - Specifies tool-specific rendering rules
   
3. **`bin/vibe`** - Generator CLI (Ruby)
   - Materializes tool-specific configurations from core
   - Handles platform differences automatically

## Rationale

This architecture follows the **Adapter Pattern**:

```
┌─────────────────────────────────────┐
│  core/ (Platform-agnostic)          │
│  ├─ models/tiers.yaml               │
│  ├─ skills/registry.yaml            │
│  └─ policies/*.yaml                 │
└──────────────┬──────────────────────┘
               │ bin/vibe build
┌──────────────▼──────────────────────┐
│  targets/ (Platform adapters)       │
│  ├─ claude-code.md                  │
│  ├─ opencode.md                     │
│  └─ cursor.md                       │
└──────────────┬──────────────────────┘
               │ Render
┌──────────────▼──────────────────────┐
│  generated/<target>/                │
│  (Tool-specific configurations)     │
└─────────────────────────────────────┘
```

This separation allows:
- Core logic to evolve independently
- New tools to be added without changing core
- Tool-specific optimizations without affecting others

## Consequences

### Positive

- **Single Source of Truth**: All policies defined once in `core/`
- **Easy Multi-Platform Support**: Add new tool by creating adapter
- **Upgrade Path**: Core improvements benefit all tools automatically
- **Consistency**: All tools follow same workflow principles
- **Testability**: Core logic can be tested independently

### Negative

- **Complexity**: Three-layer architecture has learning curve
- **Indirection**: Must understand mapping to debug issues
- **Incomplete Translation**: Some tool features can't be represented portably
- **Generator Dependency**: Requires `bin/vibe` to generate configs

### Neutral

- Documentation must cover both core concepts and tool-specific usage
- Contributors need to understand adapter pattern
- Some policies may be tool-specific (handled via overlays)

## Alternatives Considered

### Alternative 1: Separate Configs per Tool

**Description**: Maintain independent configuration sets for each tool

**Pros**:
- Maximum flexibility per tool
- No generator needed
- Direct tool-specific optimizations

**Cons**:
- High maintenance burden
- Risk of drift and inconsistency
- Changes must be replicated N times
- No guarantee of consistency

**Why not chosen**: Does not scale with number of supported tools; violates DRY principle.

### Alternative 2: Universal Configuration Format

**Description**: Create a single configuration format that all tools adopt

**Pros**:
- No need for adapters
- Direct consumption by tools

**Cons**:
- Requires tool vendors to adopt our format
- Not realistic for existing tools
- Limits tool-specific features

**Why not chosen**: Not feasible without tool vendor cooperation.

### Alternative 3: Template-Based Generation

**Description**: Use string templates to generate configs

**Pros**:
- Simple to implement
- Familiar pattern

**Cons**:
- Templates become complex quickly
- Hard to validate
- Limited expressiveness
- Mixing logic and presentation

**Why not chosen**: YAML-based semantic approach is more maintainable and testable.

## Implementation Notes

### Core Invariants

1. `core/` defines **intent and policy**, not tool-specific syntax
2. `targets/` explains **how** to render, not **what** to render
3. Existing tool configs remain usable during transition
4. When tool has native enforcement, prefer it; otherwise use instructions

### Migration Path

Phase 1: Define portable spec in `core/`  
Phase 2: Implement `bin/vibe` generator  
Phase 3: Add overlay system for customization  
Phase 4: Extend to additional tools  

### File Structure

```
core/
├── models/
│   ├── tiers.yaml       # Capability tier definitions
│   └── providers.yaml   # Tool/provider profiles
├── skills/
│   └── registry.yaml    # Skill metadata
├── security/
│   └── policy.yaml      # Security policies
└── policies/
    ├── behaviors.yaml   # Behavior rules
    ├── task-routing.yaml
    └── test-standards.yaml
```

## Related Decisions

- ADR-0001: Use YAML as Configuration Format
- ADR-0004: Capability Tier Routing
- ADR-0003: Three-Layer Memory System

## References

- [Adapter Pattern](https://en.wikipedia.org/wiki/Adapter_pattern)
- [Configuration as Code](https://martinfowler.com/bliki/ConfigurationAsCode.html)
- [core/README.md](../../core/README.md)
