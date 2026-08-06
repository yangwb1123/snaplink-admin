# 技术债清单（advance 迭代引擎跟踪）

> 由 ai-batch-runner 的 `pi-batch advance` 扫描 + 人工甄别维护。
> 原则：**不机械硬拆**——内聚的大文件是合理架构；结构债随对应功能迭代处理。

## P2 结构债（advance 扫描，68 项）

| 类别 | 数量 | 说明 |
|---|---|---|
| 上帝文件 >400 行 | 12 | tab 页 500-620 行（clients/tenants/users/governance/token_security/admin_operations）；sso_client 607（判定内聚 API 客户端，保留）；dashboard 597（导航注册表，保留） |
| 深层嵌套 >8 | 17 | tenants_tab 21 / users_tab 20 / clients_tab 20 等（widget 树结构性，随功能迭代提取） |
| 决策点 >30 | 8 | oidc_authorization_flow 58 / governance 52 等（复杂逻辑，提取 policy 需谨慎） |
| api calls >5 | 13 | 需人工甄别（6 个不同端点=合理；同用途重复才提取） |

## i18n 债（手工扫描，431 条）

### 已清零（第 1-5 轮推进）

- 静态文案缺失：431 → **0**（spread catalog 逐文件扫描修正）
- 动态消息模板化：50 → **0 条有骨架**（5 轮 60+ 处；`{n}` 模板 + args + zh 注册）
  - LocalizedText 支持 args 透传；操作反馈/计数/错误前缀/详情页标题/状态行全覆盖
  - 纯数据展示（`'$e'` 错误原文、`'{index + 1}'` 序号、计数、动态字段名）无语言骨架，
    保持原文不模板化（错误正文保持 API 原文是刻意设计）
- 教训：值==key 的占位翻译会污染 `_sourcePatterns` 匹配（'Page 3 · 12 users'
  被 '{x} · {y}' pattern 截获）——纯数据一律用 Text 不用 LocalizedText

## 统一模式债

- AsyncView 三态统一：4 页已用，40+ 页手动 FutureBuilder——clients 迁移尝试回滚（分页/路由状态耦合），随页重构
- 批量操作：clients 已实现，推广到 tenants/users 时提取通用组件

## 已清零（历史）

- 魔法间距 106 → 0（8pt token 化）
- 硬编码颜色 19 → 0（AppColors）
- N+1 ×4、吞异常 ×18 → 0
- 检查器误报（.dart_tool/test/ephemeral/Python 断言风格/TS any）→ 0

## 既有测试失败（非本次迭代引入，stash 验证与所有改动无关）

- setup_screen_test: 'walks through admin creation and finish' —— enterText 找不到 'Admin username' TextField（待查：可能与 MaterialApp 无 localizations 环境相关）
- oidc_account_flow_test: 'signup registers an account' —— posted.single 为空（确认对话框流程/API mock 时序待查）

## i18n 进展（第 21-30 轮）

- 静态文案缺失：431 → **0**（5 轮推进 + 扫描方式修正：spread catalog 需逐文件查）
- 剩余：34 条动态消息（Dart `$` 插值）——需改造为 {n} 模板风格才能走 pattern 翻译；记录待处理。
  已推进（两轮）：LocalizedText 支持 args 透传；操作反馈（Client approved/rejected/actioned、
  {op} completed）、计数（{count} selected/entries）、错误前缀（Error: {detail}）、
  {label}: {count}、{resource} unavailable、{count} more results 共 12 条已模板化 + zh 注册。
  纯数据展示（'$e' 错误原文、'{devices.length}'、索引类）保持原文不模板化（无语言骨架）。
- [ ] **深色模式语义色点缀对比 <3**：dark 表面（#1E293B）上 danger/warning
  accentBlue 点缀对比 2.26-2.83（WCAG 非文本 ≥3）。StatusChip 内图标已用
  50% 叠表面提亮补偿；列表图标等使用点待 AppColors 支持主题化（或 dark
  变体）后统一解决。
