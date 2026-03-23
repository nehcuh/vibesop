# Implementation Plan: Modern CLI Tools Detection

**Version**: 1.0
**Date**: 2026-03-23
**Related**: [PRD: Modern CLI Tools Detection](./prd-modern-cli-tools.md)
**Status**: Ready for Review

---

## Overview

This document provides a detailed, step-by-step implementation plan for adding modern CLI tools detection and recommendation to VibeSOP.

**Estimated Total Time**: 2 weeks (10 working days)
**Complexity**: Medium
**Risk Level**: Low

---

## Phase 1: Configuration and Detection Logic (Days 1-3)

### Task 1.1: Create modern-cli.yaml Configuration

**File**: `core/integrations/modern-cli.yaml`
**Estimated Time**: 2 hours
**Dependencies**: None

**Implementation**:

```yaml
schema_version: 1
name: modern-cli-tools
type: tool_detection
description: Modern CLI tools detection and recommendation

tools:
  - traditional: cat
    modern: bat
    category: file_operations
    detection:
      binary: bat
      alternatives: []
    usage_notes: "Syntax highlighting, line numbers. Use --paging=never for non-interactive output"
    use_cases: ["Reading code files", "Viewing logs"]

  - traditional: find
    modern: fd
    category: file_operations
    detection:
      binary: fd
      alternatives: [fdfind]
    usage_notes: "Faster, simpler syntax. Respects .gitignore by default"
    use_cases: ["Finding files by name/pattern", "Recursive file search"]

  - traditional: grep
    modern: rg
    category: text_search
    detection:
      binary: rg
      alternatives: [ripgrep]
    usage_notes: "Respects .gitignore, faster. Use --no-ignore to search all files"
    use_cases: ["Searching code content", "Pattern matching in files"]

  - traditional: ls
    modern: eza
    category: file_operations
    detection:
      binary: eza
      alternatives: [lsd, exa]
    usage_notes: "Icons, git status, tree view. Use --icons for visual output"
    use_cases: ["Listing directory contents", "Viewing file metadata"]

  - traditional: du
    modern: dust
    category: system_monitoring
    detection:
      binary: dust
      alternatives: []
    usage_notes: "Visual disk usage. Use -d N to limit depth"
    use_cases: ["Checking directory sizes", "Finding large files"]

  - traditional: df
    modern: duf
    category: system_monitoring
    detection:
      binary: duf
      alternatives: []
    usage_notes: "Better disk usage visualization"
    use_cases: ["Checking disk space", "Monitoring storage"]

  - traditional: ps
    modern: procs
    category: system_monitoring
    detection:
      binary: procs
      alternatives: []
    usage_notes: "Better process listing with colors and tree view"
    use_cases: ["Listing processes", "Finding running programs"]

  - traditional: top
    modern: btop
    category: system_monitoring
    detection:
      binary: btop
      alternatives: [bottom, glances, htop]
    usage_notes: "Interactive system monitor with better UI"
    use_cases: ["System monitoring", "Resource usage tracking"]

integration:
  auto_enable: ask_user
  priority: P2

  targets:
    claude-code:
      method: documentation
      doc_file: TOOLS.md

    opencode:
      method: documentation
      doc_file: TOOLS.md
```

**Acceptance Criteria**:
- [ ] File created at correct location
- [ ] YAML is valid and parseable
- [ ] All 8 tools defined with complete metadata
- [ ] Follows same schema as rtk.yaml/superpowers.yaml

---

### Task 1.2: Extend external_tools.rb with Detection Logic

**File**: `lib/vibe/external_tools.rb`
**Estimated Time**: 4 hours
**Dependencies**: Task 1.1

**Implementation**:

Add the following methods to `Vibe::ExternalTools` module:

