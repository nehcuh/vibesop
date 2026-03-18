# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "fileutils"
require_relative "../../lib/vibe/tdd_enforcer"

class TestTddEnforcer < Minitest::Test
  def setup
    @dir = Dir.mktmpdir
    @enforcer = Vibe::TddEnforcer.new(@dir)
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  def touch(path)
    full = File.join(@dir, path)
    FileUtils.mkdir_p(File.dirname(full))
    FileUtils.touch(full)
  end

  # ── impl file detection ───────────────────────────────────────────────────────

  def test_not_impl_file_for_yaml
    result = @enforcer.check("config/settings.yaml")
    assert_equal :not_impl_file, result[:status]
  end

  def test_not_impl_file_for_markdown
    result = @enforcer.check("README.md")
    assert_equal :not_impl_file, result[:status]
  end

  # ── test file detection ───────────────────────────────────────────────────────

  def test_skips_test_files
    result = @enforcer.check("test/unit/test_foo.rb")
    assert_equal :skipped, result[:status]
  end

  def test_skips_spec_files
    result = @enforcer.check("spec/lib/foo_spec.rb")
    assert_equal :skipped, result[:status]
  end

  # ── missing tests ─────────────────────────────────────────────────────────────

  def test_missing_when_no_test_file
    touch("lib/vibe/foo.rb")
    result = @enforcer.check("lib/vibe/foo.rb")
    assert_equal :missing_tests, result[:status]
    refute_nil result[:test_candidates]
    refute_empty result[:test_candidates]
  end

  def test_missing_for_python_file
    touch("src/utils/helper.py")
    result = @enforcer.check("src/utils/helper.py")
    assert_equal :missing_tests, result[:status]
  end

  # ── ok when test exists ───────────────────────────────────────────────────────

  def test_ok_when_minitest_file_exists
    touch("lib/vibe/bar.rb")
    touch("test/unit/test_bar.rb")
    result = @enforcer.check("lib/vibe/bar.rb")
    assert_equal :ok, result[:status]
    assert_equal "test/unit/test_bar.rb", result[:found_test]
  end

  def test_ok_when_rspec_file_exists
    touch("lib/vibe/baz.rb")
    touch("spec/vibe/baz_spec.rb")
    result = @enforcer.check("lib/vibe/baz.rb")
    assert_equal :ok, result[:status]
  end

  # ── check_many ────────────────────────────────────────────────────────────────

  def test_check_many_groups_results
    touch("lib/vibe/covered.rb")
    touch("test/unit/test_covered.rb")
    touch("lib/vibe/uncovered.rb")

    result = @enforcer.check_many(["lib/vibe/covered.rb", "lib/vibe/uncovered.rb"])

    assert_equal 1, result[:ok].length
    assert_equal 1, result[:missing].length
    assert result[:summary].include?("1/2")
  end

  def test_check_many_summary_format
    touch("lib/a.rb")
    touch("test/unit/test_a.rb")
    touch("lib/b.rb")

    result = @enforcer.check_many(["lib/a.rb", "lib/b.rb"])
    assert_match(/\d+\/\d+ files covered/, result[:summary])
  end

  # ── audit ─────────────────────────────────────────────────────────────────────

  def test_audit_finds_uncovered_files
    touch("lib/vibe/thing.rb")
    # no test file

    result = @enforcer.audit
    missing_files = result[:missing].map { |r| r[:file] }
    assert_includes missing_files, "lib/vibe/thing.rb"
  end

  def test_audit_excludes_vendor
    touch("vendor/gems/foo/lib/foo.rb")
    result = @enforcer.audit
    all_files = (result[:ok] + result[:missing]).map { |r| r[:file] }
    refute all_files.any? { |f| f.include?("vendor/") }
  end

  # ── test candidates ───────────────────────────────────────────────────────────

  def test_candidates_are_unique
    result = @enforcer.check("lib/vibe/foo.rb")
    assert_equal result[:test_candidates].uniq, result[:test_candidates]
  end

  def test_candidates_include_minitest_path
    result = @enforcer.check("lib/vibe/foo.rb")
    assert result[:test_candidates].any? { |c| c.include?("test_foo") }
  end
end
