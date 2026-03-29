# Autonomous Experiment Skill Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

 **Goal:** Add a `autonomous-experiment` skill — a predict-attribute experiment loop with multi-dimensional evaluation and worktree isolation, enabling VibeSOP agents to autonomously optimize skills, docs, workflows quality, and debugging strategies without minimal human intervention. **Architecture:** New builtin skill `skills/autonomous-experiment/SKILL.md` + Ruby CLI infrastructure (`experiment_manager.rb`) for worktree/results/beliefs management. Evaluator config in `.vibe/experiment.yaml`. All integrated with existing skill routing, registry, memory, and overlay systems. **Tech Stack:** Ruby (stdlib only), YAML config-driven design, VibeSOP CLI ( bin/vibe), Git worktrees

 ---

## References
 - Design spec: `docs/superpowers/specs/2026-03-29-autonomous-experiment-design.md`

---

## Task 1: Create experiment_manager.rb — core infrastructure

 **Files:**
- Create: `lib/vibe/experiment_manager.rb`

 **Steps:**

- [ ] **Step 1: Write ExperimentManager class skeleton with config loading**
  ```ruby
  # frozen_string_literal: true
  require 'yaml'
  require 'fileutils'
  require 'securerandom'
  require 'time'
  require 'shellwords'

  module Vibe
    class ExperimentManager
      class ExperimentError < StandardError; end
    class ExperimentNotFoundError < ExperimentError; end

    attr_reader :config_path, :results_path, :beliefs_path, :worktree_path

 :tag
  
    def initialize(config_path)
 @config_path = config_path
      @config = load_config
      @results_path = File.join(File.dirname(config_path), '.experiment', 'results.tsv')
      @beliefs_path = file.join(File.dirname(config_path), '.experiment', 'beliefs.md')
      @worktree_path = file.join(File.dirname(config_path), '.experiment', 'worktree')
      @tag = derive_tag
    end
  
    def load_config
      config = YAML.safe_load_file(@config_path)
      unless config['domain']
        raise ExperimentError, "experiment.yaml must a 'domain' key 'objective' + 'scope' + 'evaluator' + 'constraints' fields"
      end
      config
    end
  
    def derive_tag
      @tag ||= config['domain'].gsub(/[^a-z0-9]/, '-').gsub(/\s+/, '-')
      @tag = "#{@tag}-#{Time.now.strftime('%Y%m%d%HH%M%S')}"
      @tag
    end
  
    def start
      unless File.exist?(@config_path)
        raise ExperimentError, "Config not found: #{@config_path}"
      end
      FileUtils.mkdir_p(File.dirname(@results_path))
      FileUtils.mkdir_p(File.dirname(@beliefs_path))
  
      headers = ['commit'] + rubric_ids_from_config
      File.write(@results_path, headers.join("\t") + "\n")
  
      initial_beliefs = generate_initial_beliefs(@config)
      File.write(@beliefs_path, initial_beliefs)
  
      FileUtils.mkdir_p(@worktree_path)
  
      worktree_branch = "experiment/#{@tag}"
      system("git worktree add #{worktree_path} -b #{worktree_branch} 2>&1")
  
      { tag: @tag, config: @config, branch: worktree_branch }
    end
  
    def record_iteration(sha, scores, status, description)
      compound = calculate_compound(scores, @config)
      row = [sha] + scores.values.map { |s| format('%.1f', s) } + [format('%.1f', compound), status, description]
      File.open(@results_path, 'a') { |f| f.puts(row.join("\t") + "\n") }
    end
  
    def update_beliefs(content)
      File.write(@beliefs_path, content)
    end
  
    def read_beliefs
      File.read(@beliefs_path) if File.exist?(@beliefs_path)
    end
  
    def current_best
      return nil unless File.exist?(@results_path)
      lines = File.readlines(@results_path).drop(1)
      best = lines.max_by { |l| l.split("\t")[-2].to_f }
      { commit: l.split("\t")[0], score: l.split("\t")[-2].to_f }
    end
  
    def finish
      best = current_best
      {
        tag: @tag,
        branch: @worktree_path,
        best: best,
        total_iterations: count_iterations,
        summary: generate_summary
      }
    end
  
    def count_iterations
      return 0 unless File.exist?(@results_path)
      File.readlines(@results_path).drop(1).size
    end
  
    def generate_summary
      best = current_best
      total = count_iterations
      keeps = count_keep_iterations
      discards = total - keeps
      "Experiment Summary for #{@tag}\n  Total: #{total} iterations\n  Ke best compound: #{best[:score]}\n  Keeps: #{keeps}, Discards: #{discards}\n  Branch: experiment/#{@tag}"
    end
  
    def count_keep_iterations
      return 0 unless File.exist?(@results_path)
      File.readlines(@results_path).drop(1).count { |l| l.split("\t")[-2] == 'keep' }
    end
  
    def rubric_ids_from_config
      @config.dig('objective', 'evaluator', 'rubric')&.map { |r| r['id'] } || ['score']
    end
  
    def calculate_compound(scores, config)
      rubric = config.dig('objective', 'evaluator', 'rubric') || []
      return 0 if rubric.empty?
      scores.values.zip(rubric).map do |score, r|
        weight = r['weight'] || 0.33
        score.to_f * weight
      end.sum
    end
  
    def generate_initial_beliefs(config)
      <<~BELIEFS
  ## Current Beliefs (max 20)
  (to be populated by Agent during experiment)
  
  ## Experiment History
  (to be populated by Agent during experiment)
  BELIEFS
    end
  end
  ```

