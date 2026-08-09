# P3-1 / P4-1 / P5-1 交付记录（api-gap analysis fix-plan）

日期：2026-08-09 · 执行：ai-batch-runner 分析管线后续项

## P3-1 — gateway pattern 列表审计（后端，已修复）

**方法**：对照 `cmd/sso-server/build_http.go` 手维护的
`adminGatewayExactPaths`（`adminGatewayResourcePaths` + 
`adminGatewayTokenAndUserPaths`）与生成的 grpc-gateway 注册
（`gen/proto/admin/v1/*.pb.gw.go` 的 `WithHTTPPathPattern(...)`）。

**结果**：
- 生成 40 条 pattern → 归一化（`{var}`→`{id}`）35 个唯一形状
- 手维护列表 37 条 → 归一化 35 个唯一形状
- **真实漂移 1 处**：`/api/v1/admin/clients/expiring`（clients.proto
  `ListExpiring` RPC 生成）未列入 → 请求落外层 mux catch-all → SSO
  router 无此路由 → **404**
- 其余差异均为文档化例外：custom-verb 形状（`{id}:pin` 等冒号段，
  ServeMux 形状匹配即覆盖）与变量名差异（`{client_id}` vs `{id}`）

**修复**：`cmd/sso-server/build_http.go` `adminGatewayResourcePaths` 增加
`"/api/v1/admin/clients/expiring"`（含注释记录审计来源）。
验证：`go build ./cmd/sso-server/` OK；`go test ./cmd/sso-server/` 全绿。
后端提交：`0aab82b5`。

## P4-1 — dead-entry 清单修正

**修正**：branding DELETE 是**活跃**路由（此前报告误列为 dead）；
`SSOAdminClient` 未使用公开方法 6 个（非 19；19 含私有 helper 误报与
catalog 死条目混淆）：

| SSOAdminClient 方法 | 对应端点 | 前端实际载体 |
|---|---|---|
| `rotateClientSecret` | POST /api/v1/admin/clients/{id}/rotate-secret | clients_tab 直接走 `SnaplinkAdminApi` |
| `deleteConnection` | DELETE /api/v1/admin/connections/{id} | connections_tab 直接走 `SnaplinkAdminApi` |
| `deleteDomain` | DELETE /api/v1/admin/domains/{hostname} | domains 页直接走 `SnaplinkAdminApi` |
| `deleteWebhookSubscription` | DELETE /api/v1/admin/webhooks/subscriptions/{id} | webhooks_tab 直接走 `SnaplinkAdminApi` |
| `reportCredentialCompromise` | POST /api/v1/admin/credentials/{type}/compromise | credentials 页直接走 `SnaplinkAdminApi` |
| `compromiseCryptoKey` | POST /api/v1/admin/crypto/keys/{id}/compromise | crypto_keys_tab 直接走 `SnaplinkAdminApi` |

处置：**保留**（双载体是既有架构——`SSOAdminClient` 是注入面，页面多走
`SnaplinkAdminApi`；删除会破坏测试与潜在调用方）。文档记录，不做代码
删除。

## P5-1 — 权威缺口报告（重生成）

### 汇总

| 类别 | 数量 | 处置 |
|---|---|---|
| 目录条目（catalog） | 215 | 后端全部有注册（0 MISSING / 0 CONSTANT_ONLY） |
| 真实 404 面 | 2 | P0-1 checkout probe（已修 `91ac8b5`）；P3-1 clients/expiring（已修 `0aab82b5`） |
| 部署掩盖 | 1 | P0-2 compose/Dockerfile 隐式默认（已修 `789d54d`） |
| 前端未入目录调用 | 5 | /health、/readyz、/api/v1/status、jwks.json（已服务）；checkout/sessions（P0-1 门控） |
| 依赖 store 接线的 opt-in 路由 | ~175 | 部署配置问题（后端按 store 挂载）；前端能力门控在未启用时隐藏页面（设计降级） |
| 契约加固 | — | P1-1 契约测试 11 项（`test/admin_contract_consistency_test.dart`）；P2-1 写按钮门控钉 |
| dead entries | 6 | 文档记录（P4-1），不删除 |

### 结论

"专业模式全部路由不报错"的代码层面已达成：
1. 后端 215 条目录端点全部注册（分析证明 + P3-1 网关审计补上最后一处漂移）
2. 前端能力门控优先（未启用功能不显示）+ commerce checkout 探测门控
3. 部署 fail-fast（无 billing/stripe 时显式失败而非静默 404）
4. 契约测试锁定 24 个 supports* 标志与目录/后端的对应关系，防漂移
