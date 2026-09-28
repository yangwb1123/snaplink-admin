/// Literal copy used by Forge preview and admission panels.
const appForgePanelsSourceZh = <String, String>{
  'Authenticated read-only comparison over the persisted registry; no target was selected and all authority is false.':
      '基于已持久化注册表的已认证只读比较；未选择目标，所有权限标志均为 false。',
  'Candidate receipt only. No Run was created, no device was selected, and no execution authority was granted.':
      '仅为候选回执。未创建 Run、未选择设备，也未授予任何执行权限。',
  'Client instance resource view': '客户端实例资源视图',
  'Client instance session view': '客户端实例会话视图',
  'Device credential lifecycle candidate': '设备凭据生命周期候选项',
  'Execution consent preview': '执行同意预览',
  'Expand to read payload-free event markers.': '展开以查看不含载荷的事件标记。',
  'Forge preflight preview': 'Forge 预检预览',
  'Forge registry placement preview is refreshing or unavailable. Showing the last validated comparison; it may be stale.':
      'Forge 注册表放置预览正在刷新或不可用。当前显示最近一次通过验证的比较结果，可能已过期。',
  'Forge scheduler lease is unavailable. The displayed lease was not renewed.':
      'Forge 调度器租约不可用。显示的租约尚未续期。',
  'Forge scheduler lease release is unavailable. The displayed release receipt may be stale.':
      'Forge 调度器租约释放信息不可用。显示的释放回执可能已过期。',
  'Forge scheduler selection is refreshing or unavailable. Showing the last validated preview; it may be stale.':
      'Forge 调度器选择正在刷新或不可用。当前显示最近一次通过验证的预览，可能已过期。',
  'Lease and Attempt are admissible for a later reviewed dispatch step.':
      'Lease 与 Attempt 符合后续经审查派发步骤的准入条件。',
  'Lease issued; command execution, Runner dispatch, and Audit publication remain disabled. The fencing token is withheld from this view.':
      '租约已签发；命令执行、Runner 派发和 Audit 发布仍处于禁用状态。此视图不会显示 fencing token。',
  'Lifecycle registry candidate': '生命周期注册表候选项',
  'Load more pending Run-intents': '加载更多待处理 Run 意图',
  'Loading more pending Run-intents…': '正在加载更多待处理 Run 意图…',
  'Local Runner execution-readiness preview': '本地 Runner 执行就绪预览',
  'Manual reconciliation required; automatic retry disabled.':
      '需要手动协调；自动重试已禁用。',
  'Manual review · automatic retry disabled': '需要手动审核 · 自动重试已禁用',
  'Metadata-only preview; no credential material or execution authority.':
      '仅供预览的元数据；不包含凭据材料，也不授予执行权限。',
  'No pending Run-intent receipts for this session.': '此会话没有待处理的 Run 意图回执。',
  'No registry candidates.': '没有注册表候选项。',
  'Offline contract · authority disabled': '离线合约 · 权限已禁用',
  'Offline history · authority disabled': '离线历史记录 · 权限已禁用',
  'Pending Run-intent metadata': '待处理 Run 意图元数据',
  'Pending Run-intent preview': '待处理 Run 意图预览',
  'Planning-only preview. It explains one deterministic candidate and grants no lease or execution authority.':
      '仅供规划的预览。用于说明一个确定性候选项，不签发租约，也不授予执行权限。',
  'Preview only · Attempt persistence, reservation, authorization, dispatch, argv execution, lease mutation, and Audit publication are absent.':
      '仅供预览 · Attempt 持久化、预留、授权、派发、argv 执行、租约变更及 Audit 发布均未实现。',
  'Preview only · consent has not been granted; no Run or device was selected.':
      '仅供预览 · 尚未授予同意；未选择 Run 或设备。',
  'Preview only · fencing token, argv, workspace, Runner contact, execution, and Audit publication are absent.':
      '仅供预览 · 未提供 fencing token、argv、工作区或 Runner 联系；不会执行，也不会发布 Audit。',
  'Preview only · fencing token, argv, workspace, payload, Runner output, execution, and Audit publication are absent.':
      '仅供预览 · 未提供 fencing token、argv、工作区、载荷或 Runner 输出；不会执行，也不会发布 Audit。',
  'Preview only · no device authentication, Runner contact, payload send, execution, or Audit publication.':
      '仅供预览 · 不进行设备认证、联系 Runner、发送载荷、执行或发布 Audit。',
  'Preview only · no dispatch performed': '仅供预览 · 未执行派发',
  'Preview only · no execution authority granted': '仅供预览 · 未授予执行权限',
  'Read-only authenticated restart snapshot; no enrollment or execution authority.':
      '已认证的只读重启快照；不提供注册或执行权限。',
  'Read-only metadata; no Prompt or device authority.':
      '只读元数据；不具备 Prompt 或设备权限。',
  'Read-only metadata; resources are unverified and cannot run work.':
      '只读元数据；资源未经验证，不能用于执行工作。',
  'Read-only receipt metadata. Prompt content is hidden and no Run was started.':
      '只读回执元数据。Prompt 内容已隐藏，且未启动 Run。',
  'Receipt only. No Run was created and no device was selected.':
      '仅有回执。未创建 Run，也未选择设备。',
  'Registry placement preview': '注册表放置预览',
  'Request scheduling review': '请求调度审核',
  'Retry scheduling review': '重试调度审核',
  'Runner Attempt boundary preview': 'Runner Attempt 边界预览',
  'Runner dispatch admission preview': 'Runner 派发准入预览',
  'Runner dispatch-plan preview': 'Runner 派发计划预览',
  'Runner execution boundary preview': 'Runner 执行边界预览',
  'Runner transport admission preview': 'Runner 传输准入预览',
  'Scheduler lease': '调度器租约',
  'Scheduler lease released': '调度器租约已释放',
  'Scheduler selection preview': '调度器选择预览',
  'Scheduling review requested': '已请求调度审核',
  'Scheduling review requested. No task has started.': '已请求调度审核。尚未启动任何任务。',
  'Selected target: none · authority: disabled': '所选目标：无 · 权限：已禁用',
  'Server-owned P4, Runner authority, lease, transport, and effect observations line up for a future reviewed adapter.':
      '服务器拥有的 P4、Runner 权限、租约、传输及效果观察结果均相符，可供未来经审查的适配器使用。',
  'Session Runner receipt history': '会话 Runner 回执历史',
  'Session Runner receipt outcomes': '会话 Runner 回执结果',
  'Session Runner reconciliation': '会话 Runner 协调',
  'The Attempt lifecycle boundary is not dispatchable.': 'Attempt 生命周期边界不可派发。',
  'The lease-to-Runner admission recheck is not ready.':
      '租约到 Runner 的准入复核尚未就绪。',
  'The proposed Attempt lifecycle edge is display-only and awaits a separately reviewed effect adapter.':
      '拟议的 Attempt 生命周期边沿仅供显示，需等待单独审查的效果适配器。',
  'The reservation is inactive; its epoch remains in durable history for fencing. Execution, Runner dispatch, and Audit publication remain disabled.':
      '预留已停用；其 epoch 仍保留在持久化历史中用于 fencing。执行、Runner 派发和 Audit 发布仍处于禁用状态。',
  'The server-owned execution boundary is not ready.': '服务器拥有的执行边界尚未就绪。',
  'The transport-to-lease admission recheck is not ready.': '传输到租约的准入复核尚未就绪。',
  'The verified transport observation matches the current fenced lease and Attempt.':
      '已验证的传输观察结果与当前设有 fencing 的租约及 Attempt 相符。',
  'Timeline metadata': '时间线元数据',
  'Timeline metadata is not loaded.': '尚未加载时间线元数据。',
  'offline · all execution flags false': '离线 · 所有执行标志均为 false',
};