- [ ] **Step 2: Write tests for ExperimentManager**
  ```ruby
  # test/unit/test_experiment_manager.rb
  require_relative '../test_helper'
  require 'vibe/experiment_manager'
  
  class TestExperimentManager < Minitest::Test
    def setup
      @tmpdir = Dir.mktmpdir
      @config_path = File.join(@tmpdir, 'experiment.yaml')
      @config = {
        'domain' => 'test-optimization',
        'objective' => { 'description' => 'test' },
        'scope' => { 'modifiable' => ['test.txt'], 'readonly' => [] },
        'evaluator' => {
          'type' => 'command',
          'command' => 'echo "score: 7.5"',
          'extract_pattern' => 'score: (\\d+\\.\\d+)',
          'rubric' => [{ 'id' => 'score', 'weight' => 1.0 }]
        },
        'constraints' => { 'max_iterations' => 5, 'stale_threshold' => 3 }
      }
      File.write(@config_path, YAML.dump(@config))
      @manager = Vibe::ExperimentManager.new(@config_path)
    end
  
    def teardown
      FileUtils.rm_rf(@tmpdir)
    end
  
    def test_load_config
      assert_equal 'test-optimization', @manager.config['domain']
    end
  
    def test_derive_tag
      tag = @manager.tag
      assert_match(/\Atest-optimization-\d{4}-\d{2}-\d{2}/, tag)
    end
  
    def test_start_creates_results_and_beliefs
      @manager.start
      assert File.exist?(@manager.results_path)
      assert File.exist?(@manager.beliefs_path)
    end
  
    def test_record_iteration
      @manager.start
      @manager.record_iteration('abc123', { 'score' => 7.5 }, 'keep', 'test change')
      lines = File.readlines(@manager.results_path)
      assert_equal 2, lines.size
      assert_match(/abc123/, lines.last)
      assert_match(/7\.5/, lines.last)
    end
  
    def test_compound_score_calculation
      scores = { 'effectiveness' => 8.0, 'clarity' => 7.0, 'simplicity' => 6.0 }
      rubric = [
        { 'id' => 'effectiveness', 'weight' => 0.4 },
        { 'id' => 'clarity', 'weight' => 0.3 },
        { 'id' => 'simplicity', 'weight' => 0.3 }
      ]
      config = { 'objective' => { 'evaluator' => { 'rubric' => rubric } } }
      result = @manager.calculate_compound(scores, config)
      expected = 8.0 * 0.4 + 7.0 * 0.3 + 6.0 * 0.3
      assert_in_delta expected, result, 0.01
    end
  
    def test_current_best_returns_nil_when_no_results
      assert_nil @manager.current_best
    end
  
    def test_current_best_returns_best_after_record
      @manager.start
      @manager.record_iteration('a1', { 'score' => 5.0 }, 'keep', 'baseline')
      @manager.record_iteration('b2', { 'score' => 8.0 }, 'keep', 'improved')
      best = @manager.current_best
      assert_equal '8.0', best[:score]
    end
  end
  ```

- [ ] **Step 3: Run tests to verify they fail**
  Run: `ruby -Ilib test/unit test/unit/test_experiment_manager.rb`
  Expected: FAIL (ExperimentManager methods not yet implemented — specific methods fail)

  NOTE: Only test the methods that are NOT yet fully implemented.

- [ ] **Step 4: Commit**

  ```bash
  git add lib/vibe/experiment_manager.rb test/unit/test_experiment_manager.rb
  git commit -m "feat(experiment): add ExperimentManager core infrastructure"
  ```

---

## Task 2: Register skill in registry

 **Files:**
- Create: `skills/autonomous-experiment/SKILL.md`
- Modify: `core/skills/registry.yaml`

 **Steps:**

