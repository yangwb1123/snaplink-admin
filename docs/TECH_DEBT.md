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

- i18n 覆盖测试（项目标准）已通过；标准之外仍有 431 条静态文案未注册中文翻译
- 分布：admin 各 tab（commerce/recovery/scim/break-glass 等大区块最多）
- 处理：随页面功能迭代分批注册；新增代码必须注册（coverage gate 守护）

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
- 剩余：50 条动态消息（Dart `$` 插值，如 'Client $id approved.'）——需改造为 {n} 模板风格才能走 pattern 翻译；记录待处理