```ruby
# Detect modern CLI tools
# @return [Array<Hash>] Array of tool detection results
def detect_modern_cli_tools
  config = load_integration_config('modern-cli')
  return [] unless config

  tools = config['tools'] || []
  tools.map { |tool| detect_single_tool(tool) }.compact
end

# Detect a single tool with alternatives
# @param tool_def [Hash] Tool definition from YAML
# @return [Hash] Detection result
def detect_single_tool(tool_def)
  binary = tool_def.dig('detection', 'binary')
  alternatives = tool_def.dig('detection', 'alternatives') || []

  # Check primary binary
  if cmd_exist?(binary)
    return build_tool_result(tool_def, binary, true)
  end

  # Check alternatives
  alternatives.each do |alt|
    if cmd_exist?(alt)
      return build_tool_result(tool_def, alt, true)
    end
  end

  # Not found
  build_tool_result(tool_def, binary, false)
end

# Build tool detection result
# @param tool_def [Hash] Tool definition
# @param binary [String] Binary name that was checked
# @param available [Boolean] Whether tool is available
# @return [Hash] Detection result
def build_tool_result(tool_def, binary, available)
  result = {
    traditional: tool_def['traditional'],
    modern: tool_def['modern'],
    category: tool_def['category'],
    available: available,
    binary: binary,
    usage_notes: tool_def['usage_notes'],
    use_cases: tool_def['use_cases']
  }

  if available
    # Get full path
    result[:path] = which_tool(binary)
  end

  result
end

# Get full path to a command using Ruby native PATH lookup (no subprocess)
# @param cmd [String] Command name
# @return [String, nil] Full path or nil
def which_tool(cmd)
  exts = RbConfig::CONFIG['host_os'] =~ /mswin|msys|mingw|cygwin/i
         ? (ENV['PATHEXT'] || '.exe;.bat;.cmd').split(';')
         : ['']

  ENV['PATH'].split(File::PATH_SEPARATOR).each do |dir|
    exts.each do |ext|
      exe = File.join(dir, "#{cmd}#{ext}")
      return exe if File.executable?(exe) && File.file?(exe)
    end
  end
  nil
rescue StandardError
  nil
end

# Verify modern CLI tools integration
# @param target_platform [String] Target platform
# @return [Hash] Verification result
def verify_modern_cli_tools(target_platform = nil)
  detected = detect_modern_cli_tools
  available_count = detected.count { |t| t[:available] }

  {
    installed: available_count > 0,
    ready: available_count > 0,
    available_tools: detected.select { |t| t[:available] },
    unavailable_tools: detected.reject { |t| t[:available] },
    total_count: detected.size,
    available_count: available_count
  }
end
```

**Key Points**:
- Use existing `cmd_exist?` method for detection
- Handle alternative binary names (fd/fdfind)
- Return structured hash for easy consumption
- Follow Ruby 2.6 compatibility (no `filter_map`)

**Acceptance Criteria**:
- [ ] Methods added to external_tools.rb
- [ ] Detection works for all 8 tools
- [ ] Handles alternatives correctly
- [ ] Returns structured results
- [ ] Ruby 2.6 compatible (no modern syntax)

---

### Task 1.3: Unit Tests for Detection Logic

**File**: `test/unit/test_external_tools.rb`
**Estimated Time**: 3 hours
**Dependencies**: Task 1.2

**Implementation**:

Add tests to existing test file:

```ruby
def test_detect_modern_cli_tools_returns_array
  result = @host.detect_modern_cli_tools
  assert result.is_a?(Array)
end

def test_detect_modern_cli_tools_structure
  result = @host.detect_modern_cli_tools
  return if result.empty?

  tool = result.first
  assert tool.key?(:traditional)
  assert tool.key?(:modern)
  assert tool.key?(:available)
  assert tool.key?(:binary)
  assert tool.key?(:usage_notes)
  assert tool.key?(:use_cases)
end

def test_detect_single_tool_with_existing_command
  tool_def = {
    'traditional' => 'test',
    'modern' => 'ruby',  # ruby should exist
    'category' => 'test',
    'detection' => { 'binary' => 'ruby', 'alternatives' => [] },
    'usage_notes' => 'Test',
    'use_cases' => ['Testing']
  }

  result = @host.detect_single_tool(tool_def)
  assert result[:available]
  assert_equal 'ruby', result[:binary]
end

def test_detect_single_tool_with_nonexistent_command
  tool_def = {
    'traditional' => 'test',
    'modern' => 'nonexistent12345',
    'category' => 'test',
    'detection' => { 'binary' => 'nonexistent12345', 'alternatives' => [] },
    'usage_notes' => 'Test',
    'use_cases' => ['Testing']
  }

  result = @host.detect_single_tool(tool_def)
  refute result[:available]
end

def test_detect_single_tool_with_alternatives
  tool_def = {
    'traditional' => 'test',
    'modern' => 'fd',
    'category' => 'test',
    'detection' => { 'binary' => 'nonexistent', 'alternatives' => ['ruby'] },
    'usage_notes' => 'Test',
    'use_cases' => ['Testing']
  }

  result = @host.detect_single_tool(tool_def)
  # Should find ruby as alternative
  if @host.cmd_exist?('ruby')
    assert result[:available]
    assert_equal 'ruby', result[:binary]
  end
end

def test_verify_modern_cli_tools_structure
  result = @host.verify_modern_cli_tools
  assert result.is_a?(Hash)
  assert result.key?(:installed)
  assert result.key?(:ready)
  assert result.key?(:available_tools)
  assert result.key?(:unavailable_tools)
  assert result.key?(:total_count)
  assert result.key?(:available_count)
end

def test_which_tool_with_existing_command
  path = @host.which_tool('ruby')
  assert path.nil? || path.is_a?(String)
  assert path.include?('ruby') if path
end

def test_which_tool_with_nonexistent_command
  path = @host.which_tool('nonexistent12345')
  assert_nil path
end
```

