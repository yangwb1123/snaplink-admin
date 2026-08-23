# 技术债清单（advance 迭代引擎跟踪）

> 由 ai-batch-runner 的 `pi-batch advance` 扫描 + 人工甄别维护。
> 原则：**不机械硬拆**——内聚的大文件是合理架构；结构债随对应功能迭代处理。

## P2 结构债（advance 扫描，63 项）

| 类别 | 数量 | 说明 |
|---|---|---|
| 上帝文件 >400 行 | 39 | 当前工作树中的 39 个超预算 Dart 文件均已在 `engineering.yaml` 显式登记：i18n/API 数据或客户端、复杂状态页与本轮安全/治理功能页；未提高全局 400 行上限，新文件仍会触发门禁。dashboard 的低频导航已拆到 `dashboard_navigation_tail.dart`，登录、SCIM Bulk、分布式集群、租户品牌与审计日志面板的视图组合已分别拆到独立 part，其余页面按功能迭代继续组件化 |
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

## 统一模式债（已评估）

- **AsyncView 三态统一**：已评估关闭。4 页已用；其余页分为两类——
  ①纯列表页已组件化（如 break_glass 的 BreakGlassSessionsList 内部自管
  loading/error）；②混合状态页（表单+搜索+多段状态，如 clients/domains）
  套用三态容器会破坏布局（clients 迁移曾回滚：分页/路由状态耦合）。
  新页按 AsyncView（纯列表）或子组件自管（混合）模式。
- **批量操作**：已完成——BatchSelection + BatchActionBar 覆盖
  clients/tenants/users/local_users 4 页。

## 已清零（历史）

- 魔法间距 106 → 0（8pt token 化）
- 硬编码颜色 19 → 0（AppColors）
- N+1 ×4、吞异常 ×18 → 0
- 检查器误报（.dart_tool/test/ephemeral/Python 断言风格/TS any）→ 0

## 既有测试失败（已解决）

- setup_screen_test / oidc_account_flow_test 两个既有失败已在用户并行提交中修复
  （stash 验证与历史改动无关）；当前全量 1192 个 Flutter 测试 0 失败。

## i18n 当前边界

- 静态文案缺失：431 → **0**；`test/i18n_coverage_test.dart` 持续阻止新增直接英文界面文案。
- 本轮已收口所有高风险确认、批量操作提示、资源标识/数量和生命周期结果中可翻译的动态文案：统一使用 `{}` 模板、`args` 和中英文目录。
- 剩余 Dart `$` 插值均为 API 路径/序列化键、表格中的服务端数据、服务端错误原文、内部精确确认短语或纯数值展示；它们没有可复用的自然语言骨架，不进入 pattern 翻译。
- [x] **深色模式语义色点缀对比 <3**：已完成——StatusChip 和相关语义
  前景统一经 `AppColors.semanticFor` 切换同族亮色变体；`dark_mode_test`
  同时守护文字 ≥4.5 与图标/非文本点缀 ≥3.0，避免新增 token 回退到
  低对比度原色。其余未迁移的装饰性点缀仍按既有视觉债登记。
