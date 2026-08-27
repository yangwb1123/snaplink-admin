import 'package:flutter/widgets.dart';
import 'app_strings_additional.dart';
import 'app_strings_source.dart';

part 'app_strings_context.dart';
part 'app_strings_accessors.dart';

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
      'token_security': '令牌安全',
      'webhooks': 'Webhook 管理',
      'emergency_access': '紧急访问',
      'governance': '治理合规',
      'crypto_keys': '密钥管理',
      'credentials': '凭据管理',
      'domains': '域名管理',
      'threat_policies': '威胁策略',
      'access_policies': '访问策略',
      'dr_mode': '灾难恢复模式',
      'organizations': '组织管理',
      'operations': '运维操作',
      'user_support': '用户支持',
      'live_activity': '实时活动',
      'token_exchange': '令牌交换',
      'token_policies': '令牌策略',
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