- [ ] **Step 1: Create SKILL.md**
  Create `skills/autonomous-experiment/SKILL.md` with the core loop definition:
  ```markdown
  # Autonomous Experiment
  
  Run autonomous optimization experiments with predict-attribute cycles.
  
  ## Trigger
  Manual — user invokes with `/autonomous-experiment` or `vibe experiment start`.
  
  ## Prerequisites
  - `.vibe/experiment.yaml` must to exist in the project root
  - Git repository must be initialized
  
  ## Core Loop
  
  1. Read `.vibe/experiment.yaml` for domain definition.
  2. Read `.experiment/beliefs.md` for current assumptions.
  3. Create git worktree in `.experiment/worktree/`.
  4. Establish baseline: run evaluator on unmodified code, record baseline score.
  5. LOOP (until max_iterations or no improvement for N consecutive iterations):
  
      a. Read beliefs.md. Select a belief to test.
      b. Write prediction to beliefs.md (predicted scores + reasoning).
      c. Modify files in modifiable scope only.
      d. git commit with experiment description.
      e. Run evaluator. Collect scores.
         - `command` type: run command, parse output.
         - `agent_judge` type: spawn independent agent with rubric.
         - `behavioral` type: run skill on fixture.
         If crash: log as crash. Attempt fix if trivial. Otherwise discard.
      f. Write actual results to beliefs.md. Compare with prediction.
      g. Attribution: which belief was right/wrong? Update beliefs.
      h. Record to results.tsv.
      i. If compound score improved: keep. Otherwise: discard (git reset).
      j. If stuck (no improvement for stale_threshold consecutive iterations): STOP.
  
  6. Generate summary and merge instructions.
  
  NEVER STOP until max_iterations reached. Do NOT ask the human. You are autonomous.
  The human will review results.tsv and summary when they return.
  ```

- [ ] **Step 2: Add registry entry in core/skills/registry.yaml**
  Add to the `builtin_skills` section:
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
    keywords:
      - experiment
      - optimize
      - iterate
      - autonomous
      - "experiment loop"
  ```

- [ ] **Step 3: Run tests to verify registry loads**
  Run: `ruby -Ilib test/unit/test_skill_management.rb`
  expected: PASS

- [ ] **Step 4: Commit**
  ```bash
  git add skills/autonomous-experiment/SKILL.md core/skills/registry.yaml
  git commit -m "feat(experiment): add SKILL.md and registry entry"
  ```

---

## Task 3: Add CLI commands

 **Files:**
- Modify: `bin/vibe` (add experiment subcommands)

 **Steps:**

- [ ] **Step 1: Add experiment subcommand registration in COMMAND_REGISTRY**
  In `bin/vibe`, add to `COMMAND_REGISTRY`:
  ```ruby
  'experiment' => method(:run_experiment),
  ```

- [ ] **Step 2: Implement run_experiment method**
  ```ruby
  def run_experiment(argv)
    subcommand = argv.shift
