# 技能自适应系统设计方案

**文档版本**: 2.0
**更新日期**: 2026-03-28
**状态**: ✅ 已实现

---

## 📋 执行摘要

### 背景
当前项目支持多种技能包（Superpowers、gstack 等），但缺乏自动化的技能发现、安全审查和智能路由机制。用户在安装新技能后，需要手动将其注册到路由系统。

### 已实现的目标
1. ✅ **自动技能发现**: 扫描文件系统自动发现新技能
2. ✅ **安全审查**: 基于 SKILL-INJECT 论文的安全扫描
3. ✅ **智能路由**: 三层路由系统自动匹配用户意图到合适技能
4. ✅ **项目级注册**: 默认注册到项目隔离的路由配置
5. ✅ **技能选择**: 自动在多个来源（builtin/superpowers/gstack）中选择最合适技能

### 核心功能
- `vibe skills discover`: 发现未注册技能并显示安全审查结果
- `vibe skills register`: 注册技能到项目级路由
- `vibe route "<请求>">`: 智能路由用户请求到合适技能
- **自动路由**: AI 读取 CLAUDE.md 后自动检查路由配置

---

## 🏗️ 系统架构图

```
┌─────────────────────────────────────────────────────────────────────────┐
│                        Smart Skill Routing System                       │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐     │
│  │  User Request   │───▶│  Skill Router   │───▶│  Skill Execution│     │
│  │  "帮我评审代码" │    │                 │    │                 │     │
│  └─────────────────┘    └────────┬────────┘    └─────────────────┘     │
│                                   │                                     │
│                                   ▼                                     │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                      Three-Layer Routing                        │   │
│  ├─────────────────────────────────────────────────────────────────┤   │
│  │                                                                 │   │
│  │  Layer 1: Explicit Override                                     │   │
│  │    - 用户明确指定 "用 gstack" / "用 superpowers"                 │   │
│  │                                                                 │   │
│  │  Layer 2: Scenario Matching (skill-routing.yaml)               │   │
│  │    - 匹配场景: code_review, debugging, planning...             │   │
│  │    - 应用冲突解决策略                                          │   │
│  │                                                                 │   │
│  │  Layer 3: Semantic Matching                                     │   │
│  │    - 用户输入 vs skill intent 相似度计算                        │   │
│  │                                                                 │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                   │                                     │
│                                   ▼                                     │
│  ┌─────────────────────────────────────────────────────────────────┐   │
│  │                    Skill Discovery & Registry                   │   │
│  │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │   │
│  │  │   Discover   │  │    Audit     │  │   Register   │          │   │
│  │  │  (扫描目录)   │──▶│  (安全检查)  │──▶│ (项目级注册) │          │   │
│  │  └──────────────┘  └──────────────┘  └──────────────┘          │   │
│  └─────────────────────────────────────────────────────────────────┘   │
│                                                                         │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## 📦 核心模块

### 1. SkillDiscovery（技能发现器）

**文件**: `lib/vibe/skill_discovery.rb`

**职责**: 扫描技能目录，提取元数据，执行安全审查

```ruby
discovery = Vibe::SkillDiscovery.new

# 发现所有未注册技能
unregistered = discovery.unregistered_skills
# => [{ id: 'project/my-skill', name: '...', ... }, ...]

# 安全审查
audit = discovery.security_audit(skill_path)
# => { safe: false, red_flags: [...], risk_level: :high }
```

**扫描路径**:
- `~/.config/skills/personal`
- `~/.config/skills/superpowers`
- `~/.config/skills/gstack`
- `skills/` (项目本地)

### 2. SkillRegistration（技能注册器）

**文件**: `lib/vibe/skill_registration.rb`

**职责**: 将技能注册到项目级路由配置

```ruby
registration = Vibe::SkillRegistration.new

# 交互式注册
registration.interactive_register

# 自动注册（仅安全技能）
registration.register_new_skills(auto_register: true)

# 注册到特定场景
registration.register_skill(skill, scenario: 'code_review', as_alternative: true)
```

**注册位置**: `.vibe/skill-routing.yaml`（项目级）

### 3. SkillRouter（智能路由器）

**文件**: `lib/vibe/skill_router.rb`

**职责**: 将用户请求路由到最合适的技能

```ruby
router = Vibe::SkillRouter.new