**Acceptance Criteria**:
- [ ] All tests pass
- [ ] Tests cover happy path and edge cases
- [ ] Tests work on CI (macOS, Linux)
- [ ] Code coverage >80% for new methods

---

## Phase 2: Documentation Generation (Days 4-5)

### Task 2.1: Add render_tools_doc Method

**File**: `lib/vibe/doc_rendering.rb`
**Estimated Time**: 4 hours
**Dependencies**: Phase 1

**Implementation**:

Add method to `Vibe::DocRendering` module (around line 550, after `render_test_standards_doc`):

```ruby
def render_tools_doc(manifest)
  detected_tools = detect_modern_cli_tools
  available = detected_tools.select { |t| t[:available] }
  unavailable = detected_tools.reject { |t| t[:available] }

  lines = []
  lines << "# Available CLI Tools"
  lines << ""
  lines << "Your environment has the following modern tools:"
  lines << ""

  # Group by category
  categories = {
    "File Operations" => "file_operations",
    "Text Search" => "text_search",
    "System Monitoring" => "system_monitoring"
  }

  categories.each do |category_name, category_key|
    tools_in_category = detected_tools.select do |t|
      t[:category] == category_key
    end
    next if tools_in_category.empty?

    lines << "## #{category_name}"
    lines << ""

    tools_in_category.each do |tool|
      status = tool[:available] ? "✅" : "❌"
      lines << "- #{status} `#{tool[:modern]}` (replaces `#{tool[:traditional]}`)"

      if tool[:available]
        lines << "  - #{tool[:usage_notes]}"
        lines << "  - Use for: #{tool[:use_cases].join(', ')}"
        lines << "  - Path: `#{tool[:path]}`" if tool[:path]
      else
        lines << "  - Not installed"
      end
      lines << ""
    end
  end

  lines << "## Recommendation"
  lines << ""
  lines << "Prefer modern tools when available for better output and performance."
  lines << ""
  lines << "## Fallback Strategy"
  lines << ""
  lines << "If a modern tool fails with \"command not found\":"
  lines << "1. Fall back to the traditional tool"
  lines << "2. Inform the user the tool list may be outdated"
  lines << "3. Suggest running `vibe doctor` to refresh"
  lines << ""
  lines << "---"
  lines << ""
  lines << "Generated by: vibe doctor"
  lines << "Last updated: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"

  lines.join("\n")
end
```

**Acceptance Criteria**:
- [ ] Method added to doc_rendering.rb
- [ ] Generates valid markdown
- [ ] Groups tools by category
- [ ] Shows available/unavailable status
- [ ] Includes usage notes and examples

---

### Task 2.2: Update target_renderers.rb

**File**: `lib/vibe/target_renderers.rb`
**Estimated Time**: 1 hour
**Dependencies**: Task 2.1

**Implementation**:

Modify `write_target_docs` method (around line 35):

```ruby
content = case type
          when :behavior then render_behavior_doc(manifest)
          when :routing then render_routing_doc(manifest)
          when :safety then render_safety_doc(manifest)
          when :skills then render_skills_doc(manifest)
          when :task_routing then render_task_routing_doc(manifest)
          when :test_standards then render_test_standards_doc(manifest)
          when :tools then render_tools_doc(manifest)  # Add this line
          when :execution_policy then render_execution_policy_doc(manifest)
          when :execution then render_execution_policy_doc(manifest)
          when :general then render_general_doc(manifest)
          else
            raise Vibe::Error, "Unknown doc type: #{type}"
          end
