# frozen_string_literal: true

require_relative '../test_helper'
require 'fileutils'
require 'json'

class TestOpenCodeClaudeCodeAlignment < Minitest::Test
  def setup
    @repo_root = File.expand_path('../..', __dir__)
    @tmp_dir = Dir.mktmpdir
    @vibe = "#{@repo_root}/bin/vibe"
  end

  def teardown
    FileUtils.rm_rf(@tmp_dir)
  end

  def test_opencode_global_generates_same_doc_types_as_claude_code
    claude_output = File.join(@tmp_dir, 'claude-global')
    opencode_output = File.join(@tmp_dir, 'opencode-global')

    # Build both platforms
    system("#{@vibe} build claude-code --output #{claude_output} 2>/dev/null")
    system("#{@vibe} build opencode --output #{opencode_output} 2>/dev/null")

    # Both should generate behavior-policies.md and safety.md
    assert File.exist?(File.join(claude_output, '.vibe/claude-code/behavior-policies.md'))
    assert File.exist?(File.join(opencode_output, '.vibe/opencode/behavior-policies.md'))

    # Both should generate task-routing.md (NEW - aligned)
    assert File.exist?(File.join(claude_output, '.vibe/claude-code/task-routing.md')), 
           "Claude Code should have task-routing.md"
    assert File.exist?(File.join(opencode_output, '.vibe/opencode/task-routing.md')), 
           "OpenCode should have task-routing.md (aligned with Claude Code)"

    # Both should generate test-standards.md (NEW - aligned)
    assert File.exist?(File.join(claude_output, '.vibe/claude-code/test-standards.md')), 
           "Claude Code should have test-standards.md"
    assert File.exist?(File.join(opencode_output, '.vibe/opencode/test-standards.md')), 
           "OpenCode should have test-standards.md (aligned with Claude Code)"
  end

  def test_opencode_project_generates_minimal_docs_like_claude_code
    claude_project = File.join(@tmp_dir, 'claude-project')
    opencode_project = File.join(@tmp_dir, 'opencode-project')
    FileUtils.mkdir_p(claude_project)
    FileUtils.mkdir_p(opencode_project)

    # Apply both platforms to project directories
    system("#{@vibe} use claude-code #{claude_project} --force 2>/dev/null")
    system("#{@vibe} use opencode #{opencode_project} --force 2>/dev/null")

    # Both should have entrypoint
    assert File.exist?(File.join(claude_project, 'CLAUDE.md'))
    assert File.exist?(File.join(opencode_project, 'AGENTS.md'))

    # Both should have native config
    assert File.exist?(File.join(claude_project, 'settings.json'))
    assert File.exist?(File.join(opencode_project, 'opencode.json'))

    # Both should have minimal docs (behavior + safety only)
    assert File.exist?(File.join(claude_project, '.vibe/claude-code/behavior-policies.md'))
    assert File.exist?(File.join(opencode_project, '.vibe/opencode/behavior-policies.md'))

    # Neither should have task-routing or test-standards in project mode
    refute File.exist?(File.join(claude_project, '.vibe/claude-code/task-routing.md')),
           "Claude Code project should NOT have task-routing.md"
    refute File.exist?(File.join(opencode_project, '.vibe/opencode/task-routing.md')),
           "OpenCode project should NOT have task-routing.md"
    refute File.exist?(File.join(claude_project, '.vibe/claude-code/test-standards.md')),
           "Claude Code project should NOT have test-standards.md"
    refute File.exist?(File.join(opencode_project, '.vibe/opencode/test-standards.md')),
           "OpenCode project should NOT have test-standards.md"
  end

  def test_opencode_instructions_aligned_with_claude_code_structure
    output = File.join(@tmp_dir, 'opencode-test')
    system("#{@vibe} build opencode --output #{output} 2>/dev/null")

    config = JSON.parse(File.read(File.join(output, 'opencode.json')))
    instructions = config['instructions']

    # Should reference AGENTS.md (entrypoint)
    assert instructions.include?('AGENTS.md'), "Should include AGENTS.md"

    # Should reference behavior-policies.md
    assert instructions.any? { |i| i.include?('behavior-policies.md') },
           "Should include behavior-policies.md"

    # Should reference safety.md
    assert instructions.any? { |i| i.include?('safety.md') },
           "Should include safety.md"
  end
end