# 路由用户请求
result = router.route('帮我评审代码')
# => {
#   matched: true,
#   skill: '/review',
#   source: 'gstack',
#   scenario: 'code_review',
#   confidence: :high,
#   alternatives: [...]
# }
```

### 4. SecurityScanner（安全扫描器）

**文件**: `lib/vibe/security_scanner.rb`

**职责**: 基于 SKILL-INJECT 论文的安全审查

**检测项**:
- 动态代码执行 (`eval`, `exec`)
- 系统命令 (`system`, 反引号)
- 危险操作 (`rm -rf`, 文件上传)
- 网络请求 (`curl`, `fetch`, `POST`)
- **合规语言陷阱** ("authorized backup", "compliance requirement")

---

## 🔐 安全设计

### 基于 SKILL-INJECT 论文 (arxiv:2602.20156)

> **关键发现**: 使用"合规语言"（如 "authorized backup" / "compliance requirement"）的攻击成功率提高 2-3 倍，因为会误导用户认为操作是合法的。

**我们的防护措施**:

1. **显式检测合规语言**
   ```ruby
   compliance_phrases = [
     /authorized backup/i,
     /compliance requirement/i,
     /mandatory security/i,
     /official policy/i
   ]
   ```

2. **风险等级评估**
   - `critical`: 动态执行 + 网络请求
   - `high`: 3+ red flags
   - `medium`: 1-2 red flags
   - `low`: 无风险

3. **默认不信任**
   - 所有第三方技能需要显式注册
   - 高风险技能必须用户确认
   - 自动备份配置（支持回滚）

---

## 🎨 CLI 界面

### vibe skills discover

```bash
$ vibe skills discover

🔍 扫描技能目录...
项目: /Users/huchen/Projects/my-project
已发现技能: 35
已注册: 32
未注册: 3

发现 3 个未注册技能:

[1] my-custom-debug
    ID: project/my-custom-debug
    来源: project
    描述: 自定义调试流程
    安全: ✅ 通过

[2] dangerous-skill
    ID: project/dangerous-skill
    来源: project
    描述: 有危险的技能
    安全: ⚠️  风险 high
      • Dynamic code execution (eval)
      • Recursive delete command
      • Compliance language (potential legitimizing)

💡 使用 `vibe skills register` 注册这些技能
```

### vibe skills register --interactive

```bash
$ vibe skills register --interactive

🎯 技能注册向导
==================================================
发现 3 个未注册技能:

[1/3] my-custom-debug
   ID: project/my-custom-debug
   描述: 自定义调试流程
   意图: Debug application errors

🔒 安全审查中...
   ✅ 安全检查通过

注册此技能? [Y/n/s(跳过)/d(详情)] y
   选择应用场景:
      1. 代码审查 (code_review)
      2. 调试 (debugging)
      3. 规划 (planning)
      ...
   选择 [1-8]: 2

   ✅ 已注册到场景: debugging

==================================================
注册完成: 1/3 个技能已注册

项目级路由配置已更新: .vibe/skill-routing.yaml
```

### vibe route "<请求>"

```bash
$ vibe route "帮我评审代码"

📥 输入: 帮我评审代码
----------------------------------------
✅ 匹配到技能: /review
   来源: gstack
   场景: code_review
   原因: 专注于预发布审查，有 SQL 安全、LLM 信任边界检查、自动修复能力
   置信度: high

💡 替代方案:
   • /receiving-code-review (superpowers) - 需要全面质量检查
   • /codex (gstack) - 需要跨模型审查

🚀 执行建议:
   1. 加载技能: read ~/.config/skills/gstack/review/SKILL.md
   2. 遵循技能中的步骤执行
   3. 完成后运行验证
```

---

## 📊 数据结构

### 项目级路由配置 (.vibe/skill-routing.yaml)

```yaml
schema_version: 1

# 场景路由规则
routing_rules:
  - scenario: code_review
    description: 代码审查，发现生产环境 bug
    primary:
      skill: /review
      source: gstack
      reason: "专注于预发布审查，有 SQL 安全、LLM 信任边界检查、自动修复能力"
    alternatives:
      - skill: /receiving-code-review
        source: superpowers
        trigger: "需要全面的质量检查"
        priority: P2
    conflict_resolution: prefer_gstack_for_pre_landing
    keywords: ["评审", "review", "检查代码", "CR", "代码审查"]

# 项目专属技能（默认注册到这里）
exclusive_skills:
  - scenario: my_custom_debug_workflow
    skill: project/my-custom-debug
    source: project
    reason: "自定义调试流程"
    keywords: ["调试", "debug", "错误"]

