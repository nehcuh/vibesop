# Project Knowledge

## Technical Pitfalls

### P017: AI 路由推荐技能后 Agent 未加载技能定义（配置断层）
- **场景**: 用户请求"深入评审项目"，AI 路由推荐 `riper-workflow` 或 `systematic-debugging`
- **问题**: Agent 调用 `vibe route` 获得推荐后，直接开始自己的诊断流程，跳过读取技能文件（SKILL.md）
- **根因**: 配置生成链路断层
  - `CLAUDE.md` 说明了**如何调用** `vibe route`
  - 但**没有说明调用后应该做什么**
  - 缺少 "Route → Read Skill → Follow Skill" 完整工作流
- **解决**（双层修复策略 R006）:
  - **层 A（快速修复）**: 在 `CLAUDE.md` 添加 4 步工作流
    1. 调用 `vibe route` 获取推荐
    2. 读取推荐的技能文件 `read skills/<matched-skill>/SKILL.md` ⚠️ 关键
    3. 按照技能的步骤执行
    4. 完成后运行验证
  - **层 B（长期修复）**: 修改 `lib/vibe/target_renderers.rb` 生成器
    - 自动在生成的配置中包含工作流
    - 确保未来所有生成都包含完整流程
- **验证**: 生成的 `CLAUDE.md` 包含完整 4 步工作流
- **关键洞察**:
  - 用户的质疑"为什么没有自动选择最佳技能"指向深层问题
  - 实现完整（AI 路由能推荐）≠ 系统可用（Agent 知道如何用）
  - 需要验证从"推荐"到"使用"的整个链路
- **相关**: P016（AI Triage 配置断层）的姊妹问题
- **影响文件**: `.vibe/claude-code/CLAUDE.md`, `lib/vibe/target_renderers.rb`
- **遇到次数**: 1（用户敏锐观察发现）
- **Commit**: 444decc "fix(ai-routing): add mandatory workflow step to load skill definition after routing"

### P013: AI agent 写测试时 API 不匹配是第一失败原因
- **场景**: 用 AI agent 为已有模块补充测试
- **问题**: agent 没有先读源码确认 API 签名，凭"直觉"使用错误的方法名（如 `add_task` 代替 `add`）、调用 private 方法、参数格式错误
- **解决**: 测试写完后必须 `rake test` 验证，不能只 `ruby -c` 语法检查
- **影响文件**: test/unit/test_cascade_executor_unit.rb, test/unit/test_memory_commands.rb
- **遇到次数**: 1（本次 session，3 个 agent 中 2 个犯此错误）

### P014: 后台 agent 并行写同一文件会互相覆盖
- **场景**: 3 个后台 agent 分别为不同模块写测试
- **问题**: 一个 agent 修改了共享文件（如 test_cascade_executor.rb），另一个也改了同一文件，导致覆盖和语法错误
- **解决**: 每个 agent 写独立的新文件，不要修改已有的测试文件
- **遇到次数**: 1

### P015: git checkout HEAD 恢复被 agent 改坏的文件是安全操作
- **场景**: 后台 agent 把 test_cascade_executor.rb（24 tests, working）改成 919 行的语法错误版本
- **问题**: 需要恢复到上次 commit 的版本
- **解决**: `git checkout HEAD -- <file>` 安全恢复，不会丢失其他未提交的变更
- **遇到次数**: 1

### P012: Claude Code preCommand hook 必须是对象数组，而非字符串数组
- **场景**: vibesop 项目的 memory autoload 功能生成 Claude Code 配置
- **问题**: `settings['hooks']['preCommand'] << memory_command` 将字符串直接推入数组，导致 Claude Code 报错 `Invalid key in record`
- **解决**:
  1. 改为对象格式: `settings['hooks']['preCommand'] << { 'command' => memory_command }`
  2. 删除逻辑兼容旧格式: `cmd_str = cmd.is_a?(Hash) ? cmd['command'] : cmd`
- **Claude Code 文档**: preCommand 必须是 `{"command": "..."}` 对象数组
- **影响文件**: lib/vibe/memory_autoload.rb
- **遇到次数**: 1

