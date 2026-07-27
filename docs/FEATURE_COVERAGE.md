# Snaplink Console 功能覆盖与产品边界

本文档是 `sso-console` 相对同目录 `snaplink` 后端的功能基线。它同时回答三个
问题：用户能完成什么、前端依据什么契约提供该能力、哪些体验仍需要后端先
修正才可安全开放。

## 状态定义

- **专用体验**：有领域页面、校验、空态、错误态和风险确认。
- **契约入口**：由 Advanced operations 按已发布方法和路径提供，适合低频
  或专家操作，不允许输入任意 URL。
- **条件能力**：仅在后端契约或兼容清单中存在；部署未启用时显式降级。
- **后端阻塞**：当前契约不足以安全实现，前端刻意 fail closed。

## 产品覆盖矩阵

| 领域 | 已交付能力 | 覆盖方式 |
|---|---|---|
| 控制面能力发现 | 运行时端点、OpenAPI 目录、补充路由分层；模块能力裁剪；副本差异说明 | 专用体验 |
| OAuth/OIDC 客户端 | 列表、创建、编辑、删除、详情、审批/拒绝、密钥轮换 | 专用体验 |
| 用户目录 | 用户与本地用户 CRUD、生命周期、会话、Consent、MFA、密码/邮箱支持操作 | 专用体验 |
| 账户锁定支持 | 使用 `client_id + identifier` 清除锁定，不把用户 ID 误作凭据标识 | 专用体验 |
| 设备安全 | 全局设备统计、筛选、用户设备、活动、信任、单个撤销及有估算保护的批量撤销 | 专用体验、条件能力 |
| 租户与组织 | 租户 CRUD/状态、成员、邀请、用量、导出、组织视图 | 专用体验 |
| 租户品牌 | Logo、颜色、名称、登录页 URI 和未知设置无损保留；预览和重置警告 | 专用体验、条件能力 |
| 连接与域名 | 联邦连接、域名校验、健康探测、全局域名生命周期 | 专用体验 |
| 权限与授权 | 角色、分配、菜单、ReBAC 与 WASM 授权检查、策略包查看 | 专用体验 |
| Token 与会话安全 | 组合视图、可疑/临期 Token、会话、撤销、临时 Token、批量撤销 | 专用体验 |
| Token 策略与交换 | Token 策略、使用量、Subject 组合、交换链追踪 | 专用体验 |
| 网络与访问策略 | 网络策略 CRUD/分类、访问策略、威胁策略、DR 模式 | 专用体验 |
| Webhook | 订阅、删除、死信、重放和详情 | 专用体验 |
| 紧急访问与变更 | Break-glass 请求/审批/模拟/撤销；变更申请/审批/拒绝 | 专用体验 |
| 恢复与发布 | 备份、快照、恢复、发布、固定、回滚和当前版本 | 专用体验 |
| 密钥与凭据 | 加密密钥、轮换、泄露标记、凭据库存和泄露处理 | 专用体验、契约入口 |
| 治理与运维 | 配置差异/历史、集群差异、存储与联邦健康、实时事件、审计、健康 | 专用体验 |
| 隐私与合规 | 数据映射、Consent 证据、主体导出、擦除 dry-run、保留扫描、SOC 2 证据 | 专用体验、契约入口 |
| SCIM 2.0 | 能力/Schema 发现、User/Group 浏览与详情、创建/替换/PATCH/删除、分页筛选、Bulk | 专用体验、条件能力 |
| 低频管理 API | 已发布管理方法、路径参数、Query/Body、SCIM content type、写操作确认 | 契约入口 |
| 托管登录 | 客户端品牌、后端动态身份源、密码登录、外部登录跳转、错误与重试 | 专用体验 |
| 账户开通与恢复 | 注册、邮箱验证、忘记/重置密码，保持反枚举响应 | 专用体验 |
| MFA 与 WebAuthn | MFA challenge、TOTP/WebAuthn、Passkey 注册、可信设备；无效 challenge 后重新认证 | 专用体验 |
| OIDC Consent | 后端权威 Scope 描述、授权详情（RAR）、同意/拒绝及缺失上下文 fail closed | 专用体验 |
| 用户门户 | 账户资料、密码/邮箱、MFA、Passkey、恢复码、关联身份、已授权应用、组织和隐私 | 专用体验 |
| Portal 设备与会话 | 物理设备详情/改名/备注/活动/会话/信任/报失/删除，登录历史、安全活动和会话撤销 | 专用体验、条件能力 |
| 开发者门户 | Discovery 驱动的 RFC 7591 注册；一次性凭据；RFC 7592 读取、更新和删除 | 专用体验 |
| 首次初始化 | 状态探测、首个管理员、可选首个应用、多 Redirect URI、一次性密钥展示 | 专用体验 |
| 设备授权 | 设备码预检、规范化输入、终态锁定、拒绝以及认证后确认 | 专用体验、后端阻塞部分批准 |

