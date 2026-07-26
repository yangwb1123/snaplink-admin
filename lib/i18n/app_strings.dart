import 'package:flutter/widgets.dart';

/// Lightweight EN/ZH string lookup — deliberately NOT flutter's ARB/
/// gen-l10n codegen pipeline (that toolchain needs a build step wired into
/// every dev workflow and CI job for what is, right now, one screen's worth
/// of strings; revisit if/when coverage grows across the whole app). Keyed
/// by [BuildContext] so callers read the SAME [AppSettings.locale] the rest
/// of the app already reacts to (see main.dart's ListenableBuilder) — this
/// class has no state of its own, it's a pure lookup.
class AppStrings {
  final Locale locale;
  const AppStrings._(this.locale);

  static AppStrings of(BuildContext context) => AppStrings._(Localizations.localeOf(context));

  String _t(String key) => _table[locale.languageCode]?[key] ?? _table['en']![key]!;

  // Login screen
  String get signIn => _t('sign_in');
  String get username => _t('username');
  String get password => _t('password');
  String get forgotPassword => _t('forgot_password');
  String get signUp => _t('sign_up');
  String get orDivider => _t('or_divider');
  String get signInWith => _t('sign_in_with');
  String get provider => _t('provider');
  String get signedIn => _t('signed_in');
  String get networkError => _t('network_error');
  String get resetPassword => _t('reset_password');
  String get usernameOrEmail => _t('username_or_email');
  String get sendResetLink => _t('send_reset_link');
  String get back => _t('back');
  String get createAccount => _t('create_account');
  String get emailOptional => _t('email_optional');
  String get verifyIdentity => _t('verify_identity');
  String get verificationCode => _t('verification_code');
  String get verify => _t('verify');
  String get mfaMethodTotp => _t('mfa_method_totp');
  String get mfaMethodOtp => _t('mfa_method_otp');
  String get mfaMethodWebauthn => _t('mfa_method_webauthn');
  String get mfaMethodPush => _t('mfa_method_push');
  String get mfaMethodSms => _t('mfa_method_sms');

  // Settings screen
  String get settings => _t('settings');
  String get language => _t('language');
  String get theme => _t('theme');
  String get themeSystem => _t('theme_system');
  String get themeLight => _t('theme_light');
  String get themeDark => _t('theme_dark');
  String get ssoBaseUrl => _t('sso_base_url');
  String get ssoBaseUrlHint => _t('sso_base_url_hint');
  String get save => _t('save');
  String get saved => _t('saved');
  String get timezone => _t('timezone');

  // Dashboard
  String get clients => _t('clients');
  String get users => _t('users');
  String get tenants => _t('tenants');
  String get logout => _t('logout');

  // Admin - Common
  String get search => _t('search');
  String get filter => _t('filter');
  String get refresh => _t('refresh');
  String get create => _t('create');
  String get edit => _t('edit');
  String get delete => _t('delete');
  String get cancel => _t('cancel');
  String get confirm => _t('confirm');
  String get retry => _t('retry');
  String get loading => _t('loading');
  String get noData => _t('no_data');
  String get errorOccurred => _t('error_occurred');

  // Admin - Modules
  String get permissions => _t('permissions');
  String get connections => _t('connections');
  String get tokenSecurity => _t('token_security');
  String get webhooks => _t('webhooks');
  String get emergencyAccess => _t('emergency_access');
  String get governance => _t('governance');
  String get cryptoKeys => _t('crypto_keys');
  String get credentials => _t('credentials');
  String get domains => _t('domains');
  String get threatPolicies => _t('threat_policies');
  String get accessPolicies => _t('access_policies');
  String get drMode => _t('dr_mode');
  String get organizations => _t('organizations');
  String get operations => _t('operations');
  String get userSupport => _t('user_support');
  String get liveActivity => _t('live_activity');
  String get adminOperations => _t('admin_operations');
  String get platformOverview => _t('platform_overview');
  String get identityConnections => _t('identity_connections');
  String get tenantOrganizations => _t('tenant_organizations');
  String get tokenExchange => _t('token_exchange');
  String get tokenPolicies => _t('token_policies');
  String get authzChecks => _t('authz_checks');

