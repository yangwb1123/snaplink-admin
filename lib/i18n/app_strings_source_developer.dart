/// Dynamic Client Registration developer portal copy.
const appDeveloperSourceZh = <String, String>{
  'Additional metadata (JSON object)': '其他元数据（JSON 对象）',
  'Advertised: {values}': '服务器声明支持：{values}',
  'Allowed authenticators (one per line)': '允许的身份验证方式（每行一个）',
  'Allowed resources (one per line)': '允许的资源（每行一个）',
  'App deleted.': '应用已删除。',
  'App Name': '应用名称',
  'App name is required.': '必须填写应用名称。',
  'Application': '应用',
  'Application policy': '应用策略',
  'Client ID and registration access token are both required.':
      '客户端 ID 和注册访问令牌均为必填项。',
  'Client ID confirmation': '确认客户端 ID',
  'Client Secret': '客户端密钥',
  'Client credential type is locked because RFC 7592 PUT does not rotate or remove the stored client secret.':
      '客户端凭据类型已锁定，因为 RFC 7592 PUT 不会轮换或移除已存储的客户端密钥。',
  'Confidential — HTTP Basic': '机密客户端 — HTTP Basic',
  'Confidential — secret in POST body': '机密客户端 — 在 POST 请求体中发送密钥',
  'Contacts (one per line)': '联系人（每行一个）',
  'Continue and Erase Display': '继续并清除显示内容',
  'Continuing erases the one-time credential display.': '继续后将清除一次性凭据显示内容。',
  'Copy {label}': '复制{label}',
  '{label} actions': '{label}操作',
  '{label} copied.': '{label}已复制。',
  'Delete App': '删除应用',
  'Delete app permanently?': '永久删除应用？',
  'Delete was not confirmed (HTTP {status}). Retry; the credentials remain loaded.':
      '删除结果未确认（HTTP {status}）。请重试；凭据仍保持加载状态。',
  'Delete was not confirmed because Snaplink could not be reached. Retry; the credentials were not classified as invalid.':
      '由于无法连接 Snaplink，删除结果未确认。请重试；这些凭据未被判定为无效。',
  'Deleting…': '正在删除…',
  'Done and Erase': '完成并清除',
  'Dynamic client registration is not advertised by Snaplink.':
      'Snaplink 未声明支持动态客户端注册。',
  'Enter the client ID and registration access token issued at registration to load the app for management.':
      '请输入注册时签发的客户端 ID 和注册访问令牌，以加载应用进行管理。',
  'Every typed field round-trips through the RFC 7592 PUT.':
      '所有类型化字段均可通过 RFC 7592 PUT 无损往返。',
  'Examples: password, webauthn, totp.': '示例：password、webauthn、totp。',
  'Expert JSON': '高级 JSON',
  'Expert JSON cannot override typed or credential fields: {fields}.':
      '高级 JSON 不能覆盖类型化字段或凭据字段：{fields}。',
  'Expert metadata must be a JSON object.': '高级元数据必须是 JSON 对象。',
  'GET omitted grant_types. A PUT would replace the stored grants, so saving is disabled.':
      'GET 响应省略了 grant_types；PUT 会替换已存储的授权类型，因此已禁用保存。',
  'Grant type is not advertised by Snaplink: {grant}':
      'Snaplink 未声明支持此授权类型：{grant}',
  'Grant types': '授权类型',
  'Hide': '隐藏',
  'I have securely saved every credential I need.': '我已安全保存所有需要的凭据。',
  'I have securely saved the new token.': '我已安全保存新令牌。',
  'Initial Access Token': '初始访问令牌',
  'Invalid client ID or registration access token.': '客户端 ID 或注册访问令牌无效。',
  'Invalid redirect URI: {uri}': '无效的重定向 URI：{uri}',
  'Issued credentials are displayed only until you confirm they have been saved.':
      '签发的凭据只会显示到您确认已保存为止。',
  'Leave blank only when open registration is enabled': '仅在启用开放注册时留空',
  'Load a registered client with the registration access token issued during registration, then read, update, or delete it through RFC 7592.':
      '使用注册时签发的注册访问令牌加载已注册客户端，再通过 RFC 7592 读取、更新或删除它。',
  'Load App': '加载应用',
  'Loading app…': '正在加载应用…',
  'Manage App': '管理应用',
  'Manage This App': '管理此应用',
  'Manage an existing OAuth 2.0 / OIDC client': '管理现有 OAuth 2.0 / OIDC 客户端',
  'New Registration Access Token': '新的注册访问令牌',
  'No app loaded': '尚未加载应用',
  'No credentials were issued.': '未签发任何凭据。',
  'Not returned.': '服务器未返回。',
  'OAuth protocol': 'OAuth 协议',
  'OAuth resource indicators accepted for this client.': '此客户端接受的 OAuth 资源指示符。',
  'One-time credential': '一次性凭据',
  'One-time credentials for {clientId} were erased from the registration result.':
      '{clientId} 的一次性凭据已从注册结果中清除。',
  'Open registration deliberately ignores this value.': '开放注册会有意忽略此值。',
  'OpenID Provider discovery is temporarily unavailable.':
      'OpenID Provider 发现服务暂时不可用。',
  'Post-logout redirect URIs (one per line)': '退出后的重定向 URI（每行一个）',
  'Public clients cannot use the client_credentials grant.':
      '公共客户端不能使用 client_credentials 授权类型。',
  'Public clients require PKCE with S256.': '公共客户端必须使用 S256 PKCE。',
  'Public — no secret, PKCE S256 required': '公共客户端 — 无密钥，必须使用 S256 PKCE',
  'Read-only: contacts are not persisted by RFC 7592 PUT.':
      '只读：RFC 7592 PUT 不会持久化联系人。',
  'Read-only: the current management handler does not persist response_types.':
      '只读：当前管理处理程序不会持久化 response_types。',
  'Redirect URIs (one per line)': '重定向 URI（每行一个）',
  'Register App': '注册应用',
  'Register an OAuth 2.0 / OIDC client': '注册 OAuth 2.0 / OIDC 客户端',
  'Register an OAuth 2.0 / OIDC client using Snaplink Dynamic Client Registration. Public clients are forced to PKCE S256. Issued credentials are displayed only until you confirm they have been saved.':
      '使用 Snaplink 动态客户端注册来创建 OAuth 2.0 / OIDC 客户端。公共客户端强制使用 S256 PKCE；签发的凭据只显示到您确认已保存为止。',
  'Registration Access Token': '注册访问令牌',
  'Registration Client URI': '注册客户端 URI',
  'Registration is disabled for this deployment.': '此部署已禁用注册。',
  'Registration token rotated': '注册令牌已轮换',
  'Request failed with status {status}': '请求失败，状态码 {status}',
  'Require PKCE': '要求 PKCE',
  'Required for authorization_code. Fragments are not allowed.':
      'authorization_code 必须填写；不允许 URI 片段。',
  'Required for public clients; Snaplink stores S256 only.':
      '公共客户端必须启用；Snaplink 仅存储 S256。',
  'Response type is not advertised by Snaplink: {response}':
      'Snaplink 未声明支持此响应类型：{response}',
  'Response types': '响应类型',
  'Response types are only valid when authorization_code is selected.':
      '仅在选择 authorization_code 时响应类型才有效。',
  'Retry Load': '重试加载',
  'Lossless RFC 7592 representation': '无损 RFC 7592 表示',
  'SAVE THESE CREDENTIALS NOW': '请立即保存这些凭据',
  'Save Changes': '保存更改',
  'Save or erase issued credentials first': '请先保存或清除已签发的凭据',
  'Save this replacement before closing the dialog.': '请在关闭对话框前保存替代令牌。',
  'Save was not confirmed (HTTP {status}). Retry without reloading credentials.':
      '保存结果未确认（HTTP {status}）。请勿重新加载凭据，直接重试。',
  'Save was not confirmed because Snaplink could not be reached. Retry; the credentials were not classified as invalid.':
      '由于无法连接 Snaplink，保存结果未确认。请重试；这些凭据未被判定为无效。',
  'Saved.': '已保存。',
  'Saving disabled: incomplete RFC 7592 representation': '已禁用保存：RFC 7592 表示不完整',
  'Scopes (space-separated)': '权限范围（空格分隔）',
  'Select at least one grant type.': '请至少选择一种授权类型。',
  'Self-signed mTLS': '自签名 mTLS',
  'Show': '显示',
  'Snaplink discovery does not advertise a registration_endpoint. Registration is disabled for this deployment.':
      'Snaplink 发现信息未声明 registration_endpoint；此部署已禁用注册。',
  'Snaplink discovery does not advertise PKCE S256.':
      'Snaplink 发现信息未声明支持 S256 PKCE。',
  'Snaplink is temporarily unavailable (HTTP {status}). Your credentials were not classified as invalid; retry.':
      'Snaplink 暂时不可用（HTTP {status}）。这些凭据未被判定为无效，请重试。',
  'Snaplink preserves the stored tenant and ignores tenant_id on PUT.':
      'Snaplink 会保留已存储的租户，并在 PUT 时忽略 tenant_id。',
  'Snaplink rejected the delete request: {error}': 'Snaplink 拒绝了删除请求：{error}',
  'Snaplink rejected the management request: {error}':
      'Snaplink 拒绝了管理请求：{error}',
  'Tenant (immutable / not returned)': '租户（不可变 / 不返回）',
  'Tenant ID (operator-gated registration only)': '租户 ID（仅限运维人员控制的注册）',
  'The client secret and registration access token will not be shown again. Copy each required value before continuing.':
      '客户端密钥和注册访问令牌不会再次显示。继续前请复制所有需要的值。',
  'The current Snaplink DCR handler cannot register a consistent implicit/hybrid grant; use the code response type.':
      '当前 Snaplink DCR 处理程序无法注册一致的隐式/混合授权；请使用 code 响应类型。',
  'The initial access token is sent once and cleared from this form as soon as registration starts.':
      '初始访问令牌只发送一次，并会在注册开始后立即从表单中清除。',
  'The registration response was incomplete: the client ID is missing, so the issued credentials cannot be managed or erased here.':
      '注册响应不完整：缺少客户端 ID，因此无法在此管理或清除已签发的凭据。',
  'Save this replacement token now. The previous token remains valid only during the server-defined overlap window.':
      '请立即保存替代令牌。旧令牌仅在服务器定义的重叠窗口内保持有效。',
  'The selected token endpoint authentication method is not accepted by Snaplink DCR.':
      'Snaplink DCR 不接受所选的令牌端点身份验证方式。',
  'This removes the OAuth client and cannot be undone. Type the exact client ID to confirm:':
      '这将删除 OAuth 客户端且无法撤销。请输入完整客户端 ID 以确认：',
  'Token endpoint authentication': '令牌端点身份验证',
  'Token endpoint authentication method is not advertised by Snaplink: {method}':
      'Snaplink 未声明支持此令牌端点身份验证方式：{method}',
  'Token strategy': '令牌策略',
  'Token strategy must be jwt or session.': '令牌策略必须是 jwt 或 session。',
  'Type the exact client ID to enable deletion.': '输入完整的客户端 ID 以启用删除。',
  'Typed and credential fields are rejected here. Unknown keys may be ignored by Snaplink; the response is authoritative.':
      '此处不允许类型化字段和凭据字段。Snaplink 可能忽略未知键；应以响应为准。',
  'Unable to reach Snaplink. Check the connection and retry.':
      '无法连接 Snaplink，请检查连接后重试。',
  'Unable to reach Snaplink. Your credentials were not classified as invalid; check the connection and retry.':
      '无法连接 Snaplink。这些凭据未被判定为无效；请检查连接后重试。',
  'When enabled, Snaplink stores S256 as the allowed method.':
      '启用后，Snaplink 会将 S256 存储为允许的方法。',
  'authorization_code requires at least one redirect URI.':
      'authorization_code 至少需要一个重定向 URI。',
  'authorization_code must include the code response type.':
      'authorization_code 必须包含 code 响应类型。',
  'contacts are not returned or persisted by the current management handler.':
      '当前管理处理程序不会返回或持久化 contacts。',
  'contacts are shown from the registration snapshot, but the current management handler does not return or persist them.':
      'contacts 来自注册快照，但当前管理处理程序不会返回或持久化它们。',
  'mTLS client authentication': 'mTLS 客户端身份验证',
  'response_types are not returned or persisted by the current management handler.':
      '当前管理处理程序不会返回或持久化 response_types。',
  'response_types are shown from the registration snapshot, but the current management handler does not return or persist them.':
      'response_types 来自注册快照，但当前管理处理程序不会返回或持久化它们。',
  'tenant_id is omitted from management responses and remains immutable on the server.':
      '管理响应省略 tenant_id，且服务器端仍保持不可变。',
  'tenant_id is shown from the registration snapshot; management responses omit it and the server keeps it immutable.':
      'tenant_id 来自注册快照；管理响应会省略它，服务器仍保持不可变。',
  'Serving region: {region}': '服务区域：{region}',
  'Advertised by OpenID Discovery as deployment provenance, not the user location.':
      '由 OpenID Discovery 声明为部署来源信息，并非用户所在位置。',
};
