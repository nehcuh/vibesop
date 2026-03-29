# Vibe Workflow 技术优化方案

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 修复 GPT 评审指出的所有 P0/P1 问题，恢复仓库基本质量闭环

**Architecture:** 分三批实施：P0 核心修复 → P1 质量基础设施 → P2 文档清理。每个 PR 独立可合并。

**Tech Stack:** Ruby, YAML, Bash, GitHub Actions

---

## 问题总览

### P0: 必须先解决，否则不建议合并

1. **修复 native config 生成链路** - 方法名不匹配导致静默跳过
2. **修复 project/global 语义闭环** - project mode 仍复制整套 runtime
3. **统一 OpenCode 路径到 ~/.config/opencode** - 混用 ~/.opencode 和 ~/.config/opencode
4. **修复当前测试红灯** - TestSkillAdapter#test_adapt_all_as_batch 失败

### P1: 应尽快解决

5. **补齐真正的端到端测试** - 测试只测局部 helper
6. **修复 smoke test** - 无副作用且可信
7. **统一平台支持状态的 SSOT** - 文档与实现口径不一致
8. **修复 CI 与双平台策略不一致** - CI 仍按 8 平台检查

### P2: 建议在主链路稳定后清理

9. **文档诚实化与去陈旧内容** - 文档口径与实现不一致
10. **决策 knowledge.yaml 的命运** - 两套 memory 架构并存

---

## Chunk 1: P0-4 测试修复 (最简单，先热身)

### Task 1: 修复 TestSkillAdapter#test_adapt_all_as_batch

**Files:**
- Modify: `test/test_skill_management.rb:183-197`

**问题分析:**
测试使用 `skill-1`, `skill-2`, `skill-3` 作为假数据，但 `adapt_skill` 方法现在会检查 registry，这些 ID 不存在导致全部失败。

**修复方案:** 使用 registry 中真实存在的 skill ID

- [ ] **Step 1: 修改测试使用真实 skill ID**

```ruby
def test_adapt_all_as_batch
  skills = [
    { id: 'systematic-debugging' },
    { id: 'verification-before-completion' },
    { id: 'session-end' }
  ]

  results = @adapter.adapt_all_as(skills, :suggest)

  assert_equal 3, results[:adapted].length
  assert_equal 0, results[:skipped].length

  config = @adapter.send(:load_project_config)
  assert_equal 3, config['adapted_skills'].keys.length
end
```

- [ ] **Step 2: 运行测试验证通过**

Run: `ruby -Ilib:test test/test_skill_management.rb -n test_adapt_all_as_batch`
Expected: PASS

- [ ] **Step 3: 运行全部测试**

Run: `rake test`
Expected: 全部通过 (266 runs, 823 assertions, 0 failures)

- [ ] **Step 4: Commit**

```bash
git add test/test_skill_management.rb
git commit -m "fix(test): use real skill IDs in test_adapt_all_as_batch

Test was using fake skill-1/2/3 IDs that don't exist in registry.
Now uses systematic-debugging, verification-before-completion,
and session-end which are real builtin skills."
```

---

## Chunk 2: P0-3 OpenCode 路径统一

### Task 2: 统一 OpenCode 配置路径到 ~/.config/opencode

**Files:**
- Modify: `lib/vibe/native_configs.rb:125`
- Modify: `lib/vibe/target_renderers.rb:71`
- Modify: `lib/vibe/init_support.rb:122`
- Modify: `bin/vibe:395,603`
- Modify: `bin/vibe-uninstall:18,224,244`
- Modify: `test/unit/test_native_configs.rb:223`

- [ ] **Step 1: 修复 native_configs.rb**

```ruby
# lib/vibe/native_configs.rb:125
# 修改前:
"extends" => "~/.opencode/opencode.json"
# 修改后:
"extends" => "~/.config/opencode/opencode.json"
```

- [ ] **Step 2: 修复 target_renderers.rb 文案**

```ruby
# lib/vibe/target_renderers.rb:71
# 修改前:
Global workflow rules are loaded from `~/.opencode/`. This file adds project-specific context only.
# 修改后:
Global workflow rules are loaded from `~/.config/opencode/`. This file adds project-specific context only.
```

- [ ] **Step 3: 修复 init_support.rb 检测逻辑**

```ruby
# lib/vibe/init_support.rb:122
# 修改前:
return "opencode" if Dir.exist?(File.expand_path("~/.opencode"))
# 修改后:
return "opencode" if Dir.exist?(File.expand_path("~/.config/opencode"))
```

