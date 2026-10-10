# lib/api — API 客户端层

| 文件 | 职责 |
|---|---|
| `sso_client.dart` | 核心 HTTP 客户端（Snaplink 服务来源/会话/超时/重试） |
| `snaplink_admin_api.dart` | 管理端 API 封装（端点目录/能力探测） |
| `portal_api.dart` | 用户门户 API（/me 系列） |
| `audit_read_client.dart` | 审计读客户端（trio 表面，AuditQuery-only） |
| `audit_event_row.dart` | 只读审计行模型 + 纯映射器 |
| `forge_conversations_api.dart` | 独立 Forge 传输与稳定导入入口；私有 HTTP／JSON／reader part 保持同一 library |
| `forge_conversations_change_stream_api.dart` | Forge Conversation 变更 SSE/long-poll 只读适配（显式 opt-in） |
| `forge_*` 契约 | 类型化模型、严格校验与纯投影；候选不授予执行权限，结构拆分保留原导入路径 |

设计：Snaplink 核心资源通过其专属客户端读取；Audit Governance、Billing、Agent Hub
和 Forge 使用各自发布契约、显式 origin 和隔离的凭据，不隐式回退核心身份 API。
页面使用领域客户端；核心 protobuf 响应只按已知消息字段适配，SCIM／应用 map／
独立服务保持原契约。结构拆分与等价证据见 `docs/STRUCTURE_REFACTOR.md`。
