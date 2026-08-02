# frozen_string_literal: true

require_relative '../test_helper'
require_relative '../../lib/vibe/trigger_manager'

class TriggerManagerTest < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir
    @state_file = File.join(@tmpdir, 'skill-craft-state.yaml')
    @manager = new_manager
  end

  def teardown
    FileUtils.rm_rf(@tmpdir)
  end

  # --- helpers ---

  def new_manager(extra_config = {})
    Vibe::TriggerManager.new({ 'state_file' => @state_file }.merge(extra_config))
  end

  def write_state(hash)
    File.write(@state_file, YAML.dump(hash))
  end

  # ─── load_state ─────────────────────────────────────────────────────────────

  def test_load_state_returns_defaults_when_file_missing
    refute File.exist?(@state_file)
    assert_equal 0, @manager.state['session_count']
    assert_nil @manager.state['last_review']
  end

  def test_load_state_reads_existing_yaml
    write_state('session_count' => 5, 'last_review' => '2026-03-01')
    m = new_manager
    assert_equal 5, m.state['session_count']
    assert_equal '2026-03-01', m.state['last_review']
  end

  def test_load_state_rescue_on_corrupt_yaml
    File.write(@state_file, ":\ninvalid: : yaml\n  bad")
    m = new_manager
    assert_equal 0, m.state['session_count']
    assert_nil m.state['last_review']
  end

  # ─── save_state (atomic) ────────────────────────────────────────────────────

  def test_save_state_writes_file
    @manager.instance_variable_get(:@state)['session_count'] = 7
    @manager.save_state
    assert File.exist?(@state_file)
    loaded = YAML.safe_load(File.read(@state_file))
    assert_equal 7, loaded['session_count']
  end

  def test_save_state_no_tmp_file_left_behind
    @manager.save_state
    tmp_files = Dir.glob("#{@state_file}.tmp.*")
    assert_empty tmp_files, "Temporary files left after atomic write: #{tmp_files}"
  end

  # ─── accumulation_trigger? ──────────────────────────────────────────────────

  def test_accumulation_trigger_false_below_threshold
    write_state('session_count' => 9)
    m = new_manager
    refute m.accumulation_trigger?({}), 'Should not trigger at 9 (threshold=10)'
  end

  def test_accumulation_trigger_true_at_threshold
    write_state('session_count' => 10)
    m = new_manager
    assert m.accumulation_trigger?({}), 'Should trigger exactly at threshold'
  end

  def test_accumulation_trigger_true_above_threshold
    write_state('session_count' => 15)
    m = new_manager
    assert m.accumulation_trigger?({})
  end

  def test_accumulation_trigger_false_when_session_count_missing
    write_state({})
    m = new_manager
    refute m.accumulation_trigger?({})
  end

  def test_accumulation_trigger_custom_threshold
    write_state('session_count' => 3)
    m = new_manager('triggers' => { 'accumulation_threshold' => 3 })
    assert m.accumulation_trigger?({})
  end

  # ─── periodic_trigger? ──────────────────────────────────────────────────────

  def test_periodic_trigger_false_when_last_review_nil
    write_state('session_count' => 0)
    m = new_manager
    refute m.periodic_trigger?
  end

  def test_periodic_trigger_false_when_interval_not_reached
    # 6 days ago — less than default 7-day interval
    six_days_ago = (Date.today - 6).to_s
    write_state('last_review' => six_days_ago)
    m = new_manager('triggers' => { 'periodic_interval' => 7, 'periodic_day' => Date.today.wday,
                                    'max_prompts_per_day' => 5 })
    refute m.periodic_trigger?
  end

  def test_periodic_trigger_false_when_wrong_day_of_week
    eight_days_ago = (Date.today - 8).to_s
    wrong_day = (Date.today.wday + 1) % 7
    write_state('last_review' => eight_days_ago)
    m = new_manager('triggers' => { 'periodic_interval' => 7, 'periodic_day' => wrong_day,
                                    'max_prompts_per_day' => 5 })
    refute m.periodic_trigger?
  end

  def test_periodic_trigger_true_when_all_conditions_met
    eight_days_ago = (Date.today - 8).to_s
    write_state('last_review' => eight_days_ago, 'prompts_today' => [])
    m = new_manager('triggers' => { 'periodic_interval' => 7, 'periodic_day' => Date.today.wday,
                                    'max_prompts_per_day' => 5 })
    assert m.periodic_trigger?
  end

  def test_periodic_trigger_false_when_max_prompts_reached
    eight_days_ago = (Date.today - 8).to_s
    today_str = Date.today.to_s
    write_state('last_review' => eight_days_ago, 'prompts_today' => [today_str, today_str])
    m = new_manager('triggers' => { 'periodic_interval' => 7, 'periodic_day' => Date.today.wday,
                                    'max_prompts_per_day' => 2 })
    refute m.periodic_trigger?
  end

  # ─── project_completion_trigger? ────────────────────────────────────────────

  def test_project_completion_trigger_false_when_disabled
    m = new_manager('triggers' => { 'project_completion' => false })
    refute m.project_completion_trigger?(git_event: 'push to main')
  end

  def test_project_completion_trigger_false_when_git_event_not_string
    refute @manager.project_completion_trigger?(git_event: nil)
    refute @manager.project_completion_trigger?(git_event: 42)
    refute @manager.project_completion_trigger?({})
  end

  def test_project_completion_trigger_true_for_push
    assert @manager.project_completion_trigger?(git_event: 'push to main')
  end

  def test_project_completion_trigger_true_for_merge_uppercase
    assert @manager.project_completion_trigger?(git_event: 'MERGE branch feature/x')
  end

  def test_project_completion_trigger_false_for_unrelated_event
    refute @manager.project_completion_trigger?(git_event: 'commit changes')
  end

  def test_project_completion_trigger_false_for_empty_string
    refute @manager.project_completion_trigger?(git_event: '')
  end

  # ─── check_triggers ─────────────────────────────────────────────────────────

  def test_check_triggers_returns_empty_when_none_fire
    write_state('session_count' => 0)
    m = new_manager
    assert_empty m.check_triggers({})
  end

  def test_check_triggers_returns_accumulation
    write_state('session_count' => 10)
    m = new_manager
    types = m.check_triggers({}).map { |t| t[:type] }
    assert_includes types, :accumulation
  end

  def test_check_triggers_returns_project_completion
    write_state('session_count' => 0)
    m = new_manager
    types = m.check_triggers(git_event: 'push').map { |t| t[:type] }
    assert_includes types, :project_completion
  end

  def test_check_triggers_can_return_multiple
    write_state('session_count' => 10)
    m = new_manager
    triggers = m.check_triggers(git_event: 'push')
    types = triggers.map { |t| t[:type] }
    assert_includes types, :accumulation
    assert_includes types, :project_completion
    assert triggers.length >= 2
  end

  def test_check_triggers_includes_message_key
    write_state('session_count' => 10)
    m = new_manager
    trigger = m.check_triggers({}).first
    assert trigger[:message], 'Trigger should include a :message key'
  end

  # ─── increment_session_count ────────────────────────────────────────────────

  def test_increment_session_count_starts_at_zero
    @manager.increment_session_count
    loaded = YAML.safe_load(File.read(@state_file))
    assert_equal 1, loaded['session_count']
  end

  def test_increment_session_count_accumulates
    @manager.increment_session_count
    @manager.increment_session_count
    @manager.increment_session_count
    m2 = new_manager
    assert_equal 3, m2.state['session_count']
  end

  # ─── record_prompt ───────────────────────────────────────────────────────────

  def test_record_prompt_adds_today_entry
    @manager.record_prompt
    loaded = YAML.safe_load(File.read(@state_file))
    assert_includes loaded['prompts_today'], Date.today.to_s
  end

  def test_record_prompt_accumulates
    @manager.record_prompt
    @manager.record_prompt
    loaded = YAML.safe_load(File.read(@state_file))
    assert_equal 2, loaded['prompts_today'].length
  end

  # ─── record_review ───────────────────────────────────────────────────────────

  def test_record_review_resets_session_count
    write_state('session_count' => 5)
    m = new_manager
    m.record_review
    loaded = YAML.safe_load(File.read(@state_file))
    assert_equal 0, loaded['session_count']
  end

  def test_record_review_updates_last_review
    @manager.record_review
    loaded = YAML.safe_load(File.read(@state_file))
    assert_equal Date.today.to_s, loaded['last_review']
  end

  # ─── periodic_message edge case ─────────────────────────────────────────────

  def test_periodic_message_raises_when_last_review_nil
    # Document that periodic_message is unsafe to call directly when last_review is nil.
    # Normal usage: periodic_trigger? guards this, so check_triggers is safe.
    # Direct call is an unchecked public method — expected to raise.
    assert_raises(TypeError, ArgumentError) { @manager.periodic_message }
  end
end
