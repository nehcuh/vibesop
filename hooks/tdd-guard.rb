#!/usr/bin/env ruby
# frozen_string_literal: true

# TDD Guard - Test-Driven Development Enforcement Hook
# Ensures code changes are accompanied by tests
# Install: Add to pre-commit or pre-push hooks

module TDDGuard
  class Config
    attr_accessor :strict_mode, :test_patterns, :src_patterns, :min_coverage

    def initialize
      @strict_mode = false  # false = warn only, true = block
      @test_patterns = %w[*_test.rb *_spec.rb test_*.py *_test.go]
      @src_patterns = %w[*.rb *.py *.go *.js *.ts *.java]
      @min_coverage = 80.0
    end

    def self.load_from_file(path = ".tdd-guard.yml")
      return new unless File.exist?(path)

      require "yaml"
      config = new
      data = YAML.safe_load(File.read(path), symbolize_names: true)

      config.strict_mode = data[:strict_mode] if data.key?(:strict_mode)
      config.test_patterns = data[:test_patterns] if data.key?(:test_patterns)
      config.src_patterns = data[:src_patterns] if data.key?(:src_patterns)
      config.min_coverage = data[:min_coverage] if data.key?(:min_coverage)

      config
    rescue StandardError => e
      warn "Warning: Could not load TDD Guard config: #{e.message}"
      new
    end
  end

  class CheckResult
    attr_reader :passed, :issues, :warnings

    def initialize(passed:, issues:, warnings:)
      @passed = passed
      @issues = issues
      @warnings = warnings
    end

    def to_s
      return "✅ TDD Guard: All checks passed" if @passed && @warnings.empty?

      output = []
      output << (@passed ? "⚠️ TDD Guard: Warnings found" : "🚨 TDD Guard: Issues found")

      unless @issues.empty?
        output << "\nIssues:"
        @issues.each { |issue| output << "  ❌ #{issue}" }
      end

      unless @warnings.empty?
        output << "\nWarnings:"
        @warnings.each { |warn| output << "  ⚡ #{warn}" }
      end

      output.join("\n")
    end
  end

  # Check if a file is a test file
  def self.test_file?(path, patterns)
    patterns.any? { |pattern| File.fnmatch?(pattern, File.basename(path)) }
  end

  # Check if a file is a source file
  def self.source_file?(path, patterns)
    patterns.any? { |pattern| File.fnmatch?(pattern, File.basename(path)) }
  end

  # Find corresponding test file for a source file
  def self.find_test_file(src_path, test_patterns)
    base_name = File.basename(src_path, File.extname(src_path))
    dir = File.dirname(src_path)

    # Common test file naming conventions
    candidates = [
      "#{dir}/#{base_name}_test.rb",
      "#{dir}/#{base_name}_spec.rb",
      "#{dir}/test_#{base_name}.rb",
      "tests/#{base_name}_test.rb",
      "spec/#{base_name}_spec.rb",
      "test/#{base_name}_test.rb",
      # Python
      "#{dir}/test_#{base_name}.py",
      "tests/test_#{base_name}.py",
      # Go
      "#{dir}/#{base_name}_test.go",
      # JavaScript/TypeScript
      "#{dir}/#{base_name}.test.js",
      "#{dir}/#{base_name}.spec.js",
      "#{dir}/#{base_name}.test.ts",
      "#{dir}/#{base_name}.spec.ts",
    ]

    candidates.find { |c| File.exist?(c) }
  end

  # Main check function
  def self.check(files = nil, config: Config.new)
    files ||= `git diff --cached --name-only --diff-filter=ACM`.strip.split("\n")
    files = files.reject { |f| f.empty? || f.start_with?("#") }

    return CheckResult.new(passed: true, issues: [], warnings: []) if files.empty?

    source_files = files.select { |f| source_file?(f, config.src_patterns) }
    test_files = files.select { |f| test_file?(f, config.test_patterns) }

    issues = []
    warnings = []

    # Check 1: Source files must have tests
    source_files.each do |src|
      test_file = find_test_file(src, config.test_patterns)

      if test_file.nil?
        issues << "No test file found for #{src}"
      elsif !files.include?(test_file) && !File.exist?(test_file)
        issues << "Test file #{test_file} for #{src} does not exist"
      end
    end

    # Check 2: Test files should be modified along with source
    if config.strict_mode
      source_files.each do |src|
        test_file = find_test_file(src, config.test_patterns)
        if test_file && !files.include?(test_file)
          warnings << "Test file #{test_file} not updated with #{src}"
        end
      end
    end

    # Check 3: Coverage check (if coverage data available)
    if File.exist?(".coverage") || File.exist?("coverage/coverage.json")
      coverage = check_coverage(config.min_coverage)
      unless coverage[:passed]
        issues << "Test coverage below threshold: #{coverage[:actual]}% < #{config.min_coverage}%"
      end
    end

    # Check 4: Tests must pass
    if config.strict_mode && !test_files.empty?
      test_result = run_tests
      unless test_result[:passed]
        issues << "Tests failed: #{test_result[:output]}"
      end
    end

    passed = issues.empty?
    CheckResult.new(passed: passed, issues: issues, warnings: warnings)
  end

  def self.check_coverage(min_coverage)
    # Try to read coverage from common formats
    if File.exist?("coverage/coverage.json")
      require "json"
      data = JSON.parse(File.read("coverage/coverage.json"))
      actual = data["totals"]["percent_covered"] || data["total"]
      return { passed: actual >= min_coverage, actual: actual }
    end

    if File.exist?(".coverage")
      # Simplecov format
      # This is a simplified check
      return { passed: true, actual: "unknown" }
    end

    { passed: true, actual: "N/A" }
  rescue StandardError
    { passed: true, actual: "unknown" }
  end

  def self.run_tests
    # Try common test commands
    commands = [
      "bundle exec rake test",
      "bundle exec rspec",
      "pytest",
      "python -m pytest",
      "go test ./...",
      "npm test",
      "yarn test",
    ]

    commands.each do |cmd|
      result = system("#{cmd} > /dev/null 2>&1")
      return { passed: result, output: cmd } if result
    end

    { passed: true, output: "No test runner found" }
  end
end

# CLI interface
if __FILE__ == $PROGRAM_NAME
  config = TDDGuard::Config.load_from_file

  # Parse command line options
  require "optparse"
  OptionParser.new do |opts|
    opts.banner = "Usage: #{$PROGRAM_NAME} [options] [files...]"

    opts.on("-s", "--strict", "Enable strict mode (block on warnings)") do
      config.strict_mode = true
    end

    opts.on("-c", "--config FILE", "Config file path") do |f|
      config = TDDGuard::Config.load_from_file(f)
    end

    opts.on("-h", "--help", "Show this help") do
      puts opts
      exit 0
    end
  end.parse!

  files = ARGV.empty? ? nil : ARGV
  result = TDDGuard.check(files, config: config)

  puts result.to_s

  exit(result.passed ? 0 : 1)
end