```

**Acceptance Criteria**:
- [ ] `:tools` case added
- [ ] Calls `render_tools_doc`
- [ ] No syntax errors

---

### Task 2.3: Update platforms.yaml

**File**: `config/platforms.yaml`
**Estimated Time**: 30 minutes
**Dependencies**: Task 2.2

**Implementation**:

Add `tools` to `doc_types` for both platforms:

```yaml
platforms:
  claude-code:
    # ... existing config ...
    doc_types:
      global: [behavior, safety, task_routing, test_standards, tools]
      project: [behavior, safety]   # v1.0: tools is global-only

  opencode:
    # ... existing config ...
    doc_types:
      global: [behavior, safety, task_routing, test_standards, tools]
      project: [behavior, safety]   # v1.0: tools is global-only
```

**Note**: v1.0 only supports global configuration. Tools are system-level (installed per machine, not per project), so project-level detection provides no additional value. Project-level support may be added in v1.1 if there is user demand.

**Acceptance Criteria**:
- [ ] `tools` added to both platforms (global only)
- [ ] `project` doc_types unchanged (no `tools`)
- [ ] YAML is valid

---

### Task 2.4: Update Entrypoint Generation

**File**: `lib/vibe/config_driven_renderers.rb`
**Estimated Time**: 2 hours
**Dependencies**: Task 2.3

**Implementation**:

Modify `render_generic_project_md` method (around line 173):

```ruby
## Reference docs

Supporting notes are under `.vibe/#{platform_id}/`:
- `behavior-policies.md` — portable behavior baseline
- `safety.md` — safety policy
- `routing.md` — capability tier routing
- `task-routing.md` — task complexity routing
- `tools.md` — available modern CLI tools
```

Also update global entrypoint rendering in `render_target_entrypoint_md` (in `doc_rendering.rb`):

Find the section that lists reference docs and add:
```markdown
- `tools.md` — available modern CLI tools
```

**Acceptance Criteria**:
- [ ] Project entrypoint references tools.md
- [ ] Global entrypoint references tools.md
- [ ] Both Claude Code and OpenCode entrypoints updated

---

### Task 2.5: Unit Tests for Documentation

**File**: `test/unit/test_doc_rendering.rb` (create if doesn't exist)
**Estimated Time**: 2 hours
**Dependencies**: Task 2.1-2.4

**Implementation**:

```ruby
def test_render_tools_doc_returns_string
  manifest = build_test_manifest
  result = @host.render_tools_doc(manifest)
  assert result.is_a?(String)
  assert result.include?("# Available CLI Tools")
end

def test_render_tools_doc_includes_categories
  manifest = build_test_manifest
  result = @host.render_tools_doc(manifest)
  assert result.include?("## File Operations")
  assert result.include?("## Text Search")
  assert result.include?("## System Monitoring")
end

def test_render_tools_doc_includes_fallback_strategy
  manifest = build_test_manifest
  result = @host.render_tools_doc(manifest)
  assert result.include?("## Fallback Strategy")
  assert result.include?("vibe doctor")
end

def test_render_tools_doc_shows_status_icons
  manifest = build_test_manifest
  result = @host.render_tools_doc(manifest)
  # Should have at least one status icon
  assert result.include?("✅") || result.include?("❌")