## 管理端契约策略

### 三层事实来源

1. **运行时事实**：`GET /api/v1/admin/endpoints` 表示当前副本主动公布的
   能力和 feature 标签。
2. **发布契约**：控制台内置从 Snaplink `docs/openapi.yaml` 审核得到的
   方法/路径目录。当前管理、审计、合规、网络策略及 SCIM 目录共 178 个
   精确操作。
3. **源码兼容清单**：当前有 17 个已挂载但未进入 OpenAPI/运行时清单的
   Branding、Provider 和 Device/Security 路由。它们独立标记为
   `source-only`，调用方必须把 `404/501` 当作未启用。

运行时清单目前不能单独作为完整事实来源，因此导航使用三层合并结果；真正的
权限、租户边界、存储可用性和 feature gate 始终由服务端最终裁决。补充清单
不得被当作长期 API 稳定性承诺。

### 专用工作流与契约兜底

高频、破坏性或需要业务语义的操作必须使用专用页面。Advanced operations
只从契约目录选择端点，不能输入任意路径；所有非 GET 操作要求输入绑定到
确切方法与解析后资源路径的确认短语。SSE 被导向可取消的实时活动页面，主体
数据导出直接作为附件下载，
一次性密钥使用隔离对话框显示且不写入通用响应状态。可解码完整资源的
Snapshot 详情也不会进入通用响应面板。

## 安全与产品决策

- 删除、擦除、回滚、批量撤销等操作采用二次确认；批量设备撤销还要求非空
  筛选、刷新命中估算并输入 `REVOKE N DEVICES`。
- GDPR 擦除先 dry-run，再要求输入主体标识；法律保留和多状态结果不会被
  伪装成完全成功。
- Tenant Branding 与 DCR 更新保留前端不认识的服务端字段，避免一次编辑
  静默丢失新能力；Branding reset 不调用会清空全部 Settings 的后端 DELETE，
  而是基于最后读取快照移除已知品牌键。
- SCIM 详情的 `meta.version` 会原样作为 `If-Match` 发送；并发写返回 412，
  不会静默覆盖目录同步器或另一位管理员的更新。
- Scope、Consent、设备类型和运行时能力都以服务端响应为权威，不能从按钮
  文案或 URL 推断。
- `401` 才结束控制台会话；`403` 表示当前身份没有该权限，不销毁仍有效的
  登录态。
- 网络请求默认有界为 30 秒；只有 GET 可对暂时性故障自动重试，任何写操作
  超时都保持“结果未知”并要求刷新核对，绝不自动重放。
- 浏览器专属能力通过条件适配层隔离，使 API/模型/契约测试可在 VM 执行。

## 需要 Snaplink 后端处理的契约缺口

以下项目不能靠前端“补一个按钮”安全解决：

1. **Provider/Connection 配置泄密**：Provider 管理响应会返回完整配置；
   enterprise connection 的 `connectionToJSON` 也会把含
   `oidc_client_secret` 的 `Config` 原样返回。控制台会深层脱敏且不开放
   Provider CRUD，但秘密已经经过网络。后端应提供脱敏 read DTO，并把 secret
   字段定义为 write-only。
2. **设备资源路由碰撞**：不同后端能力可能把 `/me/devices` 用作物理设备或
   MFA trusted grant。Portal 会按响应 shape 区分，并在物理/歧义响应下禁用
   trusted-grant DELETE。后端应拆分为稳定且不冲突的资源路径。
3. **设备会话撤销不可靠**：后端 bulk-revoke handler 忽略设备 `Delete` 和
   session `Destroy` 的错误，却仍递增 `revoked` 并返回 200；单设备
   lost/delete/admin delete 也忽略 session list/destroy 错误。另有
   device store 已挂载而 session manager 为空时多个 `/me/devices` handler
   可能 panic 的组合。控制台只能使用保守文案并展示后端报告；后端必须增加
   nil guard、传播逐项失败并返回可核对的 multi-status。