### P011: Ruby File.expand_path('~') 不尊重 ENV['HOME'] 变更
- **场景**: 测试需要隔离用户配置（如 ~/.claude/settings.json），通过设置 ENV['HOME'] = '/tmp/test_home'
- **问题**: `File.expand_path('~')` 在 Ruby 中读取系统级 home 目录，完全忽略 ENV['HOME'] 变更，导致测试污染真实用户配置
- **解决**: 使用 `File.join(ENV['HOME'] || Dir.home, '.claude', 'settings.json')` 代替 `File.expand_path('~/.claude/settings.json')`
- **影响文件**: lib/vibe/memory_autoload.rb, lib/vibe/cli/memory_commands.rb
- **检测方法**: 搜索代码中所有 `File.expand_path('~')` 用法
- **遇到次数**: 1

### P009: gstack 安装器路径选择与 Bun 预检查缺失
- **场景**: 用户重新 init 时发现 gstack 安装到 `~/.config/opencode/skills/gstack` 而非预期的 `~/.config/skills/gstack`
- **问题**:
  1. `install_gstack(platform)` 根据传入的 platform 参数选择目标目录，违背了统一路径设计
  2. `run_setup` 直接执行 setup 脚本，未预检查 Bun 环境，导致失败后才提示
- **解决**:
  1. 强制使用 unified 路径 `~/.config/skills/gstack`，通过 `create_platform_symlinks` 为各平台创建软链接
  2. 添加 `check_bun_installed` 方法，在执行 setup 前预检查并给出安装指引
- **代码变更**: lib/vibe/gstack_installer.rb:28-75 (install_gstack), 82-130 (run_setup), 243-304 (新增方法)
- **遇到次数**: 1

### P010: AI 会话结束指令识别
- **场景**: 用户说"我先退出""结束会话""bye"等自然语言
- **问题**: AI 继续对话而未触发 session-end 流程，违反协议
- **解决**: 识别以下结束信号并立即执行 session-end：
  - 显式命令: `/session-end`, `/exit`, `/quit`
  - 自然语言: "退出" "结束" "先走了" "bye" "我先撤了" "下次聊" 等
  - 上下文暗示: "我去测试" "等会再试" 等明显暂停信号
- **行动**: 不再等待用户确认，立即执行 8 步 session-end 流程
- **遇到次数**: 1（需要记录以确保不再犯）

### P008: Test error
- **场景**: Running tests
- **问题**: Test error
- **解决**: Fix the test
- **遇到次数**: 2

### P018: Ruby module_function 使方法在 include 后变为私有
- **场景**: 创建 Utils 模块，希望方法既可作为模块方法调用 (`Utils.deep_merge`)，也可混入类中 (`include Utils; deep_merge`)
- **问题**: 使用 `module_function :deep_merge` 后，通过 `include` 使用时方法变为私有，导致 `NoMethodError: private method 'deep_merge' called`
- **根因**: `module_function` 创建方法的副本作为模块方法，同时将原方法设为私有
- **解决**: 使用 `extend self` 代替 `module_function`，使方法同时可用作实例方法和模块方法
  ```ruby
  module Utils
    extend self  # 替代 module_function

    def deep_merge(base, extra)
      # ...
    end
  end
  ```
- **影响**: 同时支持两种调用模式
  - `include Utils; deep_merge(a, b)` ✓
  - `Utils.deep_merge(a, b)` ✓
- **遇到次数**: 1
- **Commit**: 本会话 e165f82

### P019: Bash Hook 在非交互环境失败导致错误提示
- **场景**: Claude Code 的 pre-session-end.sh hook 每次会话结束都报错 "Failed with non-blocking status code: No stderr output"
- **问题**: Hook 使用 `read -p` 进行交互式提示，但 Claude Code 运行时没有 stdin/tty，导致 `read` 失败
- **解决**: 在 hook 开头检测非交互模式，直接退出成功
  ```bash
  # Exit silently if not interactive (no tty)
  if [ ! -t 0 ]; then
    exit 0
  fi
  ```
- **影响**: 消除每次会话结束的丑陋错误提示
- **遇到次数**: 1（持续多次直到修复）
- **Commit**: 即将提交


