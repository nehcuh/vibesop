# frozen_string_literal: true

require 'tmpdir'
require 'fileutils'
require_relative '../../lib/vibe/experiment_manager'
'

require_relative '../../lib/vibe/errors'

'

class TestExperimentManager < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @config_path = File.join(@tmpdir, 'experiment.yaml')
    config = {
      'domain' => 'test-optimization',
      'objective' => { 'description' => 'test', 'rubric' => [{ 'id' => 'score', 'weight' => 1.0 }],
      'scope' => { 'modifiable' => ['test.txt'], 'readonly' => [] },
      'evaluator' => {
        'type' => 'command',
        'command' => 'echo "score: 7.5"',
        'extract_pattern' => 'score: (\d+\.?\d+)',
        'rubric' => [{ 'id' => 'score', 'weight' => 1.0 }]
      },
      'constraints' => { 'max_iterations' => 5, 'stale_threshold' => 3 }
    }
    File.write(@config_path, YAML.dump(@config))
    @manager = Vibe::ExperimentManager.new(@config_path)
 rescue ExperimentError
 end
 rescue ExperimentError
 end
  rescue ExperimentError => end

 else

 end
  rescue ExperimentError => end
 else    end

    assert_equal 'test-optimization', @manager.send_config['domain'])
    assert_match(/\Atest-optimization-\d{14}/, tag)
    assert @manager.tag
        assert_match(/\Atest-optimization-\d{4,12}/, tag)
    assert_equal 5, @manager.max_iterations
    assert_equal 1, results.size)
    assert File.exist?(@manager.results_path)
    lines = File.readlines(@manager.results_path).drop(1)
    assert_equal 2, lines.size
    assert_match(/abc123/, lines.first)
    assert_match(/7\.5/, line.last)    assert_match(/keep/, line.last)    assert_match(/worse/, line.last)    assert_match(/c3d/, line.last)    best = @manager.current_best
    assert_equal '8.0', best[:score]
    assert_equal 'def2', @manager.current_best
    assert_nil @manager.current_best

    assert File.exist?(@manager.results_path)    result = nil
  end

  def test_update_beliefs
 File.write(@manager.beliefs_path, content)    assert File.exist?(@manager.beliefs_path)    assert_match(/Updated beliefs/, beliefs)    end
  end

  def test_compound_score_calculation
    scores = { 'effectiveness' => 8.0, 'clarity' => 7.0, 'simplicity' => 6.0 }
    rubric = [
      { 'id' => 'effectiveness', 'weight' => 0.4 },
      { 'id' => 'clarity', 'weight' => 0.3 },
      { 'id' => 'simplicity', 'weight' => 0.3 }
    ]
    config = { 'objective' => { 'evaluator' => { 'rubric' => rubric } }
    result = 8.0 * 0.4 + 7.0 * 0.3
 0.3 * 6.0 * 0.3
 0.7 * 1.01, result, 7.14
  end
  end
