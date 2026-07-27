# sso-console 集成测试

## 测试环境要求

- snaplink 后端运行在 `http://localhost:8080`
- sso-console 代理运行在 `http://localhost:4444`
- 管理员凭据：admin / admin

## 运行测试

```bash
python3 tests/integration/run_all.py
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

这些脚本会创建或修改测试数据，只应对专用测试部署运行。后端 feature gate
和可选存储不同会改变可执行场景，失败报告应区分“未启用”与契约回归。
