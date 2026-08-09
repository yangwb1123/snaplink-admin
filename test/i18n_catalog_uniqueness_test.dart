import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/i18n/app_strings_additional.dart';
import 'package:sso_admin/i18n/app_strings_source.dart';
import 'package:sso_admin/i18n/app_strings_source_admin_core.dart';
import 'package:sso_admin/i18n/app_strings_source_admin_distributed.dart';
import 'package:sso_admin/i18n/app_strings_source_admin_dynamic.dart';
import 'package:sso_admin/i18n/app_strings_source_admin_features.dart';
import 'package:sso_admin/i18n/app_strings_source_admin_indirect.dart';
import 'package:sso_admin/i18n/app_strings_source_admin_navigation.dart';
import 'package:sso_admin/i18n/app_strings_source_admin_residency.dart';
import 'package:sso_admin/i18n/app_strings_source_admin_ux.dart';
import 'package:sso_admin/i18n/app_strings_source_commerce.dart';
import 'package:sso_admin/i18n/app_strings_source_common.dart';
import 'package:sso_admin/i18n/app_strings_source_developer.dart';
import 'package:sso_admin/i18n/app_strings_source_oidc.dart';
import 'package:sso_admin/i18n/app_strings_source_portal.dart';

/// T-I18N-01: the admin-UX catalog must not duplicate any other catalog
/// (map-spread override would silently flip repo-wide renderings, §6.0-B),
/// and the file must be wired into `appSourceStrings` (sampled keys resolve
/// through `AppStrings.forLocale(zh)`).
Set<String> _typedTableKeys() {
  final source = File('lib/i18n/app_strings.dart').readAsStringSync();
  return {
    for (final match in RegExp(r"'([a-zA-Z0-9_]+)':").allMatches(source))
      match.group(1)!,
  };
}

void main() {
  test('T-I18N-01a: no admin-UX key duplicates any other catalog', () {
    final otherKeys = <String>{
      ...appCommonSourceZh.keys,
      ...appPortalSourceZh.keys,
      ...appDeveloperSourceZh.keys,
      ...appOidcSourceZh.keys,
      ...appAdminCoreSourceZh.keys,
      ...appAdminDistributedSourceZh.keys,
      ...appAdminFeatureSourceZh.keys,
      ...appAdminIndirectSourceZh.keys,
      ...appAdminDynamicSourceZh.keys,
      ...appAdminNavigationSourceZh.keys,
      ...appAdminResidencySourceZh.keys,
      ...appCommerceSourceZh.keys,
      ...appAdditionalStrings['en']!.keys,
      ...appAdditionalStrings['zh']!.keys,
      ..._typedTableKeys(),
    };
    final duplicates =
        appAdminUxSourceZh.keys.where(otherKeys.contains).toList()..sort();
    expect(
      duplicates,
      isEmpty,
      reason:
          'spread-order override drift — keys already exist elsewhere: '
          '$duplicates',
    );
  });

  test('T-I18N-01b: the admin-UX catalog is wired into appSourceStrings', () {
    for (final key in appAdminUxSourceZh.keys) {
      expect(
        appSourceStrings['zh']!.containsKey(key),
        isTrue,
        reason: '$key is not reachable through appSourceStrings',
      );
    }
  });

  test('T-I18N-01c: sampled keys resolve through AppStrings (zh)', () {
    final zh = AppStrings.forLocale(const Locale('zh'));
    expect(zh.translate('Live endpoints'), '在线端点');
    expect(zh.translate('Never expires'), '永不过期');
    expect(zh.translate('inactive'), '不活跃');
    expect(zh.translate('On this page'), '本页统计');
    expect(
      zh.translate('Persona: {persona}', {
        'persona': zh.translate('Persona.securityOps'),
      }),
      '角色：安全运维',
    );
  });
}
