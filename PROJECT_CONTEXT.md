# Project Context

## Session Handoff

<!-- handoff:start -->
### 2026-03-31 Windows 安装脚本调试完成

**问题**:
- Unicode 字符显示乱码（GBK vs UTF-8）
- 复杂函数调用导致静默退出
- 反斜杠字符被 CMD 解析为特殊字符

**解决过程**:
1. 移除 Unicode → 改用 ASCII
2. 移除复杂函数 → 线性执行
3. 移除 ASCII 艺术 logo → 简单标题
4. 创建极简版本测试 → 确认可工作
5. 基于工作版本逐步添加功能

**最终版本** (ee6a406):
- 147 行，纯 ASCII，线性执行
- 4 步安装流程：验证 → 检测 → 引导 → 安装
- 清晰的错误提示和安装指引

**待验证**: 用户在 Windows 上测试最终版本

<!-- handoff:end -->
