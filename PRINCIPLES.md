# VibeSOP 核心原则 (Core Principles)

**版本**: 2.0  
**最后更新**: 2026-03-29  
**状态**: 必须遵守 (Mandatory)

> **任何开发工作开始前，必须阅读并理解本文档。**  
> **所有设计决策、代码实现、功能添加都必须符合这些原则。**

---

## 🎯 项目愿景 (Vision)

### 一句话定义

**VibeSOP 是一套 AI 辅助开发的标准工作流（SOP）——个人用它积累知识、加速开发，团队用它统一规范、沉淀经验。**

### 双场景价值

| 场景 | 核心价值 | 关键能力 |
|------|---------|---------|
| **个人开发者** | 知识沉淀 + 快速开发 | Instinct learning、memory system、skill routing |
| **团队协作** | 统一配置 + 经验共享 | Overlay system、SSOT、skill registry、experience export/import |

### 我们不是什么

- **不是** AI 工具本身——VibeSOP 是工作流层，运行在 AI 工具之上
- **不是** 配置模板集——VibeSOP 是可执行的框架，有 skill routing、memory、learning
- **不是** 只服务于 Claude Code——Portable Core + Target Adapter 架构确保跨平台

### 三个核心痛点（我们解决什么）

1. **每次会话从零开始** → 结构化配置 + 分层加载，AI 不再失忆
2. **重复犯同样的错误** → Memory + Instinct 系统，让教训只犯一次
3. **每个人都要重新摸索** → Skill 生态 + 智能路由，最佳实践开箱即用

### 架构支撑

```
core/     → 平台无关的语义层（能力层级、技能注册表、安全策略）
targets/  → 平台适配器（Claude Code、OpenCode、Cursor 等）
bin/vibe  → 生成器，将可移植规范物化为平台特定配置
```

```
Layer 0: rules/     (始终加载) - 核心行为规则
Layer 1: docs/      (按需加载) - 参考资料
Layer 2: memory/    (热数据)   - 工作进度和上下文
Layer 3: instincts/ (跨项目)  - 个人/团队积累的可复用模式
```

### 整合过滤器（Integration Filter）

**每个外部理念整合前，必须通过以下检验：**

| 检验项 | 问题 | 通过标准 |
|--------|------|---------|
| 个人知识沉淀 | 它帮助个人积累可复用的知识和经验吗？ | 至少服务一个场景 |
| 团队经验共享 | 它帮助团队统一规范或共享经验吗？ | 或者显著提升效率 |
| 开发效率提升 | 它让 AI 辅助开发更快、更准、更稳吗？ | 有可衡量的改进 |
| 与架构一致 | 它符合 Portable Core + Target Adapter 模式吗？ | 不引入平台锁定 |
| 非缝合判断 | 它是有机整合，还是机械照搬？ | 能用 VibeSOP 自己的语言重述 |

---

## 📋 五大核心原则 (Five Core Principles)

### 原则 1: 生产优先 (Production-First)

**宣言**: *Not a tutorial. Not a toy config. A production workflow that actually ships.*

**要求**:
- ✅ 所有功能必须经过实战检验
- ✅ 拒绝"演示级"代码，坚持"生产级"质量
- ✅ 优先考虑稳定性而非新特性
- ✅ 每个功能都必须有测试覆盖

**检查清单**:
- [ ] 这个功能在生产环境测试过吗？
- [ ] 有全面的错误处理吗？
- [ ] 边界条件考虑了吗？
- [ ] 性能影响评估了吗？

---

### 原则 2: 结构化优于提示 (Structure > Prompting)

**宣言**: *A well-organized config file beats clever one-off prompts every time.*

**要求**:
- ✅ 优先建立结构化的配置系统
- ✅ 避免依赖聪明的单次提示
- ✅ 建立可复用的规则和模板
- ✅ 让 AI 通过读取配置而非记忆来工作

**反模式**:
- ❌ 写一个很长的提示期望 AI 记住
- ❌ 每次会话都重新解释需求
- ❌ 依赖 AI 的"理解"而非明确规则

**正确做法**:
- ✅ 将规则写入 `rules/behaviors.md`
- ✅ 将技能定义写入 `skills/*/SKILL.md`
- ✅ 将项目信息写入 `memory/`

---

### 原则 3: 记忆优于智能 (Memory > Intelligence)

**宣言**: *An AI that remembers your past mistakes is more valuable than a smarter AI that starts fresh each session.*

**要求**:
- ✅ 系统化记录经验教训
- ✅ 建立可搜索的知识库
- ✅ 自动保存工作进度
- ✅ 让错误只犯一次

**关键实践**:
- 使用 `session-end` 技能自动保存进度
- 在 `memory/project-knowledge.md` 记录技术陷阱
- 使用 `experience-evolution` 技能积累项目知识
- 建立 SSOT（单源真理）防止信息重复

---

### 原则 4: 验证优于自信 (Verification > Confidence)

**宣言**: *The cost of running `npm test` is always less than the cost of shipping a broken build.*

**要求**:
- ✅ 要求显式验证才能声称完成
- ✅ 消除"应该可以了"的假设
- ✅ 建立强制检查点
- ✅ 让测试成为完成的定义

**强制规则**:
- 任何任务完成前必须运行验证命令
- 必须阅读验证输出，不能假设通过
- 使用 `verification-before-completion` 技能强制执行

---

### 原则 5: 可移植优于特定 (Portable > Specific)

**宣言**: *`core/` keeps the semantics portable, while the existing runtime layers keep Claude Code productive right now.*

**要求**:
- ✅ 新功能必须先进入 `core/` 作为可移植规范
- ✅ 避免平台特定的硬编码
- ✅ 使用配置驱动而非代码驱动
- ✅ 支持多平台是首要考虑

