# Behavior Rules — Reference Details (On-demand loading)

> Core rules in `rules/behaviors.md`. Detailed operation guides here.

---

## Browser/Puppeteer Conflict Handling

When Puppeteer reports "browser is already running":
1. **Never tell user "can't do it"**
2. Proactively kill occupying process: `pkill -f "chrome.*puppeteer-profile" || true`
3. Retry original operation
4. If still failing, use fallback (oEmbed, curl, etc.)

Principle: **Solve the problem yourself, don't throw failures to user.**

---

## Memory Search — Scope Routing Table

**No** unscoped global search (hundreds of docs flat = terrible signal-to-noise).

| Keywords | Collection |
|----------|-----------|
| Your project keywords | `project-name` |
| Memory / patterns / recall / pitfalls | `memory` or `patterns` |
| Notes / knowledge base | `vault` |
| Not sure | Start with `memory`, expand to `all` if needed |

Example: `qmd search "deployment issue" collection=your-project`

### Code/Project Search: Two-stage RAG

When finding "where is this feature":
1. **L0** First `ls` or `find . -maxdepth 2` to locate candidate directories/files (<=5)
2. **L1** Only search within candidates using `grep` or `qmd search`

Banned: Unscoped full-text search across entire project.

---

*Split from rules/behaviors.md*
