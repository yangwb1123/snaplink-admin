# lib/api — API 客户端层

| 文件 | 职责 |
|---|---|
| `sso_client.dart` | 核心 HTTP 客户端（Snaplink 服务来源/会话/超时/重试） |
| `snaplink_admin_api.dart` | 管理端 API 封装（端点目录/能力探测） |
| `portal_api.dart` | 用户门户 API（/me 系列） |
| `audit_log_service.dart` | 本地审计日志（append-only） |

设计：所有请求走 `sso_client`（统一 base URL/认证头/超时策略）；
页面不直接使用 http。