end
```

**Acceptance Criteria**:
- [ ] Tests pass
- [ ] Tests cover doc structure
- [ ] Tests verify content presence

---

## Phase 3: User Interaction Integration (Days 6-7)

### Task 3.1: Add Tool Detection to vibe init

**File**: `lib/vibe/platform_installer.rb`
**Estimated Time**: 3 hours
**Dependencies**: Phase 2

**Implementation**:

Add method to `Vibe::PlatformInstaller` module:

```ruby
# Detect and optionally enable modern CLI tools
# @param target [String] Target platform
# @return [Boolean] Whether tools were enabled
def detect_and_enable_modern_cli_tools(target)
  puts "\n🔍 Detecting modern CLI tools..."

  detected = detect_modern_cli_tools
  available = detected.select { |t| t[:available] }
  unavailable = detected.reject { |t| t[:available] }

  # Show detection results
  available.each do |tool|
    puts "   Checking #{tool[:modern]}... ✅ found at #{tool[:path]}"
  end

  unavailable.each do |tool|
    puts "   Checking #{tool[:modern]}... ❌ not found"
  end

  puts "\n📊 Found #{available.size} of #{detected.size} modern CLI tools"
  puts

  # Ask user if they want to enable
  if available.empty?
    puts "ℹ️  No modern CLI tools detected. Skipping tool recommendations."
    return false
  end

  puts "📝 Generate tool recommendations for AI?"
  puts "   This will create TOOLS.md and help AI use modern tools automatically."
  return ask_yes_no("[Y/n]", default: true)
end
```

Then modify `build_and_deploy_target` to call this method:

```ruby
def build_and_deploy_target(target:, destination_root:, mode:, project_level: false)
  # ... existing code ...

  # Detect modern CLI tools (only for global config)
  if !project_level && mode == 'init'
    @enable_modern_cli_tools = detect_and_enable_modern_cli_tools(target)
  end

  # ... rest of existing code ...
end
```

**Acceptance Criteria**:
- [ ] Detection runs during `vibe init`
- [ ] Shows clear output with ✅/❌ status
- [ ] Asks user for confirmation
- [ ] Respects user's choice

---

### Task 3.2: Add Tool Refresh to vibe doctor

**File**: `bin/vibe` (in run_doctor method)
**Estimated Time**: 2 hours
**Dependencies**: Task 3.1

**Implementation**:

Find the `run_doctor` method and add tool detection:

```ruby
def run_doctor
  puts "\n🏥 VibeSOP Health Check"
  puts '=' * 50
  puts

  # ... existing checks ...

  # Check modern CLI tools
  puts "\n🔧 Modern CLI Tools:"
  detected = detect_modern_cli_tools
  available = detected.select { |t| t[:available] }

  if available.empty?
    puts "   ℹ️  No modern CLI tools detected"
  else
    puts "   ✅ #{available.size} tools available:"
    available.each do |tool|
      puts "      - #{tool[:modern]} (#{tool[:traditional]})"
    end
  end

  # Refresh tool documentation if needed
  if available.any?
    puts "\n📝 Refreshing tool documentation..."
    refresh_modern_cli_tools_docs
    puts "   ✅ Updated TOOLS.md"
  end

  puts
end

def refresh_modern_cli_tools_docs
  # Rebuild and redeploy for each installed platform
  %w[claude-code opencode].each do |target|
    destination = default_global_destination(target)
    next unless Dir.exist?(destination)

    # Rebuild with current tool detection
    build_and_deploy_target(
      target: target,
      destination_root: destination,
      mode: 'doctor',
      project_level: false
    )
  end
end
```

**Acceptance Criteria**:
- [ ] `vibe doctor` shows tool status
- [ ] Refreshes TOOLS.md automatically
- [ ] Works for both Claude Code and OpenCode
- [ ] Shows clear status messages

---

### Task 3.3: Unit Tests for User Interaction

**File**: `test/unit/test_platform_installer.rb`
**Estimated Time**: 2 hours
**Dependencies**: Task 3.1-3.2

**Implementation**:

```ruby
def test_detect_and_enable_modern_cli_tools_returns_boolean
  result = @host.detect_and_enable_modern_cli_tools('claude-code')
  assert [true, false].include?(result)
end

def test_refresh_modern_cli_tools_docs_does_not_crash
  # Should not crash even if no platforms installed
  assert_nothing_raised do
    @host.refresh_modern_cli_tools_docs
  end
end
```

**Acceptance Criteria**:
- [ ] Tests pass
- [ ] Tests cover user interaction flow
- [ ] Tests don't require user input (mock ask_yes_no)

---

### Task 3.4: Add `vibe tools` Subcommand

**File**: `bin/vibe`
**Estimated Time**: 2 hours
**Dependencies**: Task 3.2

**Background**: After `vibe init`, if the user opts out or wants to change their mind, there must be a clear re-entry path. Without this, users are stuck — they can't enable tool detection without re-running `vibe init`.

**Implementation**:

Add to the main command dispatch in `bin/vibe`:

```ruby
when 'tools'
  run_tools_command
