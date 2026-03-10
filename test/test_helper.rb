# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  add_filter "/test/"
  add_filter "/vendor/"
  add_group "Libraries", "lib/vibe"
  add_group "CLI", "bin/vibe"
  minimum_coverage 60
  enable_coverage :branch
end

SimpleCov.at_exit do
  SimpleCov.result.format!
end

require "minitest/autorun"