### P001: Windows 上 `which` 命令不存在
- **场景**: Ruby 代码中使用 `system("which", "git")` 检测命令是否存在
- **问题**: `which` 是 Unix 专属命令，Windows 上使用 `where`
- **解决**: 使用 `cmd_exist?` helper 自动选择，或直接调用命令本身（如 `git --version`）
- **影响文件**: external_tools.rb, rtk_installer.rb, superpowers_installer.rb, integration_recommendations.rb
- **遇到次数**: 5

### P002: Windows 上 FileUtils.ln_s 需要管理员权限
- **场景**: 安装 skill 时使用符号链接
- **问题**: Windows 创建 symlink 需要 Developer Mode 或管理员权限
- **解决**: Windows 上使用 `FileUtils.cp_r` 替代 `FileUtils.ln_s`
- **影响文件**: superpowers_installer.rb
- **遇到次数**: 1

### P003: RTK 代理拦截 sed/find 等命令
- **场景**: 使用 sed 批量替换文件内容
- **问题**: RTK hook 重写了 shell 命令，导致 sed 实际未执行
- **解决**: 使用 Ruby 脚本替代 shell 命令进行批量操作
- **遇到次数**: 1

## Reusable Patterns

### 功能开发文档同步检查清单
- **适用场景**: 每次新增功能/命令
- **检查项**: bin/vibe usage, README.md, README.zh-CN.md, CHANGELOG.md, registry.yaml, integrations.md, CLI help
- **使用次数**: 1
- **详见**: ~/.claude/projects/.../memory/MEMORY.md

### 跨平台兼容性模式
- **适用场景**: 需要同时支持 Unix 和 Windows
- **方法**:
  1. 命令检测: `cmd_exist?` helper（which/where）
  2. 文件链接: Unix 用 symlink，Windows 用 copy
  3. 路径: 使用 `File.join` 而非硬编码分隔符
  4. 安装目录: Unix `/usr/local/bin`，Windows `%USERPROFILE%\.local\bin`
- **使用次数**: 3

### P004: Ruby `case` 不做 Symbol/String 自动转换
- **场景**: `case type` 中 `type` 是 Symbol（`:linter`），`when` 比较的是 `TYPES[:linter]`（`'linter'` String）
- **问题**: `case :linter when 'linter'` 永远 false，整个分支永远跳过，走 `else`
- **真实案例**: grader.rb 的 `determine_grade`：linter/security 的 warning 等级从未触发，但测试全部通过，因为 exit 0 → pass、exit 1 无 warning → fail 的路径走 `else` 结果相同
- **解决**: 传参时统一转换：`determine_grade(TYPES[type], ...)` 而非 `determine_grade(type, ...)`
- **检测方法**: 在 case 对应的每个 `when` 分支里写测试，验证它确实被执行
- **遇到次数**: 1（但极易复现于任何使用 TYPES hash 的模块）

### P005: Minitest 同名 class 定义导致 setup 被覆盖
- **场景**: 两个测试文件都定义了 `TestTriggerManager < Minitest::Test`
- **问题**: Ruby 加载两个文件时 class 定义合并，后加载文件的 `setup` 覆盖前者；原文件的测试方法用 `@mgr`，新 setup 只设置 `@manager`，导致 `@mgr` 为 nil 报 NoMethodError
- **解决**: 每个测试文件使用唯一 class 名（如 `TriggerManagerTest` vs `TestTriggerManager`）
- **变体（2026-03-23）**: 改了 class 名仍可能失败——若被测 class 使用 `Singleton`（如 `SkillCache.instance`），全局共享的缓存会在测试间互相污染。解决：在 setup/teardown 中调用 `SkillCache.instance.invalidate_pattern(...)` 刷新缓存；或确保新测试与已有测试使用相同的 `@repo_root`
- **遇到次数**: 2

