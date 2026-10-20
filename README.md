# sso-console

Snaplink SSO 的统一 Web 控制面。一个 Flutter Web 产物同时承载管理员控制台、
托管登录、自助账户门户、开发者动态注册、首次安装、设备授权和 Agent Operations。

## 产品入口

| 入口 | 用户 | 主要能力 |
|---|---|---|
| `/admin/` | 平台、租户、安全与运维管理员 | 身份、应用、权限、策略、Token、设备、审计、治理、恢复与合规 |
| `/login/` | 最终用户 | 品牌化登录、动态身份源、账户恢复、MFA/WebAuthn、授权同意 |
| `/portal/` | 已登录用户 | 账户、凭据、设备、会话、授权、组织、活动与隐私自助 |
| `/developer/` | OAuth/OIDC 应用开发者 | RFC 7591 注册及 RFC 7592 管理 |
| `/setup/` | 首次部署的所有者 | 单次初始化管理员与首个应用 |
| `/device/verify` | 已登录用户 | RFC 8628 设备码确认或拒绝 |
| `/agent/` | Agent 操作者 | 跨实例查看 Agent 会话、回放事件并发送或取消任务 |

Agent Operations 使用独立的 Agent Hub 服务。它显示 Agent 实例/会话/轮次，
与 `/portal/` 或 `/admin/` 中的身份登录会话、登录设备管理分属不同领域。
Hub 通过 Snaplink 签发的 bearer 验证身份，但使用独立 audience `agent-hub`、
`agent.instances:read`、`agent.sessions:read`、`agent.sessions:write` 和
`agent.turns:cancel` scope；登录成功不会自动注册 OAuth resource、scope 或 Hub
operator grants。必须先配置 Snaplink first-party Console OAuth client 的
`allowed_resources`/allowed scopes，并在 Hub 配置 tenant、subject、client 与
可操作 instance grants。缺少 Hub 配置时页面明确显示服务未配置或权限不足，
不会将 Agent 请求转发给 Snaplink 身份 API。

计算设备与任务支持 NVIDIA CUDA 物理整卡需求、每卡最低空闲显存和实际分配 UUID，
使用方法与兼容性见 [Agent GPU 计算](docs/AGENT_GPU_COMPUTE.md)。

详细的功能覆盖、产品边界和后端契约缺口见
[docs/FEATURE_COVERAGE.md](docs/FEATURE_COVERAGE.md)；角色、领域边界、安全
不变量和关键流程见
[docs/PRODUCT_ARCHITECTURE.md](docs/PRODUCT_ARCHITECTURE.md)。

## 架构原则

管理端以 Snaplink 后端契约为准，不在前端猜测接口：

1. 加载当前副本的 `/api/v1/admin/endpoints` 运行时能力清单。
2. 将运行时清单与 `docs/openapi.yaml` 对应的精确方法与路径目录分开保存：
   前者决定当前副本是否可用，后者只提供兼容性导航和操作契约。
3. 对后端已挂载但尚未进入 OpenAPI 的少量路由使用独立补充清单，并在
   `404/501` 时显式降级。

接入三态门禁的能力页遵循：清单加载中显示加载态，清单读取失败显示可重试错误，
清单成功但不包含路由才显示“未启用”。这些页面不会在探测失败时误发读取或
高风险写请求；设备安全页和 Checkout 均使用运行时事实。连接、网络策略、访问策略
和 Webhook 的菜单页与详情深链共用运行时边界；清单刷新绕过旧缓存。
网关专属路由及独立的审计、计费服务不会因身份清单缺席而被误判为未启用。

导航条目与页面保持同一个描述对象，因此能力裁剪不会造成索引错位。高频和
高风险场景使用专用工作流；其余已发布管理契约由 Advanced operations 提供
受约束的兜底入口。写操作需要确认，敏感凭据只做一次性展示，PII 导出直接
下载而不进入通用响应预览。

核心实现：

- `lib/screens/admin/admin_navigation.dart`：能力驱动的管理导航
- `lib/screens/admin/admin_route.dart`：可深链的管理路由
- `lib/api/snaplink_admin_api.dart`：认证、缓存、重试和契约传输
- `lib/api/snaplink_admin_types.dart`：已发布及补充路由清单
- `lib/screens/admin/admin_capability_boundary.dart`：可选模块三态门禁
- `lib/app_router.dart`：七个产品入口的顶层分发，含代码分割
- `lib/entries/*.dart`：七个入口的 deferred chunk 边界工厂
- `lib/i18n/app_strings*.dart`：共享 EN/ZH 文案、领域目录和动态占位符翻译

