# VibeSOP

[English](README.md) | **中文**

> **不是教程，不是玩具配置。是一套真正能落地交付的生产 SOP。**
>
> 经过实战检验的多平台 AI 辅助开发工作流 SOP——支持 Claude Code、OpenCode 及未来更多平台，提供结构化配置、记忆管理和一致的开发实践。

```
┌─────────────────────────────────────────────────────────────┐
│  可移植核心（跨工具通用）                                      │
│  core/  →  模型层级、技能定义、策略规则、安全规范              │
├─────────────────────────────────────────────────────────────┤
│  目标平台适配器                                               │
│  Claude Code ✅ | OpenCode ✅ | Cursor | VS Code | ...      │
├─────────────────────────────────────────────────────────────┤
│  项目级配置 (.vibe/overlay.yaml)                              │
│  你的自定义规则和偏好                                          │
└─────────────────────────────────────────────────────────────┘
```

---

## 🚀 30秒快速开始

```bash
# 1. 克隆并安装
git clone https://github.com/nehcuh/vibesop.git && cd vibesop
bin/vibe-install          # macOS/Linux
# bin\vibe-install.bat    # Windows

# 2. 配置你的 AI 工具（选择一项）
vibe onboard                        # 推荐：5步交互式引导
# 或: vibe quickstart              # 一键配置
# 或: vibe init --platform claude-code

# 3. 应用到你的项目
cd ~/my-project
vibe switch --platform claude-code

# 4. 开始编码
claude    # AI 自动加载配置
```

**验证安装：**
```bash
vibe doctor      # 检查环境
vibe --version   # 查看版本
```

---

## 📋 60秒了解架构

### 三层运行时

| 层级 | 内容 | 加载时机 | 位置 |
|------|------|---------|------|
| **0: 规则层** | 核心行为规则 | 始终加载 | `~/.claude/rules/` |
| **1: 文档层** | 参考指南 | 按需加载 | `~/.claude/docs/` |
| **2: 记忆层** | 项目工作状态 | 会话开始时 | `memory/*.md` |

### 核心概念

- **可移植核心**（`core/`）：跨工具的通用工作流语义。添加新 AI 平台只需编写适配器，无需重写规则。
- **Overlay 系统**：项目级定制在 `.vibe/overlay.yaml` 中。保持你的修改同时升级基础配置。
- **智能技能路由**：说"帮我评审代码" → AI 自动从 builtin/superpowers/gstack 中选择最佳技能。

> **📖 核心理念**：阅读 [PRINCIPLES.md](PRINCIPLES.md) — 生产优先、结构化优于提示、记忆优于智能、验证优于自信、可移植优于特定。

---

## 🎯 常见任务速查

### 初始化

