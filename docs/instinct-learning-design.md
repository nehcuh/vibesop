# Instinct 学习系统设计文档

## 概述

Instinct 学习系统是 VibeSOP 的核心创新，能够从 session 中自动提取可复用的模式，形成"本能"知识库。

---

## 数据结构

### Instinct 对象

```yaml
instinct:
  id: string (UUID v4)
  pattern: string (模式描述)
  confidence: float (0.0-1.0, 置信度)
  source_sessions: array<string> (来源 session ID 列表)
  usage_count: integer (使用次数)
  success_rate: float (0.0-1.0, 成功率)
  created_at: timestamp (ISO 8601)
  updated_at: timestamp (ISO 8601)
  tags: array<string> (标签：domain, language, framework 等)
  context: string (可选，上下文信息)
  examples: array<string> (可选，示例场景)
  status: enum (active, archived, evolved)
```

### 字段说明

- **id**: 唯一标识符，使用 UUID v4 格式
- **pattern**: 模式的自然语言描述，例如 "修复 Ruby 语法错误时，先运行 rubocop"
- **confidence**: 置信度评分，基于成功率和使用频率计算
- **source_sessions**: 提取该模式的 session ID 列表，用于追溯
- **usage_count**: 该 instinct 被应用的次数
- **success_rate**: 应用后的成功率（成功次数 / 总次数）
- **created_at**: 创建时间
- **updated_at**: 最后更新时间
- **tags**: 分类标签，支持多维度分类
  - domain: backend, frontend, devops, testing, etc.
  - language: ruby, python, javascript, etc.
  - framework: rails, react, vue, etc.
- **context**: 可选的上下文信息，描述适用场景
- **examples**: 可选的示例场景列表
- **status**: 状态
  - active: 活跃，可以被使用
  - archived: 已归档，不再使用
  - evolved: 已升级为正式 skill

---

## 存储格式决策

### 选项对比

| 特性 | YAML | SQLite |
|------|------|--------|
| 可读性 | ⭐⭐⭐⭐⭐ 人类可读 | ⭐⭐ 需要工具查看 |
| 版本控制 | ⭐⭐⭐⭐⭐ Git 友好 | ⭐ 二进制文件 |
| 查询性能 | ⭐⭐ 需要全量加载 | ⭐⭐⭐⭐⭐ SQL 查询 |
| 并发写入 | ⭐ 容易冲突 | ⭐⭐⭐⭐ 事务支持 |
| 跨平台 | ⭐⭐⭐⭐⭐ 纯文本 | ⭐⭐⭐⭐ 需要 SQLite |
| 团队共享 | ⭐⭐⭐⭐⭐ 易于 merge | ⭐⭐ 难以 merge |
| 数据量 | ⭐⭐⭐ < 1000 条 | ⭐⭐⭐⭐⭐ 无限制 |

### 最终决策：YAML

**理由**:
1. **Git 友好**: VibeSOP 强调团队协作，YAML 可以轻松 merge
2. **人类可读**: 用户可以直接编辑 instincts.yaml
3. **轻量级**: 符合 VibeSOP 的轻量级理念
4. **数据量**: 预计 instinct 数量 < 500，YAML 性能足够

**存储路径**: `memory/instincts.yaml`

**文件结构**:
```yaml
version: "1.0"
instincts:
  - id: "550e8400-e29b-41d4-a716-446655440000"
    pattern: "修复 Ruby 语法错误时，先运行 rubocop"
    confidence: 0.85
    source_sessions: ["session-2026-03-15-001", "session-2026-03-16-003"]
    usage_count: 12
    success_rate: 0.92
    created_at: "2026-03-15T10:30:00Z"
    updated_at: "2026-03-18T14:20:00Z"
    tags: ["ruby", "linting", "debugging"]
    context: "适用于 Ruby 项目的代码质量检查"
    examples:
      - "修复 syntax error 后运行 rubocop --auto-correct"
    status: "active"
```

---

## 置信度计算算法

```ruby
def calculate_confidence(instinct)
  # 基础分数：成功率（权重 60%）
  base_score = instinct.success_rate * 0.6

  # 使用频率分数（权重 30%）
  # 使用次数越多，置信度越高，但有上限
  usage_score = [instinct.usage_count / 20.0, 1.0].min * 0.3

  # 来源多样性分数（权重 10%）
  # 来自多个 session 的模式更可靠
  diversity_score = [instinct.source_sessions.size / 5.0, 1.0].min * 0.1

  # 总分
  confidence = base_score + usage_score + diversity_score

  # 限制在 0.0-1.0 范围
  [confidence, 1.0].min
end
```

---

## API 接口设计

### InstinctManager 类

```ruby
module Vibe
  class InstinctManager
    # 初始化
    def initialize(storage_path = nil)

    # 从 session 提取模式
    def learn(session_data)

    # 评估 instinct 质量
    def evaluate(instinct_id)

    # 导出 instinct
    def export(file_path, filters = {})

    # 导入 instinct
    def import(file_path, merge_strategy = :skip)

    # 升级为 skill
    def evolve(instinct_ids, skill_name)

    # 列出 instinct
    def list(filters = {})

    # 获取单个 instinct
    def get(instinct_id)

    # 更新 instinct
    def update(instinct_id, attributes)

    # 删除 instinct
    def delete(instinct_id)

    # 记录使用
    def record_usage(instinct_id, success)

    # 加载到 context
    def load_to_context(filters = {})
  end
end
```

---

## 模式提取算法

### 输入：Session 数据

```ruby
session_data = {
  id: "session-2026-03-18-001",
  tool_calls: [
    { tool: "Bash", command: "rubocop", success: true },
    { tool: "Edit", file: "app.rb", success: true },
    { tool: "Bash", command: "ruby app.rb", success: true }
  ],
  context: {
    language: "ruby",
    task: "fix syntax error"
  }
}
```

### 提取逻辑

1. **识别成功序列**: 连续成功的 tool calls（> 3 次）
2. **模式匹配**: 检查是否与已知模式相似
3. **生成描述**: 使用 LLM 生成自然语言描述
4. **提取标签**: 从 context 中提取 tags
5. **计算初始置信度**: 基于序列长度和成功率

---

## 导入导出格式

### 导出格式

支持两种格式：
1. **YAML**: 完整数据，适合备份和团队共享
2. **JSON**: 适合程序化处理

### 冲突解决策略

导入时的 merge 策略：
- **skip**: 跳过已存在的 instinct（默认）
- **overwrite**: 覆盖已存在的 instinct
- **merge**: 合并数据（更新 usage_count, success_rate 等）
- **rename**: 重命名冲突的 instinct

---

## 安全考虑

1. **输入验证**: 所有字段必须验证类型和范围
2. **文件权限**: instincts.yaml 应设置为用户私有（chmod 600）
3. **敏感信息**: 不应在 pattern 中包含密码、token 等
4. **注入防护**: pattern 描述应转义特殊字符

---

**文档版本**: v1.0
**创建日期**: 2026-03-18
**状态**: 设计阶段
