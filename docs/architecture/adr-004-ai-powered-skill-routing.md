# ADR-004: AI-Powered Skill Routing Optimization

**Status**: Proposed
**Date**: 2026-03-29
**Decision**: Implement AI-powered semantic triage layer for skill routing
**Related**: [ADR-001: Configuration-Driven Renderer](./adr-001-renderer-refactor.md)

---

## Context

### Current State

VibeSOP uses a 4-layer routing system for skill matching:

1. **Explicit Layer**: User overrides (e.g., "use gstack for debugging")
2. **Scenario Layer**: Keyword-based scenario matching
3. **Semantic Layer**: TF-IDF + cosine similarity
4. **Fuzzy Layer**: Fuzzy matching for typos

**Performance**:
- Match accuracy: ~70% (based on keyword/algorithm matching)
- Response time: <10ms (no LLM calls)
- Cost: $0 (algorithm-based)

**Problems**:
- Cannot understand complex semantic intent
- Struggles with implicit user requests
- Limited by keyword matching and similarity algorithms
- No context awareness beyond file types

### User Proposal

Add an AI-powered semantic triage layer (Layer 0) that:
1. Uses a small model (Haiku) for fast semantic analysis
2. Matches user intent to appropriate skills
3. Then calls larger models for actual skill execution

---

## Decision

### Architecture

Implement a **5-layer routing system** with AI-powered triage:

```
Layer 0: AI Triage Layer (NEW)
  ├─ Cache check (multi-level)
  ├─ Quick algorithm pre-check
  └─ AI semantic analysis (Haiku)
Layer 1: Explicit Layer (existing)
Layer 2: Scenario Layer (existing)
Layer 3: Semantic Layer (existing)
Layer 4: Fuzzy Layer (existing)
```

### Technical Specifications

#### Layer 0: AI Triage Layer

**Model**: Claude Haiku (`claude-haiku-4-5-20251001`)
- Cost: $0.000125 per request
- Latency: ~150ms
- Max tokens: 300
- Temperature: 0.3

**Components**:
1. `AITriageLayer` - Main routing logic
2. `LLMClient` - API client with retry/timeout
3. `CacheManager` - Multi-level caching (Memory → File → Redis)
4. `CostMonitor` - Real-time cost tracking

**Optimization Strategies**:
- Multi-level caching (target >70% hit rate)
- Token optimization (reduce prompt size by 30%)
- Intelligent retry (exponential backoff)
- Rate limiting (max 100 requests/hour)
- Circuit breaker (fail fast on repeated errors)

#### Routing Logic

```ruby
def route(user_input, context = {})
  # 1. Cache check
  return cached_result if cache_hit?

  # 2. Quick algorithm check (high confidence)
  return quick_result if high_confidence_match?

  # 3. AI semantic analysis
  ai_result = call_haiku(user_input, context)

  # 4. Match skill
  match_skill(ai_result)

  # 5. Fallback to existing layers if failed
end
```

### Performance Targets

| Metric | Target | Measurement |
|--------|--------|-------------|
| Match accuracy | >90% | A/B testing |
| P95 response time | <300ms | Performance monitoring |
| Cache hit rate | >70% | Cache statistics |
| Error rate | <2% | Error monitoring |
| Monthly cost | <$1 | Cost tracking |

### Rollout Plan

**Phase 1: Implementation** (1 week)
- Core components (AITriageLayer, LLMClient, CacheManager)
- Unit tests (>80% coverage)
- Integration tests

**Phase 2: Optimization** (3 days)
- Multi-level caching
- Token optimization
- Performance testing

**Phase 3: Quality Assurance** (2 days)
- A/B testing framework
- Accuracy evaluation
- Cost validation

**Phase 4: Gradual Rollout** (1 week)
- Feature flag: 10% → 50% → 100%
- Monitoring and alerting
- User feedback collection

---

## Rationale

### Why This Approach?

**1. Accuracy Improvement**
- Current: 70% (keyword/algorithm-based)
- Proposed: 95% (semantic understanding)
- **Value**: +36% accuracy means better user experience

**2. Cost-Effective**
- Monthly cost: ~$0.11 (100 requests/day × $0.000125 × 30 days)
- With 70% cache hit: ~$0.03/month
- **Value**: Negligible cost for significant improvement

**3. Fast Enough**
- Haiku latency: ~150ms
- Cache hit: ~5ms
- P95 target: <300ms
- **Value**: Acceptable delay for better accuracy

**4. Reliable Fallback**
- If AI Triage fails → automatic fallback to existing layers
- No degradation of current functionality
- **Value**: Risk-free implementation

### Alternatives Considered

#### Alternative 1: Use Larger Model (Sonnet)
**Pros**:
- Higher accuracy potentially

**Cons**:
- 10x more expensive ($0.003/request vs $0.000125)
- Slower response time (~500ms vs ~150ms)
- Overkill for simple intent classification

**Decision**: Haiku provides better cost/performance ratio

#### Alternative 2: Purely Algorithm-Based Improvements
**Pros**:
- No additional cost
- Faster response time

**Cons**:
- Limited accuracy improvement (80% vs 95%)
- Still struggles with semantic understanding
- Requires significant R&D investment

**Decision**: AI Triage provides better ROI

