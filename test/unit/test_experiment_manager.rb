# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require 'yaml'
require_relative '../../lib/vibe/experiment_manager'

class TestExperimentManager < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @config_path = File.join(@tmpdir, 'experiment.yaml')
    write_default_config
    @manager = Vibe::ExperimentManager.new(@config_path)
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
    cleanup_experiment_branches
  end

  def test_load_config
    assert_equal 'test-optimization', @manager.config['domain']
  end

  def test_derive_tag
    tag = @manager.tag
    assert_match(/\Atest-optimization-\d{14}/, tag)
  end

  def test_rubric_ids_from_config
    assert_equal ['score'], @manager.rubric_ids
  end

  def test_rubric_ids_default_when_no_rubric
    config_path = File.join(@tmpdir, 'no_rubric.yaml')
    config = {
      'domain' => 'plain',
      'objective' => { 'evaluator' => { 'type' => 'command' } }
    }
    File.write(config_path, YAML.dump(config))
    manager = Vibe::ExperimentManager.new(config_path)
    assert_equal ['score'], manager.rubric_ids
  end

  def test_record_iteration
    manager = prepare_experiment_dir
    manager.record_iteration('abc123', { 'score' => 7.5 }, 'keep', 'baseline')
    lines = File.readlines(manager.results_path)
    assert_equal 2, lines.size
    assert_match(/abc123/, lines.last)
    assert_match(/7\.5/, lines.last)
    assert_match(/keep/, lines.last)
  end

  def test_current_best_nil_when_no_results
    assert_nil @manager.current_best
  end

  def test_current_best_returns_best_after_record
    manager = prepare_experiment_dir
    manager.record_iteration('abc123', { 'score' => 5.0 }, 'keep', 'baseline')
    manager.record_iteration('def456', { 'score' => 8.0 }, 'keep', 'improved')
    manager.record_iteration('c3d', { 'score' => 3.0 }, 'discard', 'worse')
    best = manager.current_best
    assert_in_delta 8.0, best[:score], 0.01
    assert_equal 'def456', best[:commit]
  end

  def test_update_beliefs
    manager = prepare_experiment_dir
    manager.update_beliefs("## Updated beliefs\n1. New belief added")
    beliefs = manager.read_beliefs
    assert_match(/Updated beliefs/, beliefs)
  end

  def test_read_beliefs_nil_when_missing
    assert_nil @manager.read_beliefs
  end

  def test_compound_score_calculation
    config_path = File.join(@tmpdir, 'multi_rubric.yaml')
    config = {
      'domain' => 'multi',
      'objective' => {
        'evaluator' => {
          'rubric' => [
            { 'id' => 'effectiveness', 'weight' => 0.4 },
            { 'id' => 'clarity', 'weight' => 0.3 },
            { 'id' => 'simplicity', 'weight' => 0.3 }
          ]
        }
      }
    }
    File.write(config_path, YAML.dump(config))
    manager = Vibe::ExperimentManager.new(config_path)
    scores = { 'effectiveness' => 8.0, 'clarity' => 7.0, 'simplicity' => 6.0 }
    result = manager.calculate_compound(scores)
    expected = 8.0 * 0.4 + 7.0 * 0.3 + 6.0 * 0.3
    assert_in_delta expected, result, 0.01
  end

  def test_compound_score_single_dimension
    result = @manager.calculate_compound({ 'score' => 7.5 })
    assert_in_delta 7.5, result, 0.01
  end

  def test_count_iterations_zero_when_no_results
    assert_equal 0, @manager.count_iterations
  end

  def test_count_iterations_after_record
    manager = prepare_experiment_dir
    manager.record_iteration('a1', { 'score' => 5.0 }, 'keep', 'one')
    manager.record_iteration('b2', { 'score' => 6.0 }, 'keep', 'two')
    assert_equal 2, manager.count_iterations
  end

  def test_start_creates_files_and_dirs
    manager = build_unique_manager('start-test')
    result = manager.start
    assert_equal manager.tag, result[:tag]
    assert File.exist?(manager.results_path)
    assert File.exist?(manager.beliefs_path)
    assert Dir.exist?(manager.worktree_path)
    header = File.readlines(manager.results_path).first
    assert_match(/commit/, header)
    assert_match(/compound/, header)
  end

  def test_clean_removes_experiment_artifacts
    manager = prepare_experiment_dir
    manager.record_iteration('a1', { 'score' => 5.0 }, 'keep', 'test')
    manager.clean
    refute File.exist?(manager.results_path)
    refute File.exist?(manager.beliefs_path)
  end

  def test_finish_returns_summary
    manager = prepare_experiment_dir
    manager.record_iteration('a1', { 'score' => 5.0 }, 'keep', 'baseline')
    manager.record_iteration('b2', { 'score' => 8.0 }, 'keep', 'improved')
    manager.record_iteration('c3', { 'score' => 3.0 }, 'discard', 'worse')
    summary = manager.finish
    assert_equal 3, summary[:total_iterations]
    assert_equal 2, summary[:keeps]
    assert_equal 1, summary[:discards]
    assert_in_delta 8.0, summary[:best][:score], 0.01
  end

  def test_config_not_found_raises
    assert_raises(Vibe::ExperimentManager::ExperimentNotFoundError) do
      Vibe::ExperimentManager.new('/nonexistent/path.yaml')
    end
  end

  def test_invalid_config_raises
    bad_path = File.join(@tmpdir, 'bad.yaml')
    File.write(bad_path, "just a string\n")
    assert_raises(Vibe::ExperimentManager::ExperimentError) do
      Vibe::ExperimentManager.new(bad_path)
    end
  end

  private

  def write_default_config
    config = {
      'domain' => 'test-optimization',
      'objective' => {
        'description' => 'test',
        'evaluator' => {
          'type' => 'command',
          'command' => 'echo "score: 7.5"',
          'extract_pattern' => 'score: (\d+\.?\d+)',
          'rubric' => [{ 'id' => 'score', 'weight' => 1.0 }]
        }
      },
      'scope' => { 'modifiable' => ['test.txt'], 'readonly' => [] },
      'constraints' => { 'max_iterations' => 5, 'stale_threshold' => 3 }
    }
    File.write(@config_path, YAML.dump(config))
  end

  def build_unique_manager(suffix)
    config_path = File.join(@tmpdir, "experiment-#{suffix}-#{Process.pid}-#{rand(100000)}.yaml")
    config = {
      'domain' => "test-#{suffix}-#{Process.pid}",
      'objective' => {
        'evaluator' => {
          'rubric' => [{ 'id' => 'score', 'weight' => 1.0 }]
        }
      }
    }
    File.write(config_path, YAML.dump(config))
    Vibe::ExperimentManager.new(config_path)
  end

  def prepare_experiment_dir
    manager = build_unique_manager("exp-#{object_id}")
    FileUtils.mkdir_p(File.dirname(manager.results_path))
    FileUtils.mkdir_p(File.dirname(manager.beliefs_path))
    headers = ['commit'] + manager.rubric_ids + ['compound', 'status', 'description']
    File.write(manager.results_path, headers.join("\t") + "\n")
    File.write(manager.beliefs_path, "## Beliefs\n")
    manager
  end

  def cleanup_experiment_branches
    branches = `git branch --list 'experiment/test-*' 2>/dev/null`.strip
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
  end
end