4. **设备授权缺少批准上下文**：`GET /device/verify?check=` 目前只返回
   `pending/approved/denied/expired`，没有 client、Scope、到期时间等用户确认
   所需信息。控制台允许拒绝，但在无法展示请求方和权限时不允许盲目批准。
5. **邮件 action 无法区分**：password reset、email verification、email
   change 和 invitation 共用 `smtp.link_base_url`，默认模板都只追加
   `?token=`。共享 SPA 无法安全判断 token 类型；前端只在显式
   `flow=reset_password|verify_email` 时消费。后端应使用每类链接或签名的
   action/flow envelope。
6. **RFC 7592 表示不足以往返**：DCR GET/PUT 响应省略 `grant_types`、
   `response_types`、`contacts`、`tenant_id`，但 PUT 又会用请求中的 grants
   全量替换。普通 GET 后保存可能清空授权类型；控制台因此 fail closed，只在
   刚注册且仍持有可信 request snapshot 时允许更新。后端需返回并持久化完整
   注册表示。
7. **DCR Schema 与实现漂移**：OpenAPI 宣称 `private_key_jwt`，校验器却拒绝；
   handler 支持 `tls_client_auth/self_signed_tls` 和 JWE response metadata，
   Schema 又未声明，且缺少 `jwks/jwks_uri`/证书绑定字段。后端 redirect URI
   校验也只检查非空。后端必须统一 Schema、校验和持久化语义。
8. **RAT 轮换存在不可恢复窗口**：RFC 7592 PUT 成功后旧 Registration Access
   Token 立即失效，新值只在响应中出现一次；若服务端已写入而响应丢失，应用
   会永久失去管理凭据。需要幂等更新、短重叠窗口或受控恢复机制。
9. **JARM/Redirect continuation 不适合 XHR**：`query.jwt/fragment.jwt` 的
   外部 302 会被 Hosted UI 的 fetch 跟随并受 CORS 限制；错误 JSON 又没有
   `redirect_uri_validated` 证明，前端不能安全跳转到 URL 参数中的地址。后端
   应返回一次性 authorization transaction/已验证 redirect envelope，或由
   服务端拥有顶层 continuation 和签名的成功/错误交付。
10. **MFA → Consent 缺少统一 continuation**：MFA challenge 被单次消费后，
    若登录再返回 `consent_required`，服务端没有携带“primary + MFA 已完成”的
    一次性事务。重放初始密码请求可能再次进入 MFA；网络歧义也无法重试当前
    factor。后端需要串联 primary、MFA、Consent 和 response mode 的统一登录
    transaction。
11. **用量 JSON Schema 不稳定**：`TenantUsage` 没有 JSON tags，管理响应实际
    使用 `TenantID/TokensIssued/...`，与 OpenAPI/其余 API 的 snake_case
    不一致。控制台做兼容归一化；后端应补 tags 和契约测试。
12. **变更申请 Wire Shape 不稳定**：`ChangeRequest` 缺少 JSON tags，
    `Payload []byte` 还会被默认编码为 base64，而 UI/契约期望结构化 payload。
    控制台做兼容解码并继续深层脱敏；后端应提供显式 DTO，避免字段大小写和
    payload 编码依赖 Go 默认行为。
13. **能力目录漂移**：17 个源码已挂载路由尚未进入 OpenAPI 和运行时清单。
   后端应补齐文档/生成流程，之后移除前端补充目录。
14. **首次初始化的部分成功**：Setup 可能创建管理员后再遇到可选应用失败。
   UI 会按服务端 `created` 结果如实展示，后端若要原子语义需提供事务或明确的
   可恢复工作流。
15. **Branding 整体覆盖 Tenant Settings**：Branding GET 实际返回整个
   `Tenant.Settings`，PUT 整体替换，DELETE 会清空 locale、feature flags 等
   非品牌设置，而且没有 ETag/version 防止并发覆盖。控制台禁用 DELETE，并
   基于最后读取快照 PUT 回未知键，但仍无法消除并发丢失更新。后端需独立
   branding 命名空间、字段级 PATCH/删除和条件写。
