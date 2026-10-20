# 跨应用浏览器身份 SSO

## 已实现的托管普通登录

A、B 各自通过浏览器顶层导航到同一个 canonical OP（身份提供方）的**显式托管入口**，
使用各自注册的 code/S256 请求。托管页先读取 provider discovery，再由 Snaplink 校验
HttpOnly OP 身份 Cookie 与 canonical 会话；可复用时 B 提交自己的 `resume_session`，
不再输入已满足的密码。**复用身份不等于复用授权**：每个 RP（应用）仍有自己的
consent、授权码、Token 和 client-bound SID；原始 `auth_time` 不因恢复而刷新。

Console 只是 UI；身份、客户端、会话、Token 与策略裁决归 Snaplink，不另建身份库。
普通恢复实现见 `lib/screens/oidc_login/oidc_session_flow.dart`；不同 RP origin 的
真实 Chrome 证据来自下述独立 stock fixture，不是用户实际两应用的验收。
**这不表示 generic RP 跟随 discovery 就能打开登录页：当前该导航只得到 provider JSON。**

## 双应用接入清单

**当前缺输入，以下均待应用/部署所有者核实；真实 App A→B：`not_run`。** 已知
`https://sso.ywbsd.site` 与 first-party `sso-admin-console`，并不是两份应用注册。

- [ ] 提供实际 A、B 的应用登录入口，以及各自现有注册的精确 client、callback、
  client 类型/认证方式、tenant、provider、scope/resource、consent、prompt/max_age、
  ACR/风险/MFA 边界；确认各自 code/S256、state/nonce 校验，不猜注册或有效策略。
- [ ] 确认同一个 canonical OP/issuer、advertised endpoint 的完整 scheme/authority，
  以及所有者支持的托管 UI origin、路径与当前 RP 参数 handoff。标准 discovery RP
  使用原样发布的 `authorization_endpoint`；当前未选 provider 的 `/auth/login` 返回
  JSON、没有 UI。只有显式确认/配置的托管 `/login/` 才是下述 password-once 入口；
  仅支持 discovery 自动 handoff 的 RP 当前被阻塞，不得静默改 URL 或发明生产入口。
- [ ] 由所有者确认两应用所用的托管产物、同源身份路由及 Cookie/Set-Cookie 只留在
  身份 upstream 的配置。既有部署的 SSO 开启、三副本 ready 和共享签名 key 事实，
  不等于已确认实际 UI handoff、真实 A/B 或目标跨副本会话/轮换。
- [ ] 确认是同一浏览器 profile/Cookie jar。系统浏览器、应用内 WebView、隐私窗口和
  另一浏览器可能互相独立；应用同域、本地已有 Token 都不是共享 OP 会话的证明。
- [ ] 区分 B 的**首次权限同意**与再次密码：A 的 consent 不授权 B；B 可以正常要求
  自己的 consent/MFA。保留 `prompt=login`/`select_account`、`max_age`、ACR 和全部策略，
  不靠关闭强制认证、扩大 Cookie Domain 或跨 RP 搬运 Token/hint 来“免登录”。
- [ ] 只从配置提取下述有界枚举做离线诊断；不要粘贴真实授权 URL、凭据或 Token。
  `compatible_static_declarations` 不是注册有效、共享 jar 或登录成功。
- [ ] 取得专用测试账号的安全访问与明确目标认证许可后，才可另行核验实际 A 密码一次
  → B 自己导航、所需 consent/code exchange、独立 grant 与原始认证时间。当前不执行，
  不创建/重置账号或客户端，不部署；不保存 Cookie/Token 值、HAR、trace 或截图。

**English — operator inputs.** Still needed: both actual application starts and registrations
(client/auth method, exact callbacks, tenant/provider, scopes/resources and consent/prompt/max_age/
ACR/risk/MFA policies), the owner-confirmed hosted UI handoff and canonical OP/issuer, shared-jar
confirmation, hosted routing/Cookie-boundary confirmation, and dedicated-account access plus authentication
permission. No production hosted URL is inferred here; real-account A→B remains `not_run`.