- [ ] **Step 4: 修复 bin/vibe 帮助文案**

```ruby
# bin/vibe:395
# 修改前:
init        Install global configuration for a platform (e.g., ~/.claude, ~/.opencode)
# 修改后:
init        Install global configuration for a platform (e.g., ~/.claude, ~/.config/opencode)

# bin/vibe:603
# 修改前:
vibe init --platform opencode       # Install OpenCode global config to ~/.opencode
# 修改后:
vibe init --platform opencode       # Install OpenCode global config to ~/.config/opencode
```

- [ ] **Step 5: 修复 bin/vibe-uninstall**

```ruby
# bin/vibe-uninstall:18
# 修改前:
"opencode" => "~/.opencode"
# 修改后:
"opencode" => "~/.config/opencode"

# bin/vibe-uninstall:224
# 修改前:
--remove-configs    Also remove platform configurations (e.g., ~/.claude, ~/.opencode)
# 修改后:
--remove-configs    Also remove platform configurations (e.g., ~/.claude, ~/.config/opencode)

# bin/vibe-uninstall:244
# 修改前:
- Platform configurations (e.g., ~/.claude, ~/.opencode)
# 修改后:
- Platform configurations (e.g., ~/.claude, ~/.config/opencode)
```

- [ ] **Step 6: 修复 test_native_configs.rb 断言**

```ruby
# test/unit/test_native_configs.rb:223
# 修改前:
assert_equal "~/.opencode/opencode.json", config["extends"]
# 修改后:
assert_equal "~/.config/opencode/opencode.json", config["extends"]
```

- [ ] **Step 7: 验证没有遗漏**

Run: `grep -r "~/.opencode" --include="*.rb" --include="*.md" --include="*.yaml" --include="*.json" .`
Expected: 无匹配（除非是历史兼容说明）

- [ ] **Step 8: 运行测试**

Run: `rake test`
Expected: 全部通过

- [ ] **Step 9: Commit**

```bash
git add lib/vibe/native_configs.rb lib/vibe/target_renderers.rb lib/vibe/init_support.rb bin/vibe bin/vibe-uninstall test/unit/test_native_configs.rb
git commit -m "fix(opencode): unify config path to ~/.config/opencode

Previously mixed ~/.opencode and ~/.config/opencode across codebase.
Now consistently uses ~/.config/opencode as the single source of truth.

Fixes: native_configs.rb, target_renderers.rb, init_support.rb,
       bin/vibe, bin/vibe-uninstall, test assertions"
```

---

## Chunk 3: P0-1 Native Config 生成链路

### Task 3: 修复 native config 生成链路

**Files:**
- Modify: `config/platforms.yaml`
- Modify: `lib/vibe/config_driven_renderers.rb:79-91`
- Modify: `lib/vibe/native_configs.rb` (可能需要添加新方法)

**问题分析:**
`generate_native_config` 通过文件名推导方法名：
- `settings.json` → `settings_json` (不存在，应该是 `claude_settings_config`)
- `opencode.json` → `opencode_json` (不存在，应该是 `opencode_config`)

**修复方案:** 在 platforms.yaml 中显式声明 builder 方法名

- [ ] **Step 1: 更新 platforms.yaml 添加 builder 配置**

```yaml
# config/platforms.yaml
native_config:
  global:
    type: json
    filename: settings.json
    builder: claude_settings_config
  project:
    type: json
    filename: settings.json
    builder: claude_settings_config

# opencode 部分同样修改
native_config:
  global:
    type: json
    filename: opencode.json
    builder: opencode_config
  project:
    type: json
    filename: opencode.json
    builder: opencode_project_config
```

- [ ] **Step 2: 重写 generate_native_config 方法**

```ruby
# lib/vibe/config_driven_renderers.rb:79-91
# 修改前:
def generate_native_config(output_root, manifest, config)
  config_path = File.join(output_root, config["filename"])

  case config["type"]
  when "json"
    # Use existing native config methods
    method_name = config["filename"].gsub(".", "_").gsub("-", "_")
    if respond_to?(method_name)
      content = send(method_name, manifest)
      write_json(config_path, content)
    end
  end
end

# 修改后:
def generate_native_config(output_root, manifest, config, mode)
  config_path = File.join(output_root, config["filename"])
  builder_method = config["builder"]
  
  unless builder_method
    raise ArgumentError, "Native config builder not specified for #{config['filename']}"
  end
  
  unless respond_to?(builder_method)
    raise ArgumentError, "Native config builder method not found: #{builder_method}"
  end

  case config["type"]
  when "json"
    content = send(builder_method, manifest)
    write_json(config_path, content)
  else
    raise ArgumentError, "Unsupported native config type: #{config['type']}"
  end
end
```

