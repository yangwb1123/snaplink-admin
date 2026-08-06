# Snaplink Console 产品与架构基线

## 1. 产品定位

`sso-console` 是 Snaplink 的人机交互层和管理控制面，不是另一个身份服务。
协议签名、Token 签发、身份断言校验、策略裁决和租户隔离始终由 Snaplink
后端完成；控制台负责让不同角色以可理解、可审计且不会误操作的方式使用这些
能力。

产品目标：

1. 一个静态 Web 产物覆盖管理、登录、自助、开发者、初始化和设备授权六个
   入口。
2. 以后端发布契约和当前副本能力为依据，不依赖前端猜测的私有接口。
3. 高频任务提供领域工作流，低频任务提供受契约约束的专家入口。
4. 对秘密、PII、不可逆操作和部分成功采用 fail-closed 设计。
5. 后端能力缺失时说明缺少什么，不用伪成功或不完整表单掩盖契约缺口。

## 2. 用户与核心任务

| 角色 | 主要目标 | 对应入口 |
|---|---|---|
| 平台管理员 | 管理租户、应用、身份源、系统健康和发布恢复 | `/admin/` |
| 安全管理员 | 调查 Token、设备、会话、审计事件和紧急访问 | `/admin/` |
| 租户/组织管理员 | 管理成员、邀请、品牌、权限和联邦连接 | `/admin/`、`/portal/` |
| 支持人员 | 在最小权限下处理账户锁定、MFA、恢复和生命周期问题 | `/admin/` |
| 最终用户 | 登录、同意授权并自助管理账户、安全、设备和隐私 | `/login/`、`/portal/` |
| 应用开发者 | 动态注册和维护 OAuth/OIDC 应用 | `/developer/` |
| 部署所有者 | 完成首次管理员和首个应用初始化 | `/setup/` |
| 设备码用户 | 看清请求方和权限后批准或拒绝；上下文缺失时只能拒绝 | `/device/verify` |

## 3. 领域边界

### 管理控制面

管理控制面按身份、应用、授权、安全、租户、治理和运维拆分。导航项与页面使用
同一个模块描述对象，避免能力裁剪后路由索引错位。运行时清单、OpenAPI 目录
和源码兼容清单合并为页面可用契约；服务端的鉴权、feature gate、存储和租户
边界仍是最终裁决。

### 托管交互面

登录、MFA、WebAuthn、Consent、账户开通/恢复和设备授权是后端状态机的用户
界面。前端只能推进后端给出的 challenge，不自行推导 Scope、客户端身份或
授权结果。缺少批准上下文时必须拒绝继续高风险步骤。

### 用户自助面

Portal 使用当前用户 Token 调用 `/me` 资源，只允许用户管理自己的资料、
凭据、设备、会话、关联身份、Consent、组织和隐私请求。管理 API 与自助 API
不共享可变状态模型，避免把管理员权限意外带入用户工作流。

### 开发者面

Developer Portal 按 Discovery 暴露的能力完成 RFC 7591/7592。初始
client secret、Registration Access Token 及其轮换值只展示一次。若服务端
读取表示不足以无损执行替换更新，表单禁用保存而不是覆盖未知注册元数据。

## 4. 契约和状态模型

```text
Snaplink runtime inventory ─┐
OpenAPI published catalog ──┼─> Effective capabilities ─> Navigation + pages
Source-only compatibility ──┘                               │
                                                            v
                                              Server authorization/gates
                                                   remain authoritative
```

- OpenAPI 目录提供稳定的方法、路径和参数模板。
- Runtime inventory 覆盖同一路由时，其 feature 元数据优先。
- Source-only 路由只代表某些版本已挂载；`404/501` 是正常的能力降级。
- Advanced operations 只能选择目录中的操作，不能输入任意 URL。

读状态采用有界缓存和并发请求去重；用户刷新可绕过缓存。成功写操作按资源路径
边界失效列表和详情缓存，并发布本地数据变更事件。只有幂等 GET 会自动重试；
任何超时的写操作都保持结果未知，不自动重放。SCIM 写操作优先携带
`If-Match`，以 `412` 暴露并发冲突。

## 5. 安全和隐私不变量

- Access Token 仅保存在 tab 级 `sessionStorage`；显式退出同时清理会话上下文。
- 可信浏览器 grant 只允许在用户明确选择后按 client ID 存入 `localStorage`，
  并可由用户撤销；该 bearer 等价凭据不从 URL 接收，也不转交自定义登录页。
- 联合登录的 PKCE verifier、返回目标和随机 `state` 只存在当前 tab；Portal
  action token 不进入 `state`，匹配的授权回调会在换取 Token 前清除地址栏和
  整组一次性状态。
