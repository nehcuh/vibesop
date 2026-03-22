# frozen_string_literal: true

require 'rake/testtask'

Rake::TestTask.new(:test) do |t|
  t.libs << 'test' << 'lib'
  t.test_files = FileList['test/test_*.rb', 'test/**/test_*.rb']
  t.verbose = true
end

Rake::TestTask.new(:test_single) do |t|
  t.libs << 'test' << 'lib'
  t.verbose = true
end

desc 'Run all validation checks'
task :validate do
  require 'yaml'

  puts '🔍 Running validation pipeline...'

  # 1. Validate YAML files
  Dir.glob('core/**/*.yaml').each do |f|
    YAML.safe_load(File.read(f), aliases: true)
    puts "✓ #{f}"
  rescue StandardError => e
    abort "✗ #{f}: #{e.message}"
  end
  puts '✅ Core YAML files are well-formed.'

  # 2. Vibe inspect
  abort '❌ Vibe inspect failed.' unless system('bin/vibe inspect --json > /dev/null')
  puts '✅ Vibe inspect succeeded.'

  # 3. Skill entrypoint paths
  puts '🔍 Checking skill entrypoint paths...'
  registry = YAML.safe_load(File.read('core/skills/registry.yaml'), aliases: true)
  registry['skills'].select { |s| s['namespace'] == 'builtin' }.each do |s|
    path = s['entrypoint']
    abort "Missing entrypoint: #{path}" unless File.exist?(path)
  end
  puts '✅ All builtin skill entrypoints exist.'

  # 4. Document cross-references
  puts '🔍 Checking document cross-references...'
  behaviors_path = 'rules/behaviors.md'
  if File.exist?(behaviors_path)
    content = File.read(behaviors_path)
    refs = content.scan(%r{Read (docs/[^\s)]+)})
    refs.each do |ref|
      path = ref[0]
      abort "Missing doc: #{path}" unless File.exist?(path)
    end
  end
  puts '✅ All doc references exist.'

  puts '✅ Validation complete.'
end

desc 'Run tests with coverage (requires: gem install --user-install simplecov)'
task :coverage do
  # Check if SimpleCov is available
  simplecov_check = system('ruby', '-e', "require 'simplecov'",
                           %i[out err] => File::NULL)

  unless simplecov_check
    abort "❌ SimpleCov not installed.\n" \
          "   Install with: gem install --user-install simplecov\n" \
          '   Or skip with: COVERAGE=false rake test'
  end

  # Enable coverage and run tests
  ENV['COVERAGE'] = 'true'
  Rake::Task[:test].invoke

  # Show coverage results
  if File.exist?('coverage/.last_run.json')
    require 'json'
    last_run = JSON.parse(File.read('coverage/.last_run.json'))
    line_cov = last_run.dig('result', 'line') || 0
    branch_cov = last_run.dig('result', 'branch') || 0

    puts "\n📊 Coverage Summary:"
    puts "   Line Coverage:   #{line_cov.round(2)}%"
    puts "   Branch Coverage: #{branch_cov.round(2)}%"
    puts '   Full Report:     coverage/index.html'

    # Warn if below minimum
    if line_cov < 50
      warn "\n⚠️  Line coverage (#{line_cov.round(2)}%) is below minimum (50%)"
    end
    if branch_cov < 50
      warn "⚠️  Branch coverage (#{branch_cov.round(2)}%) is below minimum (50%)"
    end
  else
    warn "\n⚠️  Coverage report not found at coverage/.last_run.json"
  end
end

desc 'Clean generated files'
task :clean do
  rm_rf 'generated'
  rm_rf 'coverage'
  puts '🧹 Cleaned generated files'
end

desc 'Build all supported targets'
task :build do
  targets = %w[claude-code opencode]
  targets.each do |target|
    puts "Building #{target}..."
    system('ruby', '-Ilib', 'bin/vibe', 'build', target, '--output',
           "generated/#{target}")
  end
end

task default: :test
