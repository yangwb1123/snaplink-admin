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
2. 合并 `docs/openapi.yaml` 对应的精确方法与路径目录。
3. 对后端已挂载但尚未进入 OpenAPI 的少量路由使用独立补充清单，并在
   `404/501` 时显式降级。

导航条目与页面保持同一个描述对象，因此能力裁剪不会造成索引错位。高频和
高风险场景使用专用工作流；其余已发布管理契约由 Advanced operations 提供
受约束的兜底入口。写操作需要确认，敏感凭据只做一次性展示，PII 导出直接
下载而不进入通用响应预览。

核心实现：

- `lib/screens/admin/admin_navigation.dart`：能力驱动的管理导航
- `lib/screens/admin/admin_route.dart`：可深链的管理路由
- `lib/api/snaplink_admin_api.dart`：认证、缓存、重试和契约传输
- `lib/api/snaplink_admin_types.dart`：已发布及补充路由清单
- `lib/app_router.dart`：六个产品入口的顶层分发

## 本地开发

```bash
# 需要 Flutter 3 / Dart 3
flutter pub get

# 启动开发代理；Snaplink 后端默认监听 localhost:8080
make serve

# 另一个终端构建 Web 产物
make build
```

控制台默认通过 `http://localhost:4444` 访问。认证账号、身份源和功能开关由
所连接的 Snaplink 部署决定，不应在前端仓库中保存默认生产凭据。

## 质量门禁

```bash
flutter analyze
flutter test
flutter build web --release
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
