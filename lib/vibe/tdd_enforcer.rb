# frozen_string_literal: true

module Vibe
  # Enforces test-first development by detecting implementation files
  # that lack corresponding test coverage.
  #
  # Usage:
  #   enforcer = TddEnforcer.new("/path/to/project")
  #   result   = enforcer.check("lib/foo/bar.rb")
  #   puts result[:status]   # => :missing_tests
  #   puts result[:message]  # => "No test file found for lib/foo/bar.rb"
  class TddEnforcer
    STATUS = {
      ok:             :ok,
      missing_tests:  :missing_tests,
      skipped:        :skipped,
      not_impl_file:  :not_impl_file
    }.freeze

    # Patterns that identify implementation files by path
    IMPL_PATTERNS = [
      /\Alib\//,
      /\Aapp\//,
      /\Asrc\//,
      /\.rb\z/,
      /\.py\z/,
      /\.ts\z/,
      /\.js\z/
    ].freeze

    # Patterns that identify test files — these are never checked
    TEST_PATTERNS = [
      /\Atest\//,
      /\Aspec\//,
      /\A__tests__\//,
      /_test\.rb\z/,
      /_spec\.rb\z/,
      /\.test\.(ts|js)\z/,
      /\.spec\.(ts|js)\z/,
      /test_.*\.rb\z/,
      /test_.*\.py\z/
    ].freeze

    # Candidate test path generators: given an impl path, return possible test paths.
    # Each lambda returns nil when the pattern does not apply to the given path.
    TEST_PATH_RESOLVERS = [
      # Ruby (lib/): lib/vibe/foo.rb → test/unit/test_foo.rb
      ->(p) { p.match?(/\Alib\/.*\.rb\z/) ? "test/unit/test_#{File.basename(p)}" : nil },
      # Ruby (lib/): lib/vibe/foo.rb → spec/vibe/foo_spec.rb
      ->(p) { p.match?(/\Alib\/.*\.rb\z/) ? p.sub(/\Alib\//, "spec/").sub(/\.rb\z/, "_spec.rb") : nil },
      # Ruby (lib/): lib/vibe/foo.rb → test/vibe/foo_test.rb
      ->(p) { p.match?(/\Alib\/.*\.rb\z/) ? p.sub(/\Alib\//, "test/").sub(/\.rb\z/, "_test.rb") : nil },
      # Python: any .py → tests/test_<basename>
      ->(p) { p.match?(/\.py\z/) ? "tests/test_#{File.basename(p)}" : nil },
      # Python (src/): src/foo/bar.py → tests/test_foo/bar.py
      ->(p) { p.match?(/\Asrc\/.*\.py\z/) ? p.sub(/\Asrc\//, "tests/test_") : nil },
      # JS/TS: foo/bar.ts → foo/bar.test.ts
      ->(p) { (m = p.match(/\.(ts|js)\z/)) ? p.sub(/\.(ts|js)\z/, ".test.#{m[1]}") : nil },
      # JS/TS: foo/bar.ts → __tests__/bar.test.ts
      ->(p) { (m = p.match(/\.(ts|js)\z/)) ? "__tests__/#{File.basename(p, m[0])}.test.#{m[1]}" : nil }
    ].freeze

    attr_reader :project_root

    def initialize(project_root = nil)
      @project_root = File.expand_path(project_root || Dir.pwd)
    end

    # Check a single file for test coverage
    # @param file_path [String] relative path from project root
    # @return [Hash] { status:, file:, test_candidates:, found_test: }
    def check(file_path)
      rel = file_path.sub(/\A#{Regexp.escape(@project_root)}\//, "")

      # Test files are never checked — return :skipped before impl_file? check
      return { status: STATUS[:skipped], file: rel, test_candidates: [], found_test: nil } \
        if test_file?(rel)

      return { status: STATUS[:not_impl_file], file: rel, test_candidates: [], found_test: nil } \
        unless impl_file?(rel)

      candidates = TEST_PATH_RESOLVERS.map { |r| r.call(rel) }.compact.uniq
      found = candidates.find { |c| File.exist?(File.join(@project_root, c)) }

      if found
        { status: STATUS[:ok], file: rel, test_candidates: candidates, found_test: found }
      else
        { status: STATUS[:missing_tests], file: rel, test_candidates: candidates, found_test: nil }
      end
    end

    # Check multiple files and return a summary
    # @param files [Array<String>]
    # @return [Hash] { ok:, missing:, skipped:, summary: }
    def check_many(files)
      results = files.map { |f| check(f) }

      {
        ok:      results.select { |r| r[:status] == STATUS[:ok] },
        missing: results.select { |r| r[:status] == STATUS[:missing_tests] },
        skipped: results.select { |r| r[:status] == STATUS[:skipped] || r[:status] == STATUS[:not_impl_file] },
        summary: build_summary(results)
      }
    end

    # Scan the entire project for implementation files missing tests
    # @return [Hash]
    def audit
      impl_files = find_impl_files
      check_many(impl_files)
    end

    private

    def impl_file?(path)
      IMPL_PATTERNS.any? { |p| p.match?(path) } && !test_file?(path)
    end

    def test_file?(path)
      TEST_PATTERNS.any? { |p| p.match?(path) }
    end

    def find_impl_files
      Dir.glob(File.join(@project_root, "**", "*.{rb,py,ts,js}"))
         .map { |f| f.sub("#{@project_root}/", "") }
         .reject { |f| test_file?(f) }
         .reject { |f| f.include?("node_modules/") || f.include?("vendor/") }
    end

    def build_summary(results)
      total   = results.count { |r| r[:status] != STATUS[:not_impl_file] }
      covered = results.count { |r| r[:status] == STATUS[:ok] }
      missing = results.count { |r| r[:status] == STATUS[:missing_tests] }

      coverage = total.positive? ? (covered.to_f / total * 100).round(1) : 100.0

      "#{covered}/#{total} files covered (#{coverage}%), #{missing} missing tests"
    end
  end
end
