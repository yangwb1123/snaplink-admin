# 技术债清单（R205 structure / i18n / docs fan-out ledger reconciliation）

> 本账以当前工作树和当前 `engineering.yaml` 为准。原则：**不机械硬拆**——内聚的大文件、协议流程和数据表是合理架构；结构债随对应功能迭代处理。R173-R179 对账 R166-R178 的 census、i18n、docs fan-out 与最终门禁，只同步已验证的台账数字，不改变 Dart API、路由或架构阈值。

## P2 结构债（当前快照）

`engineering.yaml` 的 `filesize.max_lines` 仍为 **400**，且边界是 `<=400`（400 行本身通过）。`lib/screens` 当前有 **248** 个 Dart 文件，页面/组件的 `>400` 上帝文件数量为 **0**。`lib` 共 **391** 个生产 Dart 文件；`lib/main.dart` 仍计入该 census，但不影响超预算结论。

| 检查口径 | 当前数量 | 台账解释 |
|---|---:|---|
| UI 上帝文件：`lib/screens/**/*.dart` `>400` | **0 / 248** | R121-R145 已将页面 root/part 收敛到 400 行以内；不把 catalog Map 或 API client 算作 UI 页面。 |
| 生产 Dart：`lib/**/*.dart` `>400` | **3 / 391** | 3 个 i18n Map/catalog 数据表，均为有理由的显式豁免；没有超预算 API client，也不是 UI 页面债。 |
| 全仓 Dart（`lib/` + `test/`，排除 `.dart_tool/`、`build/`）`>400` | **29 / 566** | 其中生产代码为上面的 3 个，另有 26 个 `_test.dart`；`_test.dart` 是 `engineering.yaml` 的既定 ignore，不计入生产 P2。 |
| 严格前端结构扫描的 heuristic warning | **32 条 / 28 个文件** | 扫描 `lib/screens` 的 248 个文件；32 条是实测 warning records，4 个文件命中两个类别。这是复杂度/耦合提示，不是 filesize 失败，也不等于页面债。 |

### 400 行边界与有意豁免

原登记的四份 i18n catalog 数据表中，当前实际仍超过 400 行的只有以下 3 个：

- i18n catalog 数据表：`lib/i18n/app_strings_source_admin_core.dart`（750）、
  `lib/i18n/app_strings_source_admin_features.dart`（480）、
  `lib/i18n/app_strings_source_portal.dart`（418）。这些是按源文件合并的 Map/catalog，拆分会破坏既有 catalog 合并方式，因此保留显式豁免，不作为 UI 页面债。

`lib/i18n/app_strings.dart` 是同一 catalog 架构中的另一份入口数据表，R152 后为 **206 行**，已不再需要 filesize 豁免；它仍包含 catalog Map，但 catalog Map 不等于页面债。`lib/api/sso_client.dart` 经 R151 后为 **101 行**，也已不再需要 API 层豁免。

此外，`engineering.yaml` 仍明确登记 `lib/main.dart`（56 行、required exemption）和 7 个 3 行兼容 re-export forwarder：`lib/sso_client.dart`、`lib/screens/admin/snaplink_admin_api.dart`、`lib/screens/admin/snaplink_admin_types.dart`、`lib/screens/portal/portal_api.dart`、`lib/screens/oidc_login/oidc_login_api.dart`、`lib/screens/device/device_verify_api.dart`、`lib/screens/setup/setup_api.dart`。它们既未超过 400 行，也不是 UI 页面。当前没有为超预算 `lib/screens` 实现保留的 filesize 豁免。

所有 `lib/screens` root/part 均通过 400 行预算：恰好位于边界的 root 是 `lib/screens/developer/dcr_credentials.dart` 和 `lib/screens/developer/manage_panel.dart`（均 400 行）；56 个 screen part 中最大为 `lib/screens/oidc_login/oidc_login_view_flow.dart`（392 行）。R199 重新扫描结果为 **0 / 248** 个 `lib/screens` 文件超 400 行。

## R121-R145 已完成的预算拆分范围

以下行数是当前代码核对值，格式为 root/part 或 root/view；所有文件均 `<=400`。拆分使用同一 library 的 Dart `part`，保留 root 中的状态、controller、mutation、路由、API/capability 和安全语义，未复制业务实现。

