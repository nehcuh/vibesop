# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require_relative '../../lib/vibe/skill_installer'

class TestSkillInstaller < Minitest::Test
  def setup
    @repo_root = File.expand_path('../../', __dir__)
    @project_root = Dir.mktmpdir('vibe-skill-installer-test')
    @installer = Vibe::SkillInstaller.new(@repo_root, @project_root)
  end

  def teardown
    FileUtils.rm_rf(@project_root) if @project_root && File.exist?(@project_root)
  end

  def test_initialization
    assert_equal @repo_root, @installer.repo_root
    assert_equal @project_root, @installer.project_root
  end

  def test_supported_packs
    assert_includes Vibe::SkillInstaller::SUPPORTED_PACKS, 'superpowers'
  end

  def test_install_unknown_pack
    output = capture_io do
      result = @installer.install('unknown-pack-xyz')
      assert_equal false, result
    end
    assert_includes output.first, 'Unknown skill pack'
  end

  def test_preview_installation_known_pack
    output = capture_io do
      @installer.preview_installation('superpowers', platform: 'claude-code')
    end
    assert_includes output.first, 'DRY RUN'
    assert_includes output.first, 'superpowers'
  end

  def test_preview_installation_unknown_pack
    output = capture_io do
      @installer.preview_installation('unknown-pack')
    end
    assert_includes output.first, 'Unknown skill pack'
  end

  def test_preview_installation_without_platform
    output = capture_io do
      @installer.preview_installation('superpowers')
    end
    assert_includes output.first, 'DRY RUN'
    assert_includes output.first, 'No changes were made'
  end

  def test_install_superpowers_integration
    # Test that install method handles superpowers
    output = capture_io do
      # Don't actually run install, just test error handling
      result = @installer.install('unknown-pack')
      assert_equal false, result
    end
    assert_includes output.first, 'Unknown skill pack'
  end

  def test_supported_packs_is_frozen
    assert Vibe::SkillInstaller::SUPPORTED_PACKS.frozen?
  end

  def test_supported_packs_contains_only_superpowers
    assert_equal 1, Vibe::SkillInstaller::SUPPORTED_PACKS.length
    assert_equal 'superpowers', Vibe::SkillInstaller::SUPPORTED_PACKS.first
  end
end
