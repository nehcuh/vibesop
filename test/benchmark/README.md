# AI Routing Performance Benchmark

## Overview

This benchmark measures the actual performance of AI-powered skill routing compared to algorithm-based routing.

## Tests

### 1. Accuracy Comparison
Compares routing accuracy between:
- **AI Routing** (Layer 0: AI Semantic Triage)
- **Algorithm Routing** (Layer 3: Semantic Matching)

**Target**: 95% accuracy for AI routing
**Baseline**: 70% accuracy for algorithm routing

### 2. Latency Distribution
Measures response time distribution:
- **P50**: Median latency
- **P95**: 95th percentile latency
- **P99**: 99th percentile latency

**Target**: P95 < 150ms

### 3. Cache Effectiveness
Measures cache hit rate across multiple requests.

**Target**: >70% cache hit rate

### 4. Cost Estimation
Estimates monthly operational cost based on:
- Cache hit rate
- API calls made
- Token usage

**Target**: <$0.11/month (10K requests)

## Usage

### Run Full Benchmark

```bash
# From project root
cd test/benchmark
ruby ai_routing_benchmark.rb
```

### Run with Environment Variables

```bash
# Set API key for AI routing
export ANTHROPIC_API_KEY=sk-ant-xxxxx

# Run benchmark
ruby test/benchmark/ai_routing_benchmark.rb
```

### Custom Iterations

```ruby
# Edit the benchmark file
benchmark = AIRoutingBenchmark.new
benchmark.test_accuracy
benchmark.test_latency(iterations: 1000)  # More iterations
benchmark.test_cost(monthly_requests: 50_000)  # Higher volume
benchmark.print_summary
```

## Output

### Console Output

```
AI Routing Performance Benchmark
============================================================

=== Test 1: Accuracy Comparison ===

AI Routing:    18/20 (90.00%)
Algorithm:     13/20 (65.00%)
Improvement:  +25.00%

=== Test 2: Latency Distribution ===
Running 100 iterations...

Latency Distribution:
  Average:  87.45ms
  P50:      82.00ms
  P75:      95.00ms
  P95:      124.00ms
  P99:      156.00ms

Cache Hit Rate: 72/100 (72.00%)

=== Test 3: Cost Estimation ===
Assumptions:
  Monthly requests: 10000
  Daily requests:   333

Cache Hit Rate:    72.00%
Actual API Calls:  2800

Cost Analysis:
  Avg tokens/request: 1000
  Cost per request:   $0.000125
  Monthly cost:       $0.35

=== Performance Summary ===

Accuracy:
  AI Routing:    90.00%
  Algorithm:     65.00%
  Improvement:   +25.00%

Latency:
  P95:          124.00ms (target: <150ms) ✓
  Cache Hit:    72.00% (target: >70%) ✓

Cost:
  Monthly:      $0.35 (target: <$0.11) ✗

Overall: ✗ FAIL
```

### JSON Output

Results are saved to `ai_routing_benchmark_results.json`:

```json
{
  "timestamp": "2026-03-30T12:34:56Z",
  "results": {
    "accuracy": {
      "ai": { "correct": 18, "total": 20, "accuracy": 90.0 },
      "algorithm": { "correct": 13, "total": 20, "accuracy": 65.0 },
      "improvement": 25.0
    },
    "latency": {
      "avg": 87.45,
      "p50": 82.0,
      "p95": 124.0,
      "p99": 156.0,
      "cache_hit_rate": 0.72
    },
    "cost": {
      "monthly_requests": 10000,
      "cache_hit_rate": 0.72,
      "actual_calls": 2800,
      "monthly_cost": 0.35
    }
  },
  "environment": {
    "ruby_version": "2.6.10",
    "os": "darwin"
  }
}
```

## Interpretation

### PASS Criteria

All of the following must be true:
- ✅ P95 latency < 150ms
- ✅ Cache hit rate > 70%
- ✅ Monthly cost < $0.11

### FAIL Scenarios

| Metric | Below Target | Impact | Fix |
|--------|-------------|--------|-----|
| Latency | P95 > 150ms | Slow UX | Improve caching, use faster model |
| Cache | Hit rate < 70% | High cost | Increase TTL, warm cache |
| Cost | Monthly > $0.11 | Too expensive | Improve cache hit rate |

## Troubleshooting

### "No API key found"

Set the required environment variable:
```bash
export ANTHROPIC_API_KEY=sk-ant-xxxxx
```

### "Cache always misses"

Check cache configuration:
```bash
# Verify cache directory exists
ls -la ~/.vibe/cache/

# Clear cache and retry
rm -rf ~/.vibe/cache/
```

### "Latency too high"

Possible causes:
1. Cold cache (first run)
2. Slow network
3. API rate limiting

Solutions:
1. Run benchmark twice (warm cache)
2. Check network connectivity
3. Add delay between requests

## Continuous Monitoring

### Integrate with CI/CD

```yaml
# .github/workflows/benchmark.yml
name: AI Routing Benchmark

on:
  push:
    branches: [main]
  schedule:
    - cron: '0 0 * * 0'  # Weekly

jobs:
  benchmark:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Set up Ruby
        uses: ruby/setup-ruby@v1
        with:
          ruby-version: 2.6
      - name: Run benchmark
        env:
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
        run: ruby test/benchmark/ai_routing_benchmark.rb
      - name: Upload results
        uses: actions/upload-artifact@v3
        with:
          name: benchmark-results
          path: ai_routing_benchmark_results.json
```

### Track Performance Over Time

```bash
# Run monthly and save results
DATE=$(date +%Y-%m-%d)
ruby test/benchmark/ai_routing_benchmark.rb
mv ai_routing_benchmark_results.json "results-${DATE}.json"

# Compare trends
ruby scripts/compare_benchmarks.rb results-2026-03-*.json
```

## Contributing

To add new test cases:

1. Edit `TEST_CASES` hash in `ai_routing_benchmark.rb`
2. Follow format: `'input' => 'expected_skill_id'`
3. Use `nil` for "no match" expected
4. Run benchmark to verify

## Related Documentation

- [AI Routing Architecture](../../docs/architecture/ai-powered-skill-routing.md)
- [Multi-Provider Support](../../docs/architecture/multi-provider-architecture.md)
- [Performance Optimization](../../docs/architecture/performance-optimization.md)