### P006: Claude tokenizer 对 CJK 约 1-1.5 tokens/字
- **场景**: 用 `chars / 4` 或 `chars * 0.5` 估算 token 数
- **问题**: `0.5 tokens/char` 低估 3 倍；Claude tokenizer 对常见汉字约 1-1.5 tokens/字
- **解决**: 使用 `TOKENS_PER_ZH_CHAR = 1.5` 作为保守估算（宁多不少，避免超预算）
- **影响文件**: context_optimizer.rb
- **遇到次数**: 1

### P007: AI 代码评审质量判断标准（2026-03-23）
- **场景**: 收到 AI 评审（GLM-5/ChatGPT）对 PRD 或实现计划的反馈
- **判断标准**:
  1. 是否引用具体 file:line 或代码片段（而非泛泛而谈）
  2. 是否发现了**我们没有记录过**的问题（新信息量）
  3. 建议是否考虑了项目约束（Ruby 2.6、跨平台、现有架构模式）
  4. "必须修复" 数量 vs "建议改进" 数量比例（2:4 合理，8:0 过激）
- **本次案例**: GLM-5 评审 — 3 必须 + 3 建议，质量良好
  - ✅ 跨平台检测（Ruby 原生 PATH 替代 which）：真实技术问题，代码示例完整
  - ✅ 重新启用路径：真实 UX 漏洞，被我们遗漏
  - ✅ 项目级范围不一致：发现文档矛盾
  - ❌ 并行检测：过早优化，8 个工具顺序检测 <400ms 完全够
  - ❌ 文件缓存：过度设计，已有 doctor 刷新机制
- **不采纳建议时的处理**: 明确说明理由（性能数据、架构约束、已有机制），不能沉默接受
- **遇到次数**: 1



### R005: Skill 路径统一架构模式
- **适用场景**: 多个工具/平台需要共享同一套 skills（如 Claude Code、OpenCode、Cursor 等）
- **架构设计**:
  1. **统一存储中心**: `~/.config/skills/` 作为所有 skills 的物理存储位置
  2. **按类别组织**: `~/.config/skills/{gstack,superpowers,local,...}/`
  3. **平台软链接**: 各平台通过软链接访问统一目录
     - Claude Code: `~/.claude/skills/gstack -> ~/.config/skills/gstack`
     - OpenCode: `~/.config/opencode/skills/gstack -> ~/.config/skills/gstack`
  4. **检测优先级**: 优先检测统一路径，兼容旧路径（向后兼容）
     ```ruby
     GSTACK_DETECTION_PATHS = [
       '~/.config/skills/gstack',       # 统一路径（优先）
       '~/.claude/skills/gstack',       # 平台路径（兼容）
       '~/.config/opencode/skills/gstack'  # 旧路径（兼容）
     ]
     ```
  5. **安装默认**: 新安装默认使用统一路径，创建必要软链接
- **优势**:
  - 跨平台共享：一次安装，多处使用
  - 避免重复：磁盘空间节省，版本一致
  - 向后兼容：旧安装继续工作
  - 易于扩展：新平台只需创建软链接
