# frozen_string_literal: true

require "simplecov"
SimpleCov.start do
  add_filter "/test/"
  add_filter "/vendor/"
  add_group "Libraries", "lib/vibe"
  add_group "CLI", "bin/vibe"
  minimum_coverage 80
end

require "minitest/autorun"