#### Alternative 3: Hybrid (Algorithm + AI)
**Pros**:
- Best of both worlds

**Cons**:
- More complex to implement
- Harder to maintain

**Decision**: This is actually our approach - algorithm pre-filter before AI

### Key Insights

1. **Small Model is Sufficient**: Haiku is powerful enough for intent classification
2. **Caching is Critical**: 70% cache hit rate makes solution cost-effective
3. **Fallback is Essential**: Reliability is more important than optimization
4. **Monitoring Matters**: Need comprehensive metrics to validate assumptions

---

## Consequences

### Positive

**1. User Experience**
- More accurate skill matching
- Better understanding of user intent
- Reduced frustration from wrong skill selection

**2. Technical Benefits**
- Modern, AI-powered architecture
- Reusable components (LLMClient, CacheManager)
- Foundation for future AI features

**3. Business Value**
- Competitive advantage (AI-powered routing)
- Improved user satisfaction
- Data-driven decision making

### Negative

**1. Added Complexity**
- More components to maintain
- Additional dependencies (API keys, cache infrastructure)
- Increased testing surface

**2. Cost**
- New operational cost ($0.11/month)
- Requires API key management
- Need cost monitoring

**3. Latency**
- Slightly slower response time (200ms vs 10ms)
- Cache misses cause delays
- Network dependency

### Mitigation Strategies

**1. Complexity**
- Comprehensive documentation
- Extensive testing (>80% coverage)
- Clear separation of concerns

**2. Cost**
- Multi-level caching (reduce API calls)
- Rate limiting (prevent runaway costs)
- Cost monitoring and alerting

**3. Latency**
- Aggressive caching (70%+ hit rate)
- Fast algorithm pre-filter
- Timeout protection (5s max)

---

## Implementation Status

### Completed
- [x] Architecture design
- [x] Technical specifications
- [x] Cost analysis
- [x] Risk assessment

### In Progress
- [ ] Core component implementation
- [ ] Unit testing
- [ ] Integration testing

### Planned
- [ ] Performance optimization
- [ ] A/B testing
- [ ] Gradual rollout
- [ ] Documentation updates

---

## Validation

### Success Criteria

**Technical**:
- [ ] Match accuracy >90% (vs 70% baseline)
- [ ] P95 response time <300ms
- [ ] Cache hit rate >70%
- [ ] Error rate <2%

**Business**:
- [ ] Monthly cost <$1
- [ ] User satisfaction >80%
- [ ] Skill usage rate increase >20%

**Quality**:
- [ ] Unit test coverage >80%
- [ ] Integration test pass rate 100%
- [ ] Zero production incidents in first month

### Monitoring

**Metrics to Track**:
```ruby
{
  # Performance
  avg_response_time: <250ms,
  p95_response_time: <300ms,
  p99_response_time: <500ms,

  # Cost
  total_requests: 100/day,
  cache_hit_rate: 70%,
  actual_api_calls: 30/day,
  daily_cost: $0.00375,
  monthly_cost: $0.11,

  # Quality
  match_accuracy: 95%,
  error_rate: 1.5%,
  timeout_rate: 0.5%,

  # User
  satisfaction_score: 85%,
  skill_usage_increase: 25%
}
```

### Rollback Criteria

**Immediate Rollback**:
- Error rate >10%
- P95 response time >1s
- Daily cost >$5

**Investigation Required**:
- Match accuracy <80%
- Cache hit rate <50%
- User satisfaction <60%

---

## Related Documents

- [Full Architecture Design](./ai-powered-skill-routing.md)
- [Implementation Details](./ai-routing-implementation-details.md)
- [Quick Reference](./ai-routing-quick-reference.md)
- [Cost Analysis](../architecture/ai-routing-cost-analysis.md) (to be created)
- [Testing Strategy](../testing/ai-routing-test-plan.md) (to be created)

---

## References

- [Haiku Model Card](https://docs.anthropic.com/claude/docs/models-overview)
- [Anthropic API Pricing](https://www.anthropic.com/pricing)
- [Best Practices for Prompt Engineering](https://docs.anthropic.com/claude/docs/prompt-engineering)
- [Skill Router Architecture](./current-architecture-analysis.md)

---

**Authors**: VibeSOP Team
**Reviewers**: TBD
**Approval**: Pending

---

## Appendix: Example Usage

### Before (Algorithm-Based)

```bash
$ vibe route "帮我看看这个生产环境的bug"

📥 输入: 帮我看看这个生产环境的bug
✅ 匹配到技能: systematic-debugging
   置信度: medium (0.65)
   方法: TF-IDF + 关键词匹配
```

### After (AI-Powered)

```bash
$ vibe route "帮我看看这个生产环境的bug"

📥 输入: 帮我看看这个生产环境的bug
✅ 匹配到技能: gstack/investigate
   置信度: high (0.92)
   方法: AI语义分析 (Haiku)
   意图: 调试 + 紧急 + 生产环境
   推理: 生产环境紧急问题适合系统性调试
   缓存: 未命中 (首次请求)
   延迟: 187ms
```

---

**Decision Summary**: Implement AI-powered semantic triage layer using Haiku for skill routing, with multi-level caching and comprehensive fallback mechanisms. Expected accuracy improvement from 70% to 95% with minimal cost impact ($0.11/month).
