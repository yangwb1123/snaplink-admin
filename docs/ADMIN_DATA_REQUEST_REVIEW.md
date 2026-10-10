# Admin 页面数据请求复核

本轮复核范围是管理端的 34 个模块入口、资源详情与子菜单的数据加载。
**页面可见不等于请求成功；测试 fixture 成功也不等于当前部署恢复。**

## 契约依据

- Snaplink 发布的 `docs/openapi.yaml`、`proto/admin/v1/*.proto` 和实际 gateway 注册。
- 核心 gRPC gateway 的 protobuf JSON 使用 camelCase、int64 字符串；兼容 REST
  响应可能使用 snake_case。请求参数仍按发布契约发送，不由响应字段反推。
- Audit Governance 的 `internal/httpapi/snaplink_console.go`：兼容接口接受
  `limit/cursor/event_type/tenant_id/trace_id/outcome`，不把 opaque cursor 转成 offset。
- 运行时 inventory 是部署证据，但可能遗漏由独立 gRPC gateway 注册的合法 RPC。
  不把这种遗漏当作用户会话、租户或权限 API 被禁用的证据。

`lib/api/admin_wire_payload.dart` 只适配上述核心 protobuf 路由的已知字段。
原始字段和值保留；`attributes/settings/branding/config/metadata` 等自定义 JSON map、
bytes 内容、SCIM 以及独立 Audit/Billing/Agent/Forge 响应不做通用递归改名。

## 逐页入口覆盖

`test/admin_page_data_loading_test.dart` 从实际导航模块定义构建页面，而不是另写一份
菜单清单。每个入口检查真实页面挂载、请求 fixture 命中、加载/渲染错误和无自动 mutation。
需要用户输入的页面不会为满足测试而发送无边界请求。

| 模块组 | 已覆盖入口 |
|---|---|
| Overview | overview、health |
| Identity | clients、users、local-users、scim-directory、permissions、authz-checks |
| Security | connections、domains、device-security、token-security、token-policies、token-exchange、network-policies、access-policies、threat-policies、dr-mode、crypto-keys、credentials、emergency-access、change-approvals |
| Tenants | tenants、organizations、commerce、usage-analytics、privacy-compliance |
| Operations | webhooks、live-activity、operations、recovery-releases |
| System | governance、audit-log、user-support |

Commerce 的测试显式注入独立 checkout probe；不靠核心 inventory 猜测服务是否启用。

## 已修正的数据链路

以下路径中的 `A` 表示 `/api/v1/admin`。

| 页面/子菜单 | 请求与响应契约 | 修复 |
|---|---|---|
| Clients 列表、详情与过期查询 | `A/clients`、`A/clients/{id}`、`A/clients/expiring`；`clients/client`、`nextPageToken/totalSize` | 保留分页、redirectUris、grantTypes、tenantId、clientSecretExpiresAt 等 protobuf 字段；不再当成空值或丢失下一页 |
| Users 列表、详情 | `A/users`、`A/users/{id}` | externalId 兼容；自定义 attributes 原样保留 |
| User Sessions / Consents / MFA / Lifecycle / Device security | `A/users/{id}/…` | 只加载当前子菜单；已发布的 sessions RPC 不被 REST inventory 的遗漏裁剪；保留主用户与独立资源错误；旧响应不能覆盖新选择 |
| User Lifecycle 内容 | `A/users/{id}/lifecycle` | 修复成功加载后 timeline 在无限高度约束下崩溃；无状态时显示 Unknown，不能默认为 active |
| Tenants 列表、详情 | `A/tenants`、`A/tenants/{id}` | homeRegion、allowedRegions、enforceWrites 兼容；settings 保持 opaque |
| Tenant Members / Invitations / Usage / Branding | 当前租户的对应资源 | 只加载当前子菜单；无可用子菜单不再越界；未读取/被拒绝的集合不伪装成零指标 |
| Domains | `A/domains`、`A/domains/{hostname}` | tenantId、isApex 兼容，SSO client 的单项 Get 正确解包 domain |
| Permission Roles / Assignments | `A/permissions/{client}/roles`、`…/assignments` | 按 roles/assignments 字段取列表，不依赖 JSON 属性顺序；显示 userId 与 roles；切换/历史导航只加载当前列表 |
| Webhooks 列表、详情、死信 | `A/webhooks/subscriptions`、`A/webhooks/deadletters` | 统一 dead_letters/旧字段兼容；按订阅过滤；读取嵌套 event.type、last_error、last_failed_at |
| Token Security 子菜单 | portfolio、suspicious、sessions、expiring、tokens | 不聚合无关子菜单失败；刷新强制读取；403/连通性/契约错误保留诊断；temp 无自动读取也能显示表单 |
| Token Policies | `A/token-policies` | 首次打开即加载，避免从未请求就显示空表；刷新绕过旧缓存 |
| Recovery / Releases / Operations | snapshots、releases、releases:current、operations 及 RPC actions | snapshotId、operationId、currentStep、gitRef、嵌套报告等 protobuf 字段兼容；不解码 bytes/秘密内容 |
| Governance 子菜单 | health、compliance、configuration、lifecycle 的对应 read specs；audit 显式查询 | 当前子菜单只加载自己的来源，刷新读取当前事实；保留具体来源错误；旧请求不能覆盖新选择 |
| Health / Distributed Cluster | health、readyz、status、storage-health、federation/health、keys、JWKS | 不吞掉可选来源错误；5 次鉴权探测实际走网络，502 不标成 unauthorized；无 backend health 数据不宣称全部健康 |
| Privacy / Retention 错误恢复 | subject erase、retention-sweep | 导出与 dry-run 可重试；执行写操作不由通用 Retry 闭包重放；发送 erasure 前使旧 preview 失效 |

