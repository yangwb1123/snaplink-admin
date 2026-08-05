/// Administration feature descriptions, validation, and safety messages.
const appAdminFeatureSourceZh = <String, String>{
  'Account lockout recovery': '账户锁定恢复',
  'Administration endpoint': '管理端点',
  'Advance bootstrap high-water mark': '推进引导高水位',
  'Advertised JWKS URL': '声明的 JWKS URL',
  'Advertised base URL': '声明的基础 URL',
  'Advertised logout URL': '声明的退出 URL',
  'Apply ordered operation': '应用有序操作',
  'Audit Log': '审计日志',
  'Break-glass approved.': '紧急访问已批准。',
  'Break-glass session created.': '紧急访问会话已创建。',
  'Create audited, time-bound emergency access to user accounts.':
      '创建经过审计且有时间限制的用户账户紧急访问。',
  'Create or replace connection': '创建或替换连接',
  'Data-subject request': '数据主体请求',
  'Domain added.': '域名已添加。',
  'Domain deleted.': '域名已删除。',
  'Domain management is not enabled.': '域名管理功能未启用。',
  'Domain ownership': '域名所有权',
  'Encrypted transport complete; export downloaded.': '加密传输完成，导出文件已下载。',
  'Enter a client ID first.': '请先输入客户端 ID。',
  'Enter a connection ID first.': '请先输入连接 ID。',
  'Enter a credential type.': '请输入凭据类型。',
  'Enter a hostname.': '请输入主机名。',
  'Enter a policy name.': '请输入策略名称。',
  'Enter a remote address to classify.': '请输入要分类的远程地址。',
  'Enter a subject identifier.': '请输入主体标识。',
  'Enter a tenant ID first.': '请先输入租户 ID。',
  'Enter a tenant ID to list its connections.': '请输入租户 ID 以列出其连接。',
  'Enter a token ID (jti).': '请输入令牌 ID（jti）。',
  'Enter a user ID first.': '请先输入用户 ID。',
  'Enter a user ID.': '请输入用户 ID。',
  'Enter at least one role code.': '请至少输入一个角色代码。',
  'Enter the affected snapshot, release, or change ID.': '请输入受影响的快照、发布或变更 ID。',
  'Enter the data subject’s user ID.': '请输入数据主体的用户 ID。',
  'Exact write confirmation': '精确写入确认',
  'Failed to create break-glass session.': '无法创建紧急访问会话。',
  'Fleet posture, device-level investigation, and bounded incident response.':
      '设备群安全状态、设备级调查和有限范围的事件响应。',
  'Grant record revoked. Verify all derived sessions and tokens.':
      '授权记录已撤销，请核对所有派生会话和令牌。',
  'Grant record revoked. Verify derived sessions and tokens.':
      '授权记录已撤销，请核对派生会话和令牌。',
  'High-impact changes require an independent administrator to approve them before application.':
      '高影响变更必须由独立管理员批准后才能应用。',
  'Hostname matches take precedence over CIDRs.': '主机名匹配优先于 CIDR。',
  'Identity connection management is not enabled on this Snaplink replica.':
      '此 Snaplink 副本未启用身份连接管理。',
  'Invalid JSON in menus field.': '菜单字段中的 JSON 无效。',
  'Invalid JSON or request failed.': 'JSON 无效或请求失败。',
  'Local password users are not enabled on this replica.': '此副本未启用本地密码用户。',
  'Manage email domains for home-realm discovery.': '管理用于主域发现的邮箱域名。',
  'Manage encrypted state snapshots and coordinated frontend/backend release pins.':
      '管理加密状态快照以及前后端协调发布固定点。',
  'Map trusted CIDRs and hostnames to advertised endpoints. Higher priority wins; hostname matches win over CIDRs.':
      '将受信任的 CIDR 和主机名映射到声明端点。优先级越高越先匹配，主机名优先于 CIDR。',
  'Network policy management is not enabled.': '网络策略管理功能未启用。',
  'No optional administration routes are registered on this replica.':
      '此副本未注册可选管理路由。',
  'Operational telemetry is aggregated and may lag live authentication traffic slightly.':
      '运维遥测经过聚合，可能略微滞后于实时身份验证流量。',
  'Organization management is not enabled on this Snaplink replica.':
      '此 Snaplink 副本未启用组织管理。',
  'Password-authenticated accounts managed by this SSO server.':
      '由此 SSO 服务器管理的密码身份验证账户。',
  'Payload must be a JSON object.': '负载必须是 JSON 对象。',
  'Priority and metadata must be valid values.': '优先级和元数据必须是有效值。',
  'Provider capabilities': '提供商能力',
  'Recovery and releases': '恢复与发布',
  'Response copied to clipboard.': '响应已复制到剪贴板。',
  'Rotation inventory': '轮换清单',
  'SCIM 2.0 Directory': 'SCIM 2.0 目录',
  'SCIM 2.0 is not advertised by this deployment.': '此部署未声明支持 SCIM 2.0。',
  'Secret rotated.': '密钥已轮换。',
  'Set a subject and/or client ID to bound the revocation.':
      '请设置主体和/或客户端 ID 以限定撤销范围。',
  'Some subject data is unavailable — {errors}': '部分主体数据不可用 — {errors}',
  'Some usage data is unavailable — {errors}': '部分使用数据不可用 — {errors}',
  'Subject investigation is not enabled.': '主体调查功能未启用。',
  'Supply at least one boundary. Snaplink rejects an unscoped revoke and may require confirmation for large batches.':
      '请至少提供一个范围限制。Snaplink 会拒绝无范围撤销，并可能要求确认大型批次。',
  'Tenant usage metering is unavailable or has no data.': '租户使用计量不可用或没有数据。',
  'Test ReBAC and WASM authorization policies.': '测试 ReBAC 和 WASM 授权策略。',
  'The SCIM operation failed.': 'SCIM 操作失败。',
  'The selected device has no user/device ID.': '所选设备没有用户/设备 ID。',
  'The server returned an empty response.': '服务器返回了空响应。',
  'The secret was rotated, but its one-time value was not returned.':
      '密钥已轮换，但服务器未返回其一次性值。',
  'This bearer is shown once and is not retained by the console.':
      '此持有者令牌仅显示一次，控制台不会保留。',
  'This feature is not enabled on the connected replica.': '连接的副本未启用此功能。',
  'This secret will not be shown again.': '此密钥不会再次显示。',
  'This user resource is unavailable.': '此用户资源不可用。',
  'Threat policy management is not enabled.': '威胁策略管理功能未启用。',
  'Token exchange audit is not enabled.': '令牌交换审计功能未启用。',
  'Token issuance and validation policy configuration.': '令牌签发和验证策略配置。',
  'Token policy management is not enabled.': '令牌策略管理功能未启用。',
  'Token usage telemetry is unavailable or has no data.': '令牌使用遥测不可用或没有数据。',
  'Two-person administrative approvals are not enabled.': '双人管理审批功能未启用。',
  'Unable to load activity: {error}': '无法加载活动：{error}',
  'Usage analytics is not enabled.': '使用分析功能未启用。',
  'Usage and session insights': '使用和会话分析',
  'User ID is required.': '必须填写用户 ID。',
  'A request cannot disable server-enforced dry-run mode. Audit records remain authoritative.':
      '请求无法关闭服务器强制的试运行模式；应以审计记录为准。',
  'A successful dry run with the same snapshot, mode, exclusions, and channel is required before restore.':
      '恢复前必须使用相同快照、模式、排除项和渠道成功完成试运行。',
  'Additional string keys preserved verbatim': '按原样保留的其他字符串键',
  'Available management domains': '可用管理领域',
  'Calculate changes without persisting them.': '计算变更但不持久化。',
  'Conditions are combined with AND, matching Snaplink server semantics.':
      '各条件使用 AND 组合，与 Snaplink 服务器语义一致。',
  'Creates Snaplink’s redacted tenant offboarding or migration bundle.':
      '创建经过脱敏的 Snaplink 租户下线或迁移包。',
  'Define a bounded risk segment. Empty filters are blocked because an unfiltered revocation can affect every device.':
      '定义有限的风险分段。系统会阻止空筛选条件，因为无筛选撤销可能影响所有设备。',
  'Devices and login history': '设备与登录历史',
  'Discover provider capabilities, reconcile users and groups, and execute bounded bulk operations.':
      '发现提供商能力、核对用户和组，并执行有限范围的批量操作。',
  'Documented Snaplink administration routes are listed here; runtime inventory marks routes the current replica reports as active. Server-side feature gates remain authoritative. Write operations are audited and require explicit confirmation.':
      '此处列出已记录的 Snaplink 管理路由；运行时清单会标记当前副本报告为活跃的路由。服务器端功能门禁仍为最终依据，写操作会被审计且需要明确确认。',
  'Empty, malformed, oversized, recursive, or unsupported bulk requests are rejected before submission.':
      '空、格式错误、过大、递归或不受支持的批量请求会在提交前被拒绝。',
  'Enabled feature surfaces': '已启用的功能界面',
  'Enter client ID and press Search': '输入客户端 ID 后按“搜索”',
  'Execute data-subject requests with preview-first controls and keep destructive operations bounded.':
      '使用先预览控制执行数据主体请求，并限制破坏性操作范围。',
  'Exports may contain PII. They download directly and are never cached by the console.':
      '导出内容可能包含个人身份信息；文件会直接下载，控制台不会缓存。',
  'Fetches the OIDC discovery document or SAML metadata and records the result.':
      '获取 OIDC 发现文档或 SAML 元数据并记录结果。',
  'Inspect active refresh-token counts and linked OIDC/SAML session legs without exposing credential values.':
      '检查活跃刷新令牌数量及关联的 OIDC/SAML 会话分支，同时不暴露凭据值。',
  'Investigate access context and revoke a compromised endpoint without affecting unrelated devices.':
      '调查访问上下文并撤销已泄露的端点，不影响无关设备。',
  'Key marked as compromised.': '密钥已标记为泄露。',
  'Key rotation initiated.': '密钥轮换已启动。',
  'Lockouts are scoped by OAuth client and the exact username, email, or phone identifier.':
      '锁定按 OAuth 客户端以及精确的用户名、邮箱或电话号码标识进行限定。',
  'Must match an action enabled by the server.': '必须与服务器启用的操作匹配。',
  'No audit entries yet. Operations will appear here.': '尚无审计记录，操作会显示在此处。',
  'No resources match this query.': '没有资源匹配此查询。',
  'No suspicious or very-low-trust devices found.': '未发现可疑或信任度极低的设备。',
  'Per-operation status; overall HTTP is 200': '逐项操作状态；总体 HTTP 状态为 200',
  'Provide an array of menu items. Each item needs id and name; children and buttons are nested arrays.':
      '请提供菜单项数组。每项需要 id 和 name，children 与 buttons 使用嵌套数组。',
  'Publish each DNS TXT record and then verify it. The challenge value is public DNS data, not a bearer secret.':
      '请发布每条 DNS TXT 记录后进行验证。挑战值是公开 DNS 数据，不是持有者密钥。',
  'PUT replaces the display name and reconciles membership to the exact submitted list.':
      'PUT 会替换显示名称，并将成员关系核对为提交的精确列表。',
  'ReBAC policy check': 'ReBAC 策略检查',
  'Replace mode removes operator-managed state before seeding the snapshot. The server requires the snapshot ID as confirmation.':
      '替换模式会先移除运维人员管理的状态，再写入快照；服务器要求使用快照 ID 进行确认。',
  'Required. The server assigns the immutable ID.': '必填。服务器会分配不可变 ID。',
  'Result:': '结果：',
  'RFC 7644 filter; blank returns all resources': 'RFC 7644 筛选条件；留空返回所有资源',
  'Rotate the signing key?': '轮换签名密钥？',
  'Save this token now. It will not be shown again.': '请立即保存此令牌，它不会再次显示。',
  'Save this value now. It is not retained or shown in the operation response.':
      '请立即保存此值；操作响应不会保留或再次显示它。',
  'Save this value through an approved secure channel. It will not be shown again.':
      '请通过获批准的安全渠道保存此值；它不会再次显示。',
  'Saving an existing ID replaces its configuration and domain routing.':
      '保存已有 ID 会替换其配置和域名路由。',
  'Subject export downloaded without previewing it.': '主体导出已下载，未在控制台中预览。',
  'Test a network tuple before changing edge routing.': '更改边缘路由前测试网络元组。',
  'These public values theme the hosted sign-in experience. Unknown keys are preserved verbatim.':
      '这些公开值用于设置托管登录体验的主题；未知键会按原样保留。',
  'This endpoint rotates the active signing key; it does not rotate credential encryption keys.':
      '此端点会轮换活跃签名密钥，不会轮换凭据加密密钥。',
  'This service provider does not advertise Bulk.': '此服务提供商未声明支持 Bulk。',
  'Use this for snapshots, deployments, disaster recovery, retention, and two-person change control.':
      '用于快照、部署、灾难恢复、保留策略和双人变更控制。',
  'Use {} when none are required.': '不需要参数时请使用 {}。',
  'WASM authorization check': 'WASM 授权检查',
  'When a resource exposes meta.version, this console sends it as If-Match to prevent lost updates.':
      '当资源暴露 meta.version 时，控制台会将其作为 If-Match 发送，以防更新丢失。',
  'Enter a token JTI to trace its exchange chain': '输入令牌 JTI 以跟踪其交换链',
  'One per line, for example 10.0.0.0/8.': '每行一个，例如 10.0.0.0/8。',
  'Webhook subscription created.': 'Webhook 订阅已创建。',
  '25 per page': '每页 25 条',
  '100 per page': '每页 100 条',
  '250 per page': '每页 250 条',
  'A request cannot disable server-enforced dry-run mode. Audit events past retention are reported, never deleted by this sweep.':
      '请求无法关闭服务器强制的试运行模式。超过保留期的审计事件只会被报告，此清理不会删除它们。',
  'A successful dry run with the same snapshot, mode, exclusions, and bootstrap setting is required before commit.':
      '提交前必须使用相同快照、模式、排除项和引导设置成功完成试运行。',
  'Bulk result is unknown because the response was not received. Operations may have partially applied. Reconcile Users and Groups before acknowledging and sending another request.':
      '由于未收到响应，批量操作结果未知，部分操作可能已经生效。请先核对用户和组，再确认并发送其他请求。',
  'Client ID and the exact login identifier are required to clear a lockout.':
      '清除锁定需要客户端 ID 和精确的登录标识。',
  'Comma or line separated. Snaplink validates that each role exists.':
      '使用逗号或换行分隔。Snaplink 会验证每个角色是否存在。',
  'Configure a tenant\'s OIDC or SAML upstream and verify its email-domain routing.':
      '配置租户的 OIDC 或 SAML 上游，并验证其邮箱域名路由。',
  'Could not load access policies.': '无法加载访问策略。',
  'Active-session convergence is not advertised by this server.':
      '此服务器未公布存量会话收敛能力。',
  'Apply current policies?': '立即应用当前策略？',
  'Apply to active sessions': '应用到活跃会话',
  'This immediately re-evaluates active sessions. Sessions may be revoked, marked for step-up, or have their scope ceiling reduced.':
      '这将立即重新评估活跃会话。会话可能被撤销、标记为需要增强验证，或被缩减权限范围上限。',
  'Could not converge active sessions.': '无法收敛活跃会话。',
  'No conditions (matches every session)': '无条件（匹配所有会话）',
  'Scope ceiling': '权限范围上限',
  'Could not load break-glass sessions.': '无法加载紧急访问会话。',
  'Could not load credentials.': '无法加载凭据。',
  'Could not load crypto keys.': '无法加载加密密钥。',
  'Could not load domains.': '无法加载域名。',
  'Could not load DR mode status.': '无法加载灾难恢复模式状态。',
  'Could not load exchange chain.': '无法加载交换链。',
  'Could not load threat policies.': '无法加载威胁策略。',
  'Could not load token policies.': '无法加载令牌策略。',
  'Could not load webhooks.': '无法加载 Webhook。',
  'Define a bounded risk segment. Empty filters are blocked because the operation can permanently remove every matched device. Verify devices and sessions after it completes.':
      '定义有限的风险分段。系统会阻止空筛选条件，因为此操作可能永久移除所有匹配设备。完成后请核对设备和会话。',
  'Discover provider capabilities, reconcile users and groups, and run bounded provisioning batches.':
      '发现提供商能力、核对用户和组，并运行有限范围的预配批次。',
  'Empty, malformed, oversized, recursive, or unsupported requests cannot be sent. Keep credentials and secrets out of the editor; the server returns per-operation status.':
      '无法发送空、格式错误、过大、递归或不受支持的请求。请勿在编辑器中填写凭据或密钥；服务器会返回每项操作的状态。',
  'Example: {"tenant_id":"acme","outcome":"failure","limit":100}':
      '示例：{"tenant_id":"acme","outcome":"failure","limit":100}',
  'Execute data-subject requests with preview-first controls and keep sensitive exports out of the console display.':
      '使用先预览控制执行数据主体请求，并避免在控制台中显示敏感导出内容。',
  'Exports may contain PII. They download directly and are never placed in console history or clipboard.':
      '导出内容可能包含个人身份信息。文件会直接下载，不会进入控制台历史记录或剪贴板。',
  'Lockouts are scoped by OAuth client and the exact username, email, or phone value used at login—not by the internal user ID.':
      '锁定按 OAuth 客户端及登录时使用的精确用户名、邮箱或电话号码限定，而不是按内部用户 ID。',
  'Mutation inputs are locked. Select and run a safe GET, or use the dedicated resource screen, then explicitly acknowledge reconciliation.':
      '写操作输入已锁定。请选择并运行安全的 GET，或使用专用资源页面，然后明确确认已完成核对。',
  'One per line or comma-separated. Leave blank to accept any authenticator.':
      '每行一个或使用逗号分隔。留空表示接受任意身份验证器。',
  'One per line: address | type | primary. Only one primary.':
      '每行一个：地址 | 类型 | 是否主要。只能有一个主要地址。',
  'Provider and connection reads are server-redacted, secret fields remain write-only, and ordinary snapshot detail is server-redacted. High-impact workflows with dedicated preview or reconciliation screens cannot be bypassed here.':
      '提供商和连接读取由服务器脱敏，密钥字段保持只写，普通快照详情也由服务器脱敏。此处不能绕过带有专用预览或核对页面的高影响工作流。',
  'PUT replaces the display name and reconciles membership to exactly this list. Role and membership persistence is not a cross-store transaction; reconcile after a partial failure.':
      'PUT 会替换显示名称，并将成员关系核对为此精确列表。角色与成员关系的持久化不是跨存储事务；发生部分失败后请进行核对。',
  'Reconciliation acknowledged. Review the draft before sending.':
      '已确认完成核对。发送前请检查草稿。',
  'Reconciliation acknowledged. Review the endpoint, path, and body before submitting another write.':
      '已确认完成核对。提交其他写操作前，请检查端点、路径和请求体。',
  'Save this value through an approved secure channel. It will not be retained or shown again after you acknowledge this dialog.':
      '请通过获批准的安全渠道保存此值。确认此对话框后，它不会被保留或再次显示。',
  'The retained request is locked until server state has been reconciled.':
      '在服务器状态完成核对前，保留的请求将保持锁定。',
  'The token may have been issued, but Snaplink did not return its one-time value. Do not retry until you verify server state.':
      '令牌可能已经签发，但 Snaplink 未返回其一次性值。在核实服务器状态前请勿重试。',
  'These public values theme the hosted sign-in experience. Unknown settings are preserved when saving.':
      '这些公开值用于设置托管登录体验的主题；保存时会保留未知设置。',
  'This endpoint rotates the active signing key; it does not rotate every encryption or credential key. Services may briefly reload the signing-key set.':
      '此端点会轮换活跃签名密钥，不会轮换所有加密密钥或凭据密钥。服务可能会短暂重新加载签名密钥集。',
  'Add an incident or change reference before degrading service.':
      '降低服务级别前，请添加事件或变更引用。',
  'Approval payloads are persisted. Reference a secret by ID; do not include passwords, tokens, or credentials.':
      '审批载荷会被持久化。请通过 ID 引用密钥，不要包含密码、令牌或凭据。',
  'Bulk execution is disabled until capability discovery succeeds.':
      '在能力发现成功前，批量执行处于禁用状态。',
  'Choose at least one condition. An unfiltered revocation is never allowed.':
      '请至少选择一个条件，绝不允许无筛选条件的撤销。',
  'Connection configuration must be a JSON object.': '连接配置必须是 JSON 对象。',
  'Generic governance payloads are retained in reports and approval records. Do not include passwords, tokens, or private keys.':
      '通用治理载荷会保留在报告和审批记录中。请勿包含密码、令牌或私钥。',
  'No devices match the current filters.': '没有设备匹配当前筛选条件。',
  'Reconcile the previous write against authoritative server state before authorizing another mutation.':
      '授权其他写操作前，请根据权威服务器状态核对上一次写操作。',
  'Reconcile Users and Groups before authorizing another bulk request.':
      '授权其他批量请求前，请先核对用户和组。',
  'Refresh the estimate with a bounded filter before continuing.':
      '继续前，请使用有限筛选条件刷新估算结果。',
  'Run a fresh dry-run preview for this subject before erasure.':
      '擦除前，请为此主体重新运行试运行预览。',
  'Run a successful dry-run preview with these exact restore settings before committing.':
      '提交前，请使用这些精确的恢复设置成功运行试运行预览。',
  'Safety boundary blocked an unfiltered bulk device revocation.':
      '安全边界已阻止无筛选条件的设备批量撤销。',
  'Snaplink accepted the impersonation request but did not return a bearer. Do not retry until server state is verified.':
      'Snaplink 已接受模拟用户请求，但未返回持有者令牌。在核实服务器状态前请勿重试。',
  'The secret was rotated, but the server did not return its one-time value.':
      '密钥已轮换，但服务器未返回其一次性值。',
  'Use Live audit activity for the authenticated, cancellable event stream.':
      '请使用“实时审计活动”查看经过身份验证且可取消的事件流。',
  'SCIM Groups are not enabled': 'SCIM 组功能未启用',
  'Schema': '架构',
  'Not supported': '不支持',
  'Create SCIM group': '创建 SCIM 组',
  'Create group': '创建组',
  'Replace SCIM group': '替换 SCIM 组',
  'Replace group': '替换组',
  'Inactive': '未启用',
  'Item': '项目',
  'Create SCIM user': '创建 SCIM 用户',
  'Create user': '创建用户',
  'Replace SCIM user': '替换 SCIM 用户',
  'Replace user': '替换用户',
  'The documented event broker is not listed by this replica\'s inventory. You can connect when the route is mounted; otherwise use audit queries.':
      '此副本的运行时清单未列出文档中的事件代理。路由挂载后可以连接，否则请使用审计查询。',
  'The replica advertises the event broker. The feed shows only Snaplink\'s redacted event summaries; select an item to request its full audit record.':
      '此副本已声明事件代理。事件流仅显示 Snaplink 脱敏后的事件摘要；选择项目可请求完整审计记录。',
  'A typed confirmation is required before sending the request.':
      '发送请求前必须完成输入确认。',
  'No devices currently match; revocation is disabled.': '当前没有匹配的设备，撤销操作已禁用。',
  'All reported operations completed.': '所有报告的操作均已完成。',
  'Groups require scim.groups.enabled and a permissions provider.':
      '组功能需要启用 scim.groups.enabled 并配置权限提供程序。',
  'Inspect each status and response before retrying.': '重试前请检查每项状态和响应。',
  'The server returned 404 or 501 for this SCIM surface.':
      '服务器对此 SCIM 功能返回了 404 或 501。',
  'Group schema and role-backed provisioning are enabled.': '组架构和基于角色的预配已启用。',
  'Not advertised. Enable scim.groups and a permissions provider before sending Group operations.':
      '未声明支持。发送组操作前，请启用 scim.groups 并配置权限提供程序。',
  'Operations are validated in order before execution. Group membership storage is not transactional; reconcile the group if the server reports a partial failure.':
      '操作会在执行前按顺序验证。组成员关系存储不具备事务性；如果服务器报告部分失败，请核对该组。',
  'Operations run in order and are validated before the user is persisted once. Invalid paths abort the patch.':
      '操作按顺序运行，并在一次性持久化用户前完成验证。无效路径会中止补丁。',
  'Replace, patch, and delete send this version with If-Match. A concurrent change is rejected instead of overwritten.':
      '替换、补丁和删除操作会通过 If-Match 发送此版本。并发更改会被拒绝，而不会被覆盖。',
  'This response has no resource version. Writes against this older deployment cannot use optimistic concurrency.':
      '此响应没有资源版本。针对这一旧版部署的写入无法使用乐观并发控制。',
  'Delivery sent and dead-letter cleanup completed.': '投递已发送，死信清理已完成。',
  'Delivery succeeded; cleanup remains pending. Retrying this entry is cleanup-only and cannot redeliver it.':
      '投递成功，但清理仍待完成。重试此项目只会执行清理，不会再次投递。',
  'Durable operation journal': '持久化操作日志',
  'Restore, pin, and rollback steps remain queryable after a client disconnect or server restart.':
      '客户端断开或服务器重启后，仍可查询恢复、固定和回滚步骤。',
  'No recovery or release operations.': '暂无恢复或发布操作。',
  'Operation error': '操作错误',
};
