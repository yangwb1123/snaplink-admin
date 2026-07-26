# sso-console

snaplink SSO 服务器的管理控制台。基于 Flutter Web 构建，提供完整的身份管理、安全策略、运维监控等功能。

## 快速开始

```bash
# 构建
make build

# 启动开发代理（需要先启动 snaplink 后端）
make serve

# 访问 http://localhost:4444
# 登录: admin / admin
```

## 架构

### 三层 URL 路由

```
Level 1:  /admin/{module}              → 22 个功能模块
Level 2:  /admin/{module}/{id}         → 7 个详情页
          /admin/{module}/{id}/edit    → 编辑
          /admin/{module}/new          → 创建
Level 3:  /admin/{module}/{sub}        → 模块级子资源
          /admin/{module}/{id}/{sub}   → 资源级子资源
```

路由引擎：`lib/screens/admin/admin_route.dart`

### 模块列表

| 模块 | URL | 功能 |
|------|-----|------|
| 客户端 | `/admin/clients` | CRUD, 密钥轮换, 审批 |
| 用户 | `/admin/users` | 会话/授权/MFA/生命周期 |
| 租户 | `/admin/tenants` | 成员/邀请/用量 |
| 连接 | `/admin/connections` | 健康探测/域名 |
| 权限 | `/admin/permissions` | 角色/分配/菜单 |
| Token 安全 | `/admin/token-security` | 组合/异常/会话/过期 |
| Webhook | `/admin/webhooks` | 订阅/死信/重放 |
| 紧急访问 | `/admin/emergency-access` | 审批/模拟/审计 |
| 治理 | `/admin/governance` | 审计/合规/配置/健康 |
| 密钥 | `/admin/crypto-keys` | 轮换/泄露报告 |
| 凭据 | `/admin/credentials` | 泄露报告 |
| 域名 | `/admin/domains` | 注册/验证 |
| ... | ... | 共 23 个模块 |

### 数据流

```
浏览器 → 代理(:4444) → Flutter SPA → SnaplinkAdminApi → snaplink 后端(:8080)
         ├── 静态文件 (build/web/)
         └── API 代理 (/api/*, /auth/*)
```

### 缓存层

`lib/api/data_cache.dart` 提供透明缓存：

- GET 请求缓存 10 秒（TTL 可配置）
- 并发请求去重（相同 URL 合并为 1 个 HTTP 调用）
- 写操作（POST/PUT/DELETE）自动失效相关缓存
- `api.skipCache()` 强制跳过缓存（用户刷新时使用）

## 开发命令

```bash
make build       # 构建 Flutter Web
make test        # 运行单元测试（98 个）
make analyze     # 静态分析（dart analyze）
make serve       # 启动开发代理
make verify      # 构建 + 测试 + 集成验证
make benchmark   # 性能基准测试
make full-stack  # 全栈验证（需后端运行）
make watch       # 监听文件变化自动构建
```

## 测试

```bash
# 单元测试（不依赖后端）
flutter test test/admin_route_test.dart
flutter test test/data_cache_test.dart
flutter test test/api_contract_test.dart

# 集成测试（需后端运行）
python3 tests/integration/full_integration_test.py  # 80 个 API 测试
python3 tests/integration/admin_flow_e2e.py          # 56 个端到端测试
python3 tests/integration/cache_validation_test.py    # 14 个缓存验证

# 浏览器 E2E（需安装 Playwright）
python3 tests/integration/browser_test.py             # 17 个浏览器测试
python3 tests/integration/browser_interaction_test.py # 18 个交互测试

# 全栈验证
python3 tests/integration/full_stack_verify.py        # 6 个步骤
python3 tests/integration/e2e_runner.py                # 74 个测试
```

## 质量门禁

所有代码在合并前必须通过：

```bash
make analyze    # dart analyze: 0 issues
make test       # 单元测试: 全部通过
make build      # Flutter 构建: 成功
```

## 项目结构

```
lib/
├── api/
│   ├── sso_client.dart           # SSOAdminClient (40 方法)
│   ├── snaplink_admin_api.dart   # SnaplinkAdminApi (HTTP 客户端)
│   ├── snaplink_admin_types.dart # 类型定义
│   └── data_cache.dart           # 缓存层
├── screens/
│   ├── admin/                    # 管理后台 (52 文件)
│   │   ├── admin_route.dart      # 路由引擎
│   │   ├── dashboard_screen.dart # 主布局 + 导航
│   │   ├── *_tab.dart            # 23 个标签页
│   │   └── *_screen.dart         # 7 个详情页
│   ├── oidc_login/               # OIDC 登录流
│   └── portal/                   # 自助门户
├── widgets/
│   ├── admin_breadcrumb.dart     # 面包屑导航
│   ├── section_selector.dart     # 章节选择器
│   ├── empty_state.dart          # 空状态
│   ├── search_filter_bar.dart    # 搜索/筛选栏
│   ├── skeleton_list.dart        # 骨架屏加载
│   └── confirm_dialog.dart       # 确认对话框
└── main.dart
test/
├── admin_route_test.dart         # 58 个路由测试
├── data_cache_test.dart          # 15 个缓存测试
├── api_contract_test.dart        # 6 个 API 合约测试
└── ...
tools/
└── robust_proxy.py               # 开发代理服务器
tests/integration/
├── full_integration_test.py      # 80 个集成测试
├── admin_flow_e2e.py             # 56 个端到端测试
├── cache_validation_test.py      # 14 个缓存验证
├── e2e_runner.py                 # 统一测试运行器
├── full_stack_verify.py          # 全栈验证
└── perf_benchmark.py             # 性能基准测试
```

## 技术栈

- **前端**: Flutter Web 3.x (Dart 3.x)
- **后端**: snaplink SSO Server (Go)
- **代理**: Python 3.x (开发环境)
- **测试**: Flutter Test + Python + Playwright + curl
- **CI**: GitHub Actions
