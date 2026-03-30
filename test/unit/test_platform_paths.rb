# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../lib/vibe/platform_paths'
require 'fileutils'

class TestPlatformPaths < Minitest::Test
  def setup
    # Save original env vars
    @original_home = ENV['HOME']
    @original_userprofile = ENV['USERPROFILE']
    @original_vibe_home = ENV['VIBE_HOME']

    # Clear cached values
    Vibe::PlatformPaths.instance_variable_set(:@vibe_root, nil) if Vibe::PlatformPaths.instance_variable_defined?(:@vibe_root)
    Vibe::PlatformPaths.instance_variable_set(:@host_os, nil) if Vibe::PlatformPaths.instance_variable_defined?(:@host_os)
  end

  def teardown
    # Restore original env vars
    ENV['HOME'] = @original_home
    ENV['USERPROFILE'] = @original_userprofile
    ENV['VIBE_HOME'] = @original_vibe_home

    # Clear cached values
    Vibe::PlatformPaths.instance_variable_set(:@vibe_root, nil) if Vibe::PlatformPaths.instance_variable_defined?(:@vibe_root)
    Vibe::PlatformPaths.instance_variable_set(:@host_os, nil) if Vibe::PlatformPaths.instance_variable_defined?(:@host_os)
  end

  def test_vibe_root_with_vibe_home_env
    ENV['VIBE_HOME'] = '/custom/vibe'
    ENV['HOME'] = '/home/user'

    assert_equal '/custom/vibe', Vibe::PlatformPaths.vibe_root
  end

  def test_vibe_root_with_home_env
    ENV.delete('VIBE_HOME')
    ENV['HOME'] = '/home/user'

    result = Vibe::PlatformPaths.vibe_root
    assert result.end_with?('.vibe')
    assert result.include?('home/user')
  end

  def test_vibe_root_with_userprofile_env_windows
    ENV.delete('VIBE_HOME')
    ENV.delete('HOME')
    ENV['USERPROFILE'] = 'C:\\Users\\test'

    result = Vibe::PlatformPaths.vibe_root
    assert result.end_with?('.vibe')
    assert result.include?('Users')
  end

  def test_config_dir
    ENV['HOME'] = '/home/user'
    ENV.delete('VIBE_HOME')

    result = Vibe::PlatformPaths.config_dir
    assert result.end_with?('config')
    assert result.include?('.vibe')
  end

  def test_preference_file
    ENV['HOME'] = '/home/user'
    ENV.delete('VIBE_HOME')

    result = Vibe::PlatformPaths.preference_file
    assert result.end_with?('skill-preferences.yaml')
    assert result.include?('config')
  end

  def test_cache_dir
    ENV['HOME'] = '/home/user'
    ENV.delete('VIBE_HOME')

    result = Vibe::PlatformPaths.cache_dir
    assert result.end_with?('cache')
    assert result.include?('.vibe')
  end

  def test_platform_data_dir_claude_code
    ENV['HOME'] = '/home/user'

    result = Vibe::PlatformPaths.platform_data_dir(:claude_code)
    assert result.end_with?('platforms/claude_code')
    assert result.include?('.vibe')
  end

  def test_platform_data_dir_opencode
    ENV['HOME'] = '/home/user'

    result = Vibe::PlatformPaths.platform_data_dir(:opencode)
    assert result.end_with?('platforms/opencode')
    assert result.include?('.vibe')
  end

  def test_target_config_dir_claude_code
    ENV['HOME'] = '/home/user'

    result = Vibe::PlatformPaths.target_config_dir(:claude_code)
    assert result.end_with?('.claude')
    assert result.include?('home/user')
  end

  def test_target_config_dir_opencode
    ENV['HOME'] = '/home/user'

    result = Vibe::PlatformPaths.target_config_dir(:opencode)
    assert result.end_with?('.opencode')
    assert result.include?('home/user')
  end

  def test_target_config_file_claude_code
    ENV['HOME'] = '/home/user'

    result = Vibe::PlatformPaths.target_config_file(:claude_code)
    assert result.end_with?('CLAUDE.md')
    assert result.include?('.claude')
  end

  def test_target_config_file_opencode
    ENV['HOME'] = '/home/user'

    result = Vibe::PlatformPaths.target_config_file(:opencode)
    assert result.end_with?('config.yaml')
    assert result.include?('.opencode')
  end

  def test_target_config_file_cursor
    ENV['HOME'] = '/home/user'

    result = Vibe::PlatformPaths.target_config_file(:cursor)
    assert result.end_with?('settings.json')
    assert result.include?('.cursor')
  end

  def test_norm_sep_windows_path
    path = 'C:\\Users\\test\\.vibe\\config'
    result = Vibe::PlatformPaths.norm_sep(path)

    assert_equal 'C:/Users/test/.vibe/config', result
    assert_includes result, '/'
    refute_includes result, '\\'
  end

  def test_norm_sep_unix_path
    path = '/home/user/.vibe/config'
    result = Vibe::PlatformPaths.norm_sep(path)

    assert_equal path, result
  end

  def test_root_path_unix
    assert Vibe::PlatformPaths.root_path?('/')
    refute Vibe::PlatformPaths.root_path?('/home')
  end

  def test_root_path_windows
    # Windows root paths: C:\ or C:/ format
    assert Vibe::PlatformPaths.root_path?('C:/'), 'C:/ should be root'
    assert Vibe::PlatformPaths.root_path?('D:/'), 'D:/ should be root'
    assert Vibe::PlatformPaths.root_path?('C:\\'), 'C:\\ (single backslash) should be root'

    # Non-root paths
    refute Vibe::PlatformPaths.root_path?('C:/Users'), 'C:/Users should not be root'
    refute Vibe::PlatformPaths.root_path?('D:/Users'), 'D:/Users should not be root'
  end

  def test_normalize_platform_name_claude_code_variants
    assert_equal :claude_code, Vibe::PlatformPaths.normalize_platform_name(:claude_code)
    assert_equal :claude_code, Vibe::PlatformPaths.normalize_platform_name('claude-code')
    assert_equal :claude_code, Vibe::PlatformPaths.normalize_platform_name(:claude)
  end

  def test_normalize_platform_name_other_platforms
    assert_equal :opencode, Vibe::PlatformPaths.normalize_platform_name(:opencode)
    assert_equal :cursor, Vibe::PlatformPaths.normalize_platform_name(:cursor)
    assert_equal :vscode, Vibe::PlatformPaths.normalize_platform_name(:vscode)
  end

  def test_host_os_detection
    result = Vibe::PlatformPaths.host_os

    assert [:windows, :macos, :linux].include?(result)
  end

  def test_windows_detection_on_windows
    RbConfig::CONFIG.stub :[], lambda { |key|
      case key
      when 'host_os' then 'mswin'
      else nil
      end
    } do
      # Clear cached value
      Vibe::PlatformPaths.instance_variable_set(:@host_os, nil)

      result = Vibe::PlatformPaths.host_os
      assert_equal :windows, result
      assert Vibe::PlatformPaths.windows?
    end
  end

  def test_windows_detection_on_unix
    RbConfig::CONFIG.stub :[], lambda { |key|
      case key
      when 'host_os' then 'linux'
      else nil
      end
    } do
      # Clear cached value
      Vibe::PlatformPaths.instance_variable_set(:@host_os, nil)

      result = Vibe::PlatformPaths.host_os
      assert_equal :linux, result
      refute Vibe::PlatformPaths.windows?
    end
  end

  def test_ensure_directories_exist_does_not_create_real_dirs_in_test
    # This test verifies the method can be called
    # We use a temp directory to avoid side effects
    temp_home = File.join(Dir.tmpdir, 'test_vibe_user')
    ENV['HOME'] = temp_home

    # Clear cached vibe_root
    Vibe::PlatformPaths.instance_variable_set(:@vibe_root, nil)

    # Call the method (will create temp dirs, that's ok)
    Vibe::PlatformPaths.ensure_directories_exist

    # Verify directories were created
    assert Dir.exist?(File.join(temp_home, '.vibe'))
    assert Dir.exist?(Vibe::PlatformPaths.config_dir)

    # Cleanup
    FileUtils.rm_rf(temp_home) if Dir.exist?(temp_home)
  end

  def test_target_config_dir_unknown_platform
    ENV['HOME'] = '/home/user'

    result = Vibe::PlatformPaths.target_config_dir(:unknown_platform)
    assert result.end_with?('.unknown_platform')
    assert result.include?('home/user')
  end

  def test_vibe_root_does_not_use_expand_path_tilde
    # This test verifies P011 fix: we don't use File.expand_path('~')
    # which ignores ENV['HOME'] changes

    # Set HOME after first call
    ENV['HOME'] = '/home/first'
    first_result = Vibe::PlatformPaths.vibe_root

    # Change HOME (this would be ignored by File.expand_path('~'))
    Vibe::PlatformPaths.instance_variable_set(:@vibe_root, nil)
    ENV['HOME'] = '/home/second'
    second_result = Vibe::PlatformPaths.vibe_root

    # Both should respect ENV['HOME'] (due to clearing @vibe_root)
    assert first_result.include?('home/first')
    assert second_result.include?('home/second')
  end
end
