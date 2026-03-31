# OpenCode LLM 配置指南

## 概述

OpenCode 支持配置多种在线 LLM 提供商（Anthropic、OpenAI）用于 AI 路由和任务执行。

**✅ 新功能**：现在支持在配置文件中直接添加 API_KEY，无需设置环境变量。

## 配置方式

### 方式一：在配置文件中添加 API_KEY（推荐）

在 `opencode.json` 中直接配置 API key，无需环境变量：

#### 1. Anthropic Claude 配置

```json
{
  "$schema": "https://opencode.ai/config.json",
  "instructions": [
    "AGENTS.md"
  ],
  "models": {
    "fast": {
      "provider": "anthropic",
      "model": "claude-haiku-4-20250514",
      "api_key": "sk-ant-api03-your-api-key-here",
      "temperature": 0.3
    }
  }
}
```

#### 2. OpenAI 配置

```json
{
  "$schema": "https://opencode.ai/config.json",
  "instructions": [
    "AGENTS.md"
  ],
  "models": {
    "fast": {
      "provider": "openai",
      "model": "gpt-4o-mini",
      "api_key": "sk-proj-your-api-key-here",
      "temperature": 0.3
    }
  }
}
```

#### 3. 自定义 API 端点（兼容 OpenAI 格式）

```json
{
  "$schema": "https://opencode.ai/config.json",
  "instructions": [
    "AGENTS.md"
  ],
  "models": {
    "fast": {
      "provider": "openai",
      "model": "gpt-4o-mini",
      "api_key": "your-api-key-here",
      "base_url": "https://your-custom-endpoint.com/v1",
      "temperature": 0.3
    }
  }
}
```

### 方式二：使用环境变量

如果不希望在配置文件中存储 API key，可以使用环境变量：

#### 1. 设置环境变量

```bash
# Anthropic
export ANTHROPIC_API_KEY="sk-ant-api03-your-api-key-here"

# OpenAI
export OPENAI_API_KEY="sk-proj-your-api-key-here"

# 自定义端点（可选）
export OPENAI_BASE_URL="https://your-custom-endpoint.com/v1"
```

#### 2. 简化的配置文件

```json
{
  "$schema": "https://opencode.ai/config.json",
  "instructions": [
    "AGENTS.md"
  ],
  "models": {
    "fast": {
      "provider": "anthropic",
      "model": "claude-haiku-4-20250514",
      "temperature": 0.3
    }
  }
}
```

### 方式三：混合配置

**优先级**：配置文件中的 API key > 环境变量

```json
{
  "$schema": "https://opencode.ai/config.json",
  "instructions": [
    "AGENTS.md"
  ],
  "models": {
    "fast": {
      "provider": "openai",
      "model": "gpt-4o-mini",
      "api_key": "sk-proj-your-key-here",
      "base_url": "https://api.openai.com/v1"
    }
  }
}
```

如果配置文件中没有 `api_key`，系统会自动从环境变量读取。

## 完整配置示例

### Anthropic Claude 多模型配置

```json
{
  "$schema": "https://opencode.ai/config.json",
  "instructions": [
    "AGENTS.md"
  ],
  "models": {
    "critical": {
      "provider": "anthropic",
      "model": "claude-opus-4-20250514",
      "api_key": "sk-ant-api03-your-key-here",
      "temperature": 0.2
    },
    "workhorse": {
      "provider": "anthropic",
      "model": "claude-sonnet-4-20250514",
      "api_key": "sk-ant-api03-your-key-here",
      "temperature": 0.5
    },
    "fast": {
      "provider": "anthropic",
      "model": "claude-haiku-4-20250514",
      "api_key": "sk-ant-api03-your-key-here",
      "temperature": 0.3
    }
  }
}
```

### OpenAI 多模型配置

```json
{
  "$schema": "https://opencode.ai/config.json",
  "instructions": [
    "AGENTS.md"
  ],
  "models": {
    "critical": {
      "provider": "openai",
      "model": "gpt-4o",
      "api_key": "sk-proj-your-key-here",
      "temperature": 0.2
    },
    "workhorse": {
      "provider": "openai",
      "model": "gpt-4o-mini",
      "api_key": "sk-proj-your-key-here",
      "temperature": 0.5
    },
    "fast": {
      "provider": "openai",
      "model": "gpt-4o-mini",
      "api_key": "sk-proj-your-key-here",
      "temperature": 0.3
    }
  }
}
```

### 混合提供商配置

```json
{
  "$schema": "https://opencode.ai/config.json",
  "instructions": [
    "AGENTS.md"
  ],
  "models": {
    "fast": {
      "provider": "anthropic",
      "model": "claude-haiku-4-20250514",
      "api_key": "sk-ant-your-key-here",
      "temperature": 0.3
    },
    "verifier": {
      "provider": "openai",
      "model": "gpt-4o",
      "api_key": "sk-proj-your-key-here",
      "temperature": 0.3
    }
  }
}
```

## 支持的提供商和模型

### Anthropic Claude

