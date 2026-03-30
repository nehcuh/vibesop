# Project OpenCode Configuration

Generated from the portable `core/` spec with profile `opencode-default`.
Applied overlay: `none`

## ⚠️ CRITICAL AGENT INSTRUCTION

**Do NOT guess or hallucinate rules.** When you need information from any category below, you **MUST** use the `read` tool to fetch the file contents before proceeding.

## 🚀 AI-Powered Skill Routing

**⚠️ MANDATORY: ALWAYS call vibe route before starting ANY non-trivial task**
This is NOT optional — routing ensures the correct skill is loaded for the task.

### MANDATORY Workflow (必须遵循 - 无条件执行)

**Step 1**: 调用路由获取推荐
```bash
vibe route "<user_request>"
```

**Step 2**: 读取推荐的技能文件 ⚠️ 关键步骤
```markdown
read skills/<matched-skill>/SKILL.md
```

**Step 3**: 按照技能的步骤执行
- 不要跳过技能定义
- 严格按照技能说明的流程执行

**Step 4**: 完成后运行验证
```bash
# 根据技能要求运行相应的验证命令
```

## Project Context

<!-- Describe your project: tech stack, architecture, key constraints -->

## Project-specific rules

<!-- Add rules that apply only to this project -->

## Reference docs

Supporting notes are under `.vibe/opencode/`:
- `behavior-policies.md` — portable behavior baseline
- `safety.md` — safety policy
- `routing.md` — capability tier routing
- `skills.md` — available skills
- `tools.md` — available modern CLI tools
- `execution.md` — execution policy
