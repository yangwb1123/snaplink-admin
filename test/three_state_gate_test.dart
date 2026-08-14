@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// 三态门禁（质量门禁固化）：抽查 6 个产品入口的数据区域页面文件，
/// 静态确认每页包含 loading / empty / error 三态模式：
/// - loading：SkeletonListTile / (Linear|Circular)ProgressIndicator /
///   AsyncView / *_loading / isLoading / *_busy / ConnectionState.waiting；
/// - empty：EmptyState / EmptyHint / isEmpty；
/// - error：*Error / hasError / retry / catch( / MessageBanner /
///   requestFailed。
///
/// 宽松语义：单页缺失某模式仅告警输出（print），不失败；硬性部分是
/// 清单完整性——抽查页面文件必须存在且确实包含数据加载机制，防止
/// 页面被删除或改造成无状态壳后门禁失去意义。当前基线 0 告警，
/// 告警清单会同步到 docs/ui/pages-per-page/quality-gates.md。
void main() {
  test('sampled data pages exist and carry data-loading machinery', () {
    final missing = <String>[];
    final notData = <String>[];
    for (final page in _dataPages) {
      if (!File(page).existsSync()) {
        missing.add(page);
        continue;
      }
      final source = File(page).readAsStringSync();
      if (!_dataMachinery.hasMatch(source)) {
        notData.add(page);
      }
    }
    expect(
      missing,
      isEmpty,
      reason: '抽查页面文件缺失（清单需同步更新）：\n${missing.join('\n')}',
    );
    expect(
      notData,
      isEmpty,
      reason: '抽查页面不再含数据加载机制（不再是数据页，应从清单移除或补回）：\n'
          '${notData.join('\n')}',
    );
  });

  test('sampled data pages reference loading/empty/error patterns (lenient)', () {
    final warnings = <String>[];
    for (final page in _dataPages) {
      if (!File(page).existsSync()) continue;
      final source = File(page).readAsStringSync();
      final missing = <String>[
        if (!_loadingPattern.hasMatch(source)) 'loading',
        if (!_emptyPattern.hasMatch(source)) 'empty',
        if (!_errorPattern.hasMatch(source)) 'error',
      ];
      if (missing.isNotEmpty) {
        warnings.add('$page: 缺少 ${missing.join('/')} 模式');
      }
    }
    // 宽松门禁：缺失仅告警，不失败；告警计入质量门禁报告。
    // ignore: avoid_print
    print('three-state warnings (${warnings.length}):');
    for (final warning in warnings) {
      // ignore: avoid_print
      print('  $warning');
    }
  });
}

// ---------------------------------------------------------------------
// 抽查清单与模式（与 docs/ui/pages-per-page/quality-gates.md 同步）
// ---------------------------------------------------------------------

/// 抽查的数据区域页面（6 入口各取样 2-10 页，含全部 admin 数据 tab）。
const _dataPages = <String>[
  // admin
  'lib/screens/admin/clients_tab.dart',
  'lib/screens/admin/users_tab.dart',
  'lib/screens/admin/local_users_tab.dart',
  'lib/screens/admin/tenants_tab.dart',
  'lib/screens/admin/domains_tab.dart',
  'lib/screens/admin/connections_tab.dart',
  'lib/screens/admin/credentials_tab.dart',
  'lib/screens/admin/token_security_tab.dart',
  'lib/screens/admin/crypto_keys_tab.dart',
  'lib/screens/admin/webhooks_tab.dart',
  'lib/screens/admin/audit_log_tab.dart',
  'lib/screens/admin/permissions_tab.dart',
  'lib/screens/admin/governance_tab.dart',
  'lib/screens/admin/authz_check_tab.dart',
  'lib/screens/admin/change_approvals_tab.dart',
  'lib/screens/admin/threat_policies_tab.dart',
  'lib/screens/admin/access_policies_tab.dart',
  'lib/screens/admin/network_policies_tab.dart',
  'lib/screens/admin/privacy_compliance_tab.dart',
  'lib/screens/admin/dr_mode_tab.dart',
  'lib/screens/admin/device_security_tab.dart',
  'lib/screens/admin/usage_analytics_tab.dart',
  'lib/screens/admin/recovery_releases_tab.dart',
  'lib/screens/admin/user_support_tab.dart',
  'lib/screens/admin/break_glass_tab.dart',
  // portal
  'lib/screens/portal/overview_tab.dart',
  'lib/screens/portal/devices_tab.dart',
  'lib/screens/portal/identities_tab.dart',
  'lib/screens/portal/sessions_tab.dart',
  'lib/screens/portal/organizations_tab.dart',
  'lib/screens/portal/notifications_tab.dart',
  'lib/screens/portal/consents_tab.dart',
  'lib/screens/portal/security_activity_tab.dart',
  'lib/screens/portal/privacy_tab.dart',
  // developer
  'lib/screens/developer/manage_panel.dart',
  'lib/screens/developer/register_panel.dart',
  // device / setup / login
  'lib/screens/device/device_verify_screen.dart',
  'lib/screens/setup/setup_screen.dart',
  'lib/screens/oidc_login/oidc_login_screen.dart',
];

/// 数据页判据：页面必须引用至少一个数据加载机制。
final _dataMachinery = RegExp(
  r'FutureBuilder|StreamBuilder|SkeletonListTile|AsyncView|_load[A-Za-z]*\(|'
  r'_reload|onRefresh|_check[A-Za-z]*\(|widget\.api\.|_run\(',
);

final _loadingPattern = RegExp(
  r'SkeletonListTile|CircularProgressIndicator|LinearProgressIndicator|'
  r'AsyncView|_loading\b|isLoading\b|_mutating\b|_busy\b|ConnectionState\.waiting',
  caseSensitive: false,
);

final _emptyPattern = RegExp(
  r'EmptyState\b|EmptyHint\b|isEmpty\b',
  caseSensitive: false,
);

final _errorPattern = RegExp(
  r'hasError\b|Error\b|_errorState|onRetry|\bretry\b|_loadError|loadError|'
  r'catch\s*\(|MessageBanner|requestFailed',
  caseSensitive: false,
);
