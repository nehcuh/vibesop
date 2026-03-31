#!/usr/bin/env ruby
# frozen_string_literal: true

require 'yaml'
require_relative '../lib/vibe/skill_router'

router = Vibe::SkillRouter.new
registry = router.registry

puts '=== Test Case Skill IDs ==='
test_cases = {
  'systematic-debugging' => 'systematic-debugging',
  'review' => 'review',
  'refactor' => 'refactor',
  'tdd' => 'tdd',
  'planning-with-files' => 'planning-with-files',
  'riper-workflow' => 'riper-workflow',
  'exploration' => 'exploration',
  'session-end' => 'session-end'
}

test_cases.each do |id, name|
  skill = registry['skills']&.find { |s| s['id'] == id }
  exists = skill ? '✓' : '✗'
  puts "#{exists} #{id}: #{skill ? skill['name'] : 'NOT FOUND'}"
end
