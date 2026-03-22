# frozen_string_literal: true

require_relative '../test_helper'
require 'fileutils'
require 'json'

class TestProjectGlobalSemantics < Minitest::Test
  def setup
    @repo_root = File.expand_path('../..', __dir__)
    @tmp_dir = Dir.mktmpdir
    @vibe = "#{@repo_root}/bin/vibe"
  end

  def teardown
    FileUtils.rm_rf(@tmp_dir)
  end

  def test_claude_code_global_copies_runtime
    output = File.join(@tmp_dir, 'claude-global')
    result = system("#{@vibe} build claude-code --output #{output} 2>/dev/null")
    assert result, 'Build command should succeed'

    assert File.exist?(File.join(output, 'rules')), 'Global should have rules/'
    assert File.exist?(File.join(output, 'skills')), 'Global should have skills/'
    assert File.exist?(File.join(output, 'memory')), 'Global should have memory/'
  end

  def test_claude_code_global_has_all_docs
    output = File.join(@tmp_dir, 'claude-global')
    result = system("#{@vibe} build claude-code --output #{output} 2>/dev/null")
    assert result, 'Build command should succeed'

    vibe_dir = File.join(output, '.vibe', 'claude-code')
    assert File.exist?(File.join(vibe_dir, 'behavior-policies.md')),
           'Global should have behavior-policies.md'
    assert File.exist?(File.join(vibe_dir, 'safety.md')), 'Global should have safety.md'
    assert File.exist?(File.join(vibe_dir, 'task-routing.md')),
           'Global should have task-routing.md'
    assert File.exist?(File.join(vibe_dir, 'test-standards.md')),
           'Global should have test-standards.md'
  end

  def test_opencode_global_has_full_config
    output = File.join(@tmp_dir, 'opencode-global')
    result = system("#{@vibe} build opencode --output #{output} 2>/dev/null")
    assert result, 'Build command should succeed'

    config = JSON.parse(File.read(File.join(output, 'opencode.json')))
    refute config['extends'], 'Global config should not extend'
    assert config['permission'], 'Global should have full permission config'
    assert config['instructions'].length > 3, 'Global should have multiple instructions'
  end
end
