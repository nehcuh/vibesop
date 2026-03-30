# Documentation Sync Checklist

**Purpose**: Ensure documentation stays in sync with code implementation  
**Frequency**: Run before every PR, after major features, monthly audit  
**Owner**: PR author + reviewer

---

## Quick Check

Run this command to check documentation status:

```bash
bin/vibe doc-check
```

Or manually verify using the checklist below.

---

## Checklist

### ✅ After Code Changes

When you modify code, ensure these docs are updated:

| Code Change | Documentation to Update |
|-------------|------------------------|
| Add new platform | `config/platforms.yaml`, `targets/{platform}.md`, `README.md` |
| Modify routing logic | `docs/architecture/ai-powered-skill-routing.md` |
| Add new skill | `core/skills/registry.yaml`, `docs/skills-guide.md` |
| Change architecture | Update relevant ADR, mark as `Implemented` |
| Refactor major component | `docs/architecture/current-architecture-analysis.md` |
| Update CLI commands | `README.md`, `docs/usage-examples.md` |
| Change configuration format | `docs/architecture/adr-*.md`, relevant target docs |

### ✅ Line Count Verification

Verify code statistics match documentation:

```bash
# Count lines in key files
wc -l lib/vibe/target_renderers.rb lib/vibe/config_driven_renderers.rb

# Count test cases
grep -r "def test_" test/ | wc -l

# Check for TODO/FIXME
grep -r "TODO\|FIXME" lib/ --include="*.rb" | wc -l
```

**Update these docs if counts change**:
- `README.md` - test count claims
- `docs/architecture/current-architecture-analysis.md` - line counts
- `PROJECT_CONTEXT.md` - session handoff metrics

### ✅ ADR Status Verification

Ensure ADR status matches implementation:

```bash
grep -l "^## Status" docs/architecture/adr-*.md | xargs -I {} sh -c 'echo "=== {} ===" && grep "^## Status" {}'
```

**Rules**:
- If code is implemented → Status should be `Implemented ✅`
- If code is not implemented → Status should be `Proposed`
- If code is deprecated → Status should be `Deprecated`

### ✅ Architecture Consistency

Verify architecture docs match code:

| Document | Verify Against | Check |
|----------|---------------|-------|
| `multi-provider-architecture.md` | `lib/vibe/llm_provider/` | All providers implemented |
| `ai-powered-skill-routing.md` | `lib/vibe/skill_router/` | 5 layers implemented |
| `current-architecture-analysis.md` | `config/platforms.yaml` | Platform configs exist |

### ✅ Platform Support Claims

Verify platform support claims:

```bash
# Check implemented platforms
ruby -r yaml -e "puts YAML.safe_load(File.read('config/platforms.yaml'))['platforms'].keys"

# Check documented platforms
grep -E "^\\| (Claude Code|OpenCode|Cursor|VS Code)" README.md
```

**Rules**:
- `✅ Production` = Must have full implementation + tests
- `📝 Planned` = Can have partial implementation or design only
- `⚠️ Beta` = Must have implementation but may have known issues

---

## Automation

### Pre-Commit Hook

Add to `.git/hooks/pre-commit`:

```bash
#!/bin/bash
# Documentation sync check

echo "Checking documentation sync..."

# Check ADR status
grep -r "^## Status$" docs/architecture/adr-*.md | while read line; do
  file=$(echo "$line" | cut -d: -f1)
  next_line=$(grep -A1 "^## Status$" "$file" | tail -1)
  if echo "$next_line" | grep -q "Proposed"; then
    # Check if corresponding code exists
    # Add logic here
    : # placeholder
  fi
done

echo "✅ Documentation sync check passed"
```

### CI/CD Integration

Add to your CI pipeline:

```yaml
# .github/workflows/doc-sync.yml
name: Documentation Sync Check

on: [pull_request]

jobs:
  doc-sync:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Check ADR status
        run: |
          for file in docs/architecture/adr-*.md; do
            echo "Checking $file"
            # Add verification logic
          done
      - name: Verify line counts
        run: |
          echo "Verifying code statistics..."
          wc -l lib/vibe/target_renderers.rb
      - name: Check platform claims
        run: |
          ruby -r yaml -e "puts YAML.safe_load(File.read('config/platforms.yaml'))['platforms'].keys"
```

---

## Common Issues & Solutions

### Issue: ADR says "Proposed" but code is implemented

**Solution**: Update ADR status to `Implemented ✅ (YYYY-MM-DD)`

### Issue: Line counts in docs don't match code

**Solution**: Update docs with actual line counts, explain improvements

### Issue: README claims features not in code

**Solution**: Either implement feature or remove claim from README

### Issue: Platform documented but not implemented

**Solution**: 
- Change status from `✅ Production` to `📝 Planned`
- Or implement the platform

---

## Review Checklist (For PR Reviewers)

Before approving PR, verify:

- [ ] Code changes have corresponding doc updates
- [ ] ADR status matches implementation state
- [ ] README claims are accurate
- [ ] Line counts are correct (if mentioned)
- [ ] Platform support status is accurate
- [ ] New features are documented
- [ ] Examples work as documented

---

## Monthly Audit

Schedule monthly documentation audit:

```bash
# Run full documentation check
bin/vibe doc-audit

# Or manually check:
# 1. All ADR statuses
# 2. README platform support table
# 3. Architecture docs vs code
# 4. Example commands work
```

---

## Related Documents

- [Architecture Decision Records](./adr-*.md)
- [Current Architecture Analysis](./current-architecture-analysis.md)
- [Project Context](../../PROJECT_CONTEXT.md)

---

**Last Updated**: 2026-03-30  
**Status**: Active  
**Next Review**: 2026-04-30