| 轮次 | 已完成范围（当前行数） |
|---|---|
| R121-R125 | Clients：`clients_tab.dart` 380 / `clients_tab_view.dart` 260 / `clients_tab_sections.dart` 260；Token Security：399 / 371 / 202；Webhooks：264 / 161 / 254；Usage Analytics：201 / 390；Local Users：383 / 154。 |
| R126-R130 | Governance Widgets：369 / 223；Admin Operations：303 / 236；Recovery Releases：381 / 210；User Support Cards：300 / 167；R130 完成上述预算、状态、table/card/list 和回归终检。 |
| R131-R135 | Commerce：349 / 88；Tenant Detail：306 / 166；Break Glass：374 / 108；Crypto Keys：272 / 241；Setup Widgets：375 / 120。 |
| R136-R140 | Governance：295 / 127；Threat Policies：206 / 249；User Support：224 / 239；Admin Users：303 / 281。Developer Manage 保持单文件 400 行，以满足 13-file census 和固定 wire-site 约束。 |
| R141-R145 | Client Detail：227 / 302；Dashboard：379 / 70；OIDC account flow：268 / 143；Privacy/Compliance：190 / 222；R145 复核所有 root/part、唯一 part 引用和既有结构门禁。 |

## R156-R159 Portal 路径与 SSE 回归台账

- `lib/screens/portal/portal_security_contract.dart` 保留 `PortalSecurityPaths`，并集中既有 Portal root/resource paths 到 `PortalPaths`；资源 id 与 WebAuthn `session_id` 仍在 wire 位置使用 `Uri.encodeComponent`。既有 query、body、headers、Session/Consent/MFA/secret 行为和 action route index 不因 R156-R159 改动。
- R157 的 VM ownership guard 位于 `test/portal_security_contract_test.dart`：轻量 Dart lexer 先跳过行/块注释，只扫描 `lib/screens/portal` 的字符串字面量；动态 server data、display prose 和 `/portal` UI route 不会成为 API literal。唯一 owner 是 contract 与既有 re-export shim；`lib/api/portal_api.dart` 保持未修改。
- R158 的 `test/portal_notifications_test.dart` 当前为 9/9：覆盖 SSE bearer/multiline parse、初始 401（expiry hook exactly once）、403/500（不触发 hook）、有限 event 后正常 done（无重连/重复订阅），以及 Portal bell 的 event/unread 状态保留。该回归不声称 mark-read 的取消/重订阅语义。
- R159 复核：Portal contract/notification/audit guard tests、`flutter analyze`、filesize、directory fan-out 与 `git diff --check` 通过；没有修改 API client、认证、路由或安全协议。

## R161-R164 Admin capability prefix 边界台账

- R161 的 prefix classification 现为 segment-aware：保留 exact、合法 descendants、trailing-slash subtree、参数段后的 custom verbs，以及既有 normalization；`domains-x`、`devices-evil` 等 lookalike sibling 不再误开已有能力。
- R161-R163 只复用既有 runtime/catalog 路径判定，不新增后端能力、endpoint、route 或 API wire；`has` 的 exact method/path contract、runtime/documented merge 与三态语义保持不变。
- 回归范围为 `test/snaplink_admin_api_test.dart` 的 exact/descendant/custom-verb/lookalike 与 documented-prefix 正反例、`test/admin_navigation_test.dart` 的 runtime-only lookalike，以及 `test/admin_contract_consistency_test.dart` 的全量 flag/catalog 一致性。

## R166-R170 Admin wire-path owner 台账

- `lib/api/admin_paths.dart` 集中已重复的 Admin wire path constants/builders；opaque identifier 继续单次 `Uri.encodeComponent`，模板只用于 capability/catalog matching。未复制 generated `routes` catalog，也未迁移 Portal、checkout、SCIM、audit、device 或 attachment/dedicated workflow owner。
- Admin API clients、navigation、operations、tenant/user detail、webhook、break-glass、credential、crypto、domain、permission、threat、branding 与 commerce plans consumer 仅替换既有 path 来源，最终 method/query/body/header/cache/error/认证语义保持不变。
- `AdminOpsHelpers` 与 Operations selector 复用 R161 segment-aware matcher；合法 descendants/custom verbs 保留，`auditx`、`snapshots-evil` 等 sibling 不再误分类。
- R166-R170 通过 path builder、wire-equivalence、selector、dedicated workflow、navigation/catalog、security、Portal ownership、Developer census、filesize/fan-out 与最终全量门禁；无新增 endpoint、route、依赖或业务能力。
- R205 对账：当前 `lib/api/admin_paths.dart` 为 **122** 行，`routes` catalog 为 **215** 个唯一 operation；`lib/screens` 为 **248** 个文件且 **0** 个超 400 行，Developer census 仍为 **13** 个文件。`docs/ui` 顶层为 **12** 个直接子目录（上限 12）；`docs/ui/pages-per-page` 当前为 **280** 个报告文件、**0** 个子目录，不构成 fan-out 违规；`checks/filesize.py` 与 `checks/directory_fanout.py` 均 PASS。