- [ ] **Step 3: 更新 render_platform 传递 mode 参数**

```ruby
# lib/vibe/config_driven_renderers.rb:46-49
# 修改前:
if native_config
  generate_native_config(output_root, manifest, native_config)
end

# 修改后:
if native_config
  generate_native_config(output_root, manifest, native_config, mode)
end
```

- [ ] **Step 4: 创建 E2E 测试验证 native config 生成**

```ruby
# test/e2e/test_native_config_generation.rb
require_relative '../test_helper'

class TestNativeConfigGeneration < Minitest::Test
  def setup
    @repo_root = File.expand_path('../..', __FILE__)
    @tmp_dir = Dir.mktmpdir
  end

  def teardown
    FileUtils.rm_rf(@tmp_dir)
  end

  def test_claude_code_generates_settings_json
    output = File.join(@tmp_dir, 'claude-code')
    system("#{@repo_root}/bin/vibe build claude-code --output #{output}")
    
    settings_path = File.join(output, 'settings.json')
    assert File.exist?(settings_path), "settings.json should be generated for claude-code"
    
    content = JSON.parse(File.read(settings_path))
    assert content['permissions'], "settings.json should have permissions"
  end

  def test_opencode_generates_opencode_json
    output = File.join(@tmp_dir, 'opencode')
    system("#{@repo_root}/bin/vibe build opencode --output #{output}")
    
    config_path = File.join(output, 'opencode.json')
    assert File.exist?(config_path), "opencode.json should be generated for opencode"
    
    content = JSON.parse(File.read(config_path))
    assert content['instructions'], "opencode.json should have instructions"
  end

  def test_opencode_project_extends_global
    output = File.join(@tmp_dir, 'opencode-project')
    system("#{@repo_root}/bin/vibe build opencode --output #{output} --project")
    
    config_path = File.join(output, 'opencode.json')
    content = JSON.parse(File.read(config_path))
    assert_equal "~/.config/opencode/opencode.json", content['extends']
  end
end
```

- [ ] **Step 5: 运行 E2E 测试**

Run: `ruby -Ilib:test test/e2e/test_native_config_generation.rb`
Expected: 全部通过

- [ ] **Step 6: 运行全部测试**

Run: `rake test`
Expected: 全部通过

- [ ] **Step 7: Commit**

```bash
git add config/platforms.yaml lib/vibe/config_driven_renderers.rb test/e2e/test_native_config_generation.rb
git commit -m "fix(native-config): fix config generation chain

Problem: config_driven_renderers derived method names from filenames,
which didn't match actual method names in native_configs.rb.

Solution:
1. Add explicit 'builder' field in platforms.yaml
2. Update generate_native_config to use builder config
3. Add fail-fast errors when builder is missing
4. Add E2E tests verifying settings.json and opencode.json generation

Fixes: build claude-code → settings.json, build opencode → opencode.json"
```

---

## Chunk 4: P0-2 Project/Global 语义闭环

### Task 4: 修复 project/global 语义闭环

**Files:**
- Modify: `config/platforms.yaml`
- Modify: `lib/vibe/config_driven_renderers.rb`
- Modify: `lib/vibe/native_configs.rb` (可能需要调整)

**问题分析:**
- Claude Code: project mode 仍复制整套 runtime（和 global 一样）
- OpenCode: project mode 应该 lightweight，但配置和 global 相同

**修复方案:** 
1. Claude Code: project mode 只生成必要入口 + .vibe/...
2. OpenCode: project mode 使用轻量 opencode.json 并正确 extends 全局配置

- [ ] **Step 1: 更新 platforms.yaml 区分 project/global 的 runtime_dirs**

```yaml
# config/platforms.yaml - claude-code 部分
runtime_dirs:
  global:
    - rules
    - docs
    - skills
    - agents
    - commands
    - memory
  project: []  # Project mode: lightweight, no runtime copy

# 修改 doc_types 区分 project/global
doc_types:
  global: [behavior, safety, task_routing, test_standards]
  project: [behavior, safety, tools]  # Project: includes tools for consistent CLAUDE.md/AGENTS.md references
```

