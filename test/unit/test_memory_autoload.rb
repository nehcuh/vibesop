#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative '../test_helper'
require 'tmpdir'
require 'fileutils'
require 'json'
require 'yaml'
require_relative '../../lib/vibe/memory_autoload'

class TestMemoryAutoload < Minitest::Test
  include Vibe::MemoryAutoload

  class FakeInput
    def initialize(lines, tty:)
      @lines = Array(lines).dup
      @tty = tty
    end

    def gets
      @lines.shift
    end

    def tty?
      @tty
    end
  end

  def setup
    @test_dir = Dir.mktmpdir('vibe-memory-test')
    @test_home = Dir.mktmpdir('vibe-memory-test-home')
    @original_stdin = $stdin
    @original_home = ENV['HOME']
  end

  def teardown
    $stdin = @original_stdin
    ENV['HOME'] = @original_home if @original_home
    FileUtils.rm_rf(@test_dir) if @test_dir && File.exist?(@test_dir)
    FileUtils.rm_rf(@test_home) if @test_home && File.exist?(@test_home)
  end

  # === detect_memory_files tests ===

  def test_detect_memory_files_no_files
    detection = detect_memory_files(@test_dir)

    refute detection[:found]
    assert_empty detection[:files]
    assert_equal 0, detection[:count]
  end

  def test_detect_memory_files_with_session
    memory_dir = File.join(@test_dir, 'memory')
    FileUtils.mkdir_p(memory_dir)
    File.write(File.join(memory_dir, 'session.md'), '# Session\n\nTest content')

    detection = detect_memory_files(@test_dir)

    assert detection[:found]
    assert_includes detection[:files], 'memory/session.md'
    assert_equal 1, detection[:count]
  end

  def test_detect_memory_files_all_files
    memory_dir = File.join(@test_dir, 'memory')
    FileUtils.mkdir_p(memory_dir)
    File.write(File.join(memory_dir, 'session.md'), '# Session')
    File.write(File.join(memory_dir, 'project-knowledge.md'), '# Knowledge')
    File.write(File.join(memory_dir, 'overview.md'), '# Overview')

    detection = detect_memory_files(@test_dir)

    assert detection[:found]
    assert_equal 3, detection[:count]
    assert_includes detection[:files], 'memory/session.md'
    assert_includes detection[:files], 'memory/project-knowledge.md'
    assert_includes detection[:files], 'memory/overview.md'
  end

  # === prompt_memory_autoload tests ===

  def test_prompt_memory_autoload_no_files
    detection = { found: false, files: [], count: 0, missing: [] }
    $stdin = FakeInput.new([], tty: true)

    result = prompt_memory_autoload(detection, 'claude-code', @test_dir)

    refute result[:enabled]
    assert_empty result[:platforms]
  end

  def test_prompt_memory_autoload_user_declines
    memory_dir = File.join(@test_dir, 'memory')
    FileUtils.mkdir_p(memory_dir)
    File.write(File.join(memory_dir, 'session.md'), '# Session')

    detection = detect_memory_files(@test_dir)
    $stdin = FakeInput.new(['n'], tty: true)

    result = prompt_memory_autoload(detection, 'claude-code', @test_dir)

    refute result[:enabled]
    assert_empty result[:platforms]
  end

  def test_prompt_memory_autoload_user_accepts_claude_only
    memory_dir = File.join(@test_dir, 'memory')
    FileUtils.mkdir_p(memory_dir)
    File.write(File.join(memory_dir, 'session.md'), '# Session')

    detection = detect_memory_files(@test_dir)
    $stdin = FakeInput.new(['y', '1'], tty: true)

    result = prompt_memory_autoload(detection, 'claude-code', @test_dir)

    assert result[:enabled]
    assert_equal ['claude-code'], result[:platforms]
  end

  def test_prompt_memory_autoload_user_accepts_both_platforms
    memory_dir = File.join(@test_dir, 'memory')
    FileUtils.mkdir_p(memory_dir)
    File.write(File.join(memory_dir, 'session.md'), '# Session')

    detection = detect_memory_files(@test_dir)
    $stdin = FakeInput.new(['y', '3'], tty: true)

    result = prompt_memory_autoload(detection, 'claude-code', @test_dir)

    assert result[:enabled]
    assert_equal %w[claude-code opencode], result[:platforms]
  end

  def test_prompt_memory_autoload_user_cancels
    memory_dir = File.join(@test_dir, 'memory')
    FileUtils.mkdir_p(memory_dir)
    File.write(File.join(memory_dir, 'session.md'), '# Session')

    detection = detect_memory_files(@test_dir)
    $stdin = FakeInput.new(['y', '0'], tty: true)

    result = prompt_memory_autoload(detection, 'claude-code', @test_dir)

    refute result[:enabled]
    assert_empty result[:platforms]
  end

  def test_prompt_memory_autoload_non_interactive
    memory_dir = File.join(@test_dir, 'memory')
    FileUtils.mkdir_p(memory_dir)
    File.write(File.join(memory_dir, 'session.md'), '# Session')

    detection = detect_memory_files(@test_dir)
    $stdin = FakeInput.new([], tty: false)

    result = prompt_memory_autoload(detection, 'claude-code', @test_dir)

    refute result[:enabled]
  end

  # === configure_memory_autoload tests ===

  def test_configure_memory_autoload_disabled
    config = { enabled: false, platforms: [] }

    # Should not raise or create any files
    configure_memory_autoload(config, @test_dir, 'claude-code')

    refute File.exist?(File.join(@test_dir, '.vibe', 'config.yaml'))
  end

  def test_configure_memory_autoload_creates_config
    # Isolate HOME to prevent polluting user config
    ENV['HOME'] = @test_home

    memory_dir = File.join(@test_dir, 'memory')
    FileUtils.mkdir_p(memory_dir)
    File.write(File.join(memory_dir, 'session.md'), '# Session')

    config = { enabled: true, platforms: ['claude-code'] }
    configure_memory_autoload(config, @test_dir, 'claude-code')

    config_path = File.join(@test_dir, '.vibe', 'config.yaml')
    assert File.exist?(config_path)

    saved = YAML.safe_load(File.read(config_path))
    assert saved['memory_autoload']['enabled']
    assert_equal ['claude-code'], saved['memory_autoload']['platforms']
    assert saved['memory_autoload']['configured_at']
  end

  def test_configure_memory_autoload_generates_opencode_context
    memory_dir = File.join(@test_dir, 'memory')
    FileUtils.mkdir_p(memory_dir)
    File.write(File.join(memory_dir, 'session.md'), '# Session')
    File.write(File.join(memory_dir, 'project-knowledge.md'), '# Knowledge')

    config = { enabled: true, platforms: ['opencode'] }
    configure_memory_autoload(config, @test_dir, 'opencode')

    context_path = File.join(@test_dir, '.vibe', 'opencode', 'memory-context.md')
    assert File.exist?(context_path)

    content = File.read(context_path)
    assert_includes content, '# Project Memory Context'
    assert_includes content, 'memory/session.md'
    assert_includes content, 'memory/project-knowledge.md'
  end

  # === existing_autoload_config tests ===

  def test_existing_autoload_config_no_config
    result = existing_autoload_config(@test_dir)
    assert_nil result
  end

  def test_existing_autoload_config_returns_config
    vibe_dir = File.join(@test_dir, '.vibe')
    FileUtils.mkdir_p(vibe_dir)
    config = { 'memory_autoload' => { 'enabled' => true, 'platforms' => ['claude-code'] } }
    File.write(File.join(vibe_dir, 'config.yaml'), YAML.dump(config))

    result = existing_autoload_config(@test_dir)

    assert result['enabled']
    assert_equal ['claude-code'], result['platforms']
  end

  def test_existing_autoload_config_malformed_yaml
    vibe_dir = File.join(@test_dir, '.vibe')
    FileUtils.mkdir_p(vibe_dir)
    File.write(File.join(vibe_dir, 'config.yaml'), 'not: valid: yaml: [')

    result = existing_autoload_config(@test_dir)
    assert_nil result
  end

  # === Claude Code integration tests ===

  def test_configure_claude_autoload_updates_settings
    # Set HOME to test home directory (teardown will restore it)
    ENV['HOME'] = @test_home

    # Create test home directory structure
    claude_dir = File.join(@test_home, '.claude')
    FileUtils.mkdir_p(claude_dir)

    # Create memory files
    memory_dir = File.join(@test_dir, 'memory')
    FileUtils.mkdir_p(memory_dir)
    File.write(File.join(memory_dir, 'session.md'), '# Session')

    config = { enabled: true, platforms: ['claude-code'] }
    configure_memory_autoload(config, @test_dir, 'claude-code')

    # Verify settings were written to test home (not real home)
    settings_path = File.join(@test_home, '.claude', 'settings.json')
    assert File.exist?(settings_path), 'Settings should be written to test HOME'

    settings = JSON.parse(File.read(settings_path))
    assert settings['hooks']
    assert settings['hooks']['preCommand']
    assert(settings['hooks']['preCommand'].any? { |cmd| cmd.include?('memory/session.md') } ||
           settings['hooks']['preCommand'].any? { |cmd| cmd.is_a?(Hash) && cmd['command'].include?('memory/session.md') } ||
           settings['hooks']['preCommand'].any? { |cmd| cmd.is_a?(Hash) && cmd['command'].include?('ruby -e') })
  end
end