## R151-R152 已完成的非 UI 预算拆分

两轮均保持 `max_lines: 400`，只做同一 library 内的纯结构拆分，不把 API client 或 catalog Map 计作 UI 页面债：

| 轮次 | 已完成范围（当前行数） |
|---|---|
| R151 | `lib/api/sso_client.dart`：100；新增 `lib/api/sso_client_session.dart`：34、`lib/api/sso_client_resources.dart`：371、`lib/api/sso_client_transport.dart`：129。原 621 行 client 的 session、resource 和 transport 方法按 part 搬移，认证、请求、错误、超时与缓存语义保持不变。 |
| R152 | `lib/i18n/app_strings.dart`：206；新增 `lib/i18n/app_strings_accessors.dart`：208。root 保留 catalog、构造器、fallback、`_t`、`_sourceTranslations` 与 context part 关系，访问器移至 extension，i18n 行为保持等价。 |

### Developer census

`lib/screens/developer` 当前固定为 **13 个 Dart 文件**：`dcr_credentials`、`dcr_delete_dialog`、`dcr_form_controller`、`dcr_metadata_form`、`dcr_models`、`dcr_round_trip_notice`、`dcr_update_projection`、`dcr_validation`、`developer_api`、`developer_screen`、`discovery_region_notice`、`manage_panel`、`register_panel`。R139 的 part 实验会把目录扩大到 14 个并移动固定 wire-site，因此已回退；后续若拆分 Manage，必须维持 13-file census、400 行边界及 `manage_panel.dart:57` 的 `client_id` wire-site。

### OIDC / Portal 文案边界

`lib/screens/oidc_login` 当前没有 `audit` 文案或 audit-ring 字样。面向用户的静态 OIDC 文案通过 `context.tr`/目录中的 `app_strings_source_oidc.dart` 维护。Portal 保留账户 security/activity 文案和服务端事件展示，但不拥有本地 audit ring；Portal API path 仍由 `portal_security_contract.dart` 与既有 re-export shim 负责。API 路径、协议字段、服务端错误原文、token/序号和其他纯数据展示保持原值，不为没有自然语言骨架的值强行建立翻译 pattern。该边界也适用于 R143 新增的 account-flow part，不把协议/数据文本误计为 UI 文案债。

## 严格结构扫描：非阻塞 heuristic warning

执行 `python3 tools/ai-dev-gates/check-frontend-quality.py --dir lib/screens --strict --json` 的当前实测结果为 32 条 warning records（9 nesting、11 decision、12 API-call），涉及 28 个文件。该工具的严格模式会把 warning 报为 violation，但这些规则是缩进、正则和调用次数 heuristic；R153 不把它们当作页面 filesize blocker。控制流 warning 仅作为未来可安全提取的候选，必须先证明不会改变状态、表单、分页、能力门控或协议语义。

