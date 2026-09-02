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
const _removedIdentityPatterns = <String>{
  '{algorithm} · {status}',
  '{targetUser} · {status}',
  'SCIM {collection}',
  'Webhook #{id}',
  'IP {address}',
  '{status} · {plan} v{version}',
};

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

  test('T-I18N-01d: identity translations do not seed source patterns', () {
    final catalogKeys = appSourceStrings['zh']!.keys.toSet();
    expect(catalogKeys.intersection(_removedIdentityPatterns), isEmpty);

    final zh = AppStrings.forLocale(const Locale('zh'));
    // Use a localized status as the captured value. If an identity pattern
    // were still registered, its recursive capture lookup would translate
    // `active` to `活跃`; an opaque source value must remain unchanged.
    expect(zh.translate('SCIM active'), 'SCIM active');
    expect(zh.translate('Webhook #active'), 'Webhook #active');
    expect(zh.translate('IP active'), 'IP active');
    expect(zh.translate('RS256 · active'), 'RS256 · active');
    expect(zh.translate('alice · active'), 'alice · active');
    expect(zh.translate('active · plan-basic v3'), 'active · plan-basic v3');
  });

  test('T-I18N-01e: EN/ZH preserve real templates and status display', () {
    final en = AppStrings.forLocale(const Locale('en'));
    final zh = AppStrings.forLocale(const Locale('zh'));
    const start = '2026-01-01';
    const end = '2026-02-01';

    expect(
      en.translate('Period: {start} → {end}', {'start': start, 'end': end}),
      'Period: $start → $end',
    );
    expect(
      zh.translate('Period: {start} → {end}', {'start': start, 'end': end}),
      '周期：$start → $end',
    );
    expect(en.translate('active'), 'active');
    expect(zh.translate('active'), '活跃');
    expect(
      '${en.translate('active')} · plan-basic v3',
      'active · plan-basic v3',
    );
    expect('${zh.translate('active')} · plan-basic v3', '活跃 · plan-basic v3');
    expect(
      en.translate('{active} · {plan} v{version} · revision {revision}', {
        'active': en.translate('active'),
        'plan': 'plan-basic',
        'version': 3,
        'revision': 7,
      }),
      'active · plan-basic v3 · revision 7',
    );
    expect(
      zh.translate('{active} · {plan} v{version} · revision {revision}', {
        'active': zh.translate('active'),
        'plan': 'plan-basic',
        'version': 3,
        'revision': 7,
      }),
      '活跃 · plan-basic v3 · 修订版 7',
    );
  });
}
