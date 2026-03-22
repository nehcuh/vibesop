# frozen_string_literal: true

unless ENV['COVERAGE'] == 'false'
  begin
    require 'simplecov'
    SimpleCov.start do
      add_filter '/test/'
      add_filter '/vendor/'
      add_group 'Libraries', 'lib/vibe'
      add_group 'CLI', 'bin/vibe'
      minimum_coverage 0  # Don't fail on low coverage during development
      enable_coverage :branch
    end

    SimpleCov.at_exit do
      SimpleCov.result.format!
      puts "\n📊 Coverage report generated:"
      puts "   HTML: #{SimpleCov.coverage_path}/index.html"
      puts "   Line: #{SimpleCov.result.covered_percent.round(2)}%"
      puts '   Branch coverage available in full report'
    end
  rescue LoadError => e
    warn "⚠️  SimpleCov not available: #{e.message}"
    warn '   Install with: gem install --user-install simplecov'
    warn '   Then run with: COVERAGE=true rake test'
    warn '   Continuing without coverage...'
  end
end

require 'minitest/autorun'