```

Add the handler method:

```ruby
def run_tools_command
  subcommand = ARGV[1]

  case subcommand
  when 'enable'
    enable_modern_cli_tools_for_all
  when 'disable'
    disable_modern_cli_tools_for_all
  when 'refresh'
    refresh_modern_cli_tools_docs
    puts "✅ Tool documentation refreshed"
  when 'status'
    show_modern_cli_tools_status
  else
    puts "Usage: vibe tools <enable|disable|refresh|status>"
    puts ""
    puts "  enable   — Generate TOOLS.md for all installed platforms"
    puts "  disable  — Remove TOOLS.md from all installed platforms"
    puts "  refresh  — Re-detect tools and update TOOLS.md"
    puts "  status   — Show current tool detection status"
    exit 1
  end
end

def show_modern_cli_tools_status
  puts "\n🔧 Modern CLI Tools Status"
  puts '=' * 40
  detected = detect_modern_cli_tools
  detected.each do |tool|
    icon = tool[:available] ? '✅' : '❌'
    puts "  #{icon} #{tool[:modern].ljust(10)} (#{tool[:traditional]})"
  end
  puts
  available_count = detected.count { |t| t[:available] }
  puts "  #{available_count}/#{detected.size} tools available"
end
```

Update `bin/vibe` usage/help text to include `tools` command.

**Acceptance Criteria**:
- [ ] `vibe tools status` shows detected tools
- [ ] `vibe tools refresh` regenerates TOOLS.md
- [ ] `vibe tools enable` / `disable` work correctly
- [ ] `vibe help` shows the `tools` command
- [ ] Unknown subcommand shows usage and exits 1

---

## Phase 4: End-to-End Testing and Documentation (Days 8-10)

### Task 4.1: E2E Test for Full Flow

**File**: `test/e2e/test_modern_cli_tools_flow.rb` (new file)
**Estimated Time**: 4 hours
**Dependencies**: Phase 3

**Implementation**:

```ruby
require 'minitest/autorun'
require 'tmpdir'
require 'fileutils'
require_relative '../../lib/vibe'

class TestModernCliToolsFlow < Minitest::Test
  def setup
    @repo_root = File.expand_path('../../', __dir__)
    @temp_dir = Dir.mktmpdir
  end

  def teardown
    FileUtils.rm_rf(@temp_dir) if @temp_dir && Dir.exist?(@temp_dir)
  end

  def test_full_init_flow_generates_tools_md
    # This test requires actual vibe CLI
    skip "E2E test requires full environment"

    # Would test:
    # 1. Run vibe init with tool detection
    # 2. Verify TOOLS.md is created
    # 3. Verify CLAUDE.md references TOOLS.md
    # 4. Verify content is correct
  end

  def test_doctor_refreshes_tools_md
    skip "E2E test requires full environment"

    # Would test:
    # 1. Run vibe init
    # 2. Modify TOOLS.md
    # 3. Run vibe doctor
    # 4. Verify TOOLS.md is refreshed
  end
end
```

**Acceptance Criteria**:
- [ ] E2E test file created
- [ ] Tests cover full user journey
- [ ] Tests can run in CI

---

### Task 4.2: Update README.md

**File**: `README.md`
**Estimated Time**: 2 hours
**Dependencies**: All previous tasks

**Implementation**:

Add section to README:

```markdown
### Modern CLI Tools Detection

VibeSOP can detect and recommend modern CLI tools installed in your environment:

- `bat` (replaces `cat`) - Syntax highlighting
- `fd` (replaces `find`) - Faster file search
- `rg` (replaces `grep`) - Respects .gitignore
- `eza` (replaces `ls`) - Icons and git status
- `dust`, `duf`, `procs`, `btop` - System monitoring

During `vibe init`, you'll be asked if you want to enable tool detection. If enabled, AI agents will automatically prefer these tools when available.

To refresh tool detection:
```bash
vibe doctor
```

