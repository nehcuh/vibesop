# Skill Routing API Reference

**Version**: 1.0.0  
**Last Updated**: 2026-03-30

---

## Overview

The Skill Routing system provides intelligent, multi-layered skill matching with preference learning and parallel execution capabilities.

```
Layer 0: AI Semantic Triage (Fast Model)
    ↓
Layer 1: Explicit Override (User-specified)
    ↓
Layer 2: Scenario Patterns (Predefined rules)
    ↓
Layer 3: Semantic Matching (TF-IDF + Cosine)
    ↓
Layer 4: Fuzzy Fallback (Levenshtein)
    ↓
Candidate Selection (Multi-candidate decision)
    ↓
Execution (Single or Parallel)
```

---

## Core Classes

### `Vibe::SkillRouter`

Main router class that orchestrates all routing layers.

#### Constructor

```ruby
router = Vibe::SkillRouter.new(project_root = Dir.pwd)
```

**Parameters**:
- `project_root` (String) - Path to project directory (default: current directory)

#### Methods

##### `route(user_input, context = {})`

Routes user input to the most appropriate skill.

**Parameters**:
- `user_input` (String) - User's request
- `context` (Hash) - Additional context:
  - `:current_task` - Current active task
  - `:file_type` - Type of files being worked on
  - `:recent_files` - Recently modified files
  - `:error_count` - Number of recent errors

**Returns** (Hash):
- `:matched` (Boolean) - Whether a match was found
- `:skill` (String) - Matched skill ID
- `:source` (String) - Skill source (builtin/superpowers/gstack)
- `:confidence` (Symbol) - Confidence level (:very_high, :high, :medium, :low, :very_low)
- `:reason` (String) - Explanation of the match
- `:requires_user_choice` (Boolean) - Multiple candidates available
- `:candidates` (Array<Hash>) - Alternative candidates

**Example**:
```ruby
result = router.route("帮我调试这个bug")

if result[:matched]
  puts "Matched: #{result[:skill]}"
  puts "Confidence: #{result[:confidence]}"
else
  puts "No match found"
end
```

##### `stats`

Returns routing statistics.

**Returns** (Hash):
- `:ai_triage` - AI triage layer statistics
- `:cache` - Cache statistics
- `:llm_client` - LLM client statistics
- `:routing` - Overall routing statistics

---

### `Vibe::SkillRouter::CandidateSelector`

Decides which skill to use from multiple candidates.

#### Constructor

```ruby
selector = Vibe::SkillRouter::CandidateSelector.new(
  config: selection_policy,
  preference_analyzer: analyzer
)
```

#### Methods

##### `select(candidates, context = {})`

Selects the best action from multiple candidates.

**Parameters**:
- `candidates` (Array<Hash>) - Candidate skills with confidence scores
- `context` (Hash) - Additional context

**Returns** (Hash):
- `:action` (Symbol) - Decision type:
  - `:auto_select` - Auto-selected top candidate
  - `:user_choice` - User needs to choose
  - `:parallel_execute` - Execute multiple in parallel
  - `:no_candidates` - No valid candidates
- `:selected` (Hash) - Selected candidate (for auto_select)
- `:candidates` (Array<Hash>) - Available candidates (for user_choice)
- `:prompt` (String) - User prompt (for user_choice)

---

### `Vibe::PreferenceDimensionAnalyzer`

Analyzes user preferences across multiple dimensions.

#### Constructor

```ruby
analyzer = Vibe::PreferenceDimensionAnalyzer.new(
  config: preference_config,
  preference_file: path_to_yaml
)
```

#### Methods

##### `analyze(candidates, context = {})`

Analyzes candidates and returns preference boost scores.

**Parameters**:
- `candidates` (Array<Hash>) - Candidate skills
- `context` (Hash) - Current context

**Returns** (Hash):
- Key: Skill ID (String)
- Value: Preference score (Float, 0.0-1.0)

##### `detailed_analysis(skill_id)`

Returns detailed analysis for a specific skill.

**Parameters**:
- `skill_id` (String) - Skill identifier

**Returns** (Hash):
- `:consistency` (Float) - Consistency score (0.0-1.0)
- `:satisfaction` (Float) - Satisfaction score (0.0-1.0)
- `:context` (Float) - Context match score (0.0-1.0)
- `:recency` (Float) - Recency score (0.0-1.0)
- `:overall` (Float) - Combined score (0.0-1.0)

---

### `Vibe::SkillRouter::ParallelExecutor`

Executes multiple skills in parallel and aggregates results.

#### Constructor

```ruby
executor = Vibe::SkillRouter::ParallelExecutor.new(
  config: parallel_execution_config
)
```

#### Methods

##### `execute(candidates, executor:, context: {})`

Executes skills in parallel.

**Parameters**:
- `candidates` (Array<Hash>) - Skills to execute
- `executor` (Proc) - Callable that executes a single skill
- `context` (Hash) - Execution context

**Returns** (Hash):
- `:status` (Symbol) - Aggregation status:
  - `:consensus` - All agreed
  - `:majority` - Most agreed
  - `:first_success` - First successful result
  - `:all` - All results returned
  - `:merged` - Insights merged
- `:participants` (Integer) - Number of participants
- `:failed` (Integer) - Number of failures
- `:consensus_rate` (Float) - Agreement level (0.0-1.0)
- `:insights` (Array) - Combined insights
- `:recommendations` (Array) - All recommendations
- `:best_match` (Hash) - Best scoring result

---

## Configuration

### `core/policies/skill-selection.yaml`

Cross-platform configuration for skill selection.

```yaml
candidate_selection:
  max_candidates: 3
  auto_select_threshold: 0.15
  min_confidence: 0.6
  sort_by: balanced

preference_learning:
  enabled: true
  dimensions:
    consistency:
      weight: 0.4
      threshold: 0.7
      min_samples: 5
    satisfaction:
      weight: 0.3
      min_samples: 3
    context:
      weight: 0.2
    recency:
      weight: 0.1
      decay_days: 30

parallel_execution:
  enabled: true
  max_parallel: 2
  mode: auto
  conditions:
    max_confidence_diff: 0.10
    min_candidates: 2
    max_candidates: 3
  aggregation:
    method: merged
    timeout: 300
```

---

## CLI Commands

### `vibe route "<request>"`

Routes a request to the best skill.

```bash
vibe route "帮我评审代码"
vibe route "这个 bug 很奇怪"
vibe route "准备发布新版本"
```

### `vibe route-validate`

Validates the skill routing configuration.

```bash
vibe route-validate
```

### `vibe route-select <skill>`

Manually selects a skill.

```bash
vibe route-select systematic-debugging
```

---

## Error Handling

All routing methods handle errors gracefully:

```ruby
result = router.route(user_input)

case result[:status]
when :error
  # Handle routing error
  puts "Error: #{result[:message]}"
when :no_match
  # Handle no match
  puts "No match found"
when :matched
  # Process match
  process_skill(result[:skill])
end
```

---

## Performance

- **Routing latency**: ~50-200ms (with cache)
- **Cache hit rate**: 70%+
- **Accuracy**: 95% (vs 70% keyword-only)
- **Cost**: ~$0.11/month (per user)

---

## See Also

- [AI Routing Architecture](architecture/ai-powered-skill-routing.md)
- [Multi-Provider Architecture](architecture/multi-provider-architecture.md)
- [Skills Guide](skills-guide.md)
