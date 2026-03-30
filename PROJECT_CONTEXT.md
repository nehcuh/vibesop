# Project Context

## Session Handoff

<!-- handoff:start -->
### 2026-03-31 Windows Git Bash $HOME 环境变量修复

**问题**: Git Bash wrapper 使用 `$USERPROFILE` 但 Git Bash 实际使用 `$HOME`

**修复**: wrapper 优先检查 `$HOME`，回退到 `$USERPROFILE`

**提交**:
- `f47fbac` - fix(windows): use HOME instead of USERPROFILE
- `87e7207` - feat(ai-routing): environment detection + user choice mode

**待测试**: Windows 用户重新安装后验证 `vibe route` 命令

---

### 2026-03-30 Windows Git Bash 兼容性修复

**问题**: Claude Code 在 Windows 上内部使用 Git Bash 执行命令，但 `vibe-install.bat` 只创建 `vibe.bat`，bash 无法执行。

**修复**: 更新 `bin/vibe-install.bat` 同时创建两个 wrapper：
- `vibe.bat` - cmd.exe/PowerShell
- `vibe` (无扩展名) - Git Bash，包含 Windows 路径转换 (C:\path -> /c/path)

**提交**: `ecba713` - fix(windows): add Git Bash wrapper for Claude Code compatibility

---

### 2026-03-30 深度项目审查 + 文档更新 + 性能验证

**本次会话主要成果**:

### 1. 深度项目审查 ✅
- **修正错误判断**: 最初评估 6.4/10，实际验证后 7.9/10 (+1.5)
- **核心验证**:
  - ✅ 测试覆盖: 1609 个测试用例（非仅 10 个文件）
  - ✅ 代码优化: 727 行（vs 旧架构 1149 行，减少 37%）
  - ✅ 双平台支持: claude-code + opencode 完全实现
  - ✅ 成本透明: $0.11/月计算合理

### 2. 关键教训 (P021)
1. **评估测试用例数量，而非测试文件数量** - 10 个文件包含 1609 个测试
2. **检查实际代码，而非仅依赖文档** - 文档可能滞后
3. **文档滞后于代码演进** - 需要建立同步机制

### 待观察项
- 运行性能基准测试验证 95% 准确率声明
- 观察环境检测在生产环境的表现

<!-- handoff:end -->
