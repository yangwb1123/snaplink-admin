import 'package:flutter/widgets.dart';
import 'app_strings_additional.dart';
import 'app_strings_source.dart';

part 'app_strings_context.dart';

/// Lightweight EN/ZH string lookup — deliberately NOT flutter's ARB/
/// gen-l10n codegen pipeline (that toolchain needs a build step wired into
/// every dev workflow and CI job). The compact typed catalog covers shared
/// controls and the six product entry shells. Keyed
/// by [BuildContext] so callers read the SAME [AppSettings.locale] the rest
/// of the app already reacts to (see main.dart's ListenableBuilder) — this
/// class has no state of its own, it's a pure lookup.
class AppStrings {
  final Locale locale;
  const AppStrings._(this.locale);

  static AppStrings of(BuildContext context) =>
      AppStrings._(Localizations.localeOf(context));

  static AppStrings forLocale(Locale locale) => AppStrings._(locale);

  String _t(String key) =>
      _table[locale.languageCode]?[key] ??
      appAdditionalStrings[locale.languageCode]?[key] ??
      _table['en']?[key] ??
      appAdditionalStrings['en']![key]!;

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
  String get adminNavMode => _t('admin_nav_mode');
  String get adminNavModeNormal => _t('admin_nav_mode_normal');
  String get adminNavModeProfessional => _t('admin_nav_mode_professional');
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
  String get governanceOperations => _t('governance_operations');
  String get tokenSessionSecurity => _t('token_session_security');
  String get authzChecks => _t('authz_checks');
  String get overview => _t('overview');
  String get localUsers => _t('local_users');
  String get scimDirectory => _t('scim_directory');
  String get deviceSecurity => _t('device_security');
  String get usageInsights => _t('usage_insights');
  String get networkPolicies => _t('network_policies');
  String get changeApprovals => _t('change_approvals');
  String get recoveryReleases => _t('recovery_releases');
  String get privacyRetention => _t('privacy_retention');
  String get auditLog => _t('audit_log');
  String get health => _t('health');
  String get ssoAdmin => _t('sso_admin');
  String failedToLoadAdminConsole(Object error) =>
      '${_t('failed_to_load_admin_console')}: $error';

  // Portal
  String get accountTitle => _t('account_title');
  String get accountSubtitle => _t('account_subtitle');
  String get accessToken => _t('access_token');
  String get continueLabel => _t('continue');
  String get security => _t('security');
  String get devices => _t('devices');
  String get sessions => _t('sessions');
  String get activity => _t('activity');
  String get linkedIdentities => _t('linked_identities');
  String get connectedApps => _t('connected_apps');
  String get privacy => _t('privacy');
  String get signOut => _t('sign_out');
  String get redirectingToSignIn => _t('redirecting_to_sign_in');
  String get enterToken => _t('enter_token');
  String get tokenNotAccepted => _t('token_not_accepted');
  String get accountDeleted => _t('account_deleted');
  String get sessionRevoked => _t('session_revoked');
  String get sessionExpired => _t('session_expired');

  // Developer portal
  String get developerPortal => _t('developer_portal');
  String get registerNewApp => _t('register_new_app');
  String get manageExistingApp => _t('manage_existing_app');
  String get retryDiscovery => _t('retry_discovery');

