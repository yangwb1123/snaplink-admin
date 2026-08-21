/// Administration copy that embeds resource identifiers or runtime values.
const appAdminDynamicSourceZh = <String, String>{
  'Add role {role} for {clientId}?': '为 {clientId} 添加角色 {role}？',
  'All {count} deliveries were sent and removed from the queue.':
      '全部 {count} 次投递均已发送并从队列中移除。',
  'Approval may immediately apply {action}. You must be a different administrator from the proposer.':
      '批准后可能立即执行“{action}”。您必须是不同于提议者的管理员。',
  'Approve {clientId} for use on this authorization server?':
      '批准在此授权服务器上使用 {clientId}？',
  'Assign {roles} to {userId}?': '将 {roles} 分配给 {userId}？',
  'Audit event {id}': '审计事件 {id}',
  'Audit results ({count})': '审计结果（{count}）',
  'Apply {mode} restore from {id}? Resource families are applied sequentially. Snaplink records every step and final result in a durable operation journal for reconciliation.':
      '从 {id} 应用 {mode} 恢复？资源系列将按顺序应用。Snaplink 会将每一步和最终结果记录在持久化操作日志中，以便核对。',
  'Change the server from {current} to {selected}. {description}':
      '将服务器从 {current} 更改为 {selected}。{description}',
  'Client {clientId} approved.': '客户端 {clientId} 已批准。',
  'Client {clientId} rejected.': '客户端 {clientId} 已拒绝。',
  'Client {action}ed': '客户端已{action}',
  'Client: {clientId}': '客户端：{clientId}',
  'Grant revoked; {revoked} derived credentials were revoked and {failed} failed. Retry only the reported idempotency keys.':
      '授权已撤销；{revoked} 个派生凭据已撤销，{failed} 个失败。请仅重试已报告的幂等键。',
  'Grant and all {revoked} reported derived credentials were revoked.':
      '授权及全部 {revoked} 个已报告派生凭据均已撤销。',
  'Connected · latest {count} events are retained locally.':
      '已连接 · 最近 {count} 个事件保留在本地。',
  'Connection: {connectionId}': '连接：{connectionId}',
  'Create a {scope} break-glass grant for {target}. {approval} Reason: {reason}':
      '为 {target} 创建 {scope} 紧急访问授权。{approval} 原因：{reason}',
  'Created {date}': '创建于 {date}',
  'Current mode: {mode}': '当前模式：{mode}',
  'Current state: {state}': '当前状态：{state}',
  'Current: {id}': '当前：{id}',
  'Dead Letters ({count})': '死信（{count}）',
  'Send all {count} stored events again. Receivers may repeat business actions. Each result is reported independently.':
      '再次发送全部 {count} 个存储事件。接收方可能会重复执行业务操作。每个结果独立报告。',
  '{delivered} deliveries succeeded; cleanup is pending for {pending}. Retrying those entries is cleanup-only and cannot redeliver them.':
      '{delivered} 次投递成功；{pending} 次清理待处理。重试这些条目仅会执行清理，无法重新投递。',
  'All {delivered} deliveries were sent and cleaned up.':
      '全部 {delivered} 次投递已发送并清理完成。',
  '{delivered} deliveries were sent; {failed} failed.':
      '{delivered} 次投递已发送；{failed} 次失败。',
  'Replay result: {delivered} delivered, {failed} failed, {pending} awaiting cleanup, and {remaining} selected dead letters remain visible.':
      '重放结果：{delivered} 次已投递，{failed} 次失败，{pending} 次等待清理，{remaining} 个选中的死信仍可见。',
  'Execute {count} SCIM operations?': '执行 {count} 个 SCIM 操作？',
  'The server processes operations in order. Per-operation failures do not roll back earlier successes.':
      '服务器按顺序处理操作。单项操作失败不会回滚此前已成功的操作。',
  'The server processes operations in order. Per-operation failures do not roll back earlier successes. This request contains {count} permanent deletes.':
      '服务器按顺序处理操作。单项操作失败不会回滚此前已成功的操作。此请求包含 {count} 个永久删除。',
  'Delete {clientId} permanently? Existing tokens and integrations may stop working.':
      '永久删除 {clientId}？现有令牌和集成可能会停止工作。',
  'Delete {hostname}?': '删除 {hostname}？',
  'Delete {id}, including its configured domain routing. This cannot be undone.':
      '删除 {id} 及其已配置的域名路由？此操作无法撤销。',
  'Delete {label} and its password credential? This cannot be undone.':
      '删除 {label} 及其密码凭据？此操作无法撤销。',
  'Delete {name}? Requests will immediately fall through to the next matching policy.':
      '删除 {name}？请求将立即继续匹配下一条策略。',
  'Delete registered release {id}?': '删除已注册的发布版本 {id}？',
  'Delete SCIM {resource}?': '删除 SCIM {resource}？',
  'Permanently delete SCIM user {id}. Deactivation is safer when access may need to be restored.':
      '永久删除 SCIM 用户 {id}。如果可能需要恢复访问，停用更安全。',
  'Permanently delete SCIM group {id} and its role definition. Existing membership assignments will no longer grant this role.':
      '永久删除 SCIM 组 {id} 及其角色定义。现有成员分配将不再授予此角色。',
  'Snapshot restore, traffic pinning, registry updates, and compensations are recorded in a durable operation journal.':
      '快照恢复、流量固定、注册表更新和补偿均记录在持久化操作日志中。',
  'Delete stored snapshot {id}?': '删除已存储的快照 {id}？',
  'Delete webhook subscription {id}?': '删除 Webhook 订阅 {id}？',
  'Discovery failed ({status}): {error}': '发现失败（{status}）：{error}',
  'Domain: {domain}': '域名：{domain}',
  'Estimated matches: {count}': '预计匹配数：{count}',
  'Expires: {date}': '到期时间：{date}',
  'Expiry: {date}': '到期时间：{date}',
  'Failed: {error}': '失败：{error}',
  'Grant {requester} access?': '授予 {requester} 访问权限？',
  'ID: {id}': 'ID：{id}',
  'IP {address}': 'IP {address}',
  'IP: {address}  UA: {agent}': 'IP：{address}  用户代理：{agent}',
  'Last seen {time}': '最近出现：{time}',
  'Method: {method}': '方式：{method}',
  'Page {page} · {total} users': '第 {page} 页 · 共 {total} 个用户',
  'Path parameter: {name}': '路径参数：{name}',
  'Permissions: {clientId}': '权限：{clientId}',
  'Pin {id} as the current paired release?': '将 {id} 固定为当前配对发布版本？',
  'Provider: {provider}': '提供商：{provider}',
  'Issue a temporary bearer credential for {userId} with scopes {scopes}. The raw value must be transferred through an approved secure channel.':
      '为 {userId} 签发包含 {scopes} 范围的临时持有者凭据。原始值必须通过获批准的安全渠道传输。',
  'Requires independent approval.': '需要独立审批。',
  'May become active immediately.': '可能立即生效。',
  'Remove {userId} from tenant?': '从租户中移除 {userId}？',
  'Remove {userId} from this organization?': '从此组织中移除 {userId}？',
  'Remove all role assignments for {userId}?': '移除 {userId} 的全部角色分配？',
  'Removed {userId}': '已移除 {userId}',
  'Replay requires reconciliation: {summary}': '重放需要核对：{summary}',
  'Reject {action}? It will never be applied.': '拒绝“{action}”？它将永远不会执行。',
  'Reject the pending client registration for {clientId}?':
      '拒绝客户端 {clientId} 的待处理注册？',
  'The current secret for {clientId} remains valid for 24 hours. Update every integration with the new one-time value before that window closes.':
      '{clientId} 的当前密钥在 24 小时内仍然有效。请在该窗口关闭前使用新的一次性值更新所有集成。',
  'Resend failed: {error}': '重新发送失败：{error}',
  'Restore snapshot {snapshotId}': '恢复快照 {snapshotId}',
  'Revoke {count} matching devices?': '撤销 {count} 个匹配设备？',
  'Revoke every pending invitation for {email}?': '撤销 {email} 的所有待处理邀请？',
  'Revoke failed: {error}': '撤销失败：{error}',
  'Revoke for {clientId}?': '撤销 {clientId} 的授权？',
  'Report {type} credentials as compromised?': '将 {type} 凭据报告为已泄露？',
  'Role: {role}': '角色：{role}',
  'Rollback frontend and backend to {id}? {warning}':
      '将前端和后端回滚到 {id}？{warning}',
  'Run {method}': '运行 {method}',
  'SCIM {collection}': 'SCIM {collection}',
  'SCIM request failed ({status}): {error}': 'SCIM 请求失败（{status}）：{error}',
  'Send a new invitation message to {email}. Any previously issued invitation remains governed by the server.':
      '向 {email} 发送新的邀请消息。以前签发的邀请仍由服务器管理。',
  'Service mode changed to {mode}.': '服务模式已更改为 {mode}。',
  'Subject: {subject}': '主体：{subject}',
  'Suspend {id}? New access is blocked and Snaplink will report every refresh-token and session revocation result with a stable retry key for any failed item.':
      '暂停 {id}？新的访问将被阻止，Snaplink 会报告每项刷新令牌和会话撤销结果，并为失败项提供稳定的重试键。',
  'Return {id} to active service?': '让 {id} 恢复为活跃服务状态？',
  'Delete {label} ({id})? This cannot be undone. Snaplink will return the exact refresh-token and session revocation report.':
      '删除 {label}（{id}）？此操作无法撤销。Snaplink 将返回精确的刷新令牌和会话撤销报告。',
  'Tenant: {tenantId}': '租户：{tenantId}',
  '{action} No credential-revocation report was returned.':
      '{action} 未返回凭据撤销报告。',
  '{action} Revoked {refreshTokens} refresh tokens and {sessions} sessions; every reported credential operation completed.':
      '{action} 已撤销 {refreshTokens} 个刷新令牌和 {sessions} 个会话；所有已报告的凭据操作均已完成。',
  '{action} Revoked {refreshTokens} refresh tokens and {sessions} sessions, but {failed} credential operations failed. Retry only the reported idempotency keys.':
      '{action} 已撤销 {refreshTokens} 个刷新令牌和 {sessions} 个会话，但 {failed} 个凭据操作失败。请仅重试已报告的幂等键。',
  'The current secret for {clientId} will stop working. Update every integration with the new one-time value.':
      '{clientId} 的当前密钥将停止工作。请使用新的一次性值更新所有集成。',
  'The event stream disconnected. Retrying in {seconds} seconds.':
      '事件流已断开，将在 {seconds} 秒后重试。',
  'Unlock {identifier} for client {clientId}?':
      '为客户端 {clientId} 解锁 {identifier}？',
  'Update role {role} for {clientId}?': '更新 {clientId} 的角色 {role}？',
  'User {userId}': '用户 {userId}',
  'User: {userId}': '用户：{userId}',
  'Verify {domain}?': '验证 {domain}？',
  'Webhook #{id}': 'Webhook #{id}',
  'Webhook details': 'Webhook 详情',
  'Webhook: {id}': 'Webhook：{id}',
  'The write result is unknown (HTTP {status}). Reconcile token and session state before retrying.':
      '写入结果未知（HTTP {status}）。请先核对令牌和会话状态，再重试。',
  'The write result is unknown because no response was received. Reconcile token and session state before retrying.':
      '未收到响应，写入结果未知。请先核对令牌和会话状态，再重试。',
  'Token state reconciled?': '令牌状态已核对？',
  'Confirm only after checking the affected token or session in a safe read. This unlocks token writes; it does not prove the previous request failed.':
      '仅在通过安全读取核对受影响的令牌或会话后确认。此操作会解锁令牌写入，但不代表上一次请求一定失败。',
  'Token reconciliation acknowledged. Review the scope before sending another write.':
      '已确认令牌完成核对。再次写入前请检查作用域。',
  'The temporary token result is unknown (HTTP {status}). Do not retry until token state is verified.':
      '临时令牌结果未知（HTTP {status}）。核实令牌状态前请勿重试。',
  'The temporary token result is unknown because no response was received. Do not retry until token state is verified.':
      '未收到响应，临时令牌结果未知。核实令牌状态前请勿重试。',
  'The secret was rotated, but its one-time value was not returned. Reconcile client state before retrying.':
      '密钥已轮换，但未返回其一次性值。请先核对客户端状态，再重试。',
  'Secret rotation result is unknown. Reconcile client state before retrying.':
      '密钥轮换结果未知。请先核对客户端状态，再重试。',
  'Client secret state reconciled?': '客户端密钥状态已核对？',
  'Confirm only after checking the client and its integrations in a safe read. This unlocks secret rotation; it does not prove the previous request failed.':
      '仅在通过安全读取核对客户端及其集成后确认。此操作会解锁密钥轮换，但不代表上一次请求一定失败。',
  'The secret was rotated, but the server did not return its one-time value. Reconcile client state before retrying.':
      '密钥已轮换，但服务器未返回其一次性值。请先核对客户端状态，再重试。',
  'The break-glass write result is unknown. Reconcile the session state before retrying.':
      '紧急访问写入结果未知。请先核对会话状态，再重试。',
  'Break-glass state reconciled?': '紧急访问状态已核对？',
  'Confirm only after checking the emergency-access session in a safe read. This unlocks break-glass writes; it does not prove the previous request failed.':
      '仅在通过安全读取核对紧急访问会话后确认。此操作会解锁紧急访问写入，但不代表上一次请求一定失败。',
  'Break-glass reconciliation acknowledged. Review the target before sending another write.':
      '已确认紧急访问完成核对。再次写入前请检查目标。',
  '{active} of {total} active': '{active}/{total} 个已启用',
  '{count} additional buckets omitted.': '已省略另外 {count} 个分桶。',
  '{count} devices currently require attention': '当前有 {count} 台设备需要关注',
  '{count} live endpoints': '{count} 个活跃端点',
  '{count} more results present.': '另有 {count} 条结果。',
  '{count} runtime endpoints advertised': '运行时声明了 {count} 个端点',
  '{count} top-level attributes': '{count} 个顶层属性',
  '{count} operations returned 404/501; the target does not support them.':
      '{count} 项操作返回 404/501；目标不支持这些操作。',
  '{count} of {total} operations succeeded': '{total} 项操作中有 {count} 项成功',
  '{id} · events: {events}': '{id} · 事件：{events}',
  '{count} perms': '{count} 项权限',
  '{kind} created.': '{kind}已创建。',
  '{kind} deleted.': '{kind}已删除。',
  '{kind} patched.': '{kind}已修补。',
  '{kind} replaced.': '{kind}已替换。',
  '{label}: {value}': '{label}：{value}',
  '{status} · proposed by {user}': '{status} · 提议者：{user}',
  '{value} more': '另有 {value} 项',
  '{count}m ago': '{count} 分钟前',
  '{count}h ago': '{count} 小时前',
  'just now': '刚刚',
  'all': '全部',
  'applied': '已应用',
  'approved': '已批准',
  'day': '天',
  'degraded': '降级',
  'failed': '失败',
  'maintenance': '维护',
  'month': '月',
  'normal': '正常',
  'pending': '待处理',
  'rejected': '已拒绝',
  'unknown': '未知',
};
