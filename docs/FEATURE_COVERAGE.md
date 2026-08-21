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
| OAuth/OIDC 客户端 | 列表、创建、编辑、删除、详情、审批/拒绝、密钥轮换、联合回接登录页配置 | 专用体验 |
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
| 托管登录 | 客户端品牌、后端动态身份源、自定义登录页 OAuth 续接、密码登录、外部登录跳转、错误与重试 | 专用体验 |
| 账户开通与恢复 | 注册、邮箱验证、忘记/重置密码，保持反枚举响应 | 专用体验 |
| MFA 与 WebAuthn | MFA challenge、TOTP/WebAuthn、Passkey 注册、可信设备；无效 challenge 后重新认证 | 专用体验 |
| OIDC Consent | 后端权威 Scope 描述、授权详情（RAR）、同意/拒绝及缺失上下文 fail closed | 专用体验 |
| 用户门户 | 统一托管登录续接；账户资料、密码/邮箱、MFA、Passkey、恢复码、关联身份、已授权应用、组织和隐私 | 专用体验 |
| Portal 设备与会话 | 物理设备详情/改名/备注/活动/会话/信任/报失/删除，登录历史、安全活动和会话撤销 | 专用体验、条件能力 |
| 开发者门户 | Discovery 驱动的 RFC 7591 注册；一次性凭据；RFC 7592 读取、更新和删除 | 专用体验 |
| 首次初始化 | 状态探测、首个管理员、可选首个应用、多 Redirect URI、一次性密钥展示 | 专用体验 |
| 设备授权 | 设备码预检、请求方与 Scope/到期时间确认、规范化输入、终态锁定、拒绝以及认证后确认 | 专用体验 |
| 多区域与数据驻留 | 租户主区域/允许区域/写入强制配置与失效告警；Discovery 部署来源展示 | 专用体验 |
| 原生服务连接 | 登录前可配置并持久化 Snaplink 服务来源；全 API 客户端统一生效；HTTPS 强制与环回 HTTP 例外 | 横向产品能力 |
| 多语言体验 | Admin、Hosted Login/OIDC、Portal、Developer、Setup 和设备授权统一 EN/ZH；动态状态与错误模板可插值翻译 | 横向产品能力 |

## 管理端契约策略

### 两层事实来源与三态门禁

1. **运行时事实**：`GET /api/v1/admin/endpoints` 表示当前副本主动公布的
   能力和 feature 标签。
2. **发布契约**：控制台内置从 Snaplink `docs/openapi.yaml` 审核得到的
   方法/路径目录。当前管理、审计、合规、网络策略及 SCIM 目录共 197 个
   精确操作。

运行时清单目前不能单独作为完整操作目录，因此导航使用两层合并结果；接入快照
的页面同时保留未合并的运行时状态。快照把每个可选模块标记为三种状态：

- **loading/unknown**：清单尚未返回或读取失败，只展示加载/重试，不发送可选
  模块请求；
- **unavailable**：清单成功返回但没有对应路由，展示未启用状态；
- **available**：清单公布了对应路由，页面才开始读取并允许受门禁保护的操作。

真正的权限、租户边界、存储可用性和 feature gate 始终由服务端最终裁决。
Checkout 的 Billing/Stripe 上游同样要求显式部署配置，缺失时容器在 nginx
启动前失败，不会回退到核心 Snaplink 服务。

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
- 可信浏览器 grant 只从按 client ID 隔离的本地存储进入登录 JSON；URL 中的
  `device_token` 会被忽略并立即清除，且不会被转交到跨域自定义登录页。
- `401` 才结束控制台会话；`403` 表示当前身份没有该权限，不销毁仍有效的
  登录态。
- 网络请求默认有界为 30 秒；只有 GET 可对暂时性故障自动重试，任何写操作
  超时都保持“结果未知”并要求刷新核对，绝不自动重放。
- Consent 的一次性 transaction/challenge 在发送决定前即从页面状态移除；
  结果未知时必须重新开始授权，不能从同一页面重放同意或拒绝。
- 浏览器专属能力通过条件适配层隔离，使 API/模型/契约测试可在 VM 执行。
- Web 始终使用页面同源且不能覆盖；原生端在登录页即可进入设置，服务地址经
  校验后持久化，并同时用于登录、Portal、Setup、设备授权、开发者注册和管理 API。
  非环回地址必须使用 HTTPS，且地址不能携带凭据、路径、Query 或 Fragment。
  已登录时切换服务来源会先销毁当前会话并清空导航栈，旧部署签发的 Bearer
  不会被带入新部署；登录前切换则丢弃已填写凭据、challenge、OAuth 上下文和
  一次性 action，重新进入干净登录页。
