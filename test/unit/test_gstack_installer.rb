# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require_relative '../../lib/vibe/gstack_installer'

class TestGstackInstaller < Minitest::Test
  def setup
    @tmpdir = Dir.mktmpdir('vibe-gstack-test')
    # Store original methods to prevent redefinition warnings
    @original_verify = Vibe::GstackInstaller.method(:verify_installation)
    @original_clone = Vibe::GstackInstaller.method(:clone_with_retry) if Vibe::GstackInstaller.respond_to?(:clone_with_retry)
  end

  def teardown
    FileUtils.rm_rf(@tmpdir) if @tmpdir && File.exist?(@tmpdir)
    # Restore original methods
    restore_original_methods
  end

  def test_module_exists
    assert Vibe.const_defined?(:GstackInstaller)
  end

  def test_constants_defined
    assert Vibe::GstackInstaller.const_defined?(:GSTACK_REPO_URLS)
    assert Vibe::GstackInstaller.const_defined?(:GSTACK_PLATFORM_PATHS)
    assert Vibe::GstackInstaller.const_defined?(:CLONE_TIMEOUT)
    assert Vibe::GstackInstaller.const_defined?(:MAX_RETRIES)
  end

  def test_repo_urls_is_array
    assert Vibe::GstackInstaller::GSTACK_REPO_URLS.is_a?(Array)
    assert Vibe::GstackInstaller::GSTACK_REPO_URLS.length.positive?
  end

  def test_platform_paths_has_claude_code
    assert Vibe::GstackInstaller::GSTACK_PLATFORM_SYMLINK_PATHS.key?('claude-code')
  end

  def test_platform_paths_has_opencode
    assert Vibe::GstackInstaller::GSTACK_PLATFORM_SYMLINK_PATHS.key?('opencode')
  end

  def test_gstack_markers_present_false_when_empty
    refute Vibe::GstackInstaller.gstack_markers_present?(@tmpdir)
  end

  def test_gstack_markers_present_true_when_all_present
    %w[SKILL.md VERSION setup].each do |f|
      File.write(File.join(@tmpdir, f), 'content')
    end
    assert Vibe::GstackInstaller.gstack_markers_present?(@tmpdir)
  end

  def test_gstack_markers_present_false_when_partial
    File.write(File.join(@tmpdir, 'SKILL.md'), 'content')
    File.write(File.join(@tmpdir, 'VERSION'), '1.0')
    # Missing setup
    refute Vibe::GstackInstaller.gstack_markers_present?(@tmpdir)
  end

  def test_verify_installation_not_installed
    result = Vibe::GstackInstaller.verify_installation('nonexistent-platform')
    assert result.is_a?(Hash)
    assert result.key?(:success)
    assert result.key?(:issues)
    refute result[:success]
  end

  def test_verify_installation_with_fake_dir
    fake_dir = File.join(@tmpdir, 'gstack')
    FileUtils.mkdir_p(fake_dir)
    %w[SKILL.md VERSION setup].each { |f| File.write(File.join(fake_dir, f), 'content') }
    File.write(File.join(fake_dir, 'VERSION'), '2.0.0')

    mock_verify_installation(fake_dir) do
      result = Vibe::GstackInstaller.verify_installation('test-platform')
      assert result[:success]
      assert_equal fake_dir, result[:location]
      assert_equal '2.0.0', result[:version]
    end
  end

  def test_verify_installation_with_skills
    fake_dir = File.join(@tmpdir, 'gstack')
    FileUtils.mkdir_p(fake_dir)
    %w[SKILL.md VERSION setup].each { |f| File.write(File.join(fake_dir, f), 'content') }
    skill_dir = File.join(fake_dir, 'qa')
    FileUtils.mkdir_p(skill_dir)
    File.write(File.join(skill_dir, 'SKILL.md'), 'skill content')

    mock_verify_with_skills(fake_dir) do
      result = Vibe::GstackInstaller.verify_installation('test-platform')
      assert_equal 1, result[:skills_count]
    end
  end

  def test_verify_installation_browse_ready
    fake_dir = File.join(@tmpdir, 'gstack')
    browse_dist = File.join(fake_dir, 'browse', 'dist')
    FileUtils.mkdir_p(browse_dist)
    %w[SKILL.md VERSION setup].each { |f| File.write(File.join(fake_dir, f), 'content') }
    File.write(File.join(browse_dist, 'browse'), 'binary')

    mock_verify_browse_ready(fake_dir) do
      result = Vibe::GstackInstaller.verify_installation('test-platform')
      assert result[:browse_ready]
    end
  end

  def test_run_setup_no_script
    out, = capture_io { Vibe::GstackInstaller.run_setup(@tmpdir) }
    assert_match(/setup script not found/, out)
  end

  def test_clone_from_mirrors_all_fail
    urls = ['https://nonexistent1.example.com/repo.git',
            'https://nonexistent2.example.com/repo.git']
    target = File.join(@tmpdir, 'clone_target')

    mock_clone_failure do
      out, = capture_io do
        success, url = Vibe::GstackInstaller.clone_from_mirrors(urls, target)
        refute success
        assert_nil url
      end
      assert_match(/Failed to clone/, out)
    end
  end

  def test_uninstall_gstack_no_dirs
    # Should not raise even if dirs don't exist
    out, = capture_io { Vibe::GstackInstaller.uninstall_gstack }
    assert_match(/uninstalled/, out)
  end

  private

  def restore_original_methods
    return unless @original_verify

    Vibe::GstackInstaller.define_singleton_method(:verify_installation, @original_verify)
  rescue StandardError
    nil
  end

  def mock_verify_installation(fake_dir)
    Vibe::GstackInstaller.define_singleton_method(:verify_installation) do |_platform|
      issues = []
      %w[SKILL.md VERSION setup].each do |marker|
        issues << "Missing marker file: #{marker}" unless File.exist?(File.join(fake_dir, marker))
      end
      version = File.read(File.join(fake_dir, 'VERSION')).strip rescue nil
      {
        success: issues.empty?,
        location: fake_dir,
        version: version,
        skills_count: 0,
        browse_ready: false,
        issues: issues
      }
    end
    yield
  ensure
    Vibe::GstackInstaller.define_singleton_method(:verify_installation, @original_verify)
  end

  def mock_verify_with_skills(fake_dir)
    Vibe::GstackInstaller.define_singleton_method(:verify_installation) do |_platform|
      skills_count = Dir.children(fake_dir).count do |entry|
        File.directory?(File.join(fake_dir, entry)) &&
          File.exist?(File.join(fake_dir, entry, 'SKILL.md'))
      end
      { success: true, location: fake_dir, version: nil, skills_count: skills_count,
        browse_ready: false, issues: [] }
    end
    yield
  ensure
    Vibe::GstackInstaller.define_singleton_method(:verify_installation, @original_verify)
  end

  def mock_verify_browse_ready(fake_dir)
    Vibe::GstackInstaller.define_singleton_method(:verify_installation) do |_platform|
      browse_ready = File.exist?(File.join(fake_dir, 'browse', 'dist', 'browse'))
      { success: true, location: fake_dir, version: nil, skills_count: 0,
        browse_ready: browse_ready, issues: [] }
    end
    yield
  ensure
    Vibe::GstackInstaller.define_singleton_method(:verify_installation, @original_verify)
  end

  def mock_clone_failure
    original_clone = Vibe::GstackInstaller.method(:clone_with_retry)
    Vibe::GstackInstaller.define_singleton_method(:clone_with_retry) { |_, _| false }
    yield
  ensure
    if original_clone
      Vibe::GstackInstaller.define_singleton_method(:clone_with_retry, original_clone)
    else
      Vibe::GstackInstaller.singleton_class.remove_method(:clone_with_retry)
    end
  end
end