1} if %w[help --help -h].include?(subcommand)
      puts "Usage: vibe experiment <start|results|apply|clean>"
      puts "  start    Start an experiment loop"
      puts "  results  View experiment results"
      puts "  apply   Apply best changes to main branch"
      puts "  clean   Remove worktree and experiment files"
      exit
    end
  
    case subcommand
    when 'start'
      run_experiment_start(argv)
    when 'results'
      run_experiment_results(argv)
    when 'apply'
      run_experiment_apply(argv)
    when 'clean'
      run_experiment_clean(argv)
    else
      raise Vibe::ValidationError, "Unknown experiment subcommand: #{subcommand}"
    end
  end
  
  def run_experiment_start(argv)
    config_path = argv.shift(1) || '.vibe/experiment.yaml'
    manager = Vibe::ExperimentManager.new(config_path)
    info = manager.start
    puts "Experiment started: #{info[:tag]}"
    puts "Branch: #{info[:branch]}"
    puts "Worktree: #{info[:worktree_path]}"
    puts "Results: #{manager.results_path}"
    puts "Beliefs: #{manager.beliefs_path}"
    puts "\nAgent should now read experiment.yaml and begin the loop."
  end
  
  def run_experiment_results(argv)
    config_path = argv.shift(1) || '.vibe/experiment.yaml'
    manager = Vibe::ExperimentManager.new(config_path)
    best = manager.current_best
    total = manager.count_iterations
    if best
      puts "Best: commit=#{best[:commit]} score=#{best[:score]}"
      puts "Total iterations: #{total}"
    else
      puts "No iterations completed yet"
    end
  end
  
  def run_experiment_apply(argv)
    config_path = argv.shift(1) || '.vibe/experiment.yaml'
    manager = Vibe::ExperimentManager.new(config_path)
    best = manager.current_best
    unless best
      puts "No successful iteration found"
      return
    end
    puts "Applying commit #{best[:commit]} to main branch..."
    system("git merge #{best[:commit]} --no-edit 2>&1")
    puts "Applied successfully"
  end
  
  def run_experiment_clean(argv)
    config_path = argv.shift(1) || '.vibe/experiment.yaml'
    manager = Vibe::ExperimentManager.new(config_path)
    FileUtils.rm_rf(manager.worktree_path) if Dir.exist?(manager.worktree_path)
 0)
    FileUtils.rm_rf(manager.results_path)
    FileUtils.rm_rf(manager.beliefs_path)
    puts "Experiment files cleaned up"
  end
  ```

- [ ] **Step 3: Run tests to verify CLI commands**
  Run: `ruby -Ilib test/unit/test_skills_commands.rb -n /experiment/`
  expected: PASS

- [ ] **Step 4: Commit**
  ```bash
  git add bin/vibe
  git commit -m "feat(experiment): add vibe experiment CLI commands"
  ```

---

## Task 4: Add routing hints and example config

 **Files:**
- Modify: `.vibe/skill-routing.yaml` (if exists) or `core/skills/registry.yaml` routing section
- Create: `examples/experiment-overlay.yaml`

 **Steps:**

- [ ] **Step 1: Add routing hints**
  Add to routing configuration:
  ```yaml
  - keywords: ["experiment", "optimize", "iterate", "autonomous", "experiment loop", "循环 optimization"]
    suggest: builtin/autonomous-experiment
    message: "Use the autonomous experiment skill for run an optimization loop"
  ```

- [ ] **Step 2: Create example overlay**
  Create `examples/experiment-overlay.yaml` as a sample project-level configuration:
  ```yaml
  schema_version: 1
  name: experiment-example
  description: Example overlay for running autonomous experiments on project skills
  
  experiment:
    defaults:
      max_iterations: 10
      time_budget_per_iteration: 120
      stale_threshold: 5
  ```

- [ ] **Step 3: Commit**
  ```bash
  git add examples/experiment-overlay.yaml
  git commit -m "feat(experiment): add routing hints and example config"
  ```

---

## Task 5: Integration tests

 **Files:**
- Create: `test/integration/test_experiment_integration.rb`

 **Steps:**

- [ ] **Step 1: Write integration test**
  ```ruby
  require_relative '../test_helper'
  require 'vibe/experiment_manager'
  
  class TestExperimentIntegration < Minitest::Test
    def test_full_lifecycle
      Dir.mktmpdir do |d|
        config_path = File.join(dir.mktmpdir, 'experiment.yaml')
        config = {
          domain: 'integration-test',
          objective: { description: 'test optimization' },
          scope: { modifiable: ['test.txt'], 'readonly' => ['lock.rb'] },
          evaluator: {
            type: 'command',
            command: 'echo "score: 7.0"',
            extract_pattern: 'score: (\\d+\\.\\d+)',
            rubric: [{ id: 'score', weight: 1.0 }]
          },
          constraints: { max_iterations: 3, 'stale_threshold' => 2 }
        }
 start
  
        File.write(config_path, YAML.dump(config))
`)
        manager = Vibe::ExperimentManager.new(config_path)

  
        info = manager.start
        assert info[:tag]
        assert File.exist?(manager.results_path)
        assert File.exist?(manager.beliefs_path)
        assert File.exist?(manager.worktree_path)
  
        manager.record_iteration('abc1', { 'score' => 5.0 }, 'keep', 'baseline')
        manager.record_iteration('def2', { 'score' => 8.0 }, 'keep', 'improved')
        manager.record_iteration('c3d', { 'score' => 3.0 }, 'discard', 'worse')
  
        best = manager.current_best
        assert_equal '8.0', best[:score]
        assert_equal 'def2', best[:commit]
  
        manager.update_beliefs("## Updated beliefs\n1. New belief added")
  
        beliefs = manager.read_beliefs
        assert_match(/Updated beliefs/, beliefs)
  
        FileUtils.rm_rf(dir.mktmpdir)
      end
    end
  ```

- [ ] **Step 2: Run integration test**
  Run: `ruby -Ilib test/integration/test_experiment_integration.rb`
  expected: PASS

- [ ] **Step 3: Commit**
  ```bash
  git add test/integration/test_experiment_integration.rb
  git commit -m "test(experiment): add integration test for full lifecycle"
  ```
