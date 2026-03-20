# [ADR-0001] Use YAML as Configuration Format

## Status

**Accepted**

Proposed: 2026-03-15  
Accepted: 2026-03-15

## Context

VibeSOP needs a configuration format to store workflow rules, skill definitions, security policies, and model routing information. The configuration must be:

- Human-readable and editable
- Version control friendly
- Easy to parse programmatically
- Capable of representing hierarchical data
- Familiar to developers

The configuration files will be read frequently during builds but modified rarely.

## Decision

We will use **YAML (YAML Ain't Markup Language)** as the primary configuration format for all core configuration files in the `core/` directory.

## Rationale

YAML was chosen because it:

1. **Human-Readable**: Clean syntax with minimal punctuation makes it easy to read and edit
2. **Git-Friendly**: Line-based format works well with diff tools and version control
3. **Native Ruby Support**: Ruby's standard library includes YAML parsing (no dependencies)
4. **Hierarchical**: Naturally represents nested structures like skill definitions and policies
5. **Widely Known**: Most developers are familiar with YAML from other tools

## Consequences

### Positive

- Zero runtime dependencies (Ruby stdlib includes YAML)
- Configuration files are self-documenting
- Easy to review changes in pull requests
- Supports comments for inline documentation
- Can represent complex nested structures cleanly

### Negative

- Whitespace sensitivity can cause errors (mitigated by validation)
- Complex configurations can become hard to read
- No type system (validation must be external)
- Some editors have limited YAML support compared to JSON

### Neutral

- Team needs to follow consistent formatting conventions
- Schema validation required (implemented via JSON Schema)

## Alternatives Considered

### Alternative 1: JSON

**Description**: Use JSON as the configuration format

**Pros**:
- Universal support across all languages
- Strict syntax (easier to parse)
- Better editor support
- JSON Schema is the standard

**Cons**:
- No comments (critical for documentation)
- Verbose syntax (lots of quotes and braces)
- Harder for humans to read and edit
- Multi-line strings are awkward

**Why not chosen**: Lack of comment support makes it unsuitable for complex configuration files that need inline documentation.

### Alternative 2: TOML

**Description**: Use TOML (Tom's Obvious Minimal Language)

**Pros**:
- Human-readable
- Supports comments
- Strictly defined specification
- Good for flat configurations

**Cons**:
- Not in Ruby stdlib (requires dependency)
- Less familiar to most developers
- Hierarchical structures can be verbose
- Smaller ecosystem

**Why not chosen**: Requiring an external dependency contradicts our zero-dependency principle for runtime.

### Alternative 3: Ruby DSL

**Description**: Use Ruby code for configuration

**Pros**:
- Maximum flexibility
- Can use Ruby's full power
- No parsing needed

**Cons**:
- Security concerns (executing arbitrary code)
- Not language-agnostic
- Harder to validate
- Too much power leads to inconsistency

**Why not chosen**: Security concerns and lack of portability to other tools/languages.

## Implementation Notes

- All YAML files must include `schema_version` for future compatibility
- Use `YAML.safe_load` with `aliases: true` for security
- Validate against JSON Schema on load
- Use 2-space indentation consistently
- Prefer explicit keys over implicit typing

## Related Decisions

- ADR-0002: Portable Core Architecture
- ADR-0004: Capability Tier Routing

## References

- [YAML Specification](https://yaml.org/spec/)
- [Ruby YAML Module](https://ruby-doc.org/stdlib/libdoc/yaml/rdoc/YAML.html)
- [JSON Schema for YAML](https://json-schema.org/)
