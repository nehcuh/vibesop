# frozen_string_literal: true

require_relative '../test_helper'
require 'fileutils'
require 'json'
require 'open3'

class TestUseCommandProjectSemantics < Minitest::Test
  def setup
    @repo_root = File.expand_path('../..', __dir__)
    @tmp_dir = Dir.mktmpdir
    @vibe = "#{@repo_root}/bin/vibe"
  end

  def teardown
    FileUtils.rm_rf(@tmp_dir)
  end

  def test_use_claude_code_to_project_dir_generates_project_config
    project_dir = File.join(@tmp_dir, 'my-project')
    FileUtils.mkdir_p(project_dir)

    # Use deploy command to project directory
    output, status = Open3.capture2e(
      "#{@vibe} use claude-code #{project_dir} --force"
    )

    assert status.success?, "use command should succeed: #{output}"

    # Should generate project-level files
    assert File.exist?(File.join(project_dir, 'CLAUDE.md')), "Should have CLAUDE.md"
    assert File.exist?(File.join(project_dir, 'settings.json')), "Should have settings.json"
    assert File.exist?(File.join(project_dir, '.vibe/manifest.json')), "Should have manifest.json"

    # Should NOT copy runtime dirs (project is lightweight)
    refute File.exist?(File.join(project_dir, 'rules')), "Project should NOT have rules/"
    refute File.exist?(File.join(project_dir, 'skills')), "Project should NOT have skills/"
    refute File.exist?(File.join(project_dir, 'memory')), "Project should NOT have memory/"
  end

  def test_use_opencode_to_project_dir_generates_project_config
    project_dir = File.join(@tmp_dir, 'my-opencode-project')
    FileUtils.mkdir_p(project_dir)

    # Use deploy command to project directory
    output, status = Open3.capture2e(
      "#{@vibe} use opencode #{project_dir} --force"
    )

    assert status.success?, "use command should succeed: #{output}"

    # Should generate project-level files
    assert File.exist?(File.join(project_dir, 'AGENTS.md')), "Should have AGENTS.md"
    assert File.exist?(File.join(project_dir, 'opencode.json')), "Should have opencode.json"
    assert File.exist?(File.join(project_dir, '.vibe/manifest.json')), "Should have manifest.json"

    # Verify it's project-level config (has extends)
    config = JSON.parse(File.read(File.join(project_dir, 'opencode.json')))
    assert_equal "~/.config/opencode/opencode.json", config['extends'],
                 "Project opencode.json should extend global config"

    # Should have minimal instructions (project-level)
    assert config['instructions'].length < 5, "Project should have minimal instructions"
  end

  def test_use_opencode_to_global_dir_generates_global_config
    # Create a temp HOME directory to fully control the environment
    temp_home = File.join(@tmp_dir, 'home')
    FileUtils.mkdir_p(temp_home)
    
    # Create the global config directory inside temp HOME
    global_dir = File.join(temp_home, '.config', 'opencode')
    FileUtils.mkdir_p(global_dir)

    # Use deploy command with HOME pointing to temp directory
    output, status = Open3.capture2e(
      { 'HOME' => temp_home },
      "#{@vibe} use opencode #{global_dir} --force"
    )

    assert status.success?, "use command should succeed: #{output}"

    # Should generate global-level config (no extends)
    config = JSON.parse(File.read(File.join(global_dir, 'opencode.json')))
    refute config['extends'], "Global opencode.json should NOT extend"

    # Should have full instructions
    assert config['instructions'].length > 3, "Global should have full instructions"
  end
end
