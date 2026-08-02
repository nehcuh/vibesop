# Architecture Decision Records (ADR)

This directory contains Architecture Decision Records for the VibeSOP project.

## What is an ADR?

An Architecture Decision Record (ADR) captures an important architectural decision made along with its context and consequences. ADRs help teams understand:

- **Why** a decision was made
- **What** alternatives were considered
- **What** the consequences are

## ADR Format

Each ADR follows this structure:

1. **Title** - A short noun phrase describing the decision
2. **Status** - Proposed / Accepted / Deprecated / Superseded
3. **Context** - The issue motivating this decision
4. **Decision** - The change being proposed or made
5. **Consequences** - What becomes easier or harder as a result
6. **Alternatives Considered** - Other options that were evaluated

## Creating a New ADR

1. Copy `0000-template.md` to a new file with a sequential number
2. Fill in all sections
3. Submit for review and discussion
4. Update status from "Proposed" to "Accepted" once approved

## ADR Index

| Number | Title | Status | Date |
|--------|-------|--------|------|
| 0001 | Use YAML as Configuration Format | Accepted | 2026-03-15 |
| 0002 | Portable Core Architecture | Accepted | 2026-03-16 |
| 0003 | Three-Layer Memory System | Accepted | 2026-03-17 |
| 0004 | Capability Tier Routing | Accepted | 2026-03-18 |

## Guidelines

### When to Create an ADR

Create an ADR when:
- Making a significant architectural change
- Choosing between multiple technical approaches
- Establishing a new pattern or convention
- Changing a previous architectural decision

### What Makes a Good ADR

- **Rationale over solution**: Focus on why, not just what
- **Context is king**: Include enough background for future readers
- **Be honest about tradeoffs**: Document both pros and cons
- **Keep it concise**: Aim for 1-2 pages

### ADR Lifecycle

```
Proposed → Accepted → (maybe) Deprecated → (maybe) Superseded
    ↓
 Rejected
```

- **Proposed**: Under discussion
- **Accepted**: Approved and active
- **Rejected**: Not approved (keep for historical record)
- **Deprecated**: No longer recommended, but still in use
- **Superseded**: Replaced by a newer ADR

## References

- [Documenting Architecture Decisions - Michael Nygard](https://cognitect.com/blog/2011/11/15/documenting-architecture-decisions)
- [Architecture Decision Records - GitHub](https://adr.github.io/)
- [When and how to use ADRs](https://github.com/joelparkerhenderson/architecture_decision_record)
