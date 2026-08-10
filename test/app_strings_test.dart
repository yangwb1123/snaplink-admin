import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/i18n/app_strings_additional.dart';
import 'package:sso_admin/i18n/app_strings_source.dart';

void main() {
  test('additional English and Chinese catalogs cover identical keys', () {
    expect(
      appAdditionalStrings['zh']!.keys.toSet(),
      appAdditionalStrings['en']!.keys.toSet(),
    );
  });

  test('product-shell strings resolve in both supported languages', () {
    final english = AppStrings.forLocale(const Locale('en'));
    final chinese = AppStrings.forLocale(const Locale('zh'));

    expect(english.developerPortal, 'Developer Portal');
    expect(chinese.developerPortal, '开发者门户');
    expect(english.deviceSecurity, 'Device security');
    expect(chinese.deviceSecurity, '设备安全');
    expect(english.redirectingToSignIn, 'Redirecting to sign in…');
    expect(chinese.redirectingToSignIn, '正在跳转到登录页面…');
    expect(chinese.failedToLoadAdminConsole('timeout'), '无法加载管理控制台: timeout');
    expect(
      chinese.requestedScopes('openid, profile'),
      '申请的权限范围: openid, profile',
    );
  });

  test('unsupported locales fall back to English', () {
    final strings = AppStrings.forLocale(const Locale('fr'));

    expect(strings.signIn, 'Sign in');
    expect(strings.authorizeDevice, 'Authorize a device');
  });

  test('source catalogs preserve every interpolation placeholder', () {
    final placeholder = RegExp(r'\{[a-zA-Z][a-zA-Z0-9_]*\}');
    for (final entry in appSourceStrings['zh']!.entries) {
      expect(entry.value.trim(), isNotEmpty, reason: entry.key);
      expect(
        placeholder
            .allMatches(entry.value)
            .map((match) => match.group(0))
            .toSet(),
        placeholder
            .allMatches(entry.key)
            .map((match) => match.group(0))
            .toSet(),
        reason: entry.key,
      );
    }
  });

  test('source lookup interpolates values and keeps unsupported copy', () {
    final english = AppStrings.forLocale(const Locale('en'));
    final chinese = AppStrings.forLocale(const Locale('zh'));

    expect(
      chinese.translate('Page {page} · {total} total', {
        'page': 2,
        'total': 31,
      }),
      '第 2 页 · 共 31 项',
    );
    expect(english.translate('Page {page}', {'page': 4}), 'Page 4');
    expect(chinese.translate('Page 3 · 12 users'), '第 3 页 · 共 12 个用户');
    expect(chinese.translate('pending · proposed by alice'), '待处理 · 提议者：alice');
    expect(chinese.translate('opaque backend value'), 'opaque backend value');
  });

  test('admin UX polish keys translate in zh', () {
    final chinese = AppStrings.forLocale(const Locale('zh'));

    expect(chinese.translate('Click to copy'), '点击复制');
    expect(
      chinese.translate('{start}–{end} of {total}', {
        'start': 1,
        'end': 25,
        'total': 100,
      }),
      '第 1–25 条，共 100 条',
    );
  });
}
