# 排队任务重新调度验收记录

功能说明见 [AGENT_COMPUTE_RESCHEDULE.md](AGENT_COMPUTE_RESCHEDULE.md)。本次验证
覆盖共享 Agent Hub API、任务数据模型和 Agent Operations 的任务卡片入口。

| 检查 | 结果 |
|---|---|
| `flutter analyze --no-pub` | 通过 |
| Agent API、compute/GPU、刷新、placement、workspace 关联 VM 测试 | 153 passed |
| `dart format` | 通过 |

HTTP fixture 验证 `POST /api/v1/agent/tasks/{task_id}/reschedule` 的 JSON 形状、
202 响应和 `target_device_id` 回读；组件测试验证 queued 任务显示重调度操作，
并在请求期间禁用重复点击。真实 Hub、OAuth、远端 Fabric、在线迁移和物理移动
设备未在本机执行。