## 标准 RP 授权入口：已复现的契约阻塞

**标准 discovery RP 应使用返回的 `authorization_endpoint`，不能悄悄换成 `/login/`；
当前未选 provider 的浏览器授权导航得到 JSON 而不是登录 UI。**
已记录的匿名目标 discovery 广告 `https://sso.ywbsd.site/auth/login`；下述 Chrome
授权实验只在 owned loopback 运行，没有对目标发起授权导航。
冻结 stock 后端的 `interfaces/sso/server_discovery_config.go::buildBaseMetadata` 与
`shared/core/consts.go::PathLogin` 发布 `/auth/login`；
`server_routes.go::mountCoreOAuthOIDC` 将 GET/POST 都交给 `handleLogin`。
`server_login.go::bootstrapLoginRequest` 解析 GET query，`preAuthLoginGates` 先调用
`server_oauth.go::respondLoginProviders`：普通 code/S256 请求未选 provider 时返回
HTTP 200 `application/json`，不是 HTML 或重定向。`loginPageURIForClient` 的
`login_page_uri` 只是 JSON 字段，配置它本身不建立 HTTP UI handoff。
`server_userinfo.go::browserSessionProbe` 可报告身份可用，但不自动推进授权。

已验证的 `rp-entry` 双网关真实 Chrome 顶层导航（原生 HTML Accept / navigate / document）
已观察到：新 jar 得到 provider JSON、`op_session_available=false`；A 完成后同 jar 的 B
仍得到 JSON、该字段变为 true。两次均没有 Flutter 表单、RP callback/grant、认证 POST、
重定向或 Cookie 签发；原 Cookie 不变。问题先于“是否再输密码”：用户停在元数据文档。

**支持的托管接入是显式配置的 `<所有者确认的托管 origin>/login/?<当前 RP 授权参数>`。**
路径证据为本仓 `lib/app_router.dart::resolveProductScreen`、
`lib/entries/login_entry.dart::buildLoginScreen`、`OAuthParams.fromUri`；
`oidc_provider_flow.dart::_probeProviders` 与 `oidc_session_flow.dart::_tryBrowserSession`
再执行 discovery/有界身份恢复。相同 fixture 另用全新 state/nonce/S256 请求证明托管 A
密码一次、A/B 各自首次 consent、B 无第二次密码并得到自己的 grant/Token/SID；
Cookie/access/ID-token 原始 `auth_time` 严格一致，Cookie 不滚动，旧 grant 仍可用。
这不是 generic discovery 登录成功，也不确认任何实际应用的生产托管 URL。

**English — entry contract.** A generic RP follows discovery's advertised `authorization_endpoint`
unchanged. With no provider selected, browser GET authorization requests receive HTTP 200 provider
JSON, not a login page or UI redirect, even when an OP session is available. The supported hosted
integration is an explicitly owner-configured hosted origin plus `/login/` and that RP's own fresh
authorization parameters; only this hosted path proves password-once A→B in the disposable fixture.
It is not an automatic discovery handoff or actual-app acceptance. The client-only
`GET /auth/login?client_id=…` with `Accept: application/json` remains intact.

未发现应由 Console 修改的入口缺陷：`nginx.conf` 的身份 location 与
`tools/robust_proxy.py::should_proxy/resolve_static_file` 分离 API 和 SPA，与产品架构一致；
stock `server_routes.go::buildProbeMux` 明确只提供 API。**未改产品、路由或部署行为。**
后端 backlog：定义并发布 advertised endpoint 的浏览器授权 handoff，保留现有 JSON API
及当前 RP 的注册/tenant/provider/redirect/PKCE/scope/resource/consent/强制认证/MFA/ACR
边界、精确 `auth_time` 和服务端交付语义；中间 handoff 不得消费/重放 opaque PAR/JAR。
所有者仍须确认实际公开入口、两份注册/策略与账号许可；不能由本仓发明 redirect 替代。

