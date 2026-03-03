# Request Code Review

Prepare current changes for code review.

## 1. Collect Change Info

```bash
# Changed file list
git diff --name-only main...HEAD

# Change stats
git diff --stat main...HEAD

# Detailed changes
git diff main...HEAD
```

## 2. Generate Review Request

Based on changes, generate review summary:

```markdown
## Review Request

### Change Overview
- Purpose: [from commit message or user input]
- Scope: [X files, +Y/-Z lines]

### Changed Files
| File | Type | Description |
|------|------|-------------|
| ... | Added/Modified/Deleted | ... |

### Test Status
- [ ] lint passes
- [ ] build passes
- [ ] tests pass

### Focus Areas
Please pay special attention to:
- [parts needing careful review]

### Related Docs
- [if any]
```

## 3. Use PR Reviewer Agent

Call `pr-reviewer` agent for automated review, generate review report.

## 4. Output Review Materials

Output complete review request, usable for:
- Creating GitHub PR
- Team notifications
- Self-review
