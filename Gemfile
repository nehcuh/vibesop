# frozen_string_literal: true

source "https://rubygems.org"

ruby ">= 2.6.0"

# Runtime dependencies: NONE
# This project uses only Ruby stdlib (json, yaml, fileutils, optparse, tmpdir)
# to maintain zero-dependency portability for CLI usage.

group :development, :test do
  gem "rake", "~> 13.0"
  gem "minitest", "~> 5.20"
  gem "simplecov", "~> 0.22"
  # RuboCop 1.60+ requires Ruby 2.7+, keep 1.50 line for Ruby 2.6 compatibility
  gem "rubocop", "~> 1.50", require: false
  gem "json-schema", "~> 4.1"
end