  static const _table = <String, Map<String, String>>{
    'en': {
      'search': 'Search',
      'filter': 'Filter',
      'refresh': 'Refresh',
      'create': 'Create',
      'edit': 'Edit',
      'delete': 'Delete',
      'cancel': 'Cancel',
      'confirm': 'Confirm',
      'retry': 'Retry',
      'loading': 'Loading...',
      'no_data': 'No data',
      'error_occurred': 'An error occurred',
      'permissions': 'Permissions',
      'connections': 'Connections',
      'token_security': 'Token Security',
      'webhooks': 'Webhooks',
      'emergency_access': 'Emergency Access',
      'governance': 'Governance',
      'crypto_keys': 'Crypto Keys',
      'credentials': 'Credentials',
      'domains': 'Domains',
      'threat_policies': 'Threat Policies',
      'access_policies': 'Access Policies',
      'dr_mode': 'DR Mode',
      'organizations': 'Organizations',
      'operations': 'Operations',
      'user_support': 'User Support',
      'live_activity': 'Live Activity',
      'token_exchange': 'Token Exchange',
      'token_policies': 'Token Policies',
      'admin_operations': 'Advanced Operations',
      'platform_overview': 'Platform Overview',
      'identity_connections': 'Identity Connections',
      'tenant_organizations': 'Tenant Organizations',
      'authz_checks': 'AuthZ Checks',
      'sign_in': 'Sign in',
      'username': 'Username',
      'password': 'Password',
      'forgot_password': 'Forgot password?',
      'sign_up': 'Sign up',
      'or_divider': 'or',
      'sign_in_with': 'Sign in with',
      'provider': 'Provider',
      'signed_in': 'Signed in.',
      'network_error': 'Network error. Please try again.',
      'reset_password': 'Reset your password',
      'username_or_email': 'Username or email',
      'send_reset_link': 'Send reset link',
      'back': 'Back',
      'create_account': 'Create an account',
      'email_optional': 'Email (optional)',
      'verify_identity': 'Verify your identity',
      'verification_code': 'Verification code',
      'verify': 'Verify',
      'mfa_method_totp': 'Authenticator app (TOTP)',
      'mfa_method_otp': 'One-time code',
      'mfa_method_webauthn': 'Security key / passkey',
      'mfa_method_push': 'Push notification',
      'mfa_method_sms': 'SMS code',
      'settings': 'Settings',
      'language': 'Language',
      'theme': 'Theme',
      'theme_system': 'System',
      'theme_light': 'Light',
      'theme_dark': 'Dark',
      'sso_base_url': 'SSO base URL',
      'sso_base_url_hint': 'Only used on native builds — web always uses the page origin.',
      'save': 'Save',
      'saved': 'Saved',
      'timezone': 'Timezone',
      'clients': 'Clients',
      'users': 'Users',
      'tenants': 'Tenants',
      'logout': 'Log out',
    },
    'zh': {
      'search': '搜索',
      'filter': '筛选',
      'refresh': '刷新',
      'create': '创建',
      'edit': '编辑',
      'delete': '删除',
      'cancel': '取消',
      'confirm': '确认',
      'retry': '重试',
      'loading': '加载中...',
      'no_data': '暂无数据',
      'error_occurred': '发生错误',
      'permissions': '权限管理',
      'connections': '连接管理',
      'token_security': 'Token 安全',
      'webhooks': 'Webhook 管理',
      'emergency_access': '紧急访问',
      'governance': '治理合规',
      'crypto_keys': '密钥管理',
      'credentials': '凭据管理',
      'domains': '域名管理',
      'threat_policies': '威胁策略',
      'access_policies': '访问策略',
      'dr_mode': 'DR 模式',
      'organizations': '组织管理',
      'operations': '运维操作',
      'user_support': '用户支持',
      'live_activity': '实时活动',
      'token_exchange': 'Token 交换',
      'token_policies': 'Token 策略',
      'admin_operations': '高级操作',
      'platform_overview': '平台概览',
      'identity_connections': '身份连接',
      'tenant_organizations': '租户组织',
      'authz_checks': '授权检查',
      'sign_in': '登录',
      'username': '用户名',
      'password': '密码',
      'forgot_password': '忘记密码？',
      'sign_up': '注册',
      'or_divider': '或',
      'sign_in_with': '使用以下方式登录',
      'provider': '登录方式',
      'signed_in': '已登录。',
      'network_error': '网络错误，请重试。',
      'reset_password': '重置密码',
      'username_or_email': '用户名或邮箱',
      'send_reset_link': '发送重置链接',
      'back': '返回',
      'create_account': '创建账号',
      'email_optional': '邮箱（可选）',
      'verify_identity': '验证身份',
      'verification_code': '验证码',
      'verify': '验证',
      'mfa_method_totp': '身份验证器应用（TOTP）',
      'mfa_method_otp': '一次性验证码',
      'mfa_method_webauthn': '安全密钥 / 通行密钥',
      'mfa_method_push': '推送通知',
      'mfa_method_sms': '短信验证码',
      'settings': '设置',
      'language': '语言',
      'theme': '主题',
      'theme_system': '跟随系统',
      'theme_light': '浅色',
      'theme_dark': '深色',
      'sso_base_url': 'SSO 服务地址',
      'sso_base_url_hint': '仅原生客户端需要——网页版始终使用当前页面的源。',
      'save': '保存',
      'saved': '已保存',
      'timezone': '时区',
      'clients': '客户端',
      'users': '用户',
      'tenants': '租户',
      'logout': '登出',
    },
  };
}
