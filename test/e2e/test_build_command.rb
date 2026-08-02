# frozen_string_literal: true

require_relative '../test_helper'
require 'fileutils'
require 'json'

class TestBuildCommand < Minitest::Test
  def setup
    @repo_root = File.expand_path('../..', __dir__)
    @tmp_dir = Dir.mktmpdir
    @vibe = "#{@repo_root}/bin/vibe"
  end

  def teardown
    FileUtils.rm_rf(@tmp_dir)
  end

  def test_build_claude_code_creates_all_expected_files
    output = File.join(@tmp_dir, 'output')
    result = system("#{@vibe} build claude-code --output #{output} 2>/dev/null")
    assert result, "Build command should succeed"

    assert File.exist?(File.join(output, 'CLAUDE.md')), "Should have CLAUDE.md"
    assert File.exist?(File.join(output, 'settings.json')), "Should have settings.json"
    assert File.exist?(File.join(output, '.vibe/manifest.json')), "Should have manifest.json"
    assert File.exist?(File.join(output, '.vibe/claude-code/behavior-policies.md')), "Should have behavior-policies.md"
  end

  def test_build_opencode_creates_all_expected_files
    output = File.join(@tmp_dir, 'output')
    result = system("#{@vibe} build opencode --output #{output} 2>/dev/null")
    assert result, "Build command should succeed"

    assert File.exist?(File.join(output, 'AGENTS.md')), "Should have AGENTS.md"
    assert File.exist?(File.join(output, 'opencode.json')), "Should have opencode.json"
    assert File.exist?(File.join(output, '.vibe/manifest.json')), "Should have manifest.json"
    assert File.exist?(File.join(output, '.vibe/opencode/behavior-policies.md')), "Should have behavior-policies.md"
    # Verify alignment with Claude Code - should generate task-routing and test-standards
    assert File.exist?(File.join(output, '.vibe/opencode/task-routing.md')), "Should have task-routing.md (aligned with Claude Code)"
    assert File.exist?(File.join(output, '.vibe/opencode/test-standards.md')), "Should have test-standards.md (aligned with Claude Code)"
  end

  def test_build_with_overlay_applies_overlay
    output = File.join(@tmp_dir, 'overlay-test')
    overlay = "#{@repo_root}/examples/project-overlay.yaml"
    result = system("#{@vibe} build claude-code --output #{output} --overlay #{overlay} 2>/dev/null")
    assert result, "Build command with overlay should succeed"

    manifest = JSON.parse(File.read(File.join(output, '.vibe/manifest.json')))
    refute_nil manifest['overlay'], "Manifest should have overlay"
    assert_equal "example-regulated-project", manifest['overlay']['name'], "Overlay name should be recorded"
  end

  def test_build_generates_valid_json_files
    output = File.join(@tmp_dir, 'json-test')
    result = system("#{@vibe} build claude-code --output #{output} 2>/dev/null")
    assert result, "Build command should succeed"

    # Verify settings.json is valid JSON
    settings = JSON.parse(File.read(File.join(output, 'settings.json')))
    assert settings['permissions'], "settings.json should have permissions"

    # Verify manifest.json is valid JSON
    manifest = JSON.parse(File.read(File.join(output, '.vibe/manifest.json')))
    assert_equal 5, manifest['schema_version'], "manifest should have schema_version 5"
    assert manifest['target'], "manifest should have target"
    assert manifest['profile'], "manifest should have profile"
  end
end
