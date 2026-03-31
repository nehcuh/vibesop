# ⚠️ 安全警告

## API Key 暴露问题

我注意到你之前的 `opencode.json` 配置中直接包含了 API key：
```json
"api_key": "2f0aef8640994fd799787cf0af93d225.ZEff5BdUdOt5ids6"
```

**请立即采取以下措施**：

1. **撤销/重新生成这个 API key**：因为它已经暴露，应该立即更换
2. **不要将 API key 提交到 git**：确保 `opencode.json` 和 `.vibe/llm-config.json` 在 `.gitignore` 中

```bash
echo "opencode.json" >> .gitignore
echo ".vibe/llm-config.json" >> .gitignore
```

## 配置文件分离

为了兼容 OpenCode，我们已经将配置分离为两个文件：

### 1. `opencode.json`（OpenCode 原生配置）

只包含 OpenCode 支持的字段：
```json
{
  "$schema": "https://opencode.ai/config.json",
  "instructions": [
    "AGENTS.md",
    ".vibe/opencode/behavior-policies.md",
    ".vibe/opencode/safety.md"
  ]
}
```

### 2. `.vibe/llm-config.json`（Vibe 扩展配置）

包含 Vibe 专用的 LLM 配置：
```json
{
  "models": {
    "fast": {
      "provider": "openai",
      "model": "glm-4.5-air",
      "base_url": "https://open.bigmodel.cn/api/coding/paas/v4",
      "api_key": "YOUR_NEW_API_KEY_HERE",
      "temperature": 0.7
    }
  }
}
```

## 配置优先级

Vibe 会按以下顺序查找配置：

1. **`.vibe/llm-config.json`**（推荐，不影响 OpenCode）
2. **`opencode.json` 中的 `models` 字段**（不推荐，会导致 OpenCode 验证错误）
3. **环境变量**（`ANTHROPIC_API_KEY`, `OPENAI_API_KEY` 等）

## 推荐配置方式

### 方式一：使用 `.vibe/llm-config.json`（推荐）

```bash
# 编辑配置文件
vim .vibe/llm-config.json

# 添加你的 API key
{
  "models": {
    "fast": {
      "provider": "openai",
      "model": "glm-4.5-air",
      "base_url": "https://open.bigmodel.cn/api/coding/paas/v4",
      "api_key": "your-new-api-key-here",
      "temperature": 0.7
    }
  }
}

# 设置文件权限（只有你能读写）
chmod 600 .vibe/llm-config.json

# 添加到 .gitignore
echo ".vibe/llm-config.json" >> .gitignore
```

### 方式二：使用环境变量（最安全）

```bash
# 在 ~/.zshrc 或 ~/.bashrc 中添加
export OPENAI_API_KEY="your-api-key-here"

# 或者为当前项目设置
echo "export OPENAI_API_KEY=\"your-api-key-here\"" >> .envrc
echo ".envrc" >> .gitignore
```

### 方式三：混合配置

```json
{
  "models": {
    "fast": {
      "provider": "openai",
      "model": "glm-4.5-air",
      "base_url": "https://open.bigmodel.cn/api/coding/paas/v4",
      "api_key": null,
      "temperature": 0.7
    }
  }
}
```

然后在环境变量中设置 API key：
```bash
export OPENAI_API_KEY="your-api-key-here"
```

## 验证配置

```bash
# 检查路由状态
./bin/vibe route --stats
```

预期输出：
```
🤖 AI Triage Layer:
   Status: ✅ Enabled
   Environment: opencode
   Model: glm-4.5-air
   Provider: OpenAI
```

## 总结

✅ **已修复**：
- 从 `opencode.json` 中移除 `models` 字段
- 创建了 `.vibe/llm-config.json` 用于 Vibe 的 LLM 配置
- 修改了代码，优先读取 `.vibe/llm-config.json`

⚠️ **需要你做的**：
1. 立即更换暴露的 API key
2. 在 `.vibe/llm-config.json` 中添加新的 API key
3. 将配置文件添加到 `.gitignore`
4. 设置文件权限：`chmod 600 .vibe/llm-config.json`
