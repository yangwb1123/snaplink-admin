/// Hosted login, account recovery, MFA, and consent copy.
const appOidcSourceZh = <String, String>{
    'snaplink console': 'snaplink 控制台',
  'Identity & Access Management': '身份与访问管理',
  'Enterprise-grade identity & access management': '企业级身份与访问管理',
'Show password': '显示密码',
  'Hide password': '隐藏密码',

  'Account created. You can now sign in.': '账户已创建，现在可以登录。',
  'Allow': '允许',
  'An account could not be created with those details.': '无法使用这些信息创建账户。',
  'Approve the notification on your device, then continue.': '请在设备上批准通知，然后继续。',
  'Authentication failed.': '身份验证失败。',
  'Authorization detail {number}': '授权详情 {number}',
  'Authorization has been disabled.': '授权已禁用。',
  '{message} Authorization has been disabled.': '{message} 授权已禁用。',
  'Authorization is disabled because the request summary is invalid.':
      '请求摘要无效，因此授权已禁用。',
  'Back to sign in': '返回登录',
  'Check the required account details and try again.': '请检查必填账户信息后重试。',
  'Check your email': '请检查邮箱',
  'Datatypes': '数据类型',
  'Choose a new password for your account.': '请为账户设置新密码。',
  'Choose a passkey to sign in without a password.': '选择通行密钥以免密登录。',
  'Confirm below to finish creating your account.': '请在下方确认以完成账户创建。',
  'Confirm new password': '确认新密码',
  'Continue to {provider} to sign in.': '继续前往 {provider} 登录。',
  'Federated sign-in could not start because secure tab storage is unavailable.':
      '由于安全的标签页存储不可用，无法开始联合登录。',
  'Federated PAR or JAR sign-in requires a Snaplink deployment that preserves the server-owned authorization request.':
      '联合 PAR 或 JAR 登录需要 Snaplink 部署完整保留服务器拥有的授权请求。',
  'Federated RP sign-in requires a Snaplink deployment that preserves the server-owned authorization request and securely resumes it after the identity-provider callback.':
      '联合 RP 登录要求 Snaplink 完整保留服务器拥有的授权请求，并在身份提供方回调后安全续接。',
  'Federated sign-in requires the web console.': '联合登录需要使用 Web 控制台。',
  'Create a Snaplink account. Some organizations require email verification before the account becomes active.':
      '创建 Snaplink 账户。部分组织要求验证邮箱后账户才能激活。',
  'Deny': '拒绝',
  'Email verified': '邮箱已验证',
  'Email verified.': '邮箱已验证。',
  'Enter a new password.': '请输入新密码。',
  'Enter a username and password.': '请输入用户名和密码。',
  'Enter an email address or phone number.': '请输入邮箱地址或电话号码。',
  'Enter your username and verification code.': '请输入用户名和验证码。',
  'Enter your username or email.': '请输入用户名或邮箱。',
  'Enter your username or email. If the account is eligible, Snaplink will send recovery instructions.':
      '请输入用户名或邮箱。如果账户符合条件，Snaplink 将发送恢复说明。',
  'Enter your work email.': '请输入工作邮箱。',
  'Exact request': '原始请求',
  'Fine-grained authorization': '细粒度授权',
  'If an eligible account exists, recovery instructions have been sent.':
      '如果存在符合条件的账户，恢复说明已经发送。',
  'Instructions sent.': '说明已发送。',
  'Identifier': '标识符',
  'Invalid WebAuthn options.': 'WebAuthn 选项无效。',
  'Invalid passkey algorithm.': '通行密钥算法无效。',
  'Invalid passkey options.': '通行密钥选项无效。',
  'No authorization error was redirected.': '未重定向任何授权错误。',
  'No client is configured for this sign-in.': '此登录未配置客户端。',
  'No organization sign-in route was found.': '未找到组织登录路由。',
  'No passkey assertion was returned.': '未返回通行密钥断言。',
  'No sign-in methods are available for this application.': '此应用没有可用的登录方式。',
  'Locations': '位置',
  'Organization sign-in is not enabled.': '组织登录功能未启用。',
  'Organization logo': '组织徽标',
  'Passkey algorithms are missing.': '缺少通行密钥算法。',
  'Passkey data is missing.': '缺少通行密钥数据。',
  'Passkey sign-in unavailable.': '通行密钥登录不可用。',
  'Passkey verification is unavailable.': '通行密钥验证不可用。',
  'Password recovery is not available for this deployment.': '此部署未启用密码恢复。',
  'Password updated': '密码已更新',
  'Phone number': '电话号码',
  'Push verification is unavailable.': '推送验证不可用。',
  'Recovery code': '恢复代码',
  'Recovery instructions could not be requested. Try again.': '无法请求恢复说明，请重试。',
  'Registration could not be approved.': '无法批准注册。',
  'Request or enter a verification code.': '请请求或输入验证码。',
  'Resend code': '重新发送验证码',
  'Resend link': '重新发送链接',
  'Review every permission before you continue.': '继续前请逐项检查权限。',
  'Scope: {scope}': '权限范围：{scope}',
  'Select a verification method.': '请选择验证方式。',
  'Send code': '发送验证码',
  'Send link': '发送链接',
  'Sign in with passkey': '使用通行密钥登录',
  'Sign in with {provider}': '使用 {provider} 登录',
  'Sign-in failed: {error}': '登录失败：{error}',
  'Sign-in succeeded, but this browser cannot securely store the session. Enable site storage and try again.':
      '登录成功，但此浏览器无法安全保存会话。请启用网站存储后重试。',
  'Skip future MFA when allowed.': '策略允许时跳过后续 MFA。',
  'Snaplink could not deliver the signed JARM response.':
      'Snaplink 无法传送已签名的 JARM 响应。',
  'Snaplink did not confirm the redirect URI for this error. No authorization error was redirected.':
      'Snaplink 未确认此错误的重定向 URI，因此未重定向授权错误。',
  'Snaplink did not provide a secure authorization transaction. The request was not approved or denied.':
      'Snaplink 未提供安全的授权事务，因此请求未被批准或拒绝。',
  'Snaplink did not provide a server-validated authorization continuation. No code, token, or error was redirected.':
      'Snaplink 未提供经服务器验证的授权续接地址；未重定向任何授权码、令牌或错误。',
  'Snaplink did not return a server-signed JARM response or a validated continuation. No unsigned code or token was redirected.':
      'Snaplink 未返回服务器签名的 JARM 响应或经验证的后续地址；未重定向未签名的代码或令牌。',
  'Snaplink returned an incomplete verification challenge. Sign in again to request a new challenge.':
      'Snaplink 返回的验证挑战不完整。请重新登录以请求新的挑战。',
  'Snaplink did not return an access token. Sign in again to retry.':
      'Snaplink 未返回访问令牌。请重新登录后重试。',
  'Stay signed in': '保持登录',
  'The account could not be created. Try again.': '无法创建账户，请重试。',
  'The authorization request contains no permissions to review.':
      '授权请求中没有可供检查的权限。',
  'The authorization request could not be summarized safely.': '无法安全地汇总授权请求。',
  'The authorization decision was submitted. Restart authorization if no result is received.':
      '授权决定已提交。如未收到结果，请重新开始授权。',
  'The authorization result is unknown. Restart authorization; this decision was not replayed.':
      '授权结果未知。请重新开始授权；本次决定未被重放。',
  'The federated sign-in return timed out after its one-time PKCE state was consumed. Start sign-in again.':
      '联合登录返回超时，且一次性 PKCE 状态已使用。请重新开始登录。',
  'The federated authorization result is unknown. Restart sign-in; the one-time continuation was not replayed.':
      '联合授权结果未知。请重新开始登录；一次性续接事务未被重放。',
  'The new password does not meet the password policy. Request a new reset link before trying again.':
      '新密码不符合密码策略。请申请新的重置链接后再试。',
  'The passkey response was invalid.': '通行密钥响应无效。',
  'Passkey authentication requires WebAuthn in a browser.':
      '通行密钥认证需要在支持 WebAuthn 的浏览器中进行。',
  'The password does not meet the password policy.': '密码不符合密码策略。',
  'The passwords do not match.': '两次输入的密码不一致。',
  'The server did not provide a consent challenge.': '服务器未提供授权同意挑战。',
  'The server did not provide a secure authorization transaction.':
      '服务器未提供安全的授权事务。',
  'The form_post response mode requires the web console.':
      'form_post 响应模式需要使用 Web 控制台。',
  'Snaplink returned an authorization form without a relying-party request. Sign in again.':
      'Snaplink 返回了没有依赖方请求的授权表单。请重新登录。',
  'The server form response requires the web console.': '服务器表单响应需要使用 Web 控制台。',
  'The verification attempt expired. Sign in again to get a new challenge.':
      '本次验证尝试已过期，请重新登录以获取新挑战。',
  'This application': '此应用',
  '{application} wants access': '{application} 请求访问',
  'This reset link is invalid or expired. Request a new link.':
      '此重置链接无效或已过期，请申请新链接。',
  'This reset link is missing its token.': '此重置链接缺少令牌。',
  'This reset link is missing its token. Request a new link.':
      '此重置链接缺少令牌，请申请新链接。',
  'This verification challenge can no longer be used. Sign in again to get a new challenge.':
      '此验证挑战已无法使用，请重新登录以获取新挑战。',
  'This verification link is invalid or expired. Request a new link.':
      '此验证链接无效或已过期，请申请新链接。',
  'This verification link is missing its token.': '此验证链接缺少令牌。',
  'This verification link is missing its token. Request a new link.':
      '此验证链接缺少令牌，请申请新链接。',
  'Too many registration attempts. Please wait and try again.':
      '注册尝试次数过多，请稍后重试。',
  'Too many requests. Please wait and try again.': '请求过多，请稍后重试。',
  'Trust this device': '信任此设备',
  'Unable to send instructions.': '无法发送说明。',
  'Unsupported JARM response mode.': '不支持的 JARM 响应模式。',
  'Use a registered passkey to verify this sign-in.': '使用已注册的通行密钥验证此次登录。',
  'Use organization sign-in': '使用组织登录',
  'Use passkey': '使用通行密钥',
  'Verification could not be completed safely. Sign in again to get a new challenge.':
      '无法安全完成验证，请重新登录以获取新挑战。',
  'Verification failed.': '验证失败。',
  'Verify email': '验证邮箱',
  'Verify your email': '验证您的邮箱',
  'View your email address': '查看您的邮箱地址',
  'View your profile': '查看您的个人资料',
  'WebAuthn challenge is missing.': '缺少 WebAuthn 挑战。',
  'Your account is ready. You can now sign in.': '账户已就绪，现在可以登录。',
  'Your password has been changed and existing sessions have been revoked where supported.':
      '密码已更改，并在受支持的情况下撤销了现有会话。',
  'Your registration is pending. Use the verification link sent to your email address to finish creating the account.':
      '注册正在等待验证。请使用发送到邮箱的验证链接完成账户创建。',
  'Token': '令牌',
};
