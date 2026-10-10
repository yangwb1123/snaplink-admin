# sso-console 集成测试

## 测试环境要求

- 专用 Snaplink 测试后端；默认地址为 `http://localhost:8080`
- 已构建的控制台与同源代理；默认地址为 `http://localhost:4444`
- 具有 `admin:read`、`admin:write` 的专用测试账户

脚本统一从环境变量读取配置，不包含默认登录凭据：

| 变量 | 必需 | 默认值 | 用途 |
|---|---|---|---|
| `SNAPLINK_API_URL` | 否 | `http://localhost:8080` | 后端绝对地址 |
| `SNAPLINK_PROXY_URL` | 否 | `http://localhost:4444` | 控制台/代理绝对地址 |
| `SNAPLINK_TEST_USERNAME` | 认证测试必需 | 无 | 测试账户 |
| `SNAPLINK_TEST_PASSWORD` | 认证测试必需 | 无 | 测试账户密码 |
| `SNAPLINK_TEST_CLIENT_ID` | 否 | `sso-admin-console` | 登录使用的客户端 |
| `SNAPLINK_TEST_USER_ID` | 否 | 与用户名相同 | 测试账户的后端资源 ID |
| `SNAPLINK_MANAGE_PROXY` | 否 | 本地地址为 `true` | 是否由脚本启动/停止本地代理 |

## 运行测试

```bash
export SNAPLINK_TEST_USERNAME='test-admin'
export SNAPLINK_TEST_PASSWORD='从测试环境的密钥存储读取'

# 本地后端和代理
python3 tests/integration/run_all.py

# 已部署的专用测试环境；脚本不会管理远端代理进程
SNAPLINK_API_URL='https://api.test.example' \
SNAPLINK_PROXY_URL='https://console.test.example' \
SNAPLINK_MANAGE_PROXY=false \
python3 tests/integration/full_integration_test.py
```

## 隔离的跨应用浏览器 SSO（不使用上述部署或凭据）

`browser_sso_test.py` 自行构建相邻 `../snaplink` 的 stock server，用临时 SQLite、
用户、HTTPS 证书及两个不同 loopback 主机（127.0.0.2/127.0.0.3）RP 驱动 release
Flutter UI。默认同时验证开发 Python 代理与生产 Nginx 配置，后者需要支持 host
network 的 Linux Docker；还需 Go、OpenSSL 和已构建的本地 CanvasKit。只有脚本自己创建的进程/容器会被清理，缺依赖或构建直接失败。

```bash
python3 -m venv /tmp/snaplink-console-browser-venv
. /tmp/snaplink-console-browser-venv/bin/activate
python3 -m pip install -r requirements-browser.txt
python3 -m playwright install chromium
make build-prod
make test-browser-sso
# 不支持 bundled Chromium 的宿主可明确选用已安装的 Chrome：
make test-browser-sso BROWSER_SSO_ARGS='--browser-channel chrome'
```

可显式传 `--backend-repo` / `--web-build` 指定源码与产物；`--gateway python` 或
`--gateway nginx` 只验证其中一条路径，不能替代默认的双路径证据。RP 在服务端
完成独立 code/PKCE exchange、JWKS ID-token 签名/issuer/audience/nonce 验证及
`/userinfo` 校验；不把 Token 放入页面或日志。浏览器仅访问本次 fixture 的 origin，
不留 HAR、trace 或截图。自签名证书仅用于此隔离测试；目标部署仍需真实 TLS。

通过证明同一 Cookie jar 内 A 一次密码认证 → B 无密码、独立 consent 和 Token，
并检查 Cookie 属性/认证年龄、不滚动续期、强制认证、隔离浏览器、登出及独立
服务双向 Cookie 隔离。**它不升级目标部署，不证明原生 WebView 共享 Cookie，
也不能把历史 4444/28080 的 502 报告为已修复。** 详见 `docs/BROWSER_SSO.md`。

## 测试场景

| 测试文件 | 覆盖范围 |
|---------|---------|
| `api_login_e2e.py` | 登录、Token 获取与认证错误 |
| `full_integration_test.py` | 管理 API 合约和核心资源流程 |
| `admin_flow_e2e.py` | 管理员跨模块业务流程 |
| `detail_api_test.py` | 详情和子资源 API |
| `cache_validation_test.py` | 代理及前端缓存行为 |
| `adversarial_test.py` | 非法输入和安全边界 |
| `health_e2e_test.py` | 健康及运行状态 |
| `browser_login_test.py` | 浏览器登录体验 |
| `browser_sso_test.py` | 隔离 stock OP、双网关、双 RP 的真实浏览器身份 SSO |
| `browser_test.py` | 浏览器端到端流程 |
| `browser_interaction_test.py` | 交互、导航和危险操作确认 |
| `full_stack_verify.py` | 后端、代理、静态产物的全栈冒烟 |
| `perf_benchmark.py` | 性能基准 |

除上述自建隔离 fixture 外，这些脚本会创建或修改测试数据，只应对专用测试部署运行。不要把生产凭据写入
shell history、仓库或 CI YAML；CI 中的明文 `admin/admin` 仅属于随作业销毁的
fixture 服务。后端 feature gate 和可选存储不同会改变可执行场景，失败报告
应区分“未启用”与契约回归。
