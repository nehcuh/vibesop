# frozen_string_literal: true

unless ENV['COVERAGE'] == 'false'
  begin
    require "simplecov"
    SimpleCov.start do
      add_filter "/test/"
      add_filter "/vendor/"
      add_group "Libraries", "lib/vibe"
      add_group "CLI", "bin/vibe"
      minimum_coverage 50
      enable_coverage :branch
    end

    SimpleCov.at_exit do
      SimpleCov.result.format!
    end
  rescue LoadError
    # SimpleCov not available, skip coverage
  end
end

require "minitest/autorun"