**开发流程**:
1. 在 `core/` 定义可移植语义
2. 在 `targets/` 添加适配器文档
3. 在 `rules/`/`docs/` 同步 Claude Code 文件
4. 最后扩展 `bin/vibe` 生成器

---

## 🏗️ 架构原则 (Architecture Principles)

### 分层架构 (Layered Architecture)

```
┌─────────────────────────────────────┐
│  Layer 0: rules/                    │  ← 始终加载，核心行为
│  - behaviors.md                     │
│  - skill-triggers.md                │
│  - memory-flush.md                  │
├─────────────────────────────────────┤
│  Layer 1: docs/                     │  ← 按需加载，参考资料
│  - task-routing.md                  │
│  - content-safety.md                │
│  - agents.md                        │
├─────────────────────────────────────┤
│  Layer 2: memory/                   │  ← 热数据，工作状态
│  - session.md                       │
│  - project-knowledge.md             │
│  - overview.md                      │
└─────────────────────────────────────┘
```

**原则**: 不要将所有内容 dumped 到上下文中。分层加载，按需获取。

---

### SSOT - 单源真理 (Single Source of Truth)

**宣言**: *Every piece of information has ONE canonical location.*

**要求**:
- ✅ 每个信息只有一个权威位置
- ✅ 使用 SSOT 表映射信息类型到文件
- ✅ 写入前检查 SSOT
- ✅ 防止"同一信息在 5 个地方，全部过时"的问题

**SSOT 映射**:
| 信息类型 | 权威位置 |
|---------|---------|
| 行为规则 | `rules/behaviors.md` |
| 技能定义 | `skills/*/SKILL.md` + `core/skills/registry.yaml` |
| 能力层级 | `core/models/tiers.yaml` |
| 项目状态 | `memory/session.md` |
| 安全策略 | `core/security/policy.yaml` |

---

### 配置驱动 (Configuration-Driven)

**宣言**: *Configuration over code. YAML over Ruby.*

**要求**:
- ✅ 优先使用 YAML 配置而非硬编码
- ✅ 平台定义在 `config/platforms.yaml`
- ✅ 技能定义在 `core/skills/registry.yaml`
- ✅ 使用 JSON Schema 验证配置

**反模式**:
- ❌ 在 Ruby 代码中硬编码平台特定逻辑
- ❌ 为每个平台写独立的方法
- ❌ 不使用配置就添加新功能

---

## 🚫 开发禁区 (Development Anti-Patterns)

### 绝对禁止 (Never)

1. **不要破坏向后兼容性**
   - 已有命令必须继续工作
   - 已有配置格式必须支持
   - 变更需要明确的迁移路径

2. **不要添加未经测试的功能**
   - 每个功能必须有测试
   - 测试覆盖率不能下降
   - 边界条件必须测试

3. **不要在 core/ 中添加平台特定代码**
   - `core/` 必须保持平台无关
   - 平台特定逻辑去 `targets/`
   - 使用适配器模式

4. **不要重复信息**
   - 遵循 SSOT
   - 使用引用而非复制
   - 建立信息关联而非重复

### 强烈反对 (Strongly Discourage)

1. **不要添加"演示级"功能**
   - 要么生产就绪，要么不做
   - 拒绝"先做个简单的"

2. **不要增加不必要的依赖**
   - 优先使用 Ruby 标准库
   - 每个依赖都需要理由

3. **不要忽视性能**
   - 考虑大项目的表现
   - 使用缓存和优化
   - 性能测试是必需的

---

## ✅ 开发检查清单 (Development Checklist)

### 开始开发前

- [ ] 阅读并理解本文档
- [ ] 确认功能符合项目愿景
- [ ] 检查是否已有类似功能
- [ ] 评估对现有功能的影响

### 设计阶段

- [ ] 设计符合分层架构
- [ ] 确定 SSOT 位置
- [ ] 考虑多平台支持
- [ ] 评估性能影响

### 实现阶段

- [ ] 编写测试先（TDD）
- [ ] 实现功能
- [ ] 添加错误处理
- [ ] 更新文档

### 完成前

- [ ] 所有测试通过
- [ ] 代码审查完成
- [ ] 文档更新完成
- [ ] 性能测试通过
- [ ] 向后兼容性验证

---

## 🎯 决策框架 (Decision Framework)

### 当面临技术决策时，问自己：

1. **这符合项目愿景吗？**
   - 是否让工作流更结构化？
   - 是否提升生产效率？
   - 是否保持跨平台可移植性？

2. **这遵循核心原则吗？**
   - 是生产优先吗？
   - 是结构化优于提示吗？
   - 是记忆优于智能吗？
   - 是验证优于自信吗？
   - 是可移植优于特定吗？

3. **这会增加技术债务吗？**
   - 是否引入不必要的复杂性？
   - 是否破坏现有架构？
   - 是否难以测试和维护？

4. **这对用户友好吗？**
   - 是否易于理解和使用？
   - 错误信息是否清晰？
   - 是否有完善的文档？

---

## 📚 相关文档

- [项目愿景详细说明](../README.md)
- [架构设计](../core/README.md)
- [开发指南](../docs/README.md)
- [行为规则](../rules/behaviors.md)
- [任务路由](../docs/task-routing.md)

---

## 📝 修订历史

| 版本 | 日期 | 变更 | 作者 |
|------|------|------|------|
| 1.0 | 2026-03-12 | 初始版本 | @huchen |
| 2.0 | 2026-03-29 | 明确项目愿景定位，新增双场景价值、整合过滤器、"我们不是什么" | @huchen |

---

**记住：这些原则不是建议，是要求。**

**任何偏离这些原则的开发都必须通过整合过滤器检验。**