- [ ] **Step 2: 更新 copy_runtime_dirs 方法支持 mode 区分**

```ruby
# lib/vibe/config_driven_renderers.rb:60-76
# 修改前:
def copy_runtime_dirs(output_root, dirs, mode)
  dirs.each do |entry|
    # ...
  end
end

# 修改后:
def copy_runtime_dirs(output_root, dirs_config, mode)
  dirs = dirs_config.is_a?(Hash) ? dirs_config[mode] : dirs_config
  return if dirs.nil? || dirs.empty?
  
  dirs.each do |entry|
    source = File.join(@repo_root, entry)
    next unless File.exist?(source)
    # ... rest unchanged
  end
end
```

- [ ] **Step 3: 更新 render_platform 处理新的 runtime_dirs 结构**

```ruby
# lib/vibe/config_driven_renderers.rb:40-44
# 修改前:
if config["runtime_dirs"] && !config["runtime_dirs"].empty?
  copy_runtime_dirs(output_root, config["runtime_dirs"], mode)
end

# 修改后:
if config["runtime_dirs"]
  copy_runtime_dirs(output_root, config["runtime_dirs"], mode)
end
```

- [ ] **Step 4: 验证 project/global 差异的 E2E 测试**

```ruby
# test/e2e/test_project_global_semantics.rb
require_relative '../test_helper'

class TestProjectGlobalSemantics < Minitest::Test
  def setup
    @repo_root = File.expand_path('../..', __FILE__)
    @tmp_dir = Dir.mktmpdir
  end

  def teardown
    FileUtils.rm_rf(@tmp_dir)
  end

  def test_claude_code_global_copies_runtime
    output = File.join(@tmp_dir, 'claude-global')
    system("#{@repo_root}/bin/vibe build claude-code --output #{output}")
    
    assert File.exist?(File.join(output, 'rules')), "Global should have rules/"
    assert File.exist?(File.join(output, 'skills')), "Global should have skills/"
    assert File.exist?(File.join(output, 'memory')), "Global should have memory/"
  end

  def test_claude_code_project_is_lightweight
    output = File.join(@tmp_dir, 'claude-project')
    system("#{@repo_root}/bin/vibe build claude-code --output #{output} --project")
    
    refute File.exist?(File.join(output, 'rules')), "Project should NOT have rules/"
    refute File.exist?(File.join(output, 'skills')), "Project should NOT have skills/"
    assert File.exist?(File.join(output, 'CLAUDE.md')), "Project should have CLAUDE.md"
    assert File.exist?(File.join(output, '.vibe')), "Project should have .vibe/"
  end

  def test_opencode_global_has_full_config
    output = File.join(@tmp_dir, 'opencode-global')
    system("#{@repo_root}/bin/vibe build opencode --output #{output}")
    
    config = JSON.parse(File.read(File.join(output, 'opencode.json')))
    refute config['extends'], "Global config should not extend"
    assert config['permission'], "Global should have full permission config"
  end

  def test_opencode_project_extends_global
    output = File.join(@tmp_dir, 'opencode-project')
    system("#{@repo_root}/bin/vibe build opencode --output #{output} --project")
    
    config = JSON.parse(File.read(File.join(output, 'opencode.json')))
    assert_equal "~/.config/opencode/opencode.json", config['extends']
    # Project should have minimal instructions
    assert config['instructions'].length < 5, "Project should have minimal instructions"
  end
end
```

- [ ] **Step 5: 运行 E2E 测试**

Run: `ruby -Ilib:test test/e2e/test_project_global_semantics.rb`
Expected: 全部通过

- [ ] **Step 6: Commit**

```bash
git add config/platforms.yaml lib/vibe/config_driven_renderers.rb test/e2e/test_project_global_semantics.rb
git commit -m "fix(project-global): distinguish project vs global semantics

Claude Code:
- Global: full runtime copy (rules/, skills/, memory/, etc.)
- Project: lightweight, only CLAUDE.md + .vibe/

OpenCode:
- Global: full opencode.json with complete permissions
- Project: minimal opencode.json that extends global config

Adds E2E tests asserting the differences."
```

---

## Chunk 5: P1-6 Smoke Test 修复

### Task 5: 修复 smoke test

**Files:**
- Modify: `bin/vibe-smoke`

- [ ] **Step 1: 添加关键产物存在性断言**

