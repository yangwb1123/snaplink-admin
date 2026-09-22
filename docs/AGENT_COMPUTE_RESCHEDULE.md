# 排队任务重新调度

Agent Operations 的 Compute tasks 面板允许任务创建者在任务仍为 `queued` 时，
使用目标设备选择器重新指定设备。目标必须同时属于任务提交时的原始设备集合、
当前登录账号的 compute grant 和项目绑定；选择 Automatic 会恢复自动调度。

重新调度只修改任务的目标选择器，并清除尚未派发的旧位置句柄。Hub 以一次事务
写入新的 queued 记录和生命周期事件，因此重复提交同一个目标是幂等的。任务进入
`dispatching`、`running` 或终态后，接口返回冲突，客户端不会尝试迁移或重跑任务。

CLI、TUI、Web、桌面和移动端共用同一接口：

```text
POST /api/v1/agent/tasks/{task_id}/reschedule
{"target_device_id": "DEVICE_ID"}
```

请求需要 `agent.tasks:write`，并且只能由任务创建者发起。空字符串目标表示自动
调度。真实容量预留仍由 Fabric 在派发时裁定；调度诊断可用于查看切换后的当前
阻塞原因。

本机验证结果见 [AGENT_COMPUTE_RESCHEDULE_VERIFICATION.md](AGENT_COMPUTE_RESCHEDULE_VERIFICATION.md)。