  // First-run setup
  String get setupUnavailable => _t('setup_unavailable');
  String get setupStatusUnknown => _t('setup_status_unknown');
  String get createAdministrator => _t('create_administrator');
  String get createAdministratorDescription =>
      _t('create_administrator_description');
  String get adminUsername => _t('admin_username');
  String get confirmPassword => _t('confirm_password');
  String get firstApplication => _t('first_application');
  String get optional => _t('optional');
  String get firstApplicationDescription => _t('first_application_description');
  String get applicationName => _t('application_name');
  String get redirectUris => _t('redirect_uris');
  String get oneHttpsUriPerLine => _t('one_https_uri_per_line');
  String get createAndFinish => _t('create_and_finish');
  String get skipAndFinish => _t('skip_and_finish');
  String get networkErrorRetry => _t('network_error_retry');
  String get setup => _t('setup');
  String get checkingSystemStatus => _t('checking_system_status');
  String get alreadySetUp => _t('already_set_up');
  String get alreadyInitialized => _t('already_initialized');
  String get goToAdminConsole => _t('go_to_admin_console');
  String get setupUnavailableTitle => _t('setup_unavailable_title');
  String get setupNotAvailable => _t('setup_not_available');
  String get administratorUsername => _t('administrator_username');
  String get clientId => _t('client_id');
  String get clientSecret => _t('client_secret');
  String get setupComplete => _t('setup_complete');
  String get setupCompleteDescription => _t('setup_complete_description');
  String get setupApplicationMissing => _t('setup_application_missing');
  String get retryApplicationCreation => _t('retry_application_creation');
  String get secretSavedConfirmation => _t('secret_saved_confirmation');
  String get secretEraseWarning => _t('secret_erase_warning');
  String get enterUsername => _t('enter_username');
  String get passwordMinimum => _t('password_minimum');
  String get passwordsMismatch => _t('passwords_mismatch');
  String get appNameOrSkip => _t('app_name_or_skip');
  String stepOf(int current, int total) =>
      '${_t('step')} $current ${_t('of')} $total';
  String shownOnce(String label) => '$label · ${_t('shown_once')}';
  String copyLabel(String label) => '${_t('copy')} $label';
  String copiedLabel(String label) => '$label ${_t('copied')}';

  // Device authorization
  String get authorizeDevice => _t('authorize_device');
  String get deviceCodeInstruction => _t('device_code_instruction');
  String get deviceCode => _t('device_code');
  String get checkCode => _t('check_code');
  String get checking => _t('checking');
  String get approve => _t('approve');
  String get deny => _t('deny');
  String get signInAgain => _t('sign_in_again');
  String get approveDeviceTitle => _t('approve_device_title');
  String get denyDeviceTitle => _t('deny_device_title');
  String get approveDeviceDescription => _t('approve_device_description');
  String get denyDeviceDescription => _t('deny_device_description');
  String get deviceCodeIncomplete => _t('device_code_incomplete');
  String get deviceCodeVerified => _t('device_code_verified');
  String get deviceApprovalContextMissing =>
      _t('device_approval_context_missing');
  String get deviceAlreadyApproved => _t('device_already_approved');
  String get deviceAlreadyDenied => _t('device_already_denied');
  String get deviceCodeExpired => _t('device_code_expired');
  String get deviceCodeNotFound => _t('device_code_not_found');
  String get deviceAuthorizationDisabled => _t('device_authorization_disabled');
  String get deviceCodeCheckFailed => _t('device_code_check_failed');
  String get deviceApproved => _t('device_approved');
  String get deviceDenied => _t('device_denied');
  String get signInExpired => _t('sign_in_expired');
  String get deviceCodeInvalidExpired => _t('device_code_invalid_expired');
  String get requestFailedRetry => _t('request_failed_retry');
  String requestedScopes(String scopes) => '${_t('requested_scopes')}: $scopes';

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
      'governance_operations': 'Governance and Operations',
      'token_session_security': 'Token and Session Security',
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
      'admin_nav_mode': 'Admin navigation mode',
      'admin_nav_mode_normal': 'Standard',
      'admin_nav_mode_professional': 'Professional',
      'sso_base_url': 'SSO base URL',
      'sso_base_url_hint':
          'Only used on native builds — web always uses the page origin.',
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
      'governance_operations': '治理与运维',
      'token_session_security': 'Token 与会话安全',
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
      'admin_nav_mode': '管理导航模式',
      'admin_nav_mode_normal': '标准',
      'admin_nav_mode_professional': '专业',
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

  static final _sourceTranslations = <String, Map<String, String>>{
    'zh': <String, String>{
      for (final entry in _table['en']!.entries)
        _table['en']![entry.key]!: _table['zh']![entry.key]!,
      for (final entry in appAdditionalStrings['en']!.entries)
        appAdditionalStrings['en']![entry.key]!:
            appAdditionalStrings['zh']![entry.key]!,
      ...appSourceStrings['zh']!,
    },
  };
}
