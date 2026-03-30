# Implementation Checklist

> Use this checklist BEFORE implementing any feature that involves AI/ML or external services.

## Phase 1: Analysis (Before Any Code)

### Scenarios Matrix
- [ ] List ALL runtime environments
  - [ ] Claude Code (internal AI available)
  - [ ] OpenCode (may need external AI)
  - [ ] Standalone CLI
  - [ ] Other: _______
- [ ] Define behavior for EACH environment
- [ ] Map capabilities: What does each environment provide?

### Edge Cases
- [ ] No match / Not found → What happens?
- [ ] Multiple matches (same confidence) → How to resolve?
- [ ] API failure / timeout → Fallback strategy?
- [ ] User override request → How to allow?
- [ ] Rate limits → How to handle?

### Philosophy Statement
- [ ] "AI decides" vs "AI suggests, human decides" → Pick one
- [ ] Document this choice clearly
- [ ] Design everything around this choice

### Testing Strategy
- [ ] How to test in Claude Code?
- [ ] How to test in OpenCode?
- [ ] How to test standalone?
- [ ] What mocks/stubs needed?

---

## Phase 2: Design (Before Implementation)

### Architecture
- [ ] Environment detection first
  ```ruby
  if claude_code?
    use_internal_ai
  elsif opencode?
    use_external_ai
  else
    fallback_or_error
  end
  ```
- [ ] Feature flags for runtime configuration
- [ ] Stats/metrics for observability

### Error Handling
- [ ] Each external call has timeout
- [ ] Each external call has fallback
- [ ] Each error is logged with context
- [ ] User sees helpful error message

### User Control
- [ ] Can user disable the feature?
- [ ] Can user override the default?
- [ ] Can user see what's happening?

---

## Phase 3: Implementation (During Coding)

### Red Flags
- [ ] If you find yourself patching the same area 3+ times → STOP and redesign
- [ ] If you're saying "I'll fix that later" → Fix now or document as limitation
- [ ] If docs say "should work" without testing → Either test or remove claim

### Observability
- [ ] Add `--stats` or `--debug` command
- [ ] Log environment detection
- [ ] Log decisions made
- [ ] Log fallbacks taken

---

## Phase 4: Verification (Before Commit)

### Testing
- [ ] Test in Claude Code environment
- [ ] Test in OpenCode environment (if applicable)
- [ ] Test standalone
- [ ] Test with API unavailable
- [ ] Test with timeout

### Documentation
- [ ] Every claim in README is verified
- [ ] Every example actually works
- [ ] Limitations are documented
- [ ] Workarounds are provided

### Review Questions
- [ ] Does this behave correctly in ALL environments?
- [ ] What happens if external service is down?
- [ ] Can user still work if this feature fails?
- [ ] Is the behavior documented and observable?

---

## Quick Reference: Common Patterns

### ❌ Bad Patterns

```ruby
# Bad: Assumes standalone
class Feature
  def initialize
    @api = ExternalAPI.new  # Always calls external
  end
end

# Bad: No fallback
def route(input)
  @ai.classify(input)  # Crashes if API down
end

# Bad: User locked in
if ai.suggests_x?
  use_x  # User has no choice
end
```

### ✅ Good Patterns

```ruby
# Good: Environment-aware
class Feature
  def initialize
    @env = detect_environment
    @strategy = Strategy.for(@env)
  end
end

# Good: With fallback
def route(input)
  @strategy.classify(input) || fallback_route(input)
end

# Good: User chooses
suggestion = ai.suggest(input)
puts "AI suggests: #{suggestion}"
puts "Options: accept | use <other> | skip"
choice = get_user_choice
```

---

## Post-Mortem Template

If you find yourself in a "why did we implement it this way" situation:

1. What was the original requirement?
2. What environment did we assume?
3. What environment did we miss?
4. What was the third patch trying to fix?
5. What should we have asked in Phase 1?

Use answers to update this checklist.