See [Modern CLI Tools Guide](docs/modern-cli-tools.md) for details.
```

**Acceptance Criteria**:
- [ ] README updated with feature description
- [ ] Usage examples provided
- [ ] Links to detailed docs

---

### Task 4.3: Update CHANGELOG.md

**File**: `CHANGELOG.md`
**Estimated Time**: 30 minutes
**Dependencies**: All previous tasks

**Implementation**:

Add to Unreleased section:

```markdown
## [Unreleased]

### Added
- Modern CLI tools detection and recommendation system
- `TOOLS.md` generation for AI agents
- Automatic tool detection during `vibe init`
- Tool refresh during `vibe doctor`
- Support for 8 modern CLI tools (bat, fd, rg, eza, dust, duf, procs, btop)

### Changed
- `vibe init` now asks about modern CLI tools
- `vibe doctor` now refreshes tool documentation
```

**Acceptance Criteria**:
- [ ] CHANGELOG updated
- [ ] Follows existing format
- [ ] All changes documented

---

### Task 4.4: Create User Guide

**File**: `docs/modern-cli-tools.md` (new file)
**Estimated Time**: 3 hours
**Dependencies**: All previous tasks

**Implementation**:

Create comprehensive user guide covering:
- What are modern CLI tools
- How detection works
- How to enable/disable
- How to refresh
- Troubleshooting
- FAQ

**Acceptance Criteria**:
- [ ] User guide created
- [ ] Covers all user scenarios
- [ ] Includes examples and screenshots

---

## Testing Strategy

### Unit Tests
- **Coverage Target**: >75%
- **Files to Test**:
  - `lib/vibe/external_tools.rb` (detection logic)
  - `lib/vibe/doc_rendering.rb` (doc generation)
  - `lib/vibe/platform_installer.rb` (user interaction)

### Integration Tests
- Test full build pipeline with tools enabled
- Test cross-platform rendering (Claude Code + OpenCode)

### E2E Tests
- Test `vibe init` with tool detection
- Test `vibe doctor` refresh
- Test user opt-out scenario

### Manual Testing Checklist
- [ ] Run `vibe init` on clean system
- [ ] Verify TOOLS.md generated correctly
- [ ] Verify AI can read TOOLS.md
- [ ] Install a new tool, run `vibe doctor`, verify refresh
- [ ] Test on macOS, Linux, Windows (if possible)
- [ ] Test with Ruby 2.6

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Detection is slow | Cache results, optimize with parallel checks |
| Binary name conflicts | Support alternatives in config |
| Ruby 2.6 compatibility | Strict testing, avoid modern syntax |
| Cross-platform issues | Test on multiple platforms, use RbConfig |
| User confusion | Clear messaging, good documentation |

---

## Rollback Plan

If critical issues are found:

1. **Immediate**: Disable tool detection in `vibe init` (comment out call)
2. **Short-term**: Remove `tools` from `platforms.yaml` doc_types
3. **Long-term**: Revert all commits related to this feature

---

## Success Criteria

**Must Have (P0)**:
- [ ] Tool detection works on macOS and Linux
- [ ] TOOLS.md generated correctly
- [ ] User can opt in/out during init
- [ ] `vibe doctor` refreshes tools
- [ ] All unit tests pass
- [ ] Code coverage >75%
- [ ] Ruby 2.6 compatible

**Should Have (P1)**:
- [ ] E2E tests pass
- [ ] Documentation complete
- [ ] Works on Windows
- [ ] Performance <2s for detection

**Nice to Have (P2)**:
- [ ] Tool installation suggestions
- [ ] Version checking
- [ ] Performance benchmarks

---

## Timeline

| Phase | Days | Tasks | Deliverable |
|-------|------|-------|-------------|
| Phase 1 | 1-3 | Config + Detection | Working detection logic |
| Phase 2 | 4-5 | Doc Generation | TOOLS.md generation |
| Phase 3 | 6-7 | User Interaction | Init + Doctor integration |
| Phase 4 | 8-10 | Testing + Docs | Complete feature |

**Total**: 10 working days (2 weeks)

---

## Next Steps

1. **Review**: Get approval from ChatGPT on this plan
2. **Setup**: Create feature branch `feature/modern-cli-tools`
3. **Execute**: Follow phases in order
4. **Review**: Code review after each phase
5. **Merge**: Merge to main after all tests pass

---

**Document Status**: Ready for Review
**Reviewer**: ChatGPT
**Next Action**: Review and provide feedback
