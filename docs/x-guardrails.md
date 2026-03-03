# Content Platform Guardrails (Compliance + Posting Cadence)

> On-demand loading. Trigger conditions in rules/capture.md.

---

## Affiliate/Paid Promotion Compliance

**Trigger**: Writing post that contains referral link / invite code / affiliate / promotion

**Core principle**: Conversion is good, but AI's job is **ensuring compliance disclosure**, not removing links.

**Auto-execute rules**:
- Draft contains affiliate/referral link -> **auto-append disclosure at end**
- Tool/software: `Disclosure: Affiliate link, I may earn commission. #ad`
- When official platform disclosure features are available, use those instead
- Non-monetized personal sharing -> add `Personal referral, not sponsored` to prevent false positives
- Content must have value (tutorial/deep analysis), avoid batch template/spam posts

---

## Posting Cadence Guardrails (Auto-intercept)

**Trigger**: Discussing posting / content scheduling / quoting / reply strategy

**Hard rules (intercept when violated)**:
- Daily: **3-4 original** posts as main, **<3-4 quotes** as supplement, total **<=8**
- **Original first, Quote as backup** — quotes only when genuinely out of original ideas
- Quotes only for **genuinely high-performing content** — average content just absorb, don't quote
- Quotes must add independent perspective/framework/insight, not just repost + one line
- Each original post ends with a **specific low-barrier open question** (Bad: "what do you think" Good: "which framework have you used?")

**Intercept message**:
```
Cadence guardrail reminder: [specific violation]
```

**Don't intercept**:
- Breaking news requiring fast response (timeliness > cadence)
- User explicitly says "exception today"

---

## External Link Guardrails (Auto-execute)

**Core fact**: Platform algorithms optimize for "user dwell time". Posts with external links see 30-50% impression drop.

**Auto-execute rules**:
- Post contains external link (YouTube/blog/tool etc) -> **move link to first reply**, main post uses text/image/video
- When main post has image, remind: post main content first, **within 10 seconds** post reply with link
- Exception: User explicitly says "link in main post"

---

*Customize platform-specific rules based on your posting strategy and platform of choice.*
