# Portfolio Analysis Workflow

> On-demand loading. When analyzing assets/positions/portfolio, Claude must read this first.

---

## Analysis Framework

### Information Collection (Collect first, judge later)

1. Update positions (run fetch script or API call)
2. Check all platform positions (automated fetch may miss some)
3. Check settlement/resolution criteria
4. Search latest news
5. Check smart money signals from monitoring channels
6. Cross-reference with address/watchlist databases

### Comprehensive Judgment

7. Identify user positions (cost basis, P&L)
8. Estimate probabilities (must have evidence)
9. Evaluate edge (my estimate vs market price)
10. Consider smart money signals

### Position Management Check

11. Calculate total exposure: current + planned = total
12. Compare against limits: single market <=10% of total position
13. Averaging down warning: proactively warn about "cost averaging" trap
14. Independent evaluation: decide based on "current probability edge"

### Give Recommendation

15. Use Kelly Criterion (default half-Kelly)
16. Output specific action (buy/sell/hold + amount + price)
17. One-shot recommendation, don't waver

**Banned**: Skip settlement criteria / Ignore smart money / Waver on judgment / Average down without warning

---

*Customize data sources, position limits, and risk parameters for your specific domain.*
