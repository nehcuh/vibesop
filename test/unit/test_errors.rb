# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../lib/vibe/errors'

class TestErrors < Minitest::Test
  def test_vibe_error_exists
    assert Vibe.const_defined?(:Error)
  end

  def test_vibe_error_is_standard_error
    assert Vibe::Error.ancestors.include?(StandardError)
  end

  def test_vibe_error_has_context_reader
    error = Vibe::Error.new('test', context: { key: 'value' })
    assert_equal({ key: 'value' }, error.context)
  end

  def test_vibe_error_default_context_is_empty
    error = Vibe::Error.new('test')
    assert_equal({}, error.context)
  end

  def test_vibe_error_to_s_without_context
    error = Vibe::Error.new('test message')
    assert_equal 'test message', error.to_s
  end

  def test_vibe_error_to_s_with_context
    error = Vibe::Error.new('test message', context: { key: 'value' })
    assert_match(/test message/, error.to_s)
    assert_match(/Context:/, error.to_s)
    assert_match(/key.*value/, error.to_s)
  end

  def test_path_safety_error_exists
    assert Vibe.const_defined?(:PathSafetyError)
  end

  def test_path_safety_error_is_vibe_error
    assert Vibe::PathSafetyError.ancestors.include?(Vibe::Error)
  end

  def test_security_error_exists
    assert Vibe.const_defined?(:SecurityError)
  end

  def test_security_error_is_vibe_error
    assert Vibe::SecurityError.ancestors.include?(Vibe::Error)
  end

  def test_validation_error_exists
    assert Vibe.const_defined?(:ValidationError)
  end

  def test_validation_error_is_vibe_error
    assert Vibe::ValidationError.ancestors.include?(Vibe::Error)
  end

  def test_validation_error_has_field_reader
    error = Vibe::ValidationError.new('test', field: 'username')
    assert_equal 'username', error.field
  end

  def test_validation_error_has_value_reader
    error = Vibe::ValidationError.new('test', value: 'invalid')
    assert_equal 'invalid', error.value
  end

  def test_validation_error_field_and_value_in_context
    error = Vibe::ValidationError.new('test', field: 'username', value: 'invalid')
    assert_equal 'username', error.context[:field]
    assert_equal 'invalid', error.context[:value]
  end

  def test_validation_error_to_s_with_field_and_value
    error = Vibe::ValidationError.new('Invalid input', field: 'username', value: 'abc123')
    str = error.to_s
    assert_match(/Invalid input/, str)
    assert_match(/field=username/, str)
    assert_match(/value=["']abc123["']/, str)
  end

  def test_validation_error_to_s_with_only_field
    error = Vibe::ValidationError.new('Invalid', field: 'email')
    str = error.to_s
    assert_match(/field=email/, str)
  end

  def test_validation_error_to_s_with_only_value
    error = Vibe::ValidationError.new('Invalid', value: 123)
    str = error.to_s
    assert_match(/value=123/, str)
  end

  def test_configuration_error_exists
    assert Vibe.const_defined?(:ConfigurationError)
  end

  def test_configuration_error_is_vibe_error
    assert Vibe::ConfigurationError.ancestors.include?(Vibe::Error)
  end

  def test_external_tool_error_exists
    assert Vibe.const_defined?(:ExternalToolError)
  end

  def test_external_tool_error_is_vibe_error
    assert Vibe::ExternalToolError.ancestors.include?(Vibe::Error)
  end

  def test_all_error_classes_can_be_raised
    assert_raises(Vibe::PathSafetyError) { raise Vibe::PathSafetyError, 'path error' }
    assert_raises(Vibe::SecurityError) { raise Vibe::SecurityError, 'security error' }
    assert_raises(Vibe::ValidationError) do
      raise Vibe::ValidationError, 'validation error'
    end
    assert_raises(Vibe::ConfigurationError) do
      raise Vibe::ConfigurationError, 'config error'
    end
    assert_raises(Vibe::ExternalToolError) { raise Vibe::ExternalToolError, 'tool error' }
  end

  def test_vibe_error_message_preserved
    error = Vibe::Error.new('original message')
    assert_equal 'original message', error.message
  end

  def test_validation_error_inherits_context_from_base_class
    error = Vibe::ValidationError.new('test', context: { extra: 'info' })
    assert_equal 'info', error.context[:extra]
  end

  def test_validation_error_context_merges_field_and_value
    error = Vibe::ValidationError.new('test',
                                      field: 'field1',
                                      value: 'value1',
                                      context: { extra: 'info' })
    assert_equal 'field1', error.context[:field]
    assert_equal 'value1', error.context[:value]
    assert_equal 'info', error.context[:extra]
  end
end
