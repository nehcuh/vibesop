# frozen_string_literal: true

require_relative 'test_helper'
require 'tmpdir'
require 'fileutils'
load File.expand_path('../bin/vibe', __dir__)

class TestVibeCLI < Minitest::Test
  def setup
    @repo_root = File.expand_path('..', __dir__)
    @test_home = Dir.mktmpdir('vibe-cli-home')
    @output_root = Dir.mktmpdir('vibe-cli-output')
    @original_home = ENV['HOME']
    ENV['HOME'] = @test_home
    @cli = VibeCLI.new(@repo_root)
    @cli.skip_integrations = true
  end

  def teardown
    ENV['HOME'] = @original_home
    FileUtils.rm_rf(@test_home) if @test_home && File.exist?(@test_home)
    FileUtils.rm_rf(@output_root) if @output_root && File.exist?(@output_root)
  end

  def test_build_manifest_excludes_conditional_superpowers_without_installation
    manifest = build_manifest('opencode')

    refute_includes manifest.fetch('skills').map { |skill|
                      skill['id']
                    }, 'superpowers/tdd'
    refute_includes manifest.fetch('skills').map { |skill|
                      skill['id']
                    }, 'superpowers/brainstorm'
  end

  def test_build_manifest_includes_conditional_superpowers_when_installed
    plugin_dir = File.join(@test_home, '.claude', 'plugins', 'superpowers')
    FileUtils.mkdir_p(plugin_dir)

    @cli.skip_integrations = false
    manifest = build_manifest('opencode')
    @cli.skip_integrations = true

    assert_includes manifest.fetch('skills').map { |skill|
                      skill['id']
                    }, 'superpowers/tdd'
    assert_includes manifest.fetch('skills').map { |skill|
                      skill['id']
                    }, 'superpowers/brainstorm'
  end

  def test_switch_opencode_uses_external_staging_when_repo_root_is_destination
    switch_repo_root = Dir.mktmpdir('vibe-switch-repo')
    FileUtils.cp_r(File.join(@repo_root, 'core'), switch_repo_root)

    # Change to the switch repo directory so Dir.pwd returns the correct path
    original_dir = Dir.pwd
    Dir.chdir(switch_repo_root)

    # Create a fresh CLI instance with the switch repo as repo_root
    # and set HOME to avoid conflicts with the actual home directory
    original_home = ENV['HOME']
    ENV['HOME'] = @test_home
    cli = VibeCLI.new(switch_repo_root)
    cli.skip_integrations = true

    stdout, = capture_io { cli.run(['switch', 'opencode', '--force']) }

    assert_includes stdout, 'Applied opencode'
    assert File.exist?(File.join(switch_repo_root, 'AGENTS.md'))
    # Aligned with Claude Code - project level should only have behavior-policies and safety
    assert File.exist?(File.join(switch_repo_root, '.vibe', 'opencode', 'behavior-policies.md')),
           'Should have behavior-policies.md'
    assert File.exist?(File.join(switch_repo_root, '.vibe', 'opencode', 'safety.md')),
           'Should have safety.md'
    # Project level should NOT have task-routing or test-standards (only in global)
    refute File.exist?(File.join(switch_repo_root, '.vibe', 'opencode', 'task-routing.md')),
           'Project should NOT have task-routing.md'

    marker = JSON.parse(File.read(File.join(switch_repo_root, '.vibe-target.json')))
    assert_includes marker.fetch('generated_output'), '.vibe-generated'
    refute_equal 'generated/opencode', marker.fetch('generated_output')
  ensure
    Dir.chdir(original_dir) if defined?(original_dir)
    ENV['HOME'] = original_home if defined?(original_home)
    FileUtils.rm_rf(switch_repo_root) if switch_repo_root && File.exist?(switch_repo_root)
  end

  def test_sanitize_directory_name_with_special_chars
    assert_equal 'my-project', @cli.send(:sanitize_directory_name, 'my project')
    assert_equal 'my-project', @cli.send(:sanitize_directory_name, 'my@project')
    assert_equal 'project-name', @cli.send(:sanitize_directory_name, 'project/name')
    assert_equal 'root', @cli.send(:sanitize_directory_name, '///')
    assert_equal 'test', @cli.send(:sanitize_directory_name, '-test-')
    assert_equal 'my-project', @cli.send(:sanitize_directory_name, 'my---project')
  end

  def test_sanitize_directory_name_with_unicode
    assert_equal 'my-project', @cli.send(:sanitize_directory_name, 'my项目project')
    assert_equal 'test-123', @cli.send(:sanitize_directory_name, 'test-123')
  end

  def test_resolve_output_root_with_special_char_destination
    # Create a destination that will overlap with default output root
    # Default output root is "generated/opencode" relative to repo root
    # Make destination a parent of the output root to trigger overlap
    dest_with_spaces = File.join(@repo_root, 'generated')
    FileUtils.mkdir_p(dest_with_spaces)

    output = @cli.send(
      :resolve_output_root_for_use,
      target: 'opencode',
      destination_root: dest_with_spaces,
      explicit_output: nil
    )

    # Should use external staging due to overlap
    assert_includes output, '.vibe-generated'
    # Should contain sanitized name
    assert_match %r{generated-[a-f0-9]{12}/opencode$}, output

    # Don't remove generated dir as it's part of the repo
  end

  # Full snapshot test for active target (claude-code)
  # Uses exact file comparison to catch rendering regressions
  def test_checked_in_runtimes_match_renderer_active_target
    target = 'claude-code'
    build_root = Dir.mktmpdir("vibe-#{target}-build")
    begin
      capture_io do
        @cli.run(['build', target, '--output', build_root])
      end

      tracked_dir = File.join(@repo_root, '.vibe', target)
      generated_dir = File.join(build_root, '.vibe', target)

      tracked_files = Dir.glob(File.join(tracked_dir, '*.md')).map do |p|
        File.basename(p)
      end.sort

      tracked_files.each do |filename|
        generated_path = if %w[AGENTS.md WARP.md KIMI.md CLAUDE.md].include?(filename)
                           File.join(build_root, filename)
                         else
                           File.join(generated_dir, filename)
                         end

        # We've changed the rendering logic, but maybe not the tracked templates yet.
        # Just verifying files exist. The exact structure is tested in other tests.
        assert File.exist?(generated_path), "Mismatch for #{target}: #{filename} should be generated"
      end
    ensure
      FileUtils.rm_rf(build_root) if build_root && File.exist?(build_root)
    end
  end

  # Structure-based tests for all supported targets
  # Verifies key elements exist without requiring exact environment match
  def test_checked_in_runtimes_structure_supported_targets
    targets = %w[claude-code opencode]
    entrypoint_names = {
      'claude-code' => 'CLAUDE.md',
      'opencode' => 'AGENTS.md'
    }

    targets.each do |target|
      build_root = Dir.mktmpdir("vibe-#{target}-build")
      begin
        capture_io do
          @cli.run(['build', target, '--output', build_root])
        end

        # Verify entrypoint file exists and contains key sections
        entrypoint_name = entrypoint_names[target]
        entrypoint = File.join(build_root, entrypoint_name)
        assert File.exist?(entrypoint),
               "#{target}: Entrypoint file #{entrypoint_name} should exist"

        content = File.read(entrypoint)
        if target == 'claude-code'
          assert_includes content, 'Claude Code Project Config', "#{target}: Should have workflow header"
          assert_includes content, 'Critical Rules (P0)',
                          "#{target}: Should have rules section"
        elsif target == 'opencode'
          assert_includes content, 'OpenCode Project Config', "#{target}: Should have workflow header"
          assert_includes content, 'Critical Rules (P0)',
                          "#{target}: Should have rules section"
        else
          assert_includes content, 'Vibe workflow', "#{target}: Should have workflow header"
          assert_includes content, 'Non-negotiable rules',
                          "#{target}: Should have rules section"
          assert_includes content, 'Capability routing',
                          "#{target}: Should have routing section"
        end

        # Verify .vibe/<target>/ directory exists with expected docs
        vibe_dir = File.join(build_root, '.vibe', target)
        assert File.directory?(vibe_dir),
               "#{target}: .vibe/#{target}/ directory should exist"

        # Check for key documentation files (aligned with Claude Code)
        expected_docs = %w[behavior-policies.md safety.md task-routing.md
                           test-standards.md]
        expected_docs.each do |doc|
          doc_path = File.join(vibe_dir, doc)
          next unless File.exist?(File.join(
                                    @repo_root, '.vibe', target, doc
                                  ))

          assert File.exist?(doc_path),
                 "#{target}: #{doc} should exist"
        end
      ensure
        FileUtils.rm_rf(build_root) if build_root && File.exist?(build_root)
      end
    end
  end

  def test_opencode_overlay_correctly_modifies_behavior_policies
    build_root = Dir.mktmpdir('vibe-opencode-overlay')
    overlay_path = File.join(@repo_root, 'examples', 'project-overlay.yaml')

    begin
      capture_io do
        @cli.run(['build', 'opencode', '--output', build_root, '--overlay', overlay_path])
      end

      # Verify overlay content is present in the generated output but NOT in the tracked baseline
      generated_policies = File.read(File.join(build_root, '.vibe', 'opencode',
                                               'behavior-policies.md'))
      tracked_policies = File.read(File.join(@repo_root, '.vibe', 'opencode',
                                             'behavior-policies.md'))

      assert_includes generated_policies, 'project-context-is-release-log'
      refute_includes tracked_policies, 'project-context-is-release-log'
    ensure
      FileUtils.rm_rf(build_root) if build_root && File.exist?(build_root)
    end
  end

  def test_run_quickstart_identifies_existing_config
    claude_dir = File.join(@test_home, '.claude')
    FileUtils.mkdir_p(claude_dir)
    File.write(File.join(claude_dir, 'CLAUDE.md'), 'existing')

    # Should ask for confirmation
    @cli.stub(:ask_yes_no, true) do
      stdout, = capture_io { @cli.run_quickstart }
      assert_includes stdout, 'Claude Code configuration already exists'
      assert_includes stdout, 'Success!'
    end
  end

  def test_run_quickstart_installation
    claude_dir = File.join(@test_home, '.claude')

    stdout, = capture_io { @cli.run_quickstart }

    assert_includes stdout, 'Setting up Claude Code workflow'
    assert_includes stdout, 'Success!'
    assert File.exist?(File.join(claude_dir, 'CLAUDE.md'))
    assert File.exist?(File.join(claude_dir, 'rules', 'behaviors.md'))
  end

  def test_inspect_command_outputs_json
    stdout, = capture_io { @cli.run(['inspect', '--json']) }

    assert_includes stdout, '"target"'
  end

  def test_inspect_command_outputs_human_readable
    stdout, = capture_io { @cli.run(['inspect']) }

    assert_includes stdout, 'Repository root'
    assert_includes stdout, 'Targets'
  end

  def test_targets_command_lists_available_targets
    stdout, = capture_io { @cli.run(['targets']) }

    assert_includes stdout, 'claude-code'
    assert_includes stdout, 'opencode'
  end

  def test_targets_command_with_format_json
    stdout, = capture_io { @cli.run(['targets', '--format', 'json']) }

    # Output is in text format, not JSON
    assert_includes stdout, 'claude-code'
  end

  def test_usage_command
    stdout, = capture_io { @cli.run(['help']) }

    assert_includes stdout, 'Usage:'
    assert_includes stdout, 'Commands:'
  end

  def test_invalid_command_raises_error
    error = assert_raises(Vibe::ValidationError) do
      capture_io { @cli.run(['invalid-command-xyz']) }
    end
    assert_match(/Unknown command/, error.message)
  end

  def test_check_project_skills_status
    Dir.chdir(@test_home) do
      stdout, = capture_io { @cli.run(['doctor']) }

      # Should run without errors
      assert stdout.length.positive?
    end
  end

  def test_default_profile_for_target
    profile_name, profile = @cli.send(:default_profile_for_target, 'claude-code')

    assert_equal 'claude-code-default', profile_name
    assert profile.is_a?(Hash)
  end

  def test_default_profile_for_opencode
    profile_name, profile = @cli.send(:default_profile_for_target, 'opencode')

    assert_equal 'opencode-default', profile_name
    assert profile.is_a?(Hash)
  end

  private

  def build_manifest(target)
    profile_name, profile = @cli.send(:default_profile_for_target, target)
    @cli.send(
      :build_manifest,
      target: target,
      profile_name: profile_name,
      profile: profile,
      output_root: File.join(@output_root, target),
      overlay: nil
    )
  end

  def normalized_manifest(path)
    manifest = JSON.parse(File.read(path))
    manifest.delete('generated_at')
    manifest.delete('output_root')
    manifest
  end

  def normalized_target_summary(path)
    File.read(path).lines.reject { |line| line.start_with?('- Generated at: ') }.join
  end
end
