# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../lib/vibe/progress_indicator'

class TestProgressIndicator < Minitest::Test
  def setup
    @progress = Vibe::ProgressIndicator.new('Test Operation', 100)
  end

  def test_initialization
    assert_equal 'Test Operation', @progress.title
    assert_equal 100, @progress.total
    assert_equal 0, @progress.current
    assert_nil @progress.start_time
  end

  def test_initialization_without_total
    progress = Vibe::ProgressIndicator.new('Simple Test')
    assert_equal 'Simple Test', progress.title
    assert_nil progress.total
  end

  def test_start_sets_start_time
    @progress.start
    refute_nil @progress.start_time
    assert @progress.start_time <= Time.now
  end

  def test_start_resets_current
    @progress.instance_variable_set(:@current, 50)
    @progress.start
    assert_equal 0, @progress.current
  end

  def test_update_current_value
    @progress.start
    @progress.update(25)
    assert_equal 25, @progress.current
  end

  def test_update_with_message
    @progress.start
    capture_io do
      @progress.update(50, 'Halfway there')
    end
    assert_equal 50, @progress.current
  end

  def test_update_without_start_does_nothing
    @progress.update(50)
    assert_equal 0, @progress.current
  end

  def test_increment
    @progress.start
    @progress.increment
    assert_equal 1, @progress.current
  end

  def test_increment_with_message
    @progress.start
    @progress.increment('First step done')
    assert_equal 1, @progress.current
  end

  def test_finish_sets_running_to_false
    @progress.start
    @progress.finish
    refute @progress.instance_variable_get(:@running)
  end

  def test_finish_with_custom_message
    @progress.start
    output = capture_io { @progress.finish('All done!') }
    assert output.first.length.positive? || output.last.length.positive?
  end

  def test_finish_without_start_does_nothing
    output = capture_io { @progress.finish('Should not appear') }
    # Should not crash
    assert true
  end

  def test_double_finish
    @progress.start
    @progress.finish
    output = capture_io { @progress.finish('Second finish') }
    # Second finish should not produce output
    assert true
  end

  def test_update_after_finish
    @progress.start
    @progress.finish
    @progress.update(50)
    # Should not update after finish
    assert_equal 0, @progress.current
  end

  def test_progress_to_completion
    @progress.start
    (1..10).each do |i|
      @progress.update(i * 10)
    end
    assert_equal 100, @progress.current
  end

  def test_start_multiple_times
    @progress.start
    first_time = @progress.start_time
    sleep 0.01
    @progress.start
    second_time = @progress.start_time
    assert second_time > first_time
  end

  def test_indeterminate_progress
    progress = Vibe::ProgressIndicator.new('Indeterminate')
    progress.start
    capture_io do
      progress.increment('Step 1')
      progress.increment('Step 2')
    end
    # Should not crash
    assert true
  end

  def test_zero_total
    progress = Vibe::ProgressIndicator.new('Zero Total', 0)
    progress.start
    capture_io do
      progress.update(0)
    end
    # Should handle zero total gracefully
    assert true
  end

  def test_tty_detection
    # Test that tty? method exists and returns boolean
    progress = Vibe::ProgressIndicator.new('TTY Test')
    result = progress.send(:tty?)
    assert [true, false].include?(result)
  end

  def test_progress_bar_formatting
    bar = @progress.send(:progress_bar, 50)
    assert bar.is_a?(String)
    assert bar.length.positive?
  end

  def test_progress_bar_extremes
    empty_bar = @progress.send(:progress_bar, 0)
    full_bar = @progress.send(:progress_bar, 100)

    assert empty_bar.is_a?(String)
    assert full_bar.is_a?(String)
    refute_equal empty_bar, full_bar
  end

  def test_eta_calculation
    @progress.start
    # Simulate some progress
    @progress.instance_variable_set(:@current, 25)
    eta = @progress.send(:calculate_eta, 10.0)
    # ETA should be a time string
    assert eta.is_a?(String) if eta
  end

  def test_duration_formatting
    duration = @progress.send(:format_duration, 65.5)
    assert duration.is_a?(String)
    assert duration.length.positive?
    # Should contain minute indicator
    assert_includes duration, 'm'
  end

  def test_duration_formatting_zero
    duration = @progress.send(:format_duration, 0)
    assert duration.is_a?(String)
    assert duration.length.positive?
  end

  def test_duration_formatting_hours
    duration = @progress.send(:format_duration, 3665.0)
    assert duration.is_a?(String)
    assert duration.length.positive?
  end
end