```bash
# bin/vibe-smoke 在现有测试后添加:

# --- Native config generation verification ---
echo "Checking native config generation..."
test -f "${TMP_DIR}/generated/claude-code/settings.json" || { echo "FAIL: claude-code missing settings.json"; exit 1; }
test -f "${TMP_DIR}/generated/opencode/opencode.json" || { echo "FAIL: opencode missing opencode.json"; exit 1; }
echo "✓ Native configs generated"
```

- [ ] **Step 2: 添加 project/global 差异验证**

```bash
# 在 smoke test 中添加:

# --- Project/Global semantics verification ---
echo "Checking project/global semantics..."
"${REPO_ROOT}/bin/vibe" build claude-code --output "${TMP_DIR}/generated/claude-project" --project >/dev/null

# Project should NOT have runtime dirs
if [ -d "${TMP_DIR}/generated/claude-project/rules" ]; then
  echo "FAIL: claude-code project should not have rules/"
  exit 1
fi

# But should have CLAUDE.md
test -f "${TMP_DIR}/generated/claude-project/CLAUDE.md" || { echo "FAIL: claude-code project missing CLAUDE.md"; exit 1; }

echo "✓ Project/global semantics correct"
```

- [ ] **Step 3: 运行 smoke test**

Run: `./bin/vibe-smoke`
Expected: "vibe smoke passed: ..."

- [ ] **Step 4: Commit**

```bash
git add bin/vibe-smoke
git commit -m "test(smoke): add native config and project/global assertions

Smoke test now verifies:
- settings.json generated for claude-code
- opencode.json generated for opencode
- Project mode is lightweight (no runtime dirs)
- Project mode still has entrypoint (CLAUDE.md)"
```

---

## Chunk 6: P1-8 CI 修复

### Task 6: 修复 CI 与双平台策略一致

**Files:**
- Modify: `.github/workflows/ci.yml`

- [ ] **Step 1: 更新 CI 只检查双平台**

```yaml
# .github/workflows/ci.yml:52-58
# 修改前:
for target in claude-code codex-cli cursor kimi-code opencode vscode warp antigravity; do

# 修改后:
for target in claude-code opencode; do
```

- [ ] **Step 2: 更新 target adapters 检查**

```yaml
# .github/workflows/ci.yml:156-162
# 修改前:
for target in claude-code codex-cli cursor kimi-code opencode vscode warp antigravity; do

# 修改后:
for target in claude-code opencode; do
  # 只检查文档存在，不强制要求实现
  if [ -f "targets/${target}.md" ]; then
    echo "✓ targets/${target}.md exists"
  fi
done

# 检查其他平台文档标记为 planned
echo "Checking planned target documentation..."
for target in codex-cli cursor kimi-code vscode warp antigravity; do
  if [ -f "targets/${target}.md" ]; then
    echo "✓ targets/${target}.md exists (planned)"
  fi
done
```

- [ ] **Step 3: Commit**

```bash
git add .github/workflows/ci.yml
git commit -m "ci: align with dual-platform strategy

CI now only validates claude-code and opencode as active platforms.
Other platforms are checked as 'planned' documentation only.

Fixes: CI was checking 8 platforms but implementation only supports 2"
```

---

## Chunk 7: P1-5 E2E 测试补齐

### Task 7: 创建综合 E2E 测试套件

**Files:**
- Create: `test/e2e/test_build_command.rb`
- Create: `test/e2e/test_apply_command.rb`
- Create: `test/e2e/test_use_deploy_commands.rb`

- [ ] **Step 1: 创建 build 命令 E2E 测试**

```ruby
# test/e2e/test_build_command.rb
require_relative '../test_helper'

class TestBuildCommand < Minitest::Test
  def setup
    @repo_root = File.expand_path('../..', __FILE__)
    @tmp_dir = Dir.mktmpdir
    @vibe = "#{@repo_root}/bin/vibe"
  end

  def teardown
    FileUtils.rm_rf(@tmp_dir)
  end

  def test_build_claude_code_creates_all_expected_files
    output = File.join(@tmp_dir, 'output')
    system("#{@vibe} build claude-code --output #{output}")
    
    assert File.exist?(File.join(output, 'CLAUDE.md'))
    assert File.exist?(File.join(output, 'settings.json'))
    assert File.exist?(File.join(output, '.vibe/manifest.json'))
    assert File.exist?(File.join(output, '.vibe/claude-code/behavior-policies.md'))
  end

  def test_build_opencode_creates_all_expected_files
    output = File.join(@tmp_dir, 'output')
    system("#{@vibe} build opencode --output #{output}")
    
    assert File.exist?(File.join(output, 'AGENTS.md'))
    assert File.exist?(File.join(output, 'opencode.json'))
    assert File.exist?(File.join(output, '.vibe/manifest.json'))
    assert File.exist?(File.join(output, '.vibe/opencode/behavior-policies.md'))
  end

  def test_build_with_overlay_applies_overlay
    output = File.join(@tmp_dir, 'overlay-test')
    overlay = "#{@repo_root}/examples/project-overlay.yaml"
    system("#{@vibe} build claude-code --output #{output} --overlay #{overlay}")
    
    manifest = JSON.parse(File.read(File.join(output, '.vibe/manifest.json')))
    refute_nil manifest['overlay']
    refute_empty manifest['overlay']['applied_overlays']
  end
end
```

