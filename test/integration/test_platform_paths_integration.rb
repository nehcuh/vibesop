# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../lib/vibe/platform_paths'
require 'fileutils'
require 'tempfile'

class TestPlatformPathsIntegration < Minitest::Test
  def setup
    @original_home = ENV['HOME']
    @original_userprofile = ENV['USERPROFILE']
    @original_vibe_home = ENV['VIBE_HOME']
    @temp_dir = Dir.mktmpdir

    # Clear cached values
    Vibe::PlatformPaths.instance_variable_set(:@vibe_root, nil) if Vibe::PlatformPaths.instance_variable_defined?(:@vibe_root)
  end

  def teardown
    ENV['HOME'] = @original_home
    ENV['USERPROFILE'] = @original_userprofile
    ENV['VIBE_HOME'] = @original_vibe_home

    Vibe::PlatformPaths.instance_variable_set(:@vibe_root, nil) if Vibe::PlatformPaths.instance_variable_defined?(:@vibe_root)

    FileUtils.rm_rf(@temp_dir) if Dir.exist?(@temp_dir)
  end

  def test_complete_directory_structure_creation
    ENV['HOME'] = @temp_dir
    Vibe::PlatformPaths.instance_variable_set(:@vibe_root, nil)

    # Ensure all directories exist
    Vibe::PlatformPaths.ensure_directories_exist

    # Verify structure
    assert Dir.exist?(Vibe::PlatformPaths.vibe_root), "Vibe root should exist"
    assert Dir.exist?(Vibe::PlatformPaths.config_dir), "Config dir should exist"
    assert Dir.exist?(Vibe::PlatformPaths.cache_dir), "Cache dir should exist"
    assert Dir.exist?(File.join(Vibe::PlatformPaths.vibe_root, 'platforms')), "Platforms dir should exist"
  end

  def test_preference_file_path_with_vibe_home
    custom_vibe = File.join(@temp_dir, 'custom_vibe')
    ENV['VIBE_HOME'] = custom_vibe
    Vibe::PlatformPaths.instance_variable_set(:@vibe_root, nil)

    expected = File.join(custom_vibe, 'config', 'skill-preferences.yaml')
    assert_equal expected, Vibe::PlatformPaths.preference_file
  end

  def test_preference_file_path_without_vibe_home
    ENV['VIBE_HOME'] = nil
    ENV['HOME'] = @temp_dir
    Vibe::PlatformPaths.instance_variable_set(:@vibe_root, nil)

    expected = File.join(@temp_dir, '.vibe', 'config', 'skill-preferences.yaml')
    assert_equal expected, Vibe::PlatformPaths.preference_file
  end

  def test_cross_platform_paths_windows_simulation
    # Simulate Windows environment
    ENV.delete('VIBE_HOME')
    ENV.delete('HOME')
    ENV['USERPROFILE'] = 'C:\\Users\\TestUser'

    Vibe::PlatformPaths.instance_variable_set(:@vibe_root, nil)

    # Should use USERPROFILE on Windows
    vibe_root = Vibe::PlatformPaths.vibe_root
    assert vibe_root.include?('Users'), "Should include Users directory"
    assert vibe_root.end_with?('.vibe'), "Should end with .vibe"

    # Target config dirs should work
    claude_dir = Vibe::PlatformPaths.target_config_dir(:claude_code)
    assert claude_dir.include?('Users'), "Should use home directory"
    assert claude_dir.end_with?('.claude'), "Should end with .claude"
  end

  def test_cross_platform_paths_unix_simulation
    # Simulate Unix environment
    ENV.delete('VIBE_HOME')
    ENV.delete('USERPROFILE')
    ENV['HOME'] = @temp_dir

    Vibe::PlatformPaths.instance_variable_set(:@vibe_root, nil)

    # Should use HOME on Unix
    vibe_root = Vibe::PlatformPaths.vibe_root
    assert vibe_root.include?(@temp_dir), "Should include temp_dir"
    assert vibe_root.end_with?('.vibe'), "Should end with .vibe"

    # Target config dirs should work
    claude_dir = Vibe::PlatformPaths.target_config_dir(:claude_code)
    assert claude_dir.include?(@temp_dir), "Should use home directory"
    assert claude_dir.end_with?('.claude'), "Should end with .claude"
  end

  def test_platform_specific_data_isolation
    ENV['HOME'] = @temp_dir
    Vibe::PlatformPaths.instance_variable_set(:@vibe_root, nil)

    claude_data = Vibe::PlatformPaths.platform_data_dir(:claude_code)
    opencode_data = Vibe::PlatformPaths.platform_data_dir(:opencode)

    # Should be in different directories
    refute_equal claude_data, opencode_data, "Different platforms should have different data dirs"

    # Both should be under vibe_root/platforms
    assert claude_data.include?('platforms/claude_code'), "Claude Code data should be in platforms/claude_code"
    assert opencode_data.include?('platforms/opencode'), "OpenCode data should be in platforms/opencode"
  end

  def test_multiple_platforms_can_reference_same_preferences
    ENV['HOME'] = @temp_dir
    Vibe::PlatformPaths.instance_variable_set(:@vibe_root, nil)

    # All platforms should reference the same preference file
    pref_file = Vibe::PlatformPaths.preference_file

    # Each platform has its own config dir
    claude_dir = Vibe::PlatformPaths.target_config_dir(:claude_code)
    opencode_dir = Vibe::PlatformPaths.target_config_dir(:opencode)
    cursor_dir = Vibe::PlatformPaths.target_config_dir(:cursor)

    # All different
    refute_equal claude_dir, opencode_dir
    refute_equal claude_dir, cursor_dir
    refute_equal opencode_dir, cursor_dir

    # But all reference same preference file
    assert_equal(pref_file, Vibe::PlatformPaths.preference_file)
  end

  def test_path_normalization_across_platforms
    # Test norm_sep works for both Windows and Unix paths
    unix_path = '/home/user/.vibe/config'
    windows_path = 'C:\\Users\\user\\.vibe\\config'

    unix_normalized = Vibe::PlatformPaths.norm_sep(unix_path)
    windows_normalized = Vibe::PlatformPaths.norm_sep(windows_path)

    # Both should use forward slashes
    assert_includes unix_normalized, '/'
    refute_includes unix_normalized, '\\'

    assert_includes windows_normalized, '/'
    refute_includes windows_normalized, '\\'
  end

  def test_platform_name_normalization
    # Various formats should normalize correctly
    assert_equal :claude_code, Vibe::PlatformPaths.normalize_platform_name(:claude_code)
    assert_equal :claude_code, Vibe::PlatformPaths.normalize_platform_name('claude-code')
    assert_equal :claude_code, Vibe::PlatformPaths.normalize_platform_name('claude')
    assert_equal :opencode, Vibe::PlatformPaths.normalize_platform_name('opencode')
  end

  def test_actual_file_creation_workflow
    ENV['HOME'] = @temp_dir
    Vibe::PlatformPaths.instance_variable_set(:@vibe_root, nil)

    # Simulate actual usage: create preference file
    require 'yaml'
    pref_file = Vibe::PlatformPaths.preference_file

    # Ensure directory exists
    FileUtils.mkdir_p(File.dirname(pref_file))

    # Create a sample preference file
    sample_config = {
      'version' => 1,
      'intent_preferences' => [],
      'explicit_rules' => []
    }

    File.write(pref_file, YAML.dump(sample_config))

    # Verify file exists at expected location
    assert File.exist?(pref_file), "Preference file should exist"
    assert_includes pref_file, '.vibe/config', "Should be in .vipe/config directory"

    # Verify content
    loaded = YAML.load_file(pref_file)
    assert_equal 1, loaded['version']
  end

  def test_host_os_detection
    os = Vibe::PlatformPaths.host_os

    # Should be one of the supported OSes
    assert [:windows, :macos, :linux].include?(os), "Host OS should be recognized"

    # windows? method should match
    assert_equal os == :windows, Vibe::PlatformPaths.windows?
  end
end