| 模型 | 用途 | 推荐场景 |
|------|------|---------|
| `claude-haiku-4-20250514` | 快速、低成本 | AI 路由、简单任务 |
| `claude-sonnet-4-20250514` | 平衡性能 | 日常编程任务 |
| `claude-opus-4-20250514` | 高性能 | 复杂推理、架构设计 |

### OpenAI

| 模型 | 用途 | 推荐场景 |
|------|------|---------|
| `gpt-4o-mini` | 快速、低成本 | AI 路由、简单任务 |
| `gpt-4o` | 平衡性能 | 日常编程任务 |
| `gpt-4-turbo` | 高性能 | 复杂推理、验证 |

### OpenAI 兼容格式

OpenCode 支持任何兼容 OpenAI API 格式的端点：

```json
{
  "$schema": "https://opencode.ai/config.json",
  "instructions": [
    "AGENTS.md"
  ],
  "models": {
    "fast": {
      "provider": "openai",
      "model": "your-model-name",
      "api_key": "your-api-key",
      "base_url": "https://your-endpoint.com/v1",
      "temperature": 0.3
    }
  }
}
```

常见的兼容端点：
- **Azure OpenAI**: `https://your-resource.openai.azure.com/openai/deployments/your-deployment`
- **Together AI**: `https://api.together.xyz/v1`
- **Anyscale**: `https://api.endpoints.anyscale.com/v1`
- **其他**: 任何支持 OpenAI API 格式的服务

## 安全建议

### 使用环境变量（推荐用于生产环境）

```bash
# 不在配置文件中存储敏感信息
export ANTHROPIC_API_KEY="sk-ant-your-key-here"
```

然后在配置文件中省略 `api_key` 字段：

```json
{
  "models": {
    "fast": {
      "provider": "anthropic",
      "model": "claude-haiku-4-20250514",
      "temperature": 0.3
    }
  }
}
```

### 配置文件安全（仅用于本地开发）

如果选择在配置文件中存储 API key：

1. **添加到 .gitignore**：
```bash
echo "opencode.json" >> .gitignore
```

2. **设置文件权限**：
```bash
chmod 600 opencode.json
```

3. **使用示例配置**：
```bash
cp opencode.json opencode.json.example
# 然后编辑 opencode.json.example，移除真实的 API key
```

## 验证配置

### 检查配置状态

```bash
./bin/vibe route --stats
```

预期输出：

```
📊 Skill Routing Statistics
==================================================

🤖 AI Triage Layer:
   Status: ✅ Enabled
   Environment: opencode
   Model: claude-haiku-4-20250514
   Provider: Anthropic
   Circuit: 🟢 Closed
```

### 测试路由

```bash
./bin/vibe route "帮我调试这个 bug"
```

### 检查配置文件

```bash
# 验证 JSON 格式
cat opencode.json | jq .

# 查看配置
cat opencode.json
```

## 故障排查

### 问题：AI Triage 显示 "Disabled"

**原因**：没有配置 API key

**解决方案**：
1. 在 `opencode.json` 中添加 `api_key` 字段
2. 或设置环境变量：`export ANTHROPIC_API_KEY="..."`

### 问题：显示 "No LLM provider configured"

**原因**：无法检测到有效的提供商或 API key

**解决方案**：
1. 检查 `provider` 字段是否正确（`anthropic` 或 `openai`）
2. 检查 `api_key` 是否有效
3. 检查网络连接

### 问题：OpenAI 格式端点不工作

**原因**：`base_url` 配置不正确

**解决方案**：
1. 确保 `base_url` 包含 `/v1` 后缀
2. 确保 `provider` 设置为 `openai`
3. 检查端点是否支持 OpenAI API 格式

### 问题：配置文件中的 API key 不生效

**原因**：可能是 JSON 格式错误或配置优先级问题

**解决方案**：
1. 验证 JSON 格式：`cat opencode.json | jq .`
2. 检查配置文件路径是否正确
3. 确认 `api_key` 字段在正确的 `models` 配置下

## 配置参考

### 完整配置字段

```json
{
  "$schema": "https://opencode.ai/config.json",
  "instructions": ["AGENTS.md"],
  "models": {
    "fast": {
      "provider": "anthropic",        // 提供商：anthropic 或 openai
      "model": "claude-haiku-4-20250514",  // 模型名称
      "api_key": "sk-ant-your-key",    // API key（可选，优先于环境变量）
      "base_url": "https://...",       // 自定义端点（可选）
      "temperature": 0.3               // 温度参数（可选）
    }
  }
}
```

### 环境变量参考

| 环境变量 | 说明 | 优先级 |
|---------|------|-------|
| `ANTHROPIC_API_KEY` | Anthropic API 密钥 | 配置文件 > 环境变量 |
| `ANTHROPIC_BASE_URL` | Anthropic API 端点 | 配置文件 > 环境变量 > 默认值 |
| `OPENAI_API_KEY` | OpenAI API 密钥 | 配置文件 > 环境变量 |
| `OPENAI_BASE_URL` | OpenAI API 端点 | 配置文件 > 环境变量 > 默认值 |
