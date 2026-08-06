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
| `browser_test.py` | 浏览器端到端流程 |
| `browser_interaction_test.py` | 交互、导航和危险操作确认 |
| `full_stack_verify.py` | 后端、代理、静态产物的全栈冒烟 |
| `perf_benchmark.py` | 性能基准 |

这些脚本会创建或修改测试数据，只应对专用测试部署运行。不要把生产凭据写入
shell history、仓库或 CI YAML；CI 中的明文 `admin/admin` 仅属于随作业销毁的
fixture 服务。后端 feature gate 和可选存储不同会改变可执行场景，失败报告
应区分“未启用”与契约回归。
