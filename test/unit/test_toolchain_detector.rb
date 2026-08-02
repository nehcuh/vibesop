# frozen_string_literal: true

require "minitest/autorun"
require "tmpdir"
require "fileutils"
require_relative "../../lib/vibe/toolchain_detector"

class TestToolchainDetector < Minitest::Test
  def setup
    @dir = Dir.mktmpdir
    @detector = Vibe::ToolchainDetector.new(@dir)
  end

  def teardown
    FileUtils.rm_rf(@dir)
  end

  # helpers
  def touch(*files)
    files.each { |f| FileUtils.touch(File.join(@dir, f)) }
  end

  # ── package managers ─────────────────────────────────────────────────────────

  def test_detects_npm
    touch("package-lock.json")
    pms = @detector.detect_package_managers
    assert_includes pms.map { |p| p[:name] }, :npm
  end

  def test_detects_yarn
    touch("yarn.lock")
    pms = @detector.detect_package_managers
    assert_includes pms.map { |p| p[:name] }, :yarn
  end

  def test_detects_pnpm
    touch("pnpm-lock.yaml")
    pms = @detector.detect_package_managers
    assert_includes pms.map { |p| p[:name] }, :pnpm
  end

  def test_detects_bun
    touch("bun.lockb")
    pms = @detector.detect_package_managers
    assert_includes pms.map { |p| p[:name] }, :bun
  end

  def test_detects_poetry
    touch("poetry.lock", "pyproject.toml")
    pms = @detector.detect_package_managers
    assert_includes pms.map { |p| p[:name] }, :poetry
  end

  def test_detects_pip
    touch("requirements.txt")
    pms = @detector.detect_package_managers
    assert_includes pms.map { |p| p[:name] }, :pip
  end

  def test_detects_cargo
    touch("Cargo.toml", "Cargo.lock")
    pms = @detector.detect_package_managers
    assert_includes pms.map { |p| p[:name] }, :cargo
  end

  def test_detects_gomod
    touch("go.mod")
    pms = @detector.detect_package_managers
    assert_includes pms.map { |p| p[:name] }, :gomod
  end

  def test_detects_bundler
    touch("Gemfile", "Gemfile.lock")
    pms = @detector.detect_package_managers
    assert_includes pms.map { |p| p[:name] }, :bundler
  end

  def test_no_package_manager_when_empty
    assert_empty @detector.detect_package_managers
  end

  # ── build tools ──────────────────────────────────────────────────────────────

  def test_detects_vite
    touch("vite.config.ts")
    assert_includes @detector.detect_build_tools.map { |t| t[:name] }, :vite
  end

  def test_detects_webpack
    touch("webpack.config.js")
    assert_includes @detector.detect_build_tools.map { |t| t[:name] }, :webpack
  end

  def test_detects_make
    touch("Makefile")
    assert_includes @detector.detect_build_tools.map { |t| t[:name] }, :make
  end

  def test_detects_gradle
    touch("gradlew")
    assert_includes @detector.detect_build_tools.map { |t| t[:name] }, :gradle
  end

  def test_detects_maven
    touch("pom.xml")
    assert_includes @detector.detect_build_tools.map { |t| t[:name] }, :maven
  end

  # ── test frameworks ───────────────────────────────────────────────────────────

  def test_detects_jest
    touch("jest.config.js")
    assert_includes @detector.detect_test_frameworks.map { |t| t[:name] }, :jest
  end

  def test_detects_vitest
    touch("vitest.config.ts")
    assert_includes @detector.detect_test_frameworks.map { |t| t[:name] }, :vitest
  end

  def test_detects_pytest
    touch("pytest.ini")
    assert_includes @detector.detect_test_frameworks.map { |t| t[:name] }, :pytest
  end

  def test_detects_rspec
    FileUtils.mkdir_p(File.join(@dir, "spec"))
    touch(".rspec")
    assert_includes @detector.detect_test_frameworks.map { |t| t[:name] }, :rspec
  end

  # ── primary language ──────────────────────────────────────────────────────────

  def test_primary_language_node
    touch("package-lock.json", "vite.config.ts", "jest.config.js")
    assert_equal "node", @detector.primary_language
  end

  def test_primary_language_python
    touch("requirements.txt", "pytest.ini")
    assert_equal "python", @detector.primary_language
  end

  def test_primary_language_unknown_when_empty
    assert_equal "unknown", @detector.primary_language
  end

  # ── suggested commands ────────────────────────────────────────────────────────

  def test_suggested_install_npm
    touch("package-lock.json")
    cmds = @detector.suggested_commands
    assert_equal "npm install", cmds[:install]
  end

  def test_suggested_test_pytest
    touch("pytest.ini")
    cmds = @detector.suggested_commands
    assert_equal "pytest", cmds[:test]
  end

  def test_suggested_build_make
    touch("Makefile")
    cmds = @detector.suggested_commands
    assert_equal "make", cmds[:build]
  end

  # ── full detect ───────────────────────────────────────────────────────────────

  def test_detect_returns_full_structure
    touch("package-lock.json", "vite.config.ts", "jest.config.js")
    result = @detector.detect

    assert result[:ecosystems]
    assert result[:package_managers]
    assert result[:build_tools]
    assert result[:test_frameworks]
    assert result[:primary_language]
    assert result[:suggested_commands]
    assert_equal @dir, result[:project_root]
  end

  def test_detect_multiple_tools
    touch("package-lock.json", "yarn.lock", "Makefile", "vite.config.js")
    result = @detector.detect

    pm_names = result[:package_managers].map { |p| p[:name] }
    assert_includes pm_names, :npm
    assert_includes pm_names, :yarn
  end
end
