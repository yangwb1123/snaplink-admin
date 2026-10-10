# 跨应用浏览器身份 SSO

## 修复范围

普通 RP 的 `/login/?client_id=...&response_type=code...` 现在先读取发布的
provider discovery 能力，再由 Snaplink 校验已有 OP 身份会话。会话有效时不再
要求输入密码，仍为当前应用独立执行授权和首次 consent；没有、过期、撤销或
强度不足的会话回落正常登录。

- 前端：`lib/screens/oidc_login/oidc_session_flow.dart`。
- 后端实现：相邻 `../snaplink` 的 `protocols/oidc/browsersso/`、
  `interfaces/sso/server_userinfo.go`；正式 `cmd/sso-server` 已增加配置接线。
- `/home/u1/snaplink` 的另一份工作树及已运行服务没有被修改、切换或重启。

## 开启和部署

Snaplink SDK 和 stock server 默认关闭，避免静默改变既有认证策略。使用更新后的
Snaplink 构建，并在目标部署明确配置：

```yaml
oidc:
  browser_sso:
    enabled: true
oauth:
  auth_code:
    enabled: true
```

环境配置等价键为 `SSO_OIDC__BROWSER_SSO__ENABLED=true`；授权码能力还需
`SSO_OAUTH__AUTH_CODE__ENABLED=true`（已开启的部署保持原值）。相邻仓库的 compose
开发配置已开启；这不等于正在运行的后端已升级。

必要条件：

1. 所有应用通过同一个 HTTPS OP/登录站点的**同一浏览器 Cookie jar**发起登录。
   RP 自身域名可以不同，不需要共享 RP Cookie 或 Token。
2. 托管登录的 `/auth/login` 仍是同源代理请求；边缘必须保留请求 `Cookie` 和响应
   `Set-Cookie`，不得记录 Cookie 值或缓存认证响应。`/end_session` 和
   `/check_session_iframe` 必须路由到身份后端，不能落入 SPA fallback。
   独立 Audit、Billing、Checkout、Agent Hub/Forge API 仅透传自己的 bearer，
   不转发 OP Cookie，也不能用 `Set-Cookie` 覆盖 OP 身份；开发代理和现有 Nginx
   独立 upstream locations 均已隔离。额外部署的 Forge ingress 也需同样隔离。
3. `server.issuer` 与已发布 discovery 一致。身份 Cookie 是 host-only、HttpOnly、
   `Path=/`、`SameSite=Lax`，HTTPS issuer 下带 `Secure`，不依赖第三方 iframe Cookie。
4. 多副本共享 canonical SessionManager 和 OP 签名/验证密钥及轮换状态；不能把每个
   副本的内存会话当成 HA。原生应用优先系统浏览器；独立 WebView 不保证共享 Cookie。
5. 每个应用仍分别注册 client、redirect URI、PKCE、scope 和 resource。

正常 fresh login 仅在认证、MFA、consent 和当前应用授权最终成功后设置身份 Cookie。
Cookie 的专用 JOSE 类型只能由身份 Cookie verifier 接受，不能作为 API bearer 或
RP 的 `id_token_hint`。它指向 canonical 活跃会话，不建立平行身份会话数据库。
Cookie 最长为原始认证后八小时，并受 canonical 会话到期时间限制；免登录不会
延长身份认证时间。每个 RP 另建自己的 client-bound 授权会话和独立 Token。
新的主认证若无法建立/签发 Cookie，会清除旧的浏览器身份选择，避免下一应用
误恢复之前的账号；不会借此撤销其他 RP 已有授权。
旧 minimal/prototype adapter 的同名 raw-SID Cookie 不是本次签名 Cookie，
不会被接受为身份凭据；切换入口后需一次新的主认证，不搬迁旧 Cookie 内容。

## 发布契约与边界

provider discovery：

- `op_session_supported: true`：后端明确配置支持。
- `op_session_available`：已校验身份 Cookie 与 canonical 会话；不是应用授权。
- `op_session_error: temporarily_unavailable`：身份校验不可用，不能当成已登出或未启用。

前端只有在支持和可复用状态明确时，才发送有完整当前 RP 边界的
`POST /auth/login`，附 `resume_session: true`，不发送密码、其他应用的 Token、
Session ID 或 hint。恢复请求没有自动重试；未知结果不重放一次性事务。