代码分割：七个产品入口各编译为独立 deferred chunk，首屏只下载主包 + 当前
入口 chunk（`/login/` 首屏约 3.5MB raw / 1MB gzip，替代原来 4.7MB 单包；
admin 的 33 个模块约 0.8MB 只在进入 `/admin/` 时下载）。`main()` 在
`runApp` 前预加载当前路径对应入口，因此首屏同步渲染真实界面；跨入口导航
经 `lib/widgets/deferred_entry_screen.dart` 按需加载，失败可重试。
dart2wasm 当前不输出 deferred 分块，因此默认构建为 dart2js
（`make build-prod`），需要 skwasm 的部署可用 `make build-wasm-prod`。

所有七个入口与管理后台均支持英文和中文。页面文案使用 canonical English
源字符串查找，API 返回值和资源标识保持原样；`test/i18n_coverage_test.dart`
会阻止新增未本地化的直接文案、表单标签和运行时提示。

Agent 工作区支持在具备文件通道的原生宿主中选择输入 JSON、保存经过摘要校验的
输出 JSON 包；具体平台实现、构建和验证范围见
[原生工作区文件操作](docs/AGENT_NATIVE_WORKSPACE_FILES.md)。

原生客户端可在登录页打开设置并指定 Snaplink 服务来源，设置会跨重启保存，
且对登录、用户门户、设备授权、Setup、开发者注册和管理 API 统一生效。Agent Hub
可为原生端单独设置 API origin；Web 固定使用页面同源 `/api/v1/agent` 代理。生产
来源必须是纯 HTTPS origin；仅 localhost、127/8 和 `::1` 环回地址允许 HTTP。
Web 版本始终使用当前页面同源，不接受来源覆盖。

跨应用免密码复用的是 Snaplink 的 HttpOnly OP 身份会话，不是应用 Token。
同 canonical OP、同浏览器 Cookie jar、各自使用已注册 code/S256 请求和**显式配置的
托管 `/login/` 入口**、且后端明确开启 `oidc.browser_sso.enabled` 时，普通 B 可恢复
身份并独立取得 grant；B 首次 consent 不是重复密码，强制认证/MFA 不绕过。
标准 discovery RP 仍使用 advertised `authorization_endpoint`；当前未选 provider 的
`/auth/login` 浏览器导航只得到 provider JSON、没有登录 UI，不能把托管 fixture 通过
当成 generic RP 登录成功，也不能自行拼接实际应用的生产入口。应用本地 direct 登录
不自动变成 RP code 导航，独立浏览器/WebView 不自动共享身份。
入口契约、后端 handoff 阻塞和证据边界见[浏览器 SSO](docs/BROWSER_SSO.md)。