- 原生壳支持密码、验证码和 TOTP 登录，并用仅进程内会话完成应用内路由续接；
  未认证 Portal 默认进入统一登录并安全返回原页面，不要求手工粘贴 Bearer。
  Admin 模块、资源详情和子资源使用平台无关的当前位置与变更事件，原生端不会
  因缺少浏览器 History API 而把内部导航静默丢弃。
  联合登录、WebAuthn/Passkey 与 OIDC `form_post` 依赖浏览器安全上下文，原生
  端显式提示使用 Web 控制台，不会伪装成已执行或静默吞掉响应。

## Snaplink 后端契约状态

租户创建与编辑表单完整支持 `home_region`、`allowed_regions` 和
`enforce_writes`，包含去空白、去重、清空策略与启用强制写入时的主区域校验；
管理员可直接配置数据驻留策略，而不再依赖 API 或命令行。

以下 22 项后端阻塞已经在同工作区的 Snaplink 后端与控制台两端闭环，并
纳入契约测试。控制台仍保留必要的输入校验、旧版本兼容和高风险动作确认，但
不再用前端文案掩盖或推测服务端结果：

这些缺口同时维护在机器可校验的
[`backend-contracts.json`](backend-contracts.json) 中。每项包含稳定编号、当前
前端缓解措施和后端验收条件；新增、删除或漏编号会使单元测试失败。

1. **已闭环——Provider/Connection 秘密边界**：读取使用服务端脱敏 DTO，
   secret 字段为 write-only；控制台继续做纵深脱敏，网络响应不再携带存储值。
2. **已闭环——设备资源边界**：物理设备与 trusted-browser grant 使用不同
   资源路径及固定 schema，删除动作不会再因同名路由作用到另一类资源。
3. **已闭环——设备与会话撤销**：所有可选依赖均有 nil guard，单个和批量
   撤销返回逐设备、逐会话结果及稳定重试键，部分失败使用 multi-status。
4. **已闭环——设备授权批准上下文**：`GET /device/verify?check=` 对 pending
   code 返回权威 `client_id/client_name`、`scopes`、`expires_in/expires_at`；
   控制台仍在字段缺失时禁止批准。
5. **已闭环——显式邮件 action**：reset、email verification、email change
   和 invitation 模板分别生成带 URL 编码 token 的服务器 action URL。托管
   登录只消费显式 flow；换邮箱和邀请在认证后由 Portal 调用各自受保护端点，
   token 不能跨用途验证；Reset、邮箱验证、Magic Link 和 Portal action 在
   提交后都会立即从地址栏和当前历史项清除一次性参数，结果未知时不会因刷新
   自动重放；页面状态也会在发送前取走 verifier，只在该请求生命周期内保留
   局部副本，不能从同一页面重复提交。
6. **已闭环——RFC 7592 无损往返**：GET/PUT 返回并持久化完整管理表示，
   普通 GET → PUT 不会清空 grant、response、contacts 或 tenant 绑定。
7. **已闭环——DCR Schema 一致性**：Discovery、OpenAPI、校验与持久化已统一
   auth method、JWKS、证书绑定、JWE metadata 和安全 redirect URI 规则。
8. **已闭环——RAT 可恢复轮换**：新 RAT 带审计的短重叠窗口；控制台仍要求
   当场确认安全保存，且不会自动重放结果不明的更新。
9. **已闭环——JARM/Redirect continuation**：XHR 登录的 JARM 成功和错误都以
   单一服务器签名 `response` envelope 返回；普通 OAuth 错误只在 redirect
   URI 已注册时携带 `redirect_uri_validated=true`。`form_post.jwt` 与顶层
   GET 仍由服务端直接交付，控制台不会采用未证明的重定向。
10. **已闭环——Primary → MFA → Consent 统一事务**：MFA 或 primary 完成后若
    需要 Consent，后端签发只含已完成认证状态的一次性
    `login_transaction_id`，不保存或重放密码/设备 token；允许、拒绝、过期、
    challenge 不匹配和事务重放均由同一服务端状态机处理。
11. **已闭环——用量 Wire Schema**：`TenantUsage` 使用明确 snake_case JSON
    tags，OpenAPI、示例和契约测试与真实响应一致。
12. **已闭环——变更申请 Wire Shape**：显式 DTO 使用固定字段名和结构化 JSON
    payload，不再依赖 Go 默认大小写或 `[]byte` base64 编码。
