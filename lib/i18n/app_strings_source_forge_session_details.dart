/// Session-scoped Forge previews, import states, and validation messages.
const appForgeSessionDetailsSourceZh = <String, String>{
  'Invalid or unavailable client-instance resource view preview.':
      '客户端实例资源视图预览无效或不可用。',
  'Invalid or unavailable client-instance session view preview.':
      '客户端实例会话视图预览无效或不可用。',
  'Invalid or unavailable device placement evaluation preview.':
      '设备放置评估预览无效或不可用。',
  'Invalid or unavailable device resource summary preview.': '设备资源摘要预览无效或不可用。',
  'Invalid or unavailable execution-lease checkpoint preview.':
      '执行租约检查点预览无效或不可用。',
  'Invalid or unavailable placement batch preview.': '放置批次预览无效或不可用。',
  'Invalid or unavailable session Runner receipt history.':
      '会话 Runner 回执历史无效或不可用。',
  'Invalid or unavailable session Runner receipt vectors.':
      '会话 Runner 回执向量无效或不可用。',
  'Invalid or unavailable session Runner reconciliation projection.':
      '会话 Runner 协调投影无效或不可用。',
  'Invalid or unavailable v2 device inventory preview.': 'v2 设备清单预览无效或不可用。',
  'Invalid or unavailable v2 device placement preview.': 'v2 设备放置预览无效或不可用。',
  'Lease and terminal evidence': '租约与终态证据',
  'Lease metadata': '租约元数据',
  'Local Forge client-instance resource view preview': '本地 Forge 客户端实例资源视图预览',
  'Local Forge client-instance session view preview': '本地 Forge 客户端实例会话视图预览',
  'Local Forge device resource summary preview': '本地 Forge 设备资源摘要预览',
  'Local Forge placement batch preview': '本地 Forge 放置批次预览',
  'Local Forge placement evaluation preview': '本地 Forge 放置评估预览',
  'Local Forge v2 device inventory preview': '本地 Forge v2 设备清单预览',
  'Local Forge v2 placement evaluation preview': '本地 Forge v2 放置评估预览',
  'Local Runner Attempt boundary projection': '本地 Runner Attempt 边界投影',
  'Local Runner execution-readiness preview is refreshing or unavailable. Showing the last validated observation; it may be stale.':
      '本地 Runner 执行就绪预览正在刷新或不可用。当前显示最近一次通过验证的观察结果，可能已过期。',
  'Local Runner execution-readiness preview is waiting for a fresh validated client-instance session/resource observation.':
      '本地 Runner 执行就绪预览正在等待新的、已验证的客户端实例会话/资源观察结果。',
  'Local Runner lease/fencing preview': '本地 Runner 租约/fencing 预览',
  'Local display filter over the owner session list; instance metadata is unverified.':
      '所有者会话列表上的本地显示筛选；实例元数据未经验证。',
  'Local execution-lease checkpoint preview': '本地执行租约检查点预览',
  'Local session Runner receipt history preview': '本地会话 Runner 回执历史预览',
  'Local session Runner receipt vectors preview': '本地会话 Runner 回执向量预览',
  'Local session Runner reconciliation projection preview':
      '本地会话 Runner 协调投影预览',
  'Next metadata': '后续元数据',
  'No conversations are visible from this client instance.': '此客户端实例中没有可见会话。',
  'Observation boundary': '观察边界',
  'Offline display only. No references were resolved and no task was dispatched.':
      '仅供离线显示。未解析任何引用，也未派发任何任务。',
  'Offline read-only aggregate; all values are unverified and no target was selected.':
      '离线只读汇总；所有值均未经验证，且未选择目标。',
  'Owner declaration': '所有者声明',
  'Paste the canonical Runner execution observation JSON for this selected Run. It is not saved or used for execution.':
      '粘贴当前所选 Run 对应的规范 Runner 执行观察 JSON。内容不会保存，也不会用于执行。',
  'Paste the canonical session Runner receipt observation JSON for this selected Run. It is not saved or used for execution.':
      '粘贴当前所选 Run 对应的规范会话 Runner 回执观察 JSON。内容不会保存，也不会用于执行。',
  'Placement preview': '放置预览',
  'Prompt and Run': 'Prompt 与 Run',
  'Prompt and Runner': 'Prompt 与 Runner',
  'Prompt append is waiting for a fresh validated client-instance session/resource observation.':
      '追加 Prompt 正在等待新的、已验证的客户端实例会话/资源观察结果。',
  'Read-only binding; no target is selected and no command is executed.':
      '只读绑定；未选择目标，也未执行命令。',
  'Read-only observation; no Run or device is selected.': '只读观察；未选择 Run 或设备。',
  'Read-only restart-boundary classification; it does not retry, select a target, or grant execution authority.':
      '只读重启边界分类；不会重试、选择目标或授予执行权限。',
  'Read-only terminal evidence bound to this Run; no receipt is persisted and no target is selected.':
      '与此 Run 绑定的只读终态证据；不会持久化回执，也不会选择目标。',
  'Receipt metadata': '回执元数据',
  'Restart metadata only; no lease is restored and no Runner is contacted.':
      '仅包含重启元数据；不会恢复租约，也不会联系 Runner。',
  'Runner Attempt boundary is waiting for a fresh validated client-instance session/resource observation.':
      'Runner Attempt 边界正在等待新的、已验证的客户端实例会话/资源观察结果。',
  'Runner dispatch admission is waiting for a fresh validated client-instance session/resource observation.':
      'Runner 派发准入正在等待新的、已验证的客户端实例会话/资源观察结果。',
  'Runner dispatch-plan preview is waiting for a fresh validated client-instance session/resource observation.':
      'Runner 派发计划预览正在等待新的、已验证的客户端实例会话/资源观察结果。',
  'Runner execution intent preview': 'Runner 执行意图预览',
  'Runner execution-boundary preview is waiting for a fresh validated client-instance session/resource observation.':
      'Runner 执行边界预览正在等待新的、已验证的客户端实例会话/资源观察结果。',
  'Runner execution-intent preview is waiting for a fresh validated client-instance session/resource observation.':
      'Runner 执行意图预览正在等待新的、已验证的客户端实例会话/资源观察结果。',
  'Runner lease/fencing local preview': 'Runner 租约/fencing 本地预览',
  'Runner transport admission is waiting for a fresh validated client-instance session/resource observation.':
      'Runner 传输准入正在等待新的、已验证的客户端实例会话/资源观察结果。',
  'Scheduler lease is waiting for a fresh validated client-instance session/resource observation.':
      '调度器租约正在等待新的、已验证的客户端实例会话/资源观察结果。',
  'Scheduler selection preview is waiting for a fresh validated client-instance session/resource observation.':
      '调度器选择预览正在等待新的、已验证的客户端实例会话/资源观察结果。',
  'Scheduling review is waiting for a fresh validated client-instance session/resource observation.':
      '调度审核正在等待新的、已验证的客户端实例会话/资源观察结果。',
  'Select a client-instance session scope': '选择客户端实例会话范围',
  'Session Runner receipt preview': '会话 Runner 回执预览',
  'Session binding': '会话绑定',
  'Session visibility scope': '会话可见范围',
  'Terminal receipt': '终态回执',
  'This owner-scoped candidate is read-only and remains unverified.':
      '此所有者范围候选项仅供读取，仍未经验证。',
};
