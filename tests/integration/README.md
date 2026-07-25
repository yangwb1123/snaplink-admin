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
| 01_auth_test.py | 认证流程（登录、Token 获取、Scope 验证） |
| 02_core_crud_test.py | 核心 CRUD（客户端、用户、租户） |
| 03_admin_endpoints_test.py | 所有管理端点可用性 |
| 04_feature_modules_test.py | 功能模块（Break Glass、Webhooks、Crypto Keys 等） |
| 05_token_security_test.py | Token 安全管理 |
| 06_user_support_test.py | 用户支持功能 |
| 07_governance_test.py | 治理与配置管理 |
| 08_e2e_workflow_test.py | 端到端业务流程 |
