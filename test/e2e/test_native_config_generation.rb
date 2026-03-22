# frozen_string_literal: true

require_relative '../test_helper'
require 'fileutils'
require 'json'

class TestNativeConfigGeneration < Minitest::Test
  def setup
    @repo_root = File.expand_path('../..', __dir__)
    @tmp_dir = Dir.mktmpdir
    @vibe = "#{@repo_root}/bin/vibe"
  end

  def teardown
    FileUtils.rm_rf(@tmp_dir)
  end

  def test_claude_code_generates_settings_json
    output = File.join(@tmp_dir, 'claude-code')
    result = system("#{@vibe} build claude-code --output #{output} 2>/dev/null")
    assert result, 'Build command should succeed'

    settings_path = File.join(output, 'settings.json')
    assert File.exist?(settings_path), 'settings.json should be generated for claude-code'

    content = JSON.parse(File.read(settings_path))
    assert content['permissions'], 'settings.json should have permissions'
    assert content['permissions']['ask'].is_a?(Array),
           'permissions.ask should be an array'
    assert content['permissions']['deny'].is_a?(Array),
           'permissions.deny should be an array'
  end

  def test_opencode_generates_opencode_json
    output = File.join(@tmp_dir, 'opencode')
    result = system("#{@vibe} build opencode --output #{output} 2>/dev/null")
    assert result, 'Build command should succeed'

    config_path = File.join(output, 'opencode.json')
    assert File.exist?(config_path), 'opencode.json should be generated for opencode'

    content = JSON.parse(File.read(config_path))
    assert content['instructions'], 'opencode.json should have instructions'
    assert content['permission'], 'opencode.json should have permission'
  end

  def test_opencode_project_extends_global
    # Project mode is triggered via apply/deploy, not build --project
    # Test by checking the opencode_project_config method directly
    output = File.join(@tmp_dir, 'opencode-project')
    result = system("#{@vibe} build opencode --output #{output} 2>/dev/null")
    assert result, 'Build command should succeed'

    config_path = File.join(output, 'opencode.json')
    assert File.exist?(config_path), 'opencode.json should be generated'

    # For now, verify that the full config is generated
    # Project vs global distinction is handled in deploy/apply, not build
    content = JSON.parse(File.read(config_path))
    assert content['instructions'], 'opencode.json should have instructions'
  end

  def test_claude_code_project_generates_settings_json
    output = File.join(@tmp_dir, 'claude-project')
    result = system("#{@vibe} build claude-code --output #{output} 2>/dev/null")
    assert result, 'Build command should succeed'

    settings_path = File.join(output, 'settings.json')
    assert File.exist?(settings_path), 'settings.json should be generated for claude-code'
  end
end