13. **已闭环——能力目录**：挂载路由、运行时 inventory 与 OpenAPI 由 CI
    对比，缺路由或文档漂移会失败。
14. **已闭环——首次初始化恢复**：partial success 返回所有已提交资源和服务端
    签发的幂等恢复 envelope，控制台可按原 application 步骤继续。
15. **已闭环——Branding 并发安全**：独立 branding 资源与 ETag/`If-Match`
    避免覆盖 locale、feature flags 或并发更新。
16. **已闭环——Snapshot 读取脱敏**：普通 admin 详情始终服务端脱敏，存储的
    密封恢复制品不被改写，敏感制品下载与普通读取隔离。
17. **已闭环——持久化恢复/发布 operation**：restore、pin、rollback 在执行
    前创建 operation；步骤、补偿、结果和错误落盘，重启后可通过
    `/api/v1/admin/operations` 继续查询。
18. **已闭环——Tenant 凭据撤销报告**：suspend/delete 返回 refresh token 与
    session 的精确数量、逐项错误和稳定 idempotency key。
19. **已闭环——Break-glass 生命周期耦合**：先登记 pending grant 再 mint，
    原子激活并关联凭据；失败会补偿，撤销返回全部派生 session/token 结果。
20. **已闭环——重放与跨资源批处理**：Webhook 在投递前持久化 replay claim，
    投递成功后先记录 cleanup-pending，因此清理重试不会重投；ReBAC batch 使用
    原子 SPI 并返回逐项状态与稳定幂等键。
21. **已闭环——Crypto 精确状态**：compromise 返回来源密钥实际 retirement
    结果，rotation 返回明确 key class 与 rollout 状态。
22. **已闭环——OIDC/SAML 联邦授权续接**：顶层联邦 GET 保存完整的有效授权
    请求（包括 PAR/JAR、重复 `resource`、RAR、Claims、`id_token_hint` 和
    `max_age`），上游回调只消费服务器绑定的 provider/state 一次，不再遍历
    authenticator 或创建脱离 RP 请求的通用 session。验证后的身份经客户端
    `login_page_uri` 片段中的一次性 `login_transaction_id` 回到托管登录页，继续
    经过账户状态、风险/条件访问、MFA、Consent 和授权响应交付；片段在 POST 前
    即从历史记录清除。能力位只在该安全回接已配置时为 true，控制台对所有 RP
    联邦请求在旧部署上保持 fail closed，并只采用服务端证明的终态目标和 state。
    管理端可创建、修改或清空客户端的 `login_page_uri`，并在提交前执行与后端
    一致的 HTTPS/本机 HTTP 校验，因此持久化部署无需重新运行初始配置 seed。

机器清单中的 22 项契约均为 `resolved`；能力位缺失时控制台仍保持 fail
closed，不以版本号或按钮可用性推断安全能力。

## SCIM 运行约束

- Group 仅在 permissions provider 和 `scim.groups.enabled` 同时启用时存在。
  User schema 与 Enterprise User 扩展为常驻能力；`/Schemas` 会完整公布
  `employeeNumber`、`costCenter`、`organization`、`division`、`department`
  和 `manager` 及其子属性。
- Filter 支持标量比较、布尔组合与括号，但不支持 value-path 或带 Schema URN
  的列表查询路径。执行顺序为 filter → sort → paginate；结果上限为 200。
- User PATCH 会先验证再单次持久化；Group 成员协调和 Bulk 都不是跨资源事务。
  页面会保留逐项结果并提示失败后的 reconciliation，不把 HTTP 200 等同于整批
  成功。
- UserName 在内存、SQLite、Postgres 与 Redis 内置存储上按大小写不敏感规则
  原子唯一；并发创建由最终写入边界裁决为单一成功者，其余返回 SCIM 409
  `uniqueness`。自定义 UserProvider 仍应提供等价的唯一约束。
- Group 角色/成员协调和 Bulk 仍可能出现跨资源部分成功；面向高并发连接器的
  部署应结合逐项结果执行 reconciliation。
- Handler、Discovery 与 OpenAPI 已统一公布 `sortBy/sortOrder`，排序在过滤后、
  分页前执行。

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
make test
make build-prod
git diff --check
```

涉及浏览器 API 的组件还需运行 Chrome 平台测试；涉及真实存储、feature gate
或授权边界的场景需按 `tests/integration/README.md` 配置环境变量，并对专用
Snaplink 测试部署验证。Python 部署契约测试同时校验 Docker、Compose、
Kubernetes、nginx 和 CI 的运行参数保持一致。