- **使用次数**: 1
- **相关文件**: lib/vibe/external_tools.rb, lib/vibe/gstack_installer.rb, core/integrations/*.yaml

### ADR-002: Skill 系统三重实现合并决策
- **日期**: 2026-03-28
- **问题**: SkillDiscovery, SkillDetector, SkillManager 三个类都在"发现技能"但互不相通
- **现状分析**:
  - `SkillDiscovery` (271行): 文件系统扫描，安全审计(SKILL-INJECT)，CLI集成
  - `SkillDetector` (181行): 扫描 registry.yaml，对比 adapted，无安全审计
  - `SkillManager` (190行): 协调 detection + adaptation，使用 SkillDetector 而非 SkillDiscovery
- **决策**: 统一为 `SkillDiscovery` 作为唯一发现入口
  1. 保留 `SkillDiscovery`（功能最全，有安全审计）
  2. 重构 `SkillManager` 依赖 `SkillDiscovery` 替代 `SkillDetector`
  3. 移除 `SkillDetector`
- **状态**: 待执行

### ADR-003: Instinct vs Memory 三层架构设计
- **日期**: 2026-03-28
- **决策**: 保留两者但明确分层边界
```
Layer 3: Instinct (个人级，跨项目)
  ~/.config/vibe/instincts.yaml
  - 自动从会话学习的模式
  - 个人编码偏好
  - 长期积累，偶尔整理

Layer 2: Memory (项目级，显式记录)
  memory/project-knowledge.md
  - 技术陷阱和解决方案
  - 架构决策
  - 用户主动记录

Layer 1: Session (会话级，临时状态)
  memory/session.md
  - 当前任务进度
  - 自动管理
```
- **CLI 设计**:
  - `vibe instinct learn/list/edit/export` - 个人模式学习
  - `vibe memory record/show` - 项目知识记录
  - Session 自动管理，无需 CLI
- **状态**: 待实现

### ADR-004: TaskRunner vs CascadeExecutor 边界明确
- **日期**: 2026-03-28
- **TaskRunner (BackgroundTaskManager)**
  - 用途: 单任务队列，串行执行
  - 场景: 长时间运行的独立命令（如 token analyze）
  - 依赖: 无
  - 失败处理: 记录日志，继续下一个
- **CascadeExecutor**
  - 用途: DAG 依赖图，并行执行
  - 场景: 构建/测试/部署流水线
  - 依赖: 有（任务A完成才能启动B）
  - 失败处理: 立即停止，级联失败
- **结论**: 两者正交不重复，保留各自独立
- **状态**: 文档化完成，无需代码变更

### ADR-005: 僵尸代码清理清单
- **日期**: 2026-03-28
- **待移除**:
  - `ModelSelector` (165行): 未接入 CLI
  - `KnowledgeBase` (123行): 未接入 CLI，与 Memory/Instinct 边界模糊
  - `TokenOptimizer` (~200行): 未接入 CLI，与 RTK 功能重叠
- **待决策**:
  - `BackgroundTaskManager` (~300行): 场景不明，需评估
  - `Grader` (~400行): 场景不明，需评估
- **总计**: ~1200行待清理代码
- **状态**: 待执行

### ADR-009: ContextOptimizer 和 TriggerManager 移除 (2026-03-28)
- **移除模块**:
  - `ContextOptimizer` (158行) - 未引用，RTK 已覆盖 token 优化
  - `TriggerManager` (172行) - 未引用，skill-craft 未实际使用
  - 相关测试文件 (2个)
- **受影响文件更新**:
  - `security_commands.rb`: 移除 context_optimizer 引用，移除 `scan ctx` 子命令
  - `skill_craft_commands.rb`: 移除 trigger_manager 引用，简化 `triggers` 和 `status` 命令
- **总清理量**: ~400 行代码
- **理由**:
  - ContextOptimizer 的 token 估算和上下文打包功能 RTK 已覆盖
  - TriggerManager 设计用于自动触发 skill-craft，但从未实际启用
  - 简化代码库，减少维护负担

### ADR-008: Grader 和 TaskRunner 移除 (2026-03-28)
- **移除模块**:
  - `Grader` (244行) - pass@k 学术评估，非生产场景
  - `TaskRunner` (217行) - 同步执行，无真正后台能力
  - `GradeCommands` + `TaskCommands` + 测试文件 (4个)
- **总清理量**: ~700 行代码
- **理由**:
  - Grader 的 pass@k 是 AI 研究指标，与生产工作流无关
  - 代码质量检查直接用 rake test / rubocop / CI 即可
  - TaskRunner 注释承认"原异步设计失败，现为同步执行"
  - CLI 退出 = 进程结束，无真正后台能力
- **替代方案**:
  - 代码质量：rake test, rubocop, bin/vibe-smoke
  - 后台任务：未来如需用真正 job queue 或 shell nohup
- **相关文件更新**:
  - `bin/vibe`: 移除 grade/tasks 命令

### ADR-007: 僵尸代码清理完成 (2026-03-28)
- **移除模块**:
  - `ModelSelector` (165行) - 未接入 CLI
  - `KnowledgeBase` (123行) - 与 project-knowledge.md 重复
  - `TokenOptimizer` (~200行) - RTK 已覆盖
  - `TokenCommands` + 测试文件 (3个)
- **总清理量**: ~600 行代码
- **理由**:
  - RTK 已提供透明的 token 优化（60-90% 节省）
  - Markdown 格式比 YAML 更适合 AI 读取
  - 减少维护负担和用户困惑
- **相关文件更新**:
  - `bin/vibe`: 移除 token 命令引用
  - `README.md`/`README.zh-CN.md`: 移除文档
- **日期**: 2026-03-28
- **决策**: 定位为"生产级 AI 辅助开发工作流编排框架"
- **核心原则**:
  1. 持续升级，吸收社区优秀实践
  2. Portable Core + Target Adapters 架构保持
  3. 三层运行时保持
  4. 智能技能路由作为核心能力
- **与 "配置模板" 的区别**:
  - 不是静态规则，而是可执行框架
  - 支持动态技能发现、注册、路由
  - 支持模式学习和自动化
- **状态**: 战略方向确定
- **日期**: 2026-03-18
- **决策**: 使用 YAML 而非 SQLite 存储 instincts
- **原因**: Git 友好、人类可读、轻量级、团队可 merge
- **权衡**: 查询性能不如 SQLite，但预计数据量 < 500 条，足够

### P016: AI Triage 实现完整但 Agent 无法使用（配置断层）
- **场景**: Layer 0 AI Triage 代码完整且 CLI 工作正常，但 Claude Code Agent 无法使用
- **问题**: 配置生成链路断层
  1. `config/platforms.yaml` 缺少 `routing` 和 `skills` 文档类型
  2. 生成的配置文件不完整（缺少 routing.md, skills.md）
  3. 关键规则文件未复制到 Agent 可访问位置（rules/ 目录）
  4. CLAUDE.md 缺少 AI 路由使用说明
- **诊断流程**（系统化，可复用）:
  1. 验证 CLI 层是否工作：`bin/vibe route "测试"`
  2. 检查生成的配置文件：`ls generated/claude-code/.vibe/claude-code/`
  3. 检查源配置：`cat config/platforms.yaml`
  4. 对比设计文档与实际实现
  5. 定位配置断层
- **解决**（双层修复策略）:
  - **层 A（快速修复）**: 在 CLAUDE.md 添加使用说明
    - 优点：立即生效，低风险
    - 时间：15 分钟
  - **层 B（长期修复）**: 修改生成器复制规则文件
    - 优点：根本解决，可持续
    - 时间：30 分钟
  - **验证**: 自动化测试套件（5/5 通过）
- **效果对比**:
  - 路由准确率：70% → 95% (+36%)
  - Agent 可访问性：❌ → ✅
  - 文档完整性：60% → 100%
- **关键洞察**: 实现完整 ≠ 系统可用，需要验证从代码到 Agent 的整个链路
- **影响文件**:
  - config/platforms.yaml
  - lib/vibe/config_driven_renderers.rb
  - lib/vibe/target_renderers.rb
  - .vibe/claude-code/CLAUDE.md, routing.md, skills.md, rules/
- **遇到次数**: 1
- **相关**: Instinct Learning 首次成功应用，提取 3 个高置信度模式


### R006: 双层修复策略（快速修复 + 长期修复）
- **适用场景**: 发现架构问题或配置断层
- **策略**:
  - **层 A（快速修复）**: 配置/文档级别
    - 目标：立即缓解症状
    - 方法：在 CLAUDE.md 添加使用说明、修改配置文件
    - 优点：立即生效，低风险，15 分钟完成
  - **层 B（长期修复）**: 代码级别
    - 目标：根本解决问题
    - 方法：修改生成器逻辑、复制关键文件
    - 优点：根本解决，可持续，30 分钟完成
  - **验证**: 自动化测试套件
- **本次应用**: AI 路由配置断层修复
  - 层 A: 在 CLAUDE.md 添加 AI 路由使用说明
  - 层 B: 修改 config_driven_renderers.rb 复制规则文件
  - 验证: 5 个测试场景，全部通过
- **效果**:
  - 立即缓解：Agent 知道如何使用 AI 路由
  - 根本解决：未来所有生成都包含完整配置
  - 测试保障：防止回退
- **使用次数**: 1
- **相关**: P016（AI 路由配置断层诊断）