| 任务 | 命令 | 详见 |
|------|------|------|
| 首次配置 | `vibe onboard` | [安装指南](#安装) |
| 添加其他平台 | `vibe init --platform opencode` | [平台支持](#平台支持) |
| 应用到项目 | `vibe switch claude-code` | [项目配置](#项目配置) |
| 检查状态 | `vibe doctor` | [故障排查](#故障排查) |

### 日常开发

| 任务 | 命令 | 详见 |
|------|------|------|
| 记录错误 | `vibe memory record` | [记忆系统](#记忆系统) |
| 学习模式 | `vibe instinct learn` | [Instinct 学习](#instinct-学习) |
| 创建检查点 | `vibe checkpoint create 重构前` | [检查点](#代码检查点) |
| 智能路由 | `vibe route "帮我评审代码"` | [智能路由](#智能路由) |

### 技能管理

| 任务 | 命令 | 详见 |
|------|------|------|
| 发现新技能 | `vibe skills discover` | [技能指南](docs/skills-guide.md) |
| 注册技能 | `vibe skills register --interactive` | [技能注册](#技能管理) |
| 查看技能列表 | `vibe skills list` | - |
| 适配技能 | `vibe skills adapt superpowers/tdd` | - |

---

## 📚 文档导航

### 必读文档

| 文档 | 用途 | 何时阅读 |
|------|------|---------|
| [PRINCIPLES.md](PRINCIPLES.md) | 核心理念 | **使用之前** |
| [快速开始指南](#快速开始详细) | 详细步骤 | 首次配置 |
| [架构概览](docs/architecture/README.md) | 工作原理 | 理解内部机制 |

### 按任务查找

| 任务 | 文档 |
|------|------|
| 项目定制 | [Project Overlays](docs/project-overlays.md), [Overlay 教程](docs/overlay-tutorial.md) |
| 技能路由 | [技能路由](docs/claude/skills/routing.md), [任务路由](docs/task-routing.md) |
| 添加新平台 | [目标适配器](targets/README.md) |
| 集成外部工具 | [集成指南](docs/integrations.md) |
| 故障排查 | [故障排查](docs/troubleshooting.md) |

### 完整参考

| 主题 | 位置 |
|------|------|
| 所有 CLI 命令 | [完整命令参考](#完整命令参考) |
| 模型层级与路由 | [模型配置](#模型配置指南) |
| 安全策略 | [安全策略](core/security/policy.yaml) |
| 技能注册表 | [技能注册表](core/skills/registry.yaml) |

---

## 🛠️ 安装

### 环境要求

- **Ruby** >= 2.6.0（用于 CLI 生成器）
  - macOS：预装
  - Linux：`sudo apt install ruby-full`
  - Windows：[RubyInstaller](https://rubyinstaller.org/)
- **AI 工具**：Claude Code、OpenCode 或其他支持的平台

### 平台特定安装

```bash
# macOS/Linux
git clone https://github.com/nehcuh/vibesop.git && cd vibesop
bin/vibe-install

# Windows (cmd.exe - 无需管理员)
git clone https://github.com/nehcuh/vibesop.git && cd vibesop
bin\vibe-install.bat
```

详见 [Windows 安装指南](docs/windows-installation.md)。

---

## 🎨 核心功能

### 智能技能路由

```bash
$ vibe route "帮我评审代码"

📥 输入: 帮我评审代码
----------------------------------------
✅ 匹配到技能: /review
   来源: gstack
   场景: code_review
   置信度: high

💡 替代方案:
   • /receiving-code-review (superpowers) - 全面质量检查
   • /codex (gstack) - 跨模型审查
```

路由系统根据请求匹配场景，从可用来源中选择最佳技能。

### 记忆系统

三层记忆架构：

```
memory/
├── session.md           # 热层：每日进度、进行中的任务
├── project-knowledge.md # 温层：技术陷阱、模式经验
└── overview.md          # 冷层：目标、基础设施
```

自动或手动记录错误：
```bash
vibe memory enable              # 自动记录
vibe memory record              # 手动记录
vibe memory stats               # 查看统计
```

### 技能发现与注册

```bash
# 1. 安装新技能包
git clone https://github.com/example/skills ~/.config/skills/custom

# 2. 发现并审计
vibe skills discover

# 3. 注册（含安全检查）
vibe skills register --interactive
```

技能以项目级注册到 `.vibe/skill-routing.yaml` — 隔离且可版本控制。

---

## 📖 详细指南

### 快速开始（详细）

**场景 1：首次配置**
```bash
vibe onboard                    # 交互式 5 步引导
# 或: vibe quickstart          # 非交互式

# 验证
cd ~/my-project
vibe switch claude-code
claude
```

**场景 2：多平台使用**
```bash
vibe init --platform claude-code
vibe init --platform opencode

cd ~/project-a && vibe switch claude-code
cd ~/project-b && vibe switch opencode
```

**场景 3：团队项目自定义规则**
```bash
# 创建 overlay
cat > .vibe/overlay.yaml << 'EOF'
profile: node-fullstack
policies:
  test_command: "npm test"
  lint_command: "npm run lint"
EOF

# 应用 overlay
vibe switch claude-code   # 自动发现 overlay
```

### 项目配置

应用工作流到现有项目：

```bash
cd /path/to/project
vibe apply claude-code    # 或: vibe switch claude-code

# 使用自定义 overlay
vibe apply claude-code --overlay ./my-overlay.yaml
```

### 平台支持

| 平台 | 状态 | 命令 |
|------|------|------|
| Claude Code | ✅ 生产级 | `vibe init --platform claude-code` |
| OpenCode | ✅ 功能完整 | `vibe init --platform opencode` |
| Cursor | 📝 计划中 | - |
| VS Code | 📝 计划中 | - |
| Warp | 📝 计划中 | - |
| Kimi Code | 📝 计划中 | - |

---

## 🔧 完整命令参考

### 配置与初始化

```bash
vibe init --platform <platform>     # 安装全局配置
vibe quickstart                      # 一键配置
vibe onboard                         # 引导式 5 步配置
vibe doctor                          # 检查环境
vibe targets                         # 列出平台
```

### 项目操作

```bash
vibe build <target>                  # 从 core/ 生成配置
vibe use <target> <dir>             # 部署到全局配置目录
vibe switch <target>                # 应用到当前项目
vibe apply <target>                 # switch 的别名
vibe inspect                         # 显示项目/目标状态
```

### 技能管理

```bash
vibe skills check                    # 检查新技能
vibe skills list                     # 列出所有技能
vibe skills discover                 # 发现未注册技能
vibe skills register                 # 注册技能（交互式/自动）
vibe skills adapt <id>               # 适配特定技能
vibe skills skip <id>                # 跳过技能
vibe skills docs <id>                # 查看技能文档
vibe skills install <pack>           # 安装技能包
vibe route "<request>"               # 智能技能路由
```

### 高级功能

```bash
# Instinct 学习
vibe instinct learn                  # 从会话创建
vibe instinct status                 # 查看模式
vibe instinct export <file>          # 团队导出
vibe instinct import <file>          # 导入模式

# 记忆管理
vibe memory record                   # 记录错误/解决方案
vibe memory stats                    # 查看统计
vibe memory enable/disable           # 开关自动记录

# 代码检查点
vibe checkpoint create <name>        # 创建快照
vibe checkpoint list                 # 列出检查点
vibe checkpoint rollback <name>      # 恢复快照

# 并行开发
vibe worktree create <branch>        # 创建隔离工作树
vibe worktree list                   # 列出工作树
vibe cascade run <config.yaml>       # 运行并行流水线

# 安全与质量
vibe scan file <file>                # 安全扫描
```

---

## 🏗️ 架构深入

### 可移植核心

`core/` 目录包含跨工具的通用工作流语义：

```
core/
├── models/
│   ├── tiers.yaml          # 能力层级（critical_reasoner, workhorse_coder...）
│   └── providers.yaml      # 平台映射
├── skills/
│   └── registry.yaml       # 可移植技能定义
├── security/
│   └── policy.yaml         # P0/P1/P2 严重级别语义
└── policies/
    ├── behaviors.yaml      # 行为策略 schema
    ├── task-routing.yaml   # 任务复杂度规则
    └── test-standards.yaml # 测试要求
```

### 目录结构

```
vibesop/
├── bin/
│   ├── vibe                # 主 CLI
│   ├── vibe-install        # 安装脚本
│   └── vibe-smoke          # 冒烟测试
├── lib/vibe/               # 50+ Ruby 模块
│   ├── skill_router.rb     # 智能路由
│   ├── skill_discovery.rb  # 技能扫描
│   └── ...
├── core/                   # 可移植 SSOT
├── targets/                # 平台适配器
├── skills/                 # 内置技能
├── rules/                  # 核心行为规则
├── docs/                   # 参考指南
├── examples/               # Overlay 示例
└── test/                   # 测试套件
```

详见 [架构概览](docs/architecture/README.md)。

---

## 🤝 贡献与致谢

### 原始 vs Fork

- **原始项目**：[runesleo/claude-code-workflow](https://github.com/runesleo/claude-code-workflow) 作者 [@runes_leo](https://x.com/runes_leo)
- **本 Fork**：扩展为多平台，含可移植核心、50+ 模块、1400+ 测试

如果你只需要 Claude Code 支持且偏好简单配置，原始项目可能更适合。

### 集成项目

- **[Superpowers](https://github.com/obra/superpowers)** - 高级技能包（TDD、调试）
- **[RTK](https://github.com/rtk-ai/rtk)** - Token 优化器（节省 60-90%）
- **[everything-claude-code](https://github.com/affaan-m/everything-claude-code)** - Instinct 学习灵感来源

### 许可

MIT — 随意使用、fork、改造。

原始作品版权所有 (c) 2024 runes_leo
修改作品版权所有 (c) 2026 nehcuh

---

**快速链接**：[理念](PRINCIPLES.md) | [完整文档](docs/README.md) | [Issues](https://github.com/nehcuh/vibesop/issues) | [Telegram](https://t.me/runesgang)
