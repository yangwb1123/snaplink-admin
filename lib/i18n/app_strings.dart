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

  static const _table = <String, Map<String, String>>{
    'en': {
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
