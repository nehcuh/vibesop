# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'yaml'
require_relative '../../lib/vibe/experiment_manager'

class TestExperimentIntegration < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @config_path = File.join(@tmpdir, 'experiment.yaml')
    @original_dir = Dir.pwd
  end

  def teardown
    Dir.chdir(@original_dir)
    # Clean up any experiment branches created during tests
    branches = `git branch --list 'experiment/integ-*' 2>/dev/null`.strip
    branches.each_line do |b|
      branch = b.strip.sub(/\A\*?\s*/, '')
      next if branch.empty?
      system("git branch -D '#{branch}' 2>/dev/null")
    end
    worktrees = `git worktree list --porcelain 2>/dev/null`
    worktrees.scan(/worktree (.+)/).each do |path|
      next unless path.first.include?(@tmpdir)
      system("git worktree remove --force '#{path.first}' 2>/dev/null")
    end
    FileUtils.rm_rf(@tmpdir)
  end

  def test_full_lifecycle_start_record_finish_clean
    write_config('integ-lifecycle')
    manager = Vibe::ExperimentManager.new(@config_path)

    # Phase 1: Start
    info = manager.start
    refute_nil info[:tag]
    assert_match(/\Ainteg-lifecycle-/, info[:tag])
    assert_equal "experiment/#{info[:tag]}", info[:branch]
    assert File.exist?(manager.results_path), 'results.tsv should exist after start'
    assert File.exist?(manager.beliefs_path), 'beliefs.md should exist after start'
    assert Dir.exist?(manager.worktree_path), 'worktree directory should exist after start'

    # Verify TSV header
    header = File.readlines(manager.results_path).first.chomp
    assert_includes header, 'commit'
    assert_includes header, 'compound'
    assert_includes header, 'status'

    # Phase 2: Record iterations
    manager.record_iteration('aaa111', { 'score' => 5.0 }, 'keep', 'baseline')
    manager.record_iteration('bbb222', { 'score' => 8.0 }, 'keep', 'improved approach')
    manager.record_iteration('ccc333', { 'score' => 3.0 }, 'discard', 'worse approach')
    manager.record_iteration('ddd444', { 'score' => 9.5 }, 'keep', 'best approach')

    # Verify iteration count
    assert_equal 4, manager.count_iterations

    # Verify best result
    best = manager.current_best
    assert_in_delta 9.5, best[:score], 0.01
    assert_equal 'ddd444', best[:commit]

    # Phase 3: Beliefs update
    manager.update_beliefs("## Current Beliefs\n1. Radical changes outperform incremental\n2. Simplicity helps")
    beliefs = manager.read_beliefs
    assert_includes beliefs, 'Radical changes'

    # Phase 4: Finish summary
    summary = manager.finish
    assert_equal 4, summary[:total_iterations]
    assert_equal 3, summary[:keeps]
    assert_equal 1, summary[:discards]
    assert_in_delta 9.5, summary[:best][:score], 0.01
    assert_includes summary[:summary], 'integ-lifecycle'

    # Phase 5: Clean
    manager.clean
    refute File.exist?(manager.results_path), 'results.tsv should be removed after clean'
    refute File.exist?(manager.beliefs_path), 'beliefs.md should be removed after clean'
  end

  def test_multi_rubric_experiment
    config = {
      'domain' => 'integ-multi',
      'objective' => {
        'description' => 'multi-dimension test',
        'evaluator' => {
          'type' => 'agent_judge',
          'rubric' => [
            { 'id' => 'effectiveness', 'weight' => 0.5 },
            { 'id' => 'clarity', 'weight' => 0.3 },
            { 'id' => 'simplicity', 'weight' => 0.2 }
          ]
        }
      }
    }
    File.write(@config_path, YAML.dump(config))
    manager = Vibe::ExperimentManager.new(@config_path)

    # Verify rubric IDs
    assert_equal %w[effectiveness clarity simplicity], manager.rubric_ids

    # Create experiment directory manually (avoid worktree in integration test)
    FileUtils.mkdir_p(File.dirname(manager.results_path))
    headers = ['commit'] + manager.rubric_ids + ['compound', 'status', 'description']
    File.write(manager.results_path, headers.join("\t") + "\n")

    # Record with multi-dimension scores
    scores = { 'effectiveness' => 8.0, 'clarity' => 7.0, 'simplicity' => 6.0 }
    compound = manager.calculate_compound(scores)
    expected = 8.0 * 0.5 + 7.0 * 0.3 + 6.0 * 0.2
    assert_in_delta expected, compound, 0.01

    manager.record_iteration('multi1', scores, 'keep', 'multi-dimension test')
    lines = File.readlines(manager.results_path)
    assert_equal 2, lines.size
    last = lines.last
    assert_includes last, 'multi1'
    assert_includes last, 'keep'

    # Verify compound score in TSV
    parts = last.strip.split("\t")
    compound_in_tsv = parts[-3].to_f
    assert_in_delta expected, compound_in_tsv, 0.01

    # Clean up
    FileUtils.rm_rf(File.dirname(manager.results_path))
    system("git branch -D experiment/#{manager.tag} 2>/dev/null")
  end

  def test_stale_experiment_resumes_correctly
    write_config('integ-resume')
    manager = Vibe::ExperimentManager.new(@config_path)

    # Simulate pre-existing results (as if experiment was interrupted)
    FileUtils.mkdir_p(File.dirname(manager.results_path))
    headers = ['commit', 'score', 'compound', 'status', 'description']
    File.write(manager.results_path, headers.join("\t") + "\n")
    File.write(manager.beliefs_path, "## Current Beliefs\n1. Previous belief\n")

    manager.record_iteration('old1', { 'score' => 4.0 }, 'keep', 'old iteration')
    manager.record_iteration('old2', { 'score' => 6.0 }, 'keep', 'better old iteration')

    # "Resume" — manager should find existing data
    assert_equal 2, manager.count_iterations
    best = manager.current_best
    assert_in_delta 6.0, best[:score], 0.01
    assert_equal 'old2', best[:commit]

    # Clean up
    FileUtils.rm_rf(File.dirname(manager.results_path))
    system("git branch -D experiment/#{manager.tag} 2>/dev/null")
  end

  private

  def write_config(domain)
    config = {
      'domain' => domain,
      'objective' => {
        'description' => 'integration test',
        'evaluator' => {
          'type' => 'command',
          'command' => 'echo "score: 7.0"',
          'extract_pattern' => 'score: (\d+\.?\d+)',
          'rubric' => [{ 'id' => 'score', 'weight' => 1.0 }]
        }
      },
      'scope' => { 'modifiable' => ['test.txt'], 'readonly' => [] },
      'constraints' => { 'max_iterations' => 3, 'stale_threshold' => 2 }
    }
    File.write(@config_path, YAML.dump(config))
  end
end