实际两应用请先核对[中文接入清单](docs/BROWSER_SSO.md#双应用接入清单)：A/B 入口、
注册/callback/tenant/策略及专用凭据访问/认证许可仍缺失，**实际 A→B `not_run`**。
“为什么 B 仍要求密码”的独立[离线声明诊断](docs/BROWSER_SSO.md#离线诊断为什么-b-仍要求密码)
只读显式枚举配置，不接收 URL/凭据、不联网、不验证登录或注册；回归入口 `make test-app-sso`。
普通 stock 双网关的真实覆盖/计数见[集成测试](tests/integration/README.md#隔离的跨应用浏览器-sso不使用上述部署或凭据)。
此前 target-helper 独立审查拒绝、无有效 PASS、仍未批准；普通功能证据不解除其阻塞。

密码、邮箱/手机验证码和 TOTP 登录可在原生壳中完成，Bearer 只保存在进程
内存并通过应用内路由续接；未认证 Portal 会进入统一登录并在成功后安全返回
原页面，Admin 的模块、详情和子资源路由也使用同一应用内历史状态。依赖浏览器
安全上下文或页面提交语义的联合登录、WebAuthn/Passkey
和 OIDC `form_post` 会在原生端明确提示需使用 Web 控制台。

## 本地开发

```bash
# 需要 Flutter 3.47.4 stable / Dart 3.13.3（与 CI 一致）
flutter pub get --enforce-lockfile

# 工程结构检查读取 engineering.yaml
python3 -m pip install -r requirements-dev.txt

# 启动开发代理；SNAPLINK_API_URL 必须指向可连通的 Snaplink 部署
# 将占位符替换为实际 HTTP(S) origin；代理端口由 SNAPLINK_PROXY_PORT 覆盖
SNAPLINK_API_URL='<your-snaplink-origin>' \
AUDIT_GOVERNANCE_UPSTREAM='<your-audit-governance-origin>' make serve

# 另一个终端构建 Web 产物
make build
```

`make serve` 和 `./dev.sh` 都会继承当前 shell 中显式设置的
`AUDIT_GOVERNANCE_UPSTREAM`。Audit reads 必须显式指向 Audit Governance；未设置时
本地代理 fail closed，不会回退到 core Snaplink。上面的占位符不能原样使用，需替换为
实际部署的 origin。配置 `AGENT_HUB_UPSTREAM='<your-agent-hub-origin>'` 才能使用
Agent Operations；开发代理未配置时返回 `agent_hub_unconfigured`。控制台默认通过
`http://localhost:4444` 访问。认证账号、身份源和功能开关由
所连接的 Snaplink 部署决定，不应在前端仓库中保存默认生产凭据。
启动脚本不会杀端口占用者，端口冲突会明确失败；后端健康提示验证实际配置的
origin、HTTP 状态和 JSON，不把错误页面当成健康。UI 代理成功不等于 SSO 就绪。
目标 OP 的凭据零接触只读预检见 [浏览器 SSO](docs/BROWSER_SSO.md#目标部署的只读预检)。

开发代理的独立服务配置与路径如下；未配置时返回带配置提示的 JSON 503，
不会隐式转给 Snaplink 身份 API。最小部署若确有兼容网关，也必须显式指定其 origin。

| 服务 | 环境变量 | 同源 API 路径 |
|---|---|---|
| Billing | `SNAPLINK_BILLING_UPSTREAM` | `/api/v1/admin/commerce`、`/api/v1/commerce`、`/api/v1/metering` |
| Checkout | `SNAPLINK_STRIPE_ADAPTER_UPSTREAM` | `/api/v1/checkout/sessions`（精确匹配；兼容旧 `SNAPLINK_STRIPE_ADAPTER_URL`） |
| Audit Governance | `AUDIT_GOVERNANCE_UPSTREAM` | `/api/v1/audit/events`、`/api/v1/audit/facets` |
| Agent Hub | `AGENT_HUB_UPSTREAM` | `/api/v1/agent` |
| Forge | `FORGE_CONVERSATIONS_UPSTREAM` | `/api/v1/conversations`、`/api/v1/conversation-changes` |

遇到页面/子菜单接口错误时，先检查实际 Snaplink origin 的 `/health` 和代理的
`/health`、`/readyz`：502 表示上游连通性问题，不能通过改菜单或返回空数据修复；
503 配置错误需设置对应服务 origin。401 需重新认证，403 是权限/租户边界拒绝，
不能当成未登录。可选功能是否启用以成功获取的运行时清单及服务契约为准。
API 返回 HTML 会明确报代理/响应错误，而不是显示假空列表。不要对生产部署运行
会创建或修改数据的集成测试来“试接口”。

逐页数据契约、子菜单请求隔离与内容回归范围见
[Admin 数据请求复核](docs/ADMIN_DATA_REQUEST_REVIEW.md)。
25 个非豁免超长文件的完整拆分与验收记录见
[结构门禁修复](docs/STRUCTURE_REFACTOR.md)；仓内全绿不等于真实部署联调完成。

## 质量门禁

```bash
python3 cli.py check
python3 cli.py test
make analyze
make build-prod
make release-artifact-check
git diff --check
```

需要真实后端的集成验证位于 `tests/integration/`；运行方式见
[tests/integration/README.md](tests/integration/README.md)。部署方式见
[DEPLOY.md](DEPLOY.md)。

## 目录

```text
lib/
├── api/                  # Admin、登录、Setup、设备授权传输与缓存
├── screens/
│   ├── admin/            # 管理控制面与 SCIM
│   ├── developer/        # RFC 7591/7592
│   ├── device/           # RFC 8628 用户确认
│   ├── oidc_login/       # 托管登录、MFA 与 Consent
│   ├── portal/           # 最终用户自助门户
│   └── setup/            # 首次初始化
├── services/             # 存储、浏览器适配、缓存通知和审计
└── widgets/              # 跨领域 UI 原语
test/                     # VM 与浏览器组件/契约测试
tests/integration/        # 真实 Snaplink 端到端验证
```
