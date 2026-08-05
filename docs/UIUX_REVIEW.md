# UI/UX 审查报告（ai-batch-runner 规范驱动）

> 使用 ai-batch-runner 的 ui-specs（layout-patterns / interaction-patterns /
> component-spec / async-data）逐页分析 snaplink-console，发现的问题按
> P0-P2 分级。检查方法：`check-frontend-quality.py --strict` 机械信号 +
> 逐页人工对照规范。

## 审查范围（6 个重点页 + 通用模式）

### 1. clients_tab（列表页）— 总体达标

| 规范项 | 状态 |
|---|---|
| 页面骨架（标题+操作栏+筛选+列表） | ✅ AdminBreadcrumb + AdminListHeader + 搜索栏 + ListView |
| 操作分级（创建=主操作，批准/拒绝=危险操作+确认） | ✅ ConfirmDialog 确认 |
| 反馈闭环（成功/失败 SnackBar） | ✅ |
| 三态（loading/empty/error） | ⚠️ 手动实现（未用 AsyncView），error 态**无重试按钮** |
| 搜索触发 | ✅ onSubmitted 明确触发（符合决策表，无需防抖） |

**本轮修复**：error 态补 Retry 按钮（错误必须可恢复）。

### 2. dashboard_screen（工作台）— 数据密度高

- ✅ 指标卡片 + 事件流
- ⚠️ 597 行 god-file：卡片网格+事件流+状态混合，建议按区块提取 widget
- ⚠️ 36 决策点：条件渲染复杂，抽 helper

### 3. tenants_tab / users_tab（列表页）— 深层嵌套

- ⚠️ 嵌套深度 20-21（widget 树 + 行内 switch）——结构性深，随功能迭代提取
- ✅ 三态齐全（手动）

### 4. oidc_login/consent_view（认证流）— 状态完整

- ✅ 错误展示 + 加载
- ⚠️ 嵌套 7、18 处魔法间距（已批量修复）
- ℹ️ 认证页风险高：已由风险分级自动升级到 L2 工作流

### 5. portal/overview_tab（用户门户）— 表单交互

- ✅ 保存反馈 + 失败恢复
- ⚠️ 嵌套 7——属性控件循环提取 helper

### 6. 通用模式问题

| 模式 | 现状 | 建议 |
|---|---|---|
| 三态实现 | **两种并存**：4 页用 AsyncView，大量页手动 FutureBuilder | 新页面统一 AsyncView；存量页随功能迭代迁移 |
| 错误态可恢复 | 多数页 error 后依赖 header 刷新 | 错误态直接给 Retry（interaction-patterns） |
| 确认对话框 | ✅ ConfirmDialog 统一组件 | 保持 |
| 间距 token | ✅ 已全部 token 化（0 违规） | 保持 |
| 颜色 token | ✅ AppColors 类 | 保持 |

## 修复清单（已提交）

1. **clients_tab error 态 Retry**（P1，本轮）
2. 魔法间距 106 处 → 8pt token（上轮）
3. 颜色 19 处 → AppColors（上轮）
4. N+1 ×2 并行化（上轮）
5. 吞异常 ×5 加日志（上轮）

## 技术债（不硬拆，随功能迭代）

- god-files：dashboard 597 / clients 509 / tenants 512 / users 505 / governance 512 / token_security 624
- 深层嵌套：tenants_tab 21 / users_tab 20 / clients_tab 20
- AsyncView 统一迁移（存量 40+ 页）

## 持续守护

`make spec-check` + `.github/workflows/spec-gates.yml`（UI 规范 + 工程质量 + dart analyze）