实验保留两层传输证据：未改网关的 TLS loopback 包装下，Python 广告了 http scheme，
Nginx `$host` 丢失非默认端口；issuer 正确/匿名预检通过并不证明 endpoint origin 正确。
后端 `interfaces/middleware/request_url.go::BaseURL` 从请求/可信 forwarded headers 推导
端点；`applyMFAIssuerSigning` 只覆盖 issuer。随后使用**仅 fixture 的 identity ingress**
向 stock 转发已知 owned TLS scheme/完整 authority，要求真实返回的 endpoint 精确匹配，
不改 discovery 正文、不替换 endpoint、不跟随不合适的 origin。这不是网关部署修复，
也不证明 shipped proxy 支持任意非默认公网 origin。原始/规范入口结果分开输出。
`GET /auth/login` 仅带 client_id、Accept JSON 的响应在 direct/raw/canonical 三处逐字节
一致，并执行原有匿名预检；text/html 后端控制也返回 JSON。复现命令见
[集成测试](../tests/integration/README.md#标准-rp-entry-复现不修改产品入口)。

本节只证明本机单 stock 进程入口契约和托管普通流程；不新增并发副本、轮换、HA、
native/WebView、完整 MFA/ACR/PAR/JAR 矩阵或生产认证证据。实际 A→B 仍 `not_run`。

## 支持与证据边界

| 路径/条件 | 已实现行为与限制 |
|---|---|
| generic RP 跟随 advertised `/auth/login`，未选 provider | provider JSON、无登录 UI；新/已认证 jar 均已复现，不是授权成功 |
| 显式托管 `/login/`、同 canonical OP/同 jar、各自已注册 code/S256 | 普通 B 身份恢复后独立授权；stock 双网关已验证 |
| B 首次 consent；以后普通 repeat | 首次同意不是重复密码；fixture 覆盖四种首次策略组合及补充用例的 repeat |
| 应用本地 direct password/API | 不等于 RP code 导航；同源浏览器直接登录可种 OP Cookie，但直接 B 不自动恢复 |
| 不同/未确认 OP，独立浏览器或 WebView | 不自动继承 OP Cookie；fixture 只验证独立 Chrome jar，未验证真实 native/WebView |
| 强制认证、opaque PAR/JAR、风险/step-up | 不能保证无交互；保持服务端边界，离线不裁决有效策略 |
| 本机共享存储、先停后启 stock 进程 | 已验证持久化恢复；不是并发副本、密钥轮换、HA 或目标 failover |
| 本机两个并发 stock 进程、共享 Redis/固定 key | 已验证 R1→R2 canonical resume、双向 Token/JWKS；不是目标三副本或 failover/HA |
| 用户实际 A/B、目标会话 failover/rotation | A→B `not_run`；其他轴 `not_verified`，普通 fixture 不能代替 |

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
`SSO_OAUTH__AUTH_CODE__ENABLED=true`（已开启的部署保持原值）。配置声明或本地 fixture
通过不等于实际部署已启用；本次文档整理不升级、重启或修改部署。

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

## 普通应用登录与路由请求所有权

`redirect` 是 Console 本地登录后的返回位置，不是 RP 的 `redirect_uri`。
直接 first-party 密码 API 只更新调用方对象的 Token；显式产品客户端的托管
直接登录使用各自本地凭据槽。它们不会自动替 B 发起 code/PKCE 授权。
同源浏览器直接登录可以建立 OP Cookie，但本地 Token 本身不证明共享 Cookie jar。

Web 应用 handoff 使用真实页面导航；native 的 `BrowserNavigation` 使用新
`MaterialPageRoute`，不是在同一个登录 State 上替换授权 URL。重复的显式导航即使
URL 相同也属于新请求；主题/语言重建和一次性 URL scrub 不属于新请求。
不要把授权 URL、state、nonce 或 Token 放进 Widget key。

native `BrowserNavigation` 会把 Navigator 变更排到下一帧，故显式 assign/replace
立刻换一个不含 URL 的 opaque request identity；登录 State 在创建时捕获它，而不是
用 URL 相等判断是否同一请求。`pushNamedAndRemoveUntil` 移除旧路由后，其 State
也会在过渡期间仍然 mounted；结果同时核对 identity 和所属 `ModalRoute.isActive`。
旧请求不能继续 discovery 恢复、安装本地登录结果或把新页面跳回旧授权；凭据保存/
偏好 hydration 等等待之后再次核对。临时覆盖的 Settings 路由不等于移除原请求，
不能仅用 `isCurrent` 拒绝它。同文档 URL scrub 不更换 identity。
普通 provider/session/主认证和 consent 的回归见 `test/app_sso*_test.dart`；使用实际
native 导航与 router resolver 的现有 mock API 接缝，也覆盖真实 App 的 EN/ZH 选择、
主题重建、discovery 就绪和每请求独立的一次性 consent。远端偏好 hydration 也可在
handoff 前改变语言；托管页仅给语言选择器加 locale-only key，重建其私有编辑控制器，
不重建登录 State、不改请求 identity，也不使用任何授权 URL/秘密作为 key。
没有更改 first-party/RP 分类、注册、PKCE、scope/resource、tenant/provider、
强制认证、MFA/consent 或原始
`auth_time` 的服务端权威；已提交的未知写结果不重试，也不声称已被撤销。

这些 widget/API 回归不是设备、WebView 或目标 A→B 验收。真实 A/B 入口、两份注册/
策略与专用账号/认证许可仍缺失，目标 A→B 为 `not_run`。独立 stock fixture 使用
`/login/` 托管入口，不证明 discovery 广告的 `/auth/login`（未选 provider 时返回
JSON）已为未知应用接好 UI handoff。此前目标 helper 的独立 review 仍被拒绝、没有
有效 PASS；本节不重开、不替代或豁免该 review。

## 离线诊断：为什么 B 仍要求密码

独立入口 `tools/check_app_sso.py` + 纯计算 `tools/app_sso.py` 只解释**操作员声明**。
不导入或调用旧 target helper，没有执行模式。只读一个显式文件，不读环境配置、
默认路径、凭据或引用文件；无网络、浏览器、Cookie、认证/账号 API 或自动修复。
为了避免接收授权秘密，**不接受 URL、client/tenant/subject、redirect、state、nonce、
hint、Token 或原始请求**。请由应用所有者从配置提取以下有限枚举，不粘贴登录链接。

```sh
python3 tools/check_app_sso.py --input /operator/app-sso-declarations.json
make test-app-sso
```

文件必须是 ≤16 KiB UTF-8 JSON、绝对规范路径（不展开 `~`/变量），当前 uid/root
拥有、不可被 group/others 写入、单 hardlink 的 regular file；拒绝所有 symlink 路径、
FIFO、目录、变化中的文件。只打开指定路径的祖先目录和文件，不列目录、不重试、不写文件。
只支持有 `O_NOFOLLOW`/`dir_fd` 的 POSIX 主机；能力不足时失败，不放松完整性要求。

下面只是完整结构示例，**不是已知 A/B 配置或成功登录证据**：

```json
{
  "version": 1,
  "op_relation": "unknown",
  "browser_jar_relation": "unknown",
  "app_a": {
    "flow": "canonical_code_s256", "prompt": ["login"], "max_age": "absent",
    "request_context": "plain", "step_up": "not_declared", "consent": "required"
  },
  "app_b": {
    "flow": "canonical_code_s256", "prompt": [], "max_age": "absent",
    "request_context": "plain", "step_up": "unknown", "consent": "required"
  }
}
```

- `version` 必须是整数 1。其余顶层字段缺失/null 表示缺少声明；单独缺 A、缺 B
  有不同标签。非 null 的应用必须完整提供上例六字段；未知事实用明确的 unknown，
  不把残缺对象当成默认配置。
- `op_relation` / `browser_jar_relation`：`same`、`different`、`unknown`，仅是调用方
  声明，不从主机名、应用域名或 WebView 名称推断。同 OP + 同 jar 仍未被验证。
- `flow`：`canonical_code_s256`（声明 canonical OP code/S256 导航）、
  `app_local_direct`（应用本地直接登录）、`unknown`。直接 A 同源浏览器登录可能种下
  OP Cookie，但声明/本地 Token 不证明它存在；直接 B 不自动变成 OP code 导航。
- `prompt`：无重复的 `login`/`select_account`/`consent`/`none` 数组；`[]` 表示未显式
  请求，null 表示未知；`none` 必须单独使用。`max_age`：整数 0–2147483647、`absent`
  或 `unknown`，不接受 bool/float/null。正值不能离线比较真实会话年龄。
- `request_context`：`plain`、`par`、`jar`、`unknown`；不接收、不解析、不消费 opaque
  内容。direct + PAR/JAR 是矛盾声明，拒绝。`step_up`：`required`、`not_declared`、
  `unknown`；未声明不等于服务端没有风险/ACR/MFA 策略。`consent`：`required`、
  `not_required`、`unknown`，只描述预期交互，不确认或改变 consent 注册策略。
- 重复 JSON key（包括转义等价 key）、未知字段/枚举、错误类型、非有限数、超限及
  歧义组合整体拒绝；不从无效文件输出部分诊断，不打印原始参数/异常/正文。

输出仅含固定状态、reason `label` 和 provenance：`operator_pair`、`operator_app_a`、
`operator_app_b` 是声明来源；缺失/错误为 `input_structure`、`input_file`、`command_line`；
工具限制为 `tool_boundary`。不复制应用身份事实，始终保留 A→B `not_run`，OP/会话/
共享 jar/注册/redirect/运行策略 `not_verified`。

| `assessment` | 含义（所有 reason 一起读，不是运行态裁决） |
|---|---|
| `missing_inputs` | A/B 或关系声明缺失；不等于实际未配置 |
| `declared_barriers_or_interaction` | 声明了不同 OP/jar、direct 或 B 强制认证/选账号 |
| `offline_undetermined` | OP/jar/导航未知，或 opaque、正 max_age、step-up 等需运行态 |
| `compatible_static_declarations` | 未声明静态障碍；**不是成功登录、共享 jar 或有效注册/redirect** |
| `not_assessed` | 文件/结构/参数错误、帮助或工具异常；没有登录结论 |

B 的 `prompt=login`、`select_account`、`max_age=0` 各有独立标签；A 的强制主认证不
继承成 B 的策略。选账号/step-up 不必然等于密码，consent 不是重复密码认证；
`prompt=none` 也不证明会话可用。OPAQUE 或风险上下文可能覆盖可见声明；即使已有
静态障碍标签，其余不确定性仍保留，不宣称有效策略已解析。不得剥离强制认证策略。
退出 0 仅表示完成离线分析（包括障碍/unknown），缺输入或拒绝退出 2，内部未知退出 3，
中断退出 130。`--help` 只输出固定标签；没有在线、认证、自动修复或注册验证选项。
真实 A/B 输入、账号和认证许可仍缺失；此工具不补齐它们，也不豁免旧 helper 被拒绝的 review。

## 验证证据与边界

### 目标部署的只读预检

这不是离线诊断，也不是 A/B 验收；本次文档阶段未执行。唯一已确认的匿名预检是：

```sh
python3 tools/check_browser_sso_deployment.py \
  --origin https://sso.ywbsd.site \
  --issuer https://sso.ywbsd.site \
  --client-id sso-admin-console
```

只发四个 GET（health、readyz、OIDC discovery、仅带 client_id 的 provider discovery），
不发送密码/Cookie/bearer/授权参数，不跟随重定向、重试或读取环境代理。
输出只有固定状态/HTTP status。成功仅说明公开健康和发布能力符合预期，不证明两份
RP 注册、浏览器认证、共享会话/密钥或 HA；无 Cookie 时 `op_session_available: false`
正常，网络/探测失败是 unknown，不是未启用、登出或成功。

### 此前目标 helper 的独立审查：未批准

`tools/browser_sso_acceptance.py` 及其配套 helper 的此前独立 review 收到 provider
安全拒绝，处置仍是 **`provider_denied_no_valid_verdict`，没有有效 PASS，未获批准**。
该 gate 继续阻塞此 target helper 的发布/使用；旧操作说明不再作为可用接入入口。
原拒绝处置、证据和冻结输入保持不变，不重试、不重建 review，不运行历史 reviewer/
`tests/integration/owned/` 探针。普通 unit discovery 即使包含其未改单测，也不提供批准。
本页的独立离线诊断、widget/API 回归、普通 stock fixture 与功能审查均不替代、
豁免或完成该独立安全审查，也不证明完整生产就绪。

### 同源字体与离线构建检查

Web bootstrap 的 `canvasKitBaseUrl` 和 `fontFallbackBaseUrl` 均解析到当前
`/app/` 发布产物。`web/font-fallback/` 自带 SDK 完整 fallback 表所需的
WOFF2（含 Roboto、中文及 emoji），而不是只覆盖某次登录页的字符；不会把
缺失字体的请求改投身份 API 或外部 CDN。原生平台字体选择不变。

`python3 tools/web_font_assets.py` 离线核对当前 SDK 所需 URL、文件长度、SHA-256、
WOFF2 framing 和逐字体族许可；Make/Docker 构建在编译前执行。SDK 不匹配或
资源缺失时失败，不在构建期间下载或回退。显式 `--fetch` 仅用于初次获取公开
资源，保留上游原字节及许可，不静默替换已有版本；SDK 升级需审查资源清单。
署名和许可入口见 `web/FONT-NOTICES.txt`。

双网关浏览器回归额外验证 EN/ZH 匿名登录、真实本地字体响应和零外部资源
请求；字体断言本身不是跨副本会话证据，也不代替真实账号 A→B、原生 WebView 或 HA 验收。

### 独立 stock 双网关普通回归

入口为现有 `browser_sso_fixture.py` / `browser_sso_test.py` / `browser_sso_rp.py`，
与被阻塞 helper 无依赖。使用冻结 stock `sso-server` 源码、release Web 产物、全新临时
账号/SQLite/证书和两个不同 loopback 主机的 RP，串行驱动真实 Chrome 密码/consent UI。
不注入 OP Cookie/Token、不用直接登录 API 代替 UI，不访问目标部署或生产存储。
运行方式及完整用例表见 [集成测试](../tests/integration/README.md#隔离的跨应用浏览器-sso不使用上述部署或凭据)。

- `baseline` 保留 A skip/B required；`inverse`、`both-required`、`both-skipped`
  补齐其余三种首次 consent 组合，并各自重复普通 A、B 授权。A consent 不授权 B，
  repeat 记忆的是该用户/客户端的 consent，不是另一 RP 的 grant。
- `both-required` 还完成独立 jar 的 B 密码登录：无 Cookie 继承/自动 resume，
  但已记忆 consent 无需再同意。其新 Cookie/SID/认证时间独立，原 jar/grant 不变。
- 每次 code/S256 导航独立 state/nonce/verifier、授权码、Token/SID，保留各 RP 自己的
  scope/resource；原始 Cookie 与同 jar access/ID Token 的 `auth_time` **严格相等，无时间容差**。
  补充四例的 B/repeat 签发秒晚于原认证秒，AMR/ACR 不变、Cookie 值/到期不滚动，既有 grant 仍通过
  真实 `/userinfo`；不向 RP 转交 OP Cookie 或另一 RP Token。
- 原闭环的 HttpOnly/Secure/Lax/host-only、强制认证/选账号/max_age、独立 jar、合法
  end-session、独立服务双向 Cookie 隔离、EN/ZH 本地字体与匿名预检断言全部保留。
  强制认证用例只验证呈现密码表单且不自动 resume，不宣称完成新的认证。

`shared-store` 另在 A 完成后停自有 OP，再启动第二 stock 进程；共用新临时 SQLite
canonical identity/session、OAuth/consent store 和 stock 生成的持久化 signing key，
保持 gateway/issuer/浏览器/Cookie 不变。仅使用发布配置 `identity.session_backend`、
`oauth.backend`、`self_service.consent.backend`/各 `.sqlite.dsn` 与
`keys.signing.key_file`，不直接写 SQL、不改后端或生产配置。
B 真 UI resume+独立首次 consent/code/token、A/B repeat 及 A 原 grant `/userinfo`
都通过才算会话证据；就绪/JWKS 不算。两个进程**先停后启**、无在途重放，
只证明本机持久化恢复，不证明并发副本、密钥轮换、HA 或目标 canonical failover。

### 本机并发双进程 canonical session（非 failover/HA）

`live-replicas` 先等 R1 就绪/stock 写出 `keys.signing.key_file`，保留 R1，再启动 R2。
两原 PID 在 A 开始前及 B/repeat/交叉验证后均仍 live，无 stop/restart 捷径。A 在 R1
密码一次并同意；B 在 R2 的真实 Chrome 托管页 identity-only resume，批准 B 自己的
consent 前无 B grant；之后 A/B 各自 repeat。四 grant 的 code/state/S256/nonce、
access/refresh/ID-token、client-bound SID 独立；scope/resource 不混用，AMR/ACR 不变，
Cookie/access/ID-token 原始 `auth_time` 严格相等，后续签发秒更晚。Cookie 值/到期不滚动，
ingress 确认 R1 仅一次 Cookie 签发、R2 零重签。A 原 bearer 在 R2 `/userinfo`、B 的在 R1
校验；各 ID token 用对端 live 进程新读取的 JWKS 验签/claims，不拿公钥相同替代会话证据。

共享 `identity.session_backend: redis` / `oauth.backend: redis`；identity/consent 各为
同一临时 SQLite，固定共享 key、rotation/registry 关闭。冻结后端源依据：
`cmd/sso-server/serverbuildstore/build_identity_stores.go::BuildSessionManager`、
`infrastructure/redis/session.go::CreateWithMeta/Get` 与
`protocols/oidc/browsersso/session.go::Session.Resolve`（校验 Cookie 后读取 canonical SID）；
`cmd/sso-server/serverbuildsign/build_signing_issuers.go::buildEd25519SigningIssuer` 与
`infrastructure/defaultimpl/ed25519_types.go::WithEd25519KeyFile`；consent SQLite 按 user/client 分离。
selector 仅在完成事务且无在途请求时切换，无 fallback/重试；只用 owned TLS/loopback、
新 owner-labelled Redis（缓存 immutable image、仅发布 loopback、限资源/无持久化日志）、
可选 Nginx 与私有 temp store。资源验证移除后才输出 case PASS；无秘密或浏览器制品持久化。

`rp-entry` / `live-replicas` 的取消边界使用独立 `app_sso_supervisor`：真实同步
Playwright 只在 worker 中运行；父进程处理十分钟 deadline/SIGTERM，不抛异常进浏览器
fiber，不依赖卡住 worker 的 ExitStack。Linux subreaper + ancestry/start-ticks/pidfd
限定子孙归属；先终止/reap，再按 exact name/label/image/ID 清理父进程登记的容器，按
uid/device/inode 删除私有目录（含临时 Chrome profile/artifacts）。最终 case PASS/Evidence
只在父进程核验后发布。二十秒 teardown 总预算、五秒 create/start 命令界限及独立
Chrome SIGTERM 复现命令见[集成测试](../tests/integration/README.md#本机-live-replicas并发共享-canonical-session不是-failover)。

2026-10-18 独立复核在两个网关分别覆盖 Chrome launch 返回前、真实导航中先 SIGSTOP
worker、B grant 后 SIGTERM：**6/6 最终外部 OS census 零存活/残留，0.991–3.734 秒，
均在 20 秒内，无 emergency cleanup**。另有 shipped 四例中断回归通过；该脚本的
watchdog 是 25 秒，不将它误当成严格 20 秒证据。正常双网关完成 8 次 grant，不能
用正常路径通过替代中断证据。此前旧源码的异步 SIGTERM 失败/人工清理及中间失败仍保留；
当前结论只关闭已测试阶段的本机取消问题，不覆盖 supervisor SIGKILL、主机崩溃或 Docker 不可用。

这不是部署的三副本集群、跨节点存储、HA/failover、故障/分区、事务中途切换或跨进程
code consumption；不覆盖 native/WebView、完整策略矩阵或真实 A→B（仍 `not_run`）。
轮换不近似：`cmd/sso-server/serverbuildplatform/build_ratelimit_cluster.go::BuildSigningKeyRegistry`
仅支持关闭/memory/etcd，不支持 Redis。Redis registry 需后端实现；owned etcd/key-registry
收敛实验则另行设计，不能用每进程 memory/固定共享 key 声称已验证 rotation。

**English — two-process proof boundary.** Two original stock processes stay live concurrently on
one host, sharing a canonical Redis session store and one fixed signing key. Real Chrome proves
A authenticates on R1, B resumes on R2 with its own consent/grant/tokens/client-bound SID, exact
original `auth_time`, no cookie reissue, and opposite-process ID-token/JWKS and access-token/userinfo
verification. Owned processes, containers, listeners and temporary profiles/stores are removed on
normal completion and in the tested real-SIGTERM phases, with independent censuses within 20 seconds.
This is not the deployed three-replica cluster, rotation, HA/failover, cross-node storage,
mid-transaction switching, cross-process code consumption, native/WebView, the full policy matrix
or real-account A→B.

fixture 使用的既有后端已含客户端 consent 策略持久化及登录终态统一 `AuthTime`：
未给认证时刻时仅补一次，已有时刻不覆盖、恢复不刷新年龄；不从可编辑 Attributes
推导策略，也不猜测/恢复旧版本曾丢弃的历史配置。本次文档阶段未修改后端或部署。

### 最近已审阅的执行记录（文档修改前）

2026-10-18 UTC 的批次记录（不在仓库）为
`continuations/resume-03/gates/verify/attempt-ME6xXE9b/`，独立复核见
`continuations/resume-03/artifacts/31-replica-gate.md` 及对应 evidence/REPORT.md。
其源码 SHA-256 为 `a74dde5ecbb029bba0c00fe8fa5e9d7d7a9609b15ea1277239a25aa669de0fc8`。
以下来自该轮实际日志，**不是本次文档修改后重跑的门禁，也不是目标 helper 安全批准或真实 A/B 认证**：

| 检查 | 实际结果 |
|---|---|
| stock Chrome、Python + Nginx 双网关 | 14 个用例/网关组合（每网关七例），50 次 code grant，0 browser skip |
| 其中 `rp-entry` / `live-replicas` | 各 2 个网关组合，分别 4 / 8 次 grant；已计入 50，不重复相加 |
| 全量 Python units | 261 tests，OK；focused fixture 65、离线诊断 44 均包含其中 |
| Flutter VM 全量 | 2,274 passed，172 skipped；skips 不计作已验证行为 |
| 仓库五门禁 + harness + Python units + stock Chrome | 8/8 退出 0；harness 25 项通过 |

本次文档修改后的完整八门禁由 owning stage command 串行运行；本任务不运行完整 wrapper，
也不提前宣称修改后全绿。历史失败保留，不用此次记录覆盖。

该 fixture 记录使用 Python 3.12.3、Chrome 154.0.8037.97、Flutter 3.50.0-0.1.pre /
Dart 3.12.0-168.0.dev；现有 CI Flutter 3.47.4、Docker 3.47.1 pin 与运行时不一致，
如实保留，未升级工具或改 pin。缺依赖/不支持配置/构建失败均非零退出，不静默 skip。
只清理自有临时进程/容器，端口占用即失败，不杀占用者、不改变全局 TLS/proxy。
真实 App A→B 仍 `not_run`；目标 failover/rotation、native/WebView、HA 仍
`not_verified`；此前 target-helper 独立审查始终未批准。