保留的重新认证边界：`prompt=login`、`prompt=select_account`、`max_age=0`、过期/撤销、
ACR、账号停用、当前 provider/client/tenant 策略以及风险/MFA。首次应用 consent
仍显示当前应用真实请求的权限，不要求再次输入已满足的密码。

`prompt=none` 与普通自动恢复不同：无法免交互时交付 `login_required`、
`consent_required` 或 `interaction_required` 给 RP，不打开交互 challenge。
跳转仍要求服务端已校验的 delivery metadata；探测/网络失败而没有此证明时，
只显示本地错误，不依据浏览器输入伪造跳转或 JARM。
已有合法同 RP `id_token_hint` 的 legacy renewal 保留原路径，不跨 RP 搬用 hint。

**本次不对 opaque PAR/JAR 做自动恢复探测**：`request_uri` / `request` 继续使用
原有主认证/联合登录链路，避免自动探测消耗一次性授权请求。后端在消费前拒绝
此类 `resume_session` 请求；没有把 opaque 参数拆开或绕过其强制重新认证要求。

## 验证与运行态验收

### 本轮补齐：隔离的真实浏览器闭环

实现范围限定为 stock `sso-server` 源码构建、现有 release Web 产物、临时 HTTPS
同源网关与两个不同 loopback 主机的独立 RP。验收必须由 Chromium 实际操作密码/consent UI，
不能用页面内伪造 Token、注入 OP Cookie 或直接调用登录 API 代替。

接受条件：A 一次主认证；B 只恢复身份并独立 consent/code exchange；两套 scope、
resource、Token/SID 独立且认证时间不变；HttpOnly/Secure/Lax Cookie 不滚动续期；
独立浏览器、强制重新认证、合法登出及独立服务 Cookie 隔离有效。缺少构建、浏览器
或后端源码直接失败，不静默 skip。只启动/停止脚本自己创建的临时进程，不绑定
4444/28080、不杀已有监听器、不使用现有管理员账户、真实部署或生产数据库。

此闭环用于补足浏览器/代理证据，不取代目标部署升级和专用测试账户验收。

真实 stock + SQLite 登录发现客户端 consent 策略未持久化。修复范围限定为
SQLite/Postgres 客户端存储的 `SkipConsent`、`ConsentRefreshInterval` 和
`AllowPasswordlessOnly`：通过独立列与追加迁移保存，覆盖 Add/Put/Update、读取和
重新连接。不从可编辑 Attributes 推导授权策略，不更改 DCR 权限或自动覆盖已有
客户端。旧记录默认保留原有效零值；曾被旧版本丢弃的非零策略需运营方显式重新
配置，迁移不能猜测历史配置。接受条件是实际数据库往返与旧 schema 升级测试、
stock 登录浏览器闭环及仓内门禁通过；不因 fixture 配置而绕过 consent。

回归：

- Console：`test/oidc_session_flow_test.dart`，既有授权交付、MFA/consent、客户端
  隔离和一次性 federated continuation 测试。
- Snaplink：`test/browser_sso_test.go`、`test/browser_sso_security_test.go`，覆盖
  RP A → B 免密码、独立授权/Token/会话、consent、MFA、拒绝与撤销、Cookie purpose、
  过期/认证年龄、篡改/issuer、停用/删除账号、用户与会话存储不可用、客户端/
  provider 限制、真实 PAR 未消费、隔离浏览器、共享 canonical store 解析、
  登出和 feature-off；真实 `/userinfo` 也拒绝身份 Cookie bearer。
- Stock 接线：`cmd/sso-server/browser_sso_wiring_test.go`，真实 buildApp/buildHTTPHandler、
  SQLite 身份存储、bcrypt 凭据，以及 EdDSA/ES256/RS256/PS256。
- 代理：`tests/unit/test_proxy_http.py` 与 `test_deployment_contracts.py` 覆盖
  Cookie/重复 Set-Cookie 保留、身份登出路由、独立服务的请求/响应 Cookie 隔离，
  包括流式 SSE。

源码测试不是目标部署验收。升级服务并开启配置后，用专用测试用户在同一系统
浏览器执行 A 登录 → B 授权 → B code exchange，核对 Cookie 属性、签发客户端、
scope/resource、auth_time 与登出行为；只观察是否携带 Cookie，不记录其值。
此前身份代理 502 和未知的实际生产入口仍需部署方核实，不能用 fixture 成功代替。