# 审计追踪
project_skills:
  - id: project/my-custom-debug
    registered_at: "2026-03-28T10:00:00Z"
    path: /Users/.../skills/my-custom-debug
```

### 技能元数据 (SKILL.md)

```yaml
---
name: My Custom Debug
namespace: project
description: Custom debugging workflow
intent: Debug application errors with custom approach
trigger_mode: suggest
priority: P2
requires_tools:
  - Read
  - Grep
  - Bash
---

# My Custom Debug Skill

## When to use

When you encounter debug errors...
```

---

## 🔄 完整工作流

### 场景 1: 安装并注册新技能

```bash
# 1. 安装新技能包
git clone https://github.com/example/awesome-skills ~/.config/skills/awesome

# 2. 发现新技能
vibe skills discover
# → 发现 awesome/advanced-debug 技能

# 3. 安全审查 + 注册
vibe skills register --interactive
# → 通过安全检查
# → 注册到 debugging 场景

# 4. 现在 AI 会自动使用
# 用户: "帮我调试代码"
# AI: 匹配 debugging 场景 → 使用 awesome/advanced-debug
```

### 场景 2: 冲突解决（gstack vs superpowers）

```bash
# 用户说: "帮我评审代码"

# 系统处理:
# 1. 匹配场景: code_review
# 2. 发现多个可用技能:
#    - gstack: /review (pre-landing, SQL安全, 自动修复)
#    - superpowers: /receiving-code-review (全面质量检查)
# 3. 应用策略: prefer_gstack_for_pre_landing
# 4. 选择: /review (gstack)
# 5. 执行: 加载 skill 并执行审查
```

### 场景 3: 用户覆盖选择

```bash
# 用户说: "用 superpowers 评审代码"

# 系统处理:
# 1. Layer 1: 检测到显式覆盖 "用 superpowers"
# 2. 切换到 superpowers 版本的 review
# 3. 执行: /receiving-code-review (superpowers)
```

---

## 🧪 测试

### 运行测试

```bash
# 技能发现和注册测试
bundle exec ruby -Ilib:test test/unit/test_skill_discovery_and_registration.rb

# 智能路由测试
bundle exec ruby -Ilib:test test/unit/test_skill_router.rb

# 完整测试套件
bundle exec rake test
```

### 测试统计

```
1394 runs, 3609 assertions, 0 failures, 0 errors, 7 skips
Coverage: 72.21% line, 55.97% branch
```

---

## 📁 文件清单

| 文件 | 功能 | 行数 |
|------|------|------|
| `lib/vibe/skill_discovery.rb` | 技能扫描和元数据提取 | 271 |
| `lib/vibe/skill_registration.rb` | 项目级注册和安全审查 | 362 |
| `lib/vibe/skill_router.rb` | 智能路由引擎 | 238 |
| `lib/vibe/skill_router_commands.rb` | CLI 路由命令 | 147 |
| `lib/vibe/security_scanner.rb` | 安全扫描器（已有） | 152 |
| `lib/vibe/cli/skills_commands.rb` | CLI 技能命令 | 500+ |
| `test/unit/test_skill_discovery_and_registration.rb` | 发现和注册测试 | 304 |
| `test/unit/test_skill_router.rb` | 路由测试 | 186 |

---

## 🚀 后续优化

### Phase 2: 增强功能

1. **语义相似度计算**
   - 使用 embedding 计算用户输入与 skill intent 的相似度
   - 提高匹配准确性

2. **技能市场**
   - `vibe skills search <keyword>`
   - `vibe skills install <market-id>`

3. **自动更新检测**
   - 检测技能包更新
   - 提醒用户审查变更

4. **团队协作**
   - 共享 `.vibe/skill-routing.yaml`
   - 团队技能标准配置

---

## ✅ 验收标准

### 已实现

- [x] `vibe skills discover` 发现未注册技能
- [x] `vibe skills register` 注册技能到项目级路由
- [x] 安全审查（SKILL-INJECT 防护）
- [x] 三层智能路由（显式覆盖→场景匹配→语义匹配）
- [x] 自动备份配置
- [x] 冲突解决策略（gstack vs superpowers）
- [x] 测试覆盖率 > 70%
- [x] 完整文档

### 后续实现

- [ ] 语义相似度计算（embedding）
- [ ] 技能市场集成
- [ ] 自动更新检测
- [ ] 团队协作功能

---

**文档更新完成！系统已实现并可用。**
