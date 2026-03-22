# frozen_string_literal: true

require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require_relative '../../lib/vibe/path_safety'

class PathSafetyTestHost
  include Vibe::PathSafety
  include Vibe::Utils

  attr_accessor :repo_root

  def initialize(repo_root)
    @repo_root = repo_root
  end
end

class TestPathSafety < Minitest::Test
  def setup
    @repo_root = File.expand_path('../../', __dir__)
    @host = PathSafetyTestHost.new(@repo_root)
  end

  def test_module_exists
    assert Vibe.const_defined?(:PathSafety)
  end

  def test_module_is_a_module
    assert Vibe::PathSafety.is_a?(Module)
  end

  def test_unsafe_output_paths_constant
    assert Vibe::PathSafety.const_defined?(:UNSAFE_OUTPUT_PATHS)
    unsafe = Vibe::PathSafety::UNSAFE_OUTPUT_PATHS
    assert_includes unsafe, '/'
    assert_includes unsafe, '/tmp'
  end

  def test_safe_var_prefixes_constant
    assert Vibe::PathSafety.const_defined?(:SAFE_VAR_PREFIXES)
    safe = Vibe::PathSafety::SAFE_VAR_PREFIXES
    assert_includes safe, '/var/folders/'
  end

  def test_max_normalize_depth_constant
    assert Vibe::PathSafety.const_defined?(:MAX_NORMALIZE_DEPTH)
    assert Vibe::PathSafety::MAX_NORMALIZE_DEPTH.positive?
  end

  def test_ensure_safe_output_path_with_safe_path
    safe_path = Dir.mktmpdir('vibe-safe-path')
    begin
      # Should not raise for safe path
      result = @host.ensure_safe_output_path!(safe_path)
      assert_nil result
    ensure
      FileUtils.rm_rf(safe_path) if File.exist?(safe_path)
    end
  end

  def test_ensure_safe_output_path_raises_on_root
    error = assert_raises(Vibe::PathSafetyError) do
      @host.ensure_safe_output_path!('/')
    end
    assert_match(%r{overlaps with /}, error.message)
  end

  def test_ensure_safe_output_path_raises_on_tmp
    error = assert_raises(Vibe::PathSafetyError) do
      @host.ensure_safe_output_path!('/tmp')
    end
    assert_match(%r{overlaps with /tmp}, error.message)
  end

  def test_ensure_safe_output_path_raises_on_home
    home = Dir.home
    error = assert_raises(Vibe::PathSafetyError) do
      @host.ensure_safe_output_path!(home)
    end
    assert_match(/overlaps with \$HOME/, error.message)
  end

  def test_ensure_safe_output_path_allows_safe_var_subdirectories
    skip 'macOS-only test' unless RbConfig::CONFIG['host_os'] =~ /darwin/

    # /var/folders/* paths should be allowed
    safe_var_path = '/var/folders/test123'
    # This should not raise on macOS
    @host.ensure_safe_output_path!(safe_var_path)
  end

  def test_ensure_no_path_overlap_with_same_paths
    dir = Dir.mktmpdir('vibe-overlap-test')
    error = assert_raises(Vibe::PathSafetyError) do
      @host.ensure_no_path_overlap!(dir, dir)
    end
    assert_match(/same path/, error.message)
  ensure
    FileUtils.rm_rf(dir) if File.exist?(dir)
  end

  def test_ensure_no_path_overlap_with_overlapping_paths
    parent = Dir.mktmpdir('vibe-parent')
    child = File.join(parent, 'child')

    error = assert_raises(Vibe::PathSafetyError) do
      @host.ensure_no_path_overlap!(parent, child)
    end
    assert_match(/overlap/, error.message)
  ensure
    FileUtils.rm_rf(parent) if File.exist?(parent)
  end

  def test_ensure_no_path_overlap_with_separate_paths
    dir1 = Dir.mktmpdir('vibe-dir1')
    dir2 = Dir.mktmpdir('vibe-dir2')

    # Should not raise for separate paths
    result = @host.ensure_no_path_overlap!(dir1, dir2)
    assert_nil result
  ensure
    FileUtils.rm_rf(dir1) if File.exist?(dir1)
    FileUtils.rm_rf(dir2) if File.exist?(dir2)
  end

  def test_paths_overlap_with_parent_child
    parent = '/tmp/test'
    child = '/tmp/test/subdir'

    assert @host.paths_overlap?(parent, child)
    assert @host.paths_overlap?(child, parent)
  end

  def test_paths_overlap_with_siblings
    path1 = '/tmp/test1'
    path2 = '/tmp/test2'

    refute @host.paths_overlap?(path1, path2)
  end

  def test_paths_overlap_with_same_path
    path = '/tmp/test'
    # paths_overlap? checks for parent/child relationships, not equality
    # Same path is not considered overlapping in the traditional sense
    refute @host.paths_overlap?(path, path)
  end

  def test_paths_overlap_with_unrelated_paths
    path1 = '/tmp/test'
    path2 = '/var/test'

    refute @host.paths_overlap?(path1, path2)
  end

  def test_normalize_path_with_absolute_path
    Dir.mktmpdir do |tmpdir|
      result = @host.send(:normalize_path, tmpdir)
      assert_equal File.realpath(tmpdir), result
    end
  end

  def test_normalize_path_with_nonexistent_path
    nonexistent = '/tmp/nonexistent_test_path_12345'
    result = @host.send(:normalize_path, nonexistent)
    # On macOS, /tmp is a symlink to /private/tmp, and normalize_path
    # resolves symlinks in existing parent directories
    # Just verify it's an absolute path starting with /
    assert_match(%r{^/.*nonexistent_test_path_12345$}, result)
  end

  def test_normalize_path_resolves_symlinks
    skip 'Requires existing symlink to test'
    # This would require creating a symlink and testing normalization
  end

  def test_staged_file_paths_with_empty_directory
    Dir.mktmpdir do |tmpdir|
      result = @host.send(:staged_file_paths, tmpdir)
      assert_equal [], result
    end
  end

  def test_staged_file_paths_with_files
    Dir.mktmpdir do |tmpdir|
      File.write(File.join(tmpdir, 'file1.txt'), 'content1')
      File.write(File.join(tmpdir, 'file2.txt'), 'content2')

      result = @host.send(:staged_file_paths, tmpdir).sort
      assert_equal ['file1.txt', 'file2.txt'], result
    end
  end

  def test_staged_file_paths_with_nested_directories
    Dir.mktmpdir do |tmpdir|
      subdir = File.join(tmpdir, 'subdir')
      FileUtils.mkdir_p(subdir)
      File.write(File.join(tmpdir, 'file1.txt'), 'content1')
      File.write(File.join(subdir, 'file2.txt'), 'content2')

      result = @host.send(:staged_file_paths, tmpdir).sort
      assert_equal ['file1.txt', 'subdir/file2.txt'], result
    end
  end

  def test_copy_tree_contents_copies_files
    Dir.mktmpdir do |source|
      Dir.mktmpdir do |dest|
        File.write(File.join(source, 'file1.txt'), 'content1')
        File.write(File.join(source, 'file2.txt'), 'content2')

        @host.send(:copy_tree_contents, source, dest)

        assert File.exist?(File.join(dest, 'file1.txt'))
        assert File.exist?(File.join(dest, 'file2.txt'))
        assert_equal 'content1', File.read(File.join(dest, 'file1.txt'))
        assert_equal 'content2', File.read(File.join(dest, 'file2.txt'))
      end
    end
  end

  def test_copy_tree_contents_copies_directories
    Dir.mktmpdir do |source|
      Dir.mktmpdir do |dest|
        subdir = File.join(source, 'subdir')
        FileUtils.mkdir_p(subdir)
        File.write(File.join(subdir, 'file.txt'), 'content')

        @host.send(:copy_tree_contents, source, dest)

        assert Dir.exist?(File.join(dest, 'subdir'))
        assert File.exist?(File.join(dest, 'subdir', 'file.txt'))
      end
    end
  end

  def test_write_marker_creates_file
    Dir.mktmpdir do |tmpdir|
      marker_path = File.join(tmpdir, '.vibe-manifest.json')
      manifest = {
        'target' => 'claude-code',
        'profile' => 'default',
        'profile_mapping' => {},
        'overlay' => nil,
        'policies' => []
      }

      @host.send(:write_marker,
                 marker_path,
                 destination_root: '/tmp/dest',
                 manifest: manifest,
                 output_root: '/tmp/output',
                 mode: 'init')

      assert File.exist?(marker_path)

      content = JSON.parse(File.read(marker_path))
      assert_equal 5, content['schema_version']
      assert_equal 'init', content['mode']
      assert_equal 'claude-code', content['target']
    end
  end

  def test_enforce_safe_destination_with_no_conflicts
    Dir.mktmpdir do |staging|
      Dir.mktmpdir do |dest|
        # No conflicts - should not raise
        result = @host.send(:enforce_safe_destination!, staging, dest, false)
        assert_nil result
      end
    end
  end

  def test_enforce_safe_destination_with_conflicts
    Dir.mktmpdir do |staging|
      Dir.mktmpdir do |dest|
        # Create a file in both staging and destination
        File.write(File.join(staging, 'conflict.txt'), 'staging')
        File.write(File.join(dest, 'conflict.txt'), 'dest')

        error = assert_raises(Vibe::PathSafetyError) do
          @host.send(:enforce_safe_destination!, staging, dest, false)
        end

        assert_match(/already contains .* generated path/, error.message)
        assert_equal 1, error.context[:conflict_count]
      end
    end
  end

  def test_enforce_safe_destination_with_force_skips_check
    Dir.mktmpdir do |staging|
      Dir.mktmpdir do |dest|
        # Create conflicts
        File.write(File.join(staging, 'conflict.txt'), 'staging')
        File.write(File.join(dest, 'conflict.txt'), 'dest')

        # Should not raise with force=true
        result = @host.send(:enforce_safe_destination!, staging, dest, true)
        assert_nil result
      end
    end
  end

  def test_module_has_required_methods
    instance_methods = Vibe::PathSafety.instance_methods(false)

    required_methods = %i[
      ensure_safe_output_path!
      ensure_no_path_overlap!
      paths_overlap?
    ]

    required_methods.each do |method|
      assert instance_methods.include?(method), "Module should have #{method} method"
    end

    # Check that private methods exist in the host class
    private_methods = %i[staged_file_paths copy_tree_contents]
    private_methods.each do |method|
      assert @host.respond_to?(method, true), "Module should have #{method} method"
    end
  end
end