- [ ] **Step 2: 运行 E2E 测试**

Run: `ruby -Ilib:test test/e2e/test_build_command.rb`
Expected: 全部通过

- [ ] **Step 3: Commit**

```bash
git add test/e2e/
git commit -m "test(e2e): add comprehensive E2E test suite

Adds E2E tests for:
- build command for both platforms
- Native config generation verification
- Overlay application verification
- Project/global mode differences"
```

---

## Chunk 8: P1-7 平台支持状态 SSOT

### Task 8: 统一平台支持状态文档

**Files:**
- Modify: `README.md`
- Modify: `README.zh-CN.md`
- Modify: `docs/faq.md`
- Modify: `targets/README.md`

- [ ] **Step 1: 更新 README.md 平台状态**

```markdown
## Supported Platforms

| Platform | Status | Notes |
|----------|--------|-------|
| Claude Code | ✅ Active | Fully supported, production-ready |
| OpenCode | 🧪 Exploratory | Basic support, actively developed |
| Codex CLI | 📋 Planned | On roadmap |
| Cursor | 📋 Planned | On roadmap |
| Kimi Code | 📋 Planned | On roadmap |
| VS Code | 📋 Planned | On roadmap |
| Warp | 📋 Planned | On roadmap |
| Antigravity | 📋 Planned | On roadmap |
```

- [ ] **Step 2: 更新 targets/README.md**

```markdown
# Target Platform Adapters

## Active Platforms

### Claude Code
- **Status**: Active
- **Maturity**: Production-ready
- **Build**: `bin/vibe build claude-code`

### OpenCode  
- **Status**: Exploratory
- **Maturity**: Basic support
- **Build**: `bin/vibe build opencode`

## Planned Platforms

- Codex CLI
- Cursor
- Kimi Code
- VS Code
- Warp
- Antigravity
```

- [ ] **Step 3: Commit**

```bash
git add README.md README.zh-CN.md docs/faq.md targets/README.md
git commit -m "docs: unify platform support status across documentation

Establishes single source of truth for platform status:
- Claude Code: Active (production-ready)
- OpenCode: Exploratory (basic support)
- Others: Planned

Updates: README.md, README.zh-CN.md, docs/faq.md, targets/README.md"
```

---

## 实施顺序总结

### PR A: 核心修复 (P0)
1. ✅ P0-4: 修复测试 (Task 1)
2. ✅ P0-3: 统一 OpenCode 路径 (Task 2)
3. ✅ P0-1: 修复 native config 生成 (Task 3)
4. ✅ P0-2: 修复 project/global 语义 (Task 4)

### PR B: 质量基础设施 (P1)
5. ✅ P1-6: 修复 smoke test (Task 5)
6. ✅ P1-8: 修复 CI (Task 6)
7. ✅ P1-5: 补齐 E2E 测试 (Task 7)

### PR C: 状态统一 (P1-7)
8. ✅ P1-7: 统一平台支持状态文档 (Task 8)

### PR D: 后续清理 (P2)
9. P2-9: 文档诚实化
10. P2-10: 决策 knowledge.yaml

---

## 验收标准

每个 Task 完成后必须满足：

1. **rake test 全绿** - 0 failures, 0 errors
2. **bin/vibe-smoke 通过** - 无副作用，可重复运行
3. **E2E 测试覆盖** - 新增测试验证修复的问题
4. **grep 验证** - 相关模式不再出现（如 ~/.opencode）
5. **文档一致** - 所有文档口径统一

---

**Plan complete and saved to `docs/superpowers/plans/2026-03-13-technical-optimization.md`. Ready to execute?**