16. **Snapshot 详情可能泄露凭据材料**：`snapshot.redact_secrets` 默认关闭，
   可恢复快照的用户属性可能包含 password hash、seeded password 等；详情 API
   会把解密后的 `resources_json` 交给 `admin:read`。控制台不会请求或展示该
   详情，并从 Advanced operations 隐藏该读取。后端应强制服务端脱敏，或改为
   独立高权限、`no-store` 的密封制品下载。
17. **恢复与发布不是事务操作**：Snapshot restore 按资源族顺序落库，release
   pin/rollback 又跨 snapshot、流量 pinner 和 registry；任一步失败都可能已经
   改变部分状态，错误响应还会丢失 partial report。控制台在失败后强制刷新并
   要求外部核验；后端需持久化 operation ID/state、逐步结果和补偿结果。
18. **Tenant 状态与凭据撤销不是同一结果**：suspend/delete 成功只证明 tenant
   记录已改变；refresh token/session 枚举和销毁错误会被忽略。控制台明确要求
   到安全库存核验。后端应返回 revocation multi-status 或异步 job ID，并提供
   可重试的 reconciliation。
19. **Break-glass 级联撤销不可核验**：grant 会先标记 revoked，派生 session
   destroy 错误随后被忽略；创建时先 mint session、再保存 grant，也可能留下
   孤儿会话。控制台只称“grant record 已撤销”并要求核验派生凭据。后端需原子
   登记或补偿清理，并返回级联撤销逐项状态。
20. **批处理/重放存在部分成功语义**：Webhook replay 投递成功后可能因 DLQ
   删除失败而继续留队并被重复投递；ReBAC Bulk/Batch 也逐项写入而非事务。
   控制台刷新并展示残留项，不把错误理解为零变更。后端需事务型 SPI，或返回
   逐项 multi-status/幂等 reconciliation。
21. **Crypto 管理动作是 best-effort**：mark compromised 不保证来源密钥已
   退役，`/admin/keys/rotate` 也只轮换 signing key，并非所有 crypto keys。
   控制台采用精确文案并要求到权威 KMS/issuer 核验；后端应返回实际 retirement
   与 rollout 状态。

这些限制是显式产品边界，而不是静默失败。后端契约修复后，应先增加契约测试，
再将对应能力从 fail-closed/兼容模式升级为正式专用体验。

## SCIM 运行约束

- Group 仅在 permissions provider 和 `scim.groups.enabled` 同时启用时存在。
  User schema 为常驻能力；Enterprise User 扩展虽能读写，但当前 `/Schemas`
  尚未完整公布扩展属性。
- Filter 支持标量比较、布尔组合与括号，但不支持 value-path 或带 Schema URN
  的列表查询路径。执行顺序为 filter → sort → paginate；结果上限为 200。
- User PATCH 会先验证再单次持久化；Group 成员协调和 Bulk 都不是跨资源事务。
  页面会保留逐项结果并提示失败后的 reconciliation，不把 HTTP 200 等同于整批
  成功。
- UserName 唯一性和 Group 角色/成员写入受当前后端存储模型限制，存在并发竞争
  或部分成功窗口。面向高并发连接器的部署仍需后端提供原子约束/事务。
- Handler 与 Discovery 支持 `sortBy/sortOrder`，但当前 OpenAPI 参数说明遗漏；
  前端按真实 handler 契约发送，后端应补齐规范文档。

## 不应被前端复制的协议能力

PAR、JAR/JARM、DPoP、mTLS、CIBA、Token Exchange、FAPI、加密
ID Token/UserInfo、SAML、Kerberos、RADIUS、SSF/CAEP 等属于 Snaplink 的
协议执行面或可插拔基础设施。控制台负责配置后端已发布的客户端/策略字段、
展示 Discovery/健康信息和完成需要人参与的登录、Consent、设备确认流程；
它不会在浏览器中重新实现 Token、签名、断言验证或机器间协议。未进入管理
契约的服务器选项仍应由部署配置管理，而不是由前端发明私有接口。

## 验收基线

每次变更至少运行：

```bash
flutter analyze
flutter test
flutter build web --release
git diff --check
```

涉及浏览器 API 的组件还需运行 Chrome 平台测试；涉及真实存储、feature gate
或授权边界的场景需使用 `tests/integration/` 对目标 Snaplink 部署验证。