## 手动／按对象查询复核

在入口挂载覆盖之外，继续提交 fixture 查询并检查实际返回内容：

| 工作台 | 契约与修复 |
|---|---|
| WASM 授权检查 | `POST A/wasmauthz/check` 使用字符串 `subject/action/resource` 和可选字符串值 `context`，不是 `principal` 或对象型 resource；错误形状在发送前拒绝，POST 仅为已发布的只读调试检查 |
| ReBAC 授权检查 | `GET A/rebac/check` 按 `object/relation/subject` 查询；再次检查绕过缓存，修改输入使旧结果和迟到响应失效 |
| Token exchange chain | `GET A/tokenexchange/chains/{jti}` 显示 `subject_id/actor_subject/parent_jti/recorded_at`，保留旧字段；空集合不伪造成 envelope hop，畸形 chain 在读取阶段报契约错误而不是构建崩溃 |
| Permissions 工作台 | 输入 client 后才加载，按 roles/assignments 字段解析；选择／历史切换只读当前来源，逐项强制刷新，403 不丢失另一成功来源；编辑 client 清除旧表和菜单草稿，旧角色弹窗不能改投另一 client；`new` 作为 client ID 不再误判成模块创建动作 |
| User Support | 只输入 user ID 不等于已加载；读取绑定捕获的 user，刷新所有当前来源，拒绝迟到响应并保留具体错误；失败来源不显示假空卡片，缺失 lifecycle 为 Unknown，旧 transition 选择失效 |
| Usage subject investigation | `A/tokens/subjects/{subject}` 仅向 token 来源发送可选 client_id；linked sessions 无此筛选参数；两来源刷新均走网络，编辑 subject/client 清除旧调查结果 |
| SCIM | 保持 `Resources/startIndex/count/filter/sortBy/sortOrder` 原生大小写；刷新和 Apply 走网络，重用浏览器切换 Users/Groups 有请求代次保护；Schemas 失败不否定成功的 provider discovery，刷新错误仍可见；畸形 Resources 报错，零长度页不提供不前进的 Next |
| Commerce | tenant＋currency 绑定查询结果，编辑即清除旧财务事实，迟到响应不能覆盖新对象；wallet/ledger 刷新绕过缓存；403/502 不伪装成不存在的钱包或空账本，保留成功的订单数据；checkout probe 仍独立且 memoized |

所有需要查询边界的页面仍由操作员显式执行；读取 fixture 不产生身份、财务或授权 mutation。
没有通过隐藏模块、伪造空数据或切换独立服务来替代修复。

## 回归与未验证项

新增内容回归：

- `test/admin_wire_payload_test.dart`：两种 transport、分页、引用、报告、opaque map、
  编码 ID、旧响应兼容与独立服务隔离。
- `test/admin_detail_data_loading_test.dart`：16 个详情/深链场景与精准请求集合。
- `test/admin_submenu_data_loading_test.dart`：17 个子菜单、历史切换、缓存/403 与迟到响应场景。
- `test/admin_source_error_recovery_test.dart`：来源错误可见、集群探测与安全 Retry。
- `test/manual_authorization_chain_test.dart`：WASM 请求形状、真实 chain 字段、刷新、输入变更与契约错误。
- `test/manual_query_scope_test.dart`：权限／用户支持／主体调查的显式查询、范围隔离、部分错误与迟到响应。
- `test/manual_scim_query_test.dart`：原生 SCIM 查询、分页、独立 discovery 错误与刷新。
- `test/manual_commerce_query_test.dart`：tenant/currency 切换、钱包／账本刷新与不可用来源。

验收仍使用仓内门禁：`python3 cli.py check`、`python3 cli.py test`、`make analyze`、
`make build-prod`、`make release-artifact-check`。不添加尺寸豁免或降低阈值。

尚未完成带真实管理员凭据的全模块后端联调。当前长期代理的正确身份上游、各独立服务
origins 和权限须由部署方确认；不擅自切换到另一个健康但身份事实可能不同的服务，也不
对生产执行会创建/删除数据的验证。原有 25 个非豁免超长文件已全部完成结构拆分，
仓内 check、2239 项测试、分析、生产构建及产物检查全绿；172 个 skipped 不算部署验收。
结构等价证据与验证范围见 [结构修复记录](STRUCTURE_REFACTOR.md)。
