# sso-console

Snaplink SSO 的统一 Web 控制面。一个 Flutter Web 产物同时承载管理员控制台、
托管登录、自助账户门户、开发者动态注册、首次安装和设备授权体验。

## 产品入口

| 入口 | 用户 | 主要能力 |
|---|---|---|
| `/admin/` | 平台、租户、安全与运维管理员 | 身份、应用、权限、策略、Token、设备、审计、治理、恢复与合规 |
| `/login/` | 最终用户 | 品牌化登录、动态身份源、账户恢复、MFA/WebAuthn、授权同意 |
| `/portal/` | 已登录用户 | 账户、凭据、设备、会话、授权、组织、活动与隐私自助 |
| `/developer/` | OAuth/OIDC 应用开发者 | RFC 7591 注册及 RFC 7592 管理 |
| `/setup/` | 首次部署的所有者 | 单次初始化管理员与首个应用 |
| `/device/verify` | 已登录用户 | RFC 8628 设备码确认或拒绝 |

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
高风险写请求；设备安全页和 Checkout 均使用运行时事实。

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
- `lib/app_router.dart`：六个产品入口的顶层分发，含代码分割
- `lib/entries/*.dart`：六个入口的 deferred chunk 边界工厂
- `lib/i18n/app_strings*.dart`：共享 EN/ZH 文案、领域目录和动态占位符翻译

代码分割：六个产品入口各编译为独立 deferred chunk，首屏只下载主包 + 当前
入口 chunk（`/login/` 首屏约 3.5MB raw / 1MB gzip，替代原来 4.7MB 单包；
admin 的 33 个模块约 0.8MB 只在进入 `/admin/` 时下载）。`main()` 在
`runApp` 前预加载当前路径对应入口，因此首屏同步渲染真实界面；跨入口导航
经 `lib/widgets/deferred_entry_screen.dart` 按需加载，失败可重试。
dart2wasm 当前不输出 deferred 分块，因此默认构建为 dart2js
（`make build-prod`），需要 skwasm 的部署可用 `make build-wasm-prod`。

所有六个入口与管理后台均支持英文和中文。页面文案使用 canonical English
源字符串查找，API 返回值和资源标识保持原样；`test/i18n_coverage_test.dart`
会阻止新增未本地化的直接文案、表单标签和运行时提示。

原生客户端可在登录页打开设置并指定 Snaplink 服务来源，设置会跨重启保存，
且对登录、用户门户、设备授权、Setup、开发者注册和管理 API 统一生效。生产
来源必须是纯 HTTPS origin；仅 localhost、127/8 和 `::1` 环回地址允许 HTTP。
Web 版本始终使用当前页面同源，不接受来源覆盖。

密码、邮箱/手机验证码和 TOTP 登录可在原生壳中完成，Bearer 只保存在进程
内存并通过应用内路由续接；未认证 Portal 会进入统一登录并在成功后安全返回
原页面，Admin 的模块、详情和子资源路由也使用同一应用内历史状态。依赖浏览器
安全上下文或页面提交语义的联合登录、WebAuthn/Passkey
和 OIDC `form_post` 会在原生端明确提示需使用 Web 控制台。

## 本地开发

```bash
# 需要 Flutter 3 / Dart 3
flutter pub get

# 工程结构检查读取 engineering.yaml
python3 -m pip install -r requirements-dev.txt

# 启动开发代理；地址可通过 SNAPLINK_API_URL/SNAPLINK_PROXY_PORT 覆盖
make serve

# 另一个终端构建 Web 产物
make build
```

控制台默认通过 `http://localhost:4444` 访问。认证账号、身份源和功能开关由
所连接的 Snaplink 部署决定，不应在前端仓库中保存默认生产凭据。

## 质量门禁

```bash
flutter analyze
make test
make build-prod
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
