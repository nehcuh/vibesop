# Autonomous Experiment Skill Design

Date: 2026-03-29
Status: Draft
Inspired by: [Karpathy autoresearch](https://github.com/karpathy/autoresearch), [Bilevel Autoresearch](https://github.com/EdwardOptimization/Bilevel-Autoresearch), [Reflective Autoresearch](https://github.com/Hzz-Git/reflective-autoresearch), [tcell](https://github.com/VictorVVedtion/tcell)

Vision anchor: PRINCIPLES.md v2.0 — "个人用它积累知识、加速开发，团队用它统一规范、沉淀经验"

Integration Filter: PR5 项检验确保此功能值得整合，而非噪音。

---

## 1. Problem Statement

VibeSOP 的所有 skill 都是单次执行模式（human triggers -> one execution）。Autoresearch 引入了一种经过验证的模式：propose -> execute -> evaluate -> keep/discard, repeat indefinitely.

社区 extensions（Bilevel optimization, Reflective predict-attribute）增加了领域无关的评估和多维度 rubric，超越了单一数值指标。
我们设计 `autonomous-experiment` skill 来有机地吸收这些进展。

### 1.1 Core Pain
- **Skill optimization**: How to make a SKILL.md produce better outcomes? `rake test` verifies code quality but doesn't measure skill effectiveness.
- **Workflow tuning**: Which prompt patterns lead to faster root-cause identification? No automated way to test.
- **Code optimization**: Performance, refactoring, complexity reduction — `rake test` passes, but doesn't measure if the code actually improved.
- **Debugging**: Hypothesis -> fix -> test -> pass/fail loop works but lacks structured belief tracking of what was tried and why.

### 1.2 Design Goals
1. **Domain-agnostic experiment loop**: Support any optimization target with a measurable objective, not just ML training.
2. **Intelligent evaluation**: Multi-dimensional rubrics, AI judges, not just command-line metrics.
3. **Reflective iteration**: Predict-attribute cycle with persistent beliefs, not blind trial-and-error.
4. **Safe isolation**: Git worktree ensures main branch is never affected.
5. **Minimal human intervention**: Human defines domain once, then sleeps while Agent works.
6. **Self-improving pipeline**: Outer loop can optimize the experiment strategy itself (Bilevel pattern).
7. **Knowledge accumulation**: Successful beliefs become reusable instincts via `/evolve`. Individuals learn from experiments. Teams share beliefs via experience export/import.
8. **Team alignment**: experiment.yaml + results.tsv 可版本控制，团队共享"我们试过什么、什么有效"。

### 1.3 Key Design Decisions
| Decision | Choice | Rationale |
|----------|-------|------------|
| Single metric vs rubric | Rubric (multi-dimensional) | Skill optimization needs to measure clarity, effectiveness, simplicity separately. A single test-pass metric can't distinguish "clearer instructions" from "more concise instructions". |
| Fixed strategy vs adaptive | Adaptive (with beliefs.md) | Reflective Autoresearch showed forced prediction improves convergence 2x. Blind search wastes iterations on repeated failed approaches. |
| Immediate evaluation vs delayed | Immediate (per iteration) | Each iteration should be self-contained so Agent can attribute immediately. |
| Prompt-only vs code-gen meta-loop | Both supported | Level 1 (prompt config) ships first; Level 2 (code generation) is aspirational. |

## 2. Architecture
### 2.1 Three-Layer Stack
```
Layer 0: Domain Definition (human-writes)
  .vibe/experiment.yaml
  ├── objective: what to optimize, with rubric
  ├── scope: which files Agent can/cannot modify
  ├── evaluator: how to measure progress
  └── constraints: iteration limits, time budget

Layer 1: Experiment Loop (agent-executes)
  skills/autonomous-experiment/SKILL.md
  ├── Reads experiment.yaml + beliefs.md
  ├── Each iteration:
  │   ├── Propose hypothesis (with prediction)
  │   ├── Modify modifiable scope
  │   ├── git commit
  │   ├── Run evaluator
  │   ├── Compare prediction vs actual
  │   ├── Update beliefs.md
  │   └── Record to results.tsv
  └── Loop until max_iterations or stuck

Layer 2: Meta-Optimizer (optional, agent-self-optimizes)
  ├── Analyzes results.tsv + beliefs.md trace
  ├── Identifies search bottlenecks
  ├── Modifies experiment.yaml strategy parameters
  └── Can suggest new evaluator dimensions
```

### 2.2 Three Evaluator Types
| Type | Trigger | Output | Use Case |
|------|---------|--------|---------|
| `command` | Shell command | Numeric from stdout | Benchmark scores, test counts |
| `agent_judge` | Independent Agent call | Multi-dimensional scores (0-10 rubric) | Skill optimization, documentation quality |
| `behavioral` | Run skill on fixture | Step count + success rate | Workflow tuning, debugging strategy |

### 2.3 Evaluator Configuration
```yaml
evaluator:
  type: agent_judge
  prompt_template: |
    Evaluate the current state of {{scope.modifiable}} against the objective.

    Rubric:
      - id: effectiveness
        weight: 0.4
        description: "How well does the modification achieve the stated objective?"
        scale: "1-10"
      - id: clarity
        weight: 0.3
        description: "How clear and unambiguous are the instructions?"
        scale: "1-10"
      - id: simplicity
        weight: 0.3
        description: "Is it simpler than before? Less lines, fewer concepts?"
        scale: "1-10"
  isolation: true  # Fresh context, same model
  max_tokens: 2000
```
For `command` type:
```yaml
evaluator:
  type: command
  command: "bundle exec rspec"
  extract_pattern: "(\\d+) examples?, (\\d+) failures"
  higher_is_better: false  # lower failures = better
```
For `behavioral` type:
```yaml
evaluator:
  type: behavioral
  skill: skills/systematic-debugging/SKILL.md
  fixture: test/fixtures/debug-scenario-*.yaml
  metric: steps_to_root_cause  # lower is better
```

### 2.4 Beliefs System (from Reflective Autoresearch)
The `.experiment/beliefs.md`:
```markdown
## Current Beliefs (max 20)
1. [belief with reasoning]
2. [belief with reasoning]
...

## Experiment History
### Experiment #1
- Prediction: [what Agent predicted]
- Actual: [what happened]
- Attribution: [which belief was wrong/right]
- Action: [how beliefs updated]
...
```
Rules:
- Max 20 beliefs. When full, rewrite (not append) to keep recent and discard stale.
- Each experiment adds prediction + actual + attribution.
- Beliefs drive hypothesis generation, not random search.

### 2.5 Results Format (from autoresearch)
`.experiment/results.tsv`:
```tsv
commit	<score1>	<score2>	<score3>	<compound>	<status>	<description>
a1b2c3d	6	7	5	6.1	keep	baseline
b2c3d4e	7	8	6	7.3	keep	added phase decomposition
c3d4e5f	5	6	7	5.7	discard	removed critical step
```
- compound = weighted sum of rubric scores (from experiment.yaml weights)
- status: keep | discard | crash
- Untracked by git (like autoresearch)

### 2.6 Safety: Worktree Isolation
```ruby
module ExperimentManager
  def start(config)
    worktree = create_worktree("experiment/#{tag}")
    copy config into worktree
    create beliefs.md with initial hypotheses
    create empty results.tsv with headers
  end

  def commit_and_evaluate(worktree_path, evaluator_config)
    sha = git_commit(worktree_path, message)
    scores = run_evaluator(evaluator_config, worktree_path)
    record_results(results_path, sha, scores)
    scores
  end

  def keep_or_discard(results_path, worktree_path, current_sha)
    if improved?(results_path)
      # keep commit
    else
      # git reset -- discard commit
    end
  end

  def finish(results_path)
    generate_summary(results_path)
    output_merge_instructions(results_path)
  end
end
```

### 2.7 SKILL.md Core Loop

1. Read experiment.yaml for domain definition.
2. Read beliefs.md for current assumptions.
3. Create git worktree in `.experiment/worktree/`.
4. Establish baseline: run evaluator on unmodified code, record baseline score.
5. LOOP until max_iterations or stale_threshold reached.

### 2.8 CLI Commands
```bash
vibe experiment start [--config .vibe/experiment.yaml]
vibe experiment results
vibe experiment apply
vibe experiment clean
```

### 2.9 Registry Entry
```yaml
- id: autonomous-experiment
  namespace: builtin
  entrypoint: skills/autonomous-experiment/SKILL.md
  intent: Autonomous experiment loop with predict-attribute cycle and multi-dimensional evaluation.
  trigger_mode: manual
  priority: P1
  supported_targets:
    claude-code: native-skill
    opencode: native-skill
  requires_tools:
    - Read
    - Write
    - Edit
    - Bash
  safety_level: trusted_builtin
```

## 3. Integration with VibeSOP
### 3.1 Skill Routing
`autonomous-experiment` is registered as a manual-trigger P1 skill.

Routing hints:
```yaml
- keywords: ["实验", "优化", "迭代", "autonomous", "experiment", "循环优化"]
  suggest: builtin/autonomous-experiment
  message: "建议使用自主实验循环进行优化"
```

### 3.2 Overlay Support
```yaml
# .vibe/overlay.yaml
experiment:
  defaults:
    max_iterations: 15
    time_budget_per_iteration: 120
  evaluator_overrides:
    type: agent_judge
    rubric_append:
      - id: project_specific_dimension
        weight: 0.2
        description: "Does it follow project conventions?"
```

### 3.3 Memory Integration
```markdown
## Experiment Results (from session.md)
- Completed autonomous experiment: skill optimization
- 15 iterations, best compound score: 8.2/10
- Key insight: "Decomposing SKILL.md into phases improved clarity but reduced effectiveness"
- Applied: merged to main branch
```

### 3.4 Conflict with Existing Skills
| Overlap | Resolution |
|---------|-----------|
| `verification-before-completion` (P0 mandatory) | Takes precedence. `autonomous-experiment` uses it for individual iterations, but cannot override the mandatory verification requirement. |
| `systematic-debugging` (P0 mandatory) | If experiment crashes, Agent uses systematic-debugging to diagnose before discarding. |
| `experience-evolution` | After experiment ends, high-quality beliefs can be promoted to instincts via `/evolve`. |
| `skill-craft` | Successful experiment strategies can be extracted as new skills. |

## 4. Phased Implementation
### Phase 1: Core Loop (2-3 weeks)
- Create `skills/autonomous-experiment/SKILL.md`
- Create `lib/vibe/experiment_manager.rb` (worktree, results, beliefs management)
- Add `vibe experiment start/results/apply/clean` CLI commands
- Register in `core/skills/registry.yaml`
- Add routing hints
- Tests for experiment_manager.rb

**Deliverable**: can run a full experiment loop on a simple domain (e.g., optimize a test fixture).

### Phase 2: Evaluator Types (1-2 weeks)
- Implement `command` evaluator (shell command, score extraction)
- Implement `agent_judge` evaluator (independent agent with rubric)
- Implement `behavioral` evaluator (run skill on fixture)
- Tests for each evaluator type

**Deliverable**: All three evaluator types working with real skills.

### Phase 3: Meta-optimizer (1-2 weeks, aspirational)
- Analyze experiment trace to detect search bottlenecks
- Automatically adjust strategy (freeze/unfreeze dimensions, shift focus)
- Optional: generate new evaluation dimensions

**Deliverable**: outer loop that demonstrably improves inner loop convergence.

### Phase 4: Dogfooding (ongoing)
- Use `autonomous-experiment` to optimize VibeSOP's own skills
- Use it to optimize CLI performance
- Use it to optimize documentation clarity
- Record results in `memory/project-knowledge.md`

## 5. Inspired By
- [Karpathy autoresearch](https://github.com/karpathy/autoresearch) — Core propose-execute-evaluate loop
- [Bilevel Autoresearch](https://github.com/EdwardOptimization/Bilevel-Autoresearch) — Meta-optimization + code-generated mechanisms
- [Reflective Autoresearch](https://github.com/Hzz-Git/reflective-autoresearch) — Predict-attribute cycle with persistent beliefs
- [tcell](https://github.com/VictorVVedtion/tcell) — Domain-agnostic application + context isolation for evaluation
