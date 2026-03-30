# AI Routing Implementation Retrospective

## Issue
The AI routing feature underwent multiple iterations and fixes over several reviews:
- Initial claim: Dual platform support (Claude Code + OpenCode)
- Discovery: Auto-routing wasn't triggering
- Discovery: AI was too permissive (matched everything)
- Discovery: Wrong approach to "no match" scenario
- Discovery: Using external API when internal was available
- ... and more

## Root Cause Analysis

### 1. Insufficient Requirements Analysis

**Problem**: Started implementation without fully defining the problem space.

| What we should have done | What we actually did |
|--------------------------|----------------------|
| Define all runtime environments upfront | Assumed "CLI only" |
| Map Claude Code capabilities | Treated it as "just another target" |
| Define "no match" behavior | Added as afterthought |
| Consider user control philosophy | Defaulted to "AI knows best" |

**Lesson**: **Never implement without a complete scenarios matrix.**

---

### 2. Premature Claims in Documentation

**Problem**: README claimed features that weren't actually verified.

```
README claimed:
✅ "Simultaneous support for Claude Code and OpenCode"

Reality:
❌ Claude Code was calling external API unnecessarily
❌ Auto-routing wasn't automatic at all
```

**Lesson**: **Documentation is a spec, not marketing. Don't claim it until you've tested it.**

---

### 3. Missing "No Match" Handling

**Problem**: Assumed AI would always find a match.

```
User: "What's the weather like?"
AI: matches experience-evolution ???
```

**Root cause**: Prompt didn't explicitly allow "no match" as a valid outcome.

**Lesson**: **Always define the "fail/unmatch" case first, not last.**

---

### 4. Wrong Mental Model: AI vs Tool

**Problem**: Treated AI as the decision-maker rather than a recommender.

```
Initial approach: "AI decides which skill to use"
Better approach: "AI suggests, user decides"
```

**Lesson**: **In developer tools, the human should always have final say.**

---

### 5. Environmental Blindness

**Problem**: Didn't consider that Claude Code has built-in AI capabilities.

```
We implemented:
  Ruby → External API Call → AI Response

We should have asked:
  "Are we running inside an AI agent already?"
  "Can we use the host's capabilities instead?"
```

**Lesson**: **Always check: "Does my environment already solve this problem?"**

---

### 6. Iterative Patching vs. Re-design

**Problem**: Each fix was a patch on previous code, not a re-think.

```
Patch 1: "AI too permissive" → Change prompt
Patch 2: "Users want control" → Add fallback UI
Patch 3: "Wrong in Claude Code" → Add env detection
```

Better approach would have been to pause after Patch 1 and ask:
"What are ALL the scenarios this feature needs to handle?"

**Lesson**: **After 2-3 patches, stop and redesign. Don't paint over cracks.**

---

## Prevention Checklist

### Before Implementation

- [ ] **Scenarios Matrix**: List ALL runtime environments
  - [ ] Claude Code (internal)
  - [ ] OpenCode
  - [ ] Standalone CLI
  - [ ] Other?

- [ ] **Capability Audit**: What does each environment provide?
  - [ ] Built-in AI? → Use it
  - [ ] No AI? → Provide external option
  - [ ] Something else?

- [ ] **Edge Cases**: Define behavior for:
  - [ ] No match found
  - [ ] Multiple matches (same confidence)
  - [ ] API failure / timeout
  - [ ] User override request

- [ ] **Philosophy Statement**: "AI recommends, human decides" vs "AI decides"
  - [ ] Document this clearly
  - [ ] Design accordingly

- [ ] **Testing Strategy**:
  - [ ] How to test in Claude Code?
  - [ ] How to test in OpenCode?
  - [ ] How to test standalone?

### During Implementation

- [ ] **Environment Detection First**: Before any AI logic
  ```ruby
  def runtime_environment
    if claude_code?
      :internal_ai_available
    elsif opencode?
      :needs_external_ai
    else
      :standalone
    end
  end
  ```

- [ ] **Feature Flags**: Allow runtime configuration
  ```ruby
  enabled = ENV.fetch('FEATURE_X_ENABLED', 'auto') == 'true'
  auto_detect = ENV['FEATURE_X_ENABLED'] == 'auto'
  ```

- [ ] **Stats/Metrics**: Make behavior observable
  ```bash
  $ vibe route --stats
  Environment: claude_code
  AI Triage: Disabled (using internal)
  ```

### Before Documentation

- [ ] **Verify Every Claim**: If README says X, test X
- [ ] **Test in All Environments**: Claude Code, OpenCode, standalone
- [ ] **Document Limitations**: What doesn't work?
- [ ] **Provide Workarounds**: How to override defaults?

---

## Red Flags to Watch For

### During Development

🚩 **"I'll fix that later"** → Fix it now or document as known limitation

🚩 **"This is good enough"** → What's the failure mode?

🚩 **Adding third workaround** → Time to redesign

🚩 **Documentation says "should work"** → Either test it or remove the claim

### During Review

🚩 **"But the prompt should..."** → Prompts are not control flow

🚩 **"Most cases work"** → Define "most" and handle the rest

🚩 **"User can just override"** → Make the override explicit, not hidden

---

## Architecture Principles Learned

### 1. Environment-Aware Design

```ruby
# ❌ Bad: Assumes standalone CLI
class Router
  def initialize
    @ai_client = ExternalAIClient.new
  end
end

# ✅ Good: Environment-aware
class Router
  def initialize
    @runtime_env = detect_environment
    @ai_strategy = AIStrategy.for(@runtime_env)
  end
end
```

### 2. Fail-Open vs Fail-Closed

```ruby
# ❌ Bad: AI must match something
def route(input)
  match = ai.find_match(input) || fallback.match(input)
end

# ✅ Good: No match is valid
def route(input)
  if (match = ai.find_match(input))
    return match
  else
    return no_match_result_with_alternatives
  end
end
```

### 3. Explicit vs Implicit

```ruby
# ❌ Bad: Implicit behavior
"When uncertain, use AI routing"

# ✅ Good: Explicit contract
"MANDATORY: ALWAYS call vibe route before non-trivial tasks
 This is NOT optional — but YOU decide whether to follow the suggestion"
```

---

## Testing Strategy for Future Features

### Unit Tests
- [ ] Each environment scenario
- [ ] Each edge case (no match, multiple matches, failures)
- [ ] Environment detection logic

### Integration Tests
- [ ] Run inside Claude Code
- [ ] Run inside OpenCode
- [ ] Run as standalone CLI
- [ ] With/without API keys configured

### Documentation Tests
- [ ] Every README claim has a test
- [ ] Every example actually works
- [ ] Screenshots match current behavior

---

## Summary

| Issue | Root Cause | Fix |
|-------|-----------|-----|
| Auto-routing not triggering | Conditional prompt ("When uncertain") | Unconditional prompt + Hook |
| AI matches everything | No "no match" option | Allow null in prompt |
| Wrong in Claude Code | Didn't check environment | Environment detection |
| Users feel locked in | AI decides, not suggests | User choice mode |

**Core Lesson**: Think through ALL scenarios before writing code. Test in ALL environments before documenting.

---

## Action Items for Future Features

1. **Start with scenarios matrix** — Don't write code until you have one
2. **Test while developing** — Not after
3. **Document what you tested, not what you hope works**
4. **After 3 patches, redesign** — Don't accumulate patches
5. **Make behavior observable** — Stats, debug output, status commands