- RP 的 OIDC/SAML 上游回调只通过服务器绑定的一次性事务恢复原授权请求；
  `login_transaction_id` 只进入 URL fragment，控制台在 POST 前清除它，且不会
  与 provider discovery 并发。MFA、Consent 和终态交付继续使用同一服务端状态机。
- PAR/JAR 可以覆盖地址栏中的 `redirect_uri`、`state` 和 `response_mode`；
  终态交付只接受后端验证后回显的有效值。只有后端明确返回
  `authorization_request_passthrough_supported=true` 才开放任何 RP 联邦入口；
  旧部署或缺少有效 `login_page_uri` 时显式关闭，不降级成另一条授权请求。
- client secret、Registration Access Token、临时 Token、恢复码和模拟 Token
  只进入隔离的一次性视图；不进入通用响应、缓存、日志或跨页状态。
- Provider/Connection 等后端可能回显配置的资源，在 UI 深层脱敏；长期修复
  必须是后端 read DTO 脱敏和 secret 字段 write-only。
- 用户数据导出作为附件下载，不在 DOM、剪贴板或通用 JSON 面板中展开。
- 删除、擦除、回滚、批量撤销和紧急权限操作必须二次确认；高影响操作要求
  输入资源标识或预估命中数量。
- 批量与跨资源操作逐项呈现结果，HTTP 2xx 不自动等价为全部成功。
- `401` 结束登录态；`403` 只表示当前身份无权执行该操作。
- Admin 入口只探测受 `admin:read` 保护的只读运行时能力目录，不以读取某一类
  客户端、用户或租户资源作为全局授权替代判断。

## 6. 关键流程验收

### 登录与授权

1. 加载客户端品牌和服务端身份源。
2. 保留经校验的 OAuth 参数和返回目标。
3. 完成密码或外部身份源登录；联合回调恢复原 RP 请求，challenge 失效后重新认证。
4. Consent 显示服务端权威 Scope/RAR，只用一次性登录事务同意或拒绝；不在
   浏览器内保留、重放主密码或验证码。
5. 按后端结果返回调用方或建立本地 Portal/Admin 会话。

### 高风险管理变更

1. 读取当前资源与能力。
2. 展示影响范围、不可逆性和部分成功语义。
3. 要求适当级别的确认。
4. 发送一次写请求，不做自动重放。
5. 清除秘密、失效缓存、刷新服务端状态并显示真实结果。

### 充值 Checkout

1. 当前 Admin Token 必须同时具有 `admin:write` 与 Stripe Adapter
   的精确 audience；浏览器中不存放 machine client secret。
2. Console 先向 Billing 创建 `provider=stripe` 且无
   `provider_order_id` 的 pending 订单，金额与币种从此后不再由
   Checkout 请求提供。
3. 通过同源 `POST /api/v1/checkout/sessions` 发送显式 `tenant_id`、
   `order_id` 和从可信 Console origin 构造的成功/取消回跳地址。
4. 只将经 HTTPS 结构校验的 `redirect_url` 交给真实浏览器导航；
   不将它渲染成 HTML，native shell 不会误当作产品内路由。
5. Adapter 不可用或导航失败时，pending 订单保留且可从订单行
   重试；UI 只显示有界的安全错误，不回显上游详情。

### 动态客户端注册

1. 读取 Discovery，约束 auth method、grant type、response type 和 PKCE。
2. 本地校验 redirect URI 与组合约束。
3. 注册后一次性展示凭据，并要求确认已安全保存。
4. 管理更新前验证读取表示是否足以无损往返。
5. RAT 轮换后阻止关闭，直至用户确认已保存新值。

## 7. 非功能要求

| 维度 | 基线 |
|---|---|
| 安全 | 默认拒绝、秘密最小驻留、无写重放、服务端权限权威 |
| 可靠性 | 明确 loading/empty/error/retry；并发冲突和部分成功可见 |
| 可维护性 | 领域文件不超过工程行数预算；浏览器 API 使用条件适配层 |
| 可测试性 | API 契约、模型和关键风险控件可在 VM 测试；浏览器状态另跑 Chrome |
| 国际化 | 六个入口统一支持 EN/ZH；静态、动态和表单文案受自动漏译门禁保护 |
| 可部署性 | 单一静态产物；六个前缀由网关做 SPA fallback 和同源 API 路由 |
| 可观测性 | 服务端审计/SSE 为权威，本地操作日志只辅助当前操作者 |

完整能力矩阵、后端阻塞项和 SCIM 运行约束见
[FEATURE_COVERAGE.md](FEATURE_COVERAGE.md)。