- **控制流嵌套候选（9，阈值 >8）**：`dashboard_screen` 11、`governance_tab` 9、`permissions_cards` 13、`tenant_form_dialog` 9、`user_form_dialog` 10、`register_panel` 10、`device_verify_screen` 9、`login_view_widget_layout` 9、`oidc_login_view_flow` 10。多数是 Flutter widget tree；OIDC/device/表单项还带协议或状态语义，不能为降低数字而机械拆分。
- **决策点候选（11，阈值 >30）**：`clients_tab` 32、`connections_tab` 31、`permissions_tab` 34、`token_security_tab` 39、`jarm_completion` 40、`oauth_params` 32、`oidc_authorization_flow` 33、`oidc_provider_flow` 39、`device_detail_dialog` 35、`devices_tab` 31、`notifications_tab` 47。它们是分页/能力/授权/协议/结果分支的审查提示；若无纯展示 helper 的明确收益则保留。
- **API-call/coupling warning（12，阈值 >5）**：`admin_ops_helpers` 6、`commerce/commerce_api` 15、`connections_tab` 9、`governance_tab` 6、`permissions_tab` 9、`recovery_releases_tab` 8、`scim/scim_resource_browser` 7、`tenant_organizations_tab` 7、`user_support_tab_view` 6、`portal/notifications_tab` 6、`portal/organization_admin_tab` 6、`portal/overview_tab` 6。它们是多端点页面编排、SCIM/Commerce 适配或复杂表单状态的有意聚合；`commerce_api.dart` 也不是 `lib/api/sso_client.dart`，不能将该 heuristic 误报成 UI 大文件债。除非发现重复同用途调用，否则不为满足计数阈值抽取。

## i18n 对账（覆盖清零；identity pattern 已清理）

- EN/ZH catalog 覆盖：`appAdditionalStrings` 的 EN/ZH key 集为 **105 / 105** 且一致；`lib/i18n/app_strings_source_*.dart` 的 canonical EN key 集与 `appSourceStrings['zh']` 的对应 key 集均为 **2313**，2313 个 ZH 值全部非空，插值占位符集合 **2313 / 2313** 一致；`i18n_catalog_uniqueness_test.dart` 通过且 `appAdminUxSourceZh` 已接入 `appSourceStrings`。
- 静态文案缺失：`test/i18n_coverage_test.dart` 当前实测 **0** 条缺失（raw `Text`/localized call/property/helper 及 command palette 均通过）。英文是 source key/fallback，中文覆盖由同一测试直接核验。
- 动态消息模板化：历史基线 50 → **0 条有骨架**（5 轮 60+ 处；`{n}` 模板 + args + zh 注册）。LocalizedText 支持 args 透传；操作反馈、计数、错误前缀、详情页标题和状态行均已覆盖。
- 纯数据展示（`'$e'` 错误原文、`'{index + 1}'` 序号、计数、动态字段名）没有可复用的自然语言骨架，保持原文不模板化；错误正文保持 API 原文是刻意设计。
- R199 复核 `lib/i18n/*.dart` 的 source-pattern 输入：共 **315** 个真实模板条目，identity source-pattern 为 **0**；2313 个条目的 key/value 插值占位符集合均一致。R177 已移除经 R176 证明为纯数据的 6 个 identity 条目，R178 回归确认没有误删中文模板；纯数据展示继续使用 `Text`，不为降低计数拆 catalog Map。
- `test/i18n_coverage_test.dart` 持续阻止新增未注册的直接英文界面文案；R179 目标回归套件共 **78** 项通过（含 i18n、结构、path ownership、client_id 与 audit 边界）。

## 统一模式债（已评估）

- **AsyncView 三态统一**：已评估关闭。4 页已用；其余页分为两类——①纯列表页已组件化（如 break_glass 的 `BreakGlassSessionsList` 内部自管 loading/error）；②混合状态页（表单+搜索+多段状态，如 clients/domains）套用三态容器会破坏布局（clients 迁移曾回滚：分页/路由状态耦合）。新页按 AsyncView（纯列表）或子组件自管（混合）模式。
- **批量操作**：已完成——`BatchSelection` + `BatchActionBar` 覆盖 clients/tenants/users/local_users 4 页。

## 已清零（历史）

- 魔法间距 106 → 0（8pt token 化）。
- 硬编码颜色 19 → 0（AppColors）。
- N+1 ×4、吞异常 ×18 → 0。
- 检查器误报（`.dart_tool`/test/ephemeral/Python 断言风格/TS any）→ 0。
- 深色模式语义色点缀对比 <3：已完成——StatusChip 和相关语义前景统一经 `AppColors.semanticFor` 切换同族亮色变体；`dark_mode_test` 同时守护文字 ≥4.5 与图标/非文本点缀 ≥3.0，避免新增 token 回退到低对比度原色。其余未迁移的装饰性点缀仍按既有视觉债登记。

## 既有测试失败（历史记录）

- `setup_screen_test` / `oidc_account_flow_test` 两个既有失败已在此前并行提交中修复；R145 报告记录的全量 VM、browser 与 harness 门禁通过。此处不把历史验证数字当作本次 R153 的新测试结果。
