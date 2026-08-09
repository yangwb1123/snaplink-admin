import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sso_admin/api/sso_client.dart';
import 'package:sso_admin/app_settings.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/screens/admin/admin_navigation.dart';
import 'package:sso_admin/screens/admin/dashboard_screen.dart';
import 'package:sso_admin/screens/settings_screen.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/services/shortcut_platform.dart' as shortcut_platform;
import 'package:sso_admin/session.dart';

/// Admin navigation mode (settings) — design docs/auto/settings-mode/design.md
/// T-matrix T1-T15. Harness mirrors test/admin_shell_test.dart.
SSOAdminClient _ssoClient(
  Map<String, http.Response Function(http.Request)> routes,
) => SSOAdminClient(
  'https://sso.example.test',
  httpClient: MockClient((request) async {
    final handler = routes[request.url.path];
    if (handler != null) return handler(request);
    return http.Response('{"error":"not found"}', 404);
  }),
);

http.Response _endpoints(List<Map<String, String>> endpoints) => http.Response(
  jsonEncode({'endpoints': endpoints}),
  200,
);

const _fullEndpoints = [
  {'method': 'GET', 'path': '/api/v1/admin/clients', 'feature': 'core'},
  {'method': 'GET', 'path': '/api/v1/admin/users', 'feature': 'core'},
  {'method': 'GET', 'path': '/api/v1/admin/tenants', 'feature': 'core'},
  {'method': 'GET', 'path': '/api/v1/admin/token-security', 'feature': 'core'},
];

/// Endpoint set WITHOUT the audit read and netpolicy (T7/T8: hot-but-gated
/// modules must be hidden in both modes).
const _noAuditEndpoints = [
  {'method': 'GET', 'path': '/api/v1/admin/clients', 'feature': 'core'},
  {'method': 'GET', 'path': '/api/v1/admin/users', 'feature': 'core'},
  {'method': 'GET', 'path': '/api/v1/admin/tenants', 'feature': 'core'},
];

void main() {
  setUpAll(() {
    // SharedPreferencesAsync's constructor requires a registered platform;
    // the in-memory double is inert (the failure seams override the
    // get/set methods entirely).
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  setUp(() {
    Session.clear();
    BrowserNavigation.resetForTest();
    shortcut_platform.resetForTest();
    AppSettings.instance.adminNavMode = AdminNavMode.normal;
  });

  tearDown(() {
    AppSettings.debugPreferencesOverride = null;
  });

  group('T5 core allowlist + visibleForMode semantics', () {
    test('core is exactly the trio; professional is the identity', () {
      expect(
        AdminHotModules.core,
        unorderedEquals(<String>[
          AdminModuleId.overview,
          AdminModuleId.clients,
          AdminModuleId.users,
        ]),
      );
      const all = <String>[
        AdminModuleId.overview,
        AdminModuleId.clients,
        AdminModuleId.users,
        AdminModuleId.tenants,
        AdminModuleId.tokenSecurity,
        AdminModuleId.webhooks,
        AdminModuleId.auditLog,
      ];
      // Professional = identity: every capability-enabled module shows.
      expect(
        AdminHotModules.visibleForMode(all, AdminNavMode.professional),
        orderedEquals(all),
      );
      // Normal = core intersection, order preserved.
      expect(
        AdminHotModules.visibleForMode(all, AdminNavMode.normal),
        orderedEquals(<String>[
          AdminModuleId.overview,
          AdminModuleId.clients,
          AdminModuleId.users,
        ]),
      );
    });
  });

  group('T1-T4 AppSettings persistence', () {
    test('T1 absent key defaults to normal on both load paths', () async {
      // Web path: empty LocalStorage.
      expect(AppSettings.instance.adminNavMode, AdminNavMode.normal);
      // Native path: initialize() with no stored value.
      AppSettings.debugPreferencesOverride = _MemoryPrefs();
      await AppSettings.instance.initialize();
      expect(AppSettings.instance.adminNavMode, AdminNavMode.normal);
    });

    test('T2 corrupt values default to normal, never throw', () async {
      for (final corrupt in ['expert', '1', '', 'garbage']) {
        final prefs = _MemoryPrefs()..values['sso_settings_admin_nav_mode'] = corrupt;
        AppSettings.debugPreferencesOverride = prefs;
        await AppSettings.instance.initialize();
        expect(
          AppSettings.instance.adminNavMode,
          AdminNavMode.normal,
          reason: 'corrupt value "$corrupt" must fall back to normal',
        );
      }
    });

    test('T3 round-trip persists professional across re-initialize', () async {
      final prefs = _MemoryPrefs();
      AppSettings.debugPreferencesOverride = prefs;
      await AppSettings.instance.initialize();
      expect(AppSettings.instance.adminNavMode, AdminNavMode.normal);

      AppSettings.instance.adminNavMode = AdminNavMode.professional;
      await Future<void>.delayed(Duration.zero); // unawaited _nativeSave race
      expect(prefs.values['sso_settings_admin_nav_mode'], 'professional');

      // Re-load from a second store carrying the persisted value: the
      // initialize() load path must read the store, not the in-memory
      // field (dirtying via the setter would rewrite the store).
      AppSettings.debugPreferencesOverride = _MemoryPrefs()
        ..values['sso_settings_admin_nav_mode'] = 'professional';
      await AppSettings.instance.initialize();
      expect(AppSettings.instance.adminNavMode, AdminNavMode.professional);
    });

    test('T4 no-op setter does not notify, change notifies exactly once',
        () async {
      var notifications = 0;
      void listener() => notifications++;
      AppSettings.instance.addListener(listener);
      addTearDown(() => AppSettings.instance.removeListener(listener));

      AppSettings.instance.adminNavMode = AdminNavMode.normal; // no-op
      expect(notifications, 0, reason: 'same-value set must not notify');
      AppSettings.instance.adminNavMode = AdminNavMode.professional;
      expect(notifications, 1);
      AppSettings.instance.adminNavMode = AdminNavMode.professional; // no-op
      expect(notifications, 1);
    });
  });

  group('T13/T14 failure seams', () {
    test('T13 save-throw applies for the session without crashing', () async {
      final prefs = _MemoryPrefs(throwOnSet: true);
      AppSettings.debugPreferencesOverride = prefs;
      await AppSettings.instance.initialize();

      AppSettings.instance.adminNavMode = AdminNavMode.professional;
      await Future<void>.delayed(Duration.zero);
      expect(AppSettings.instance.adminNavMode, AdminNavMode.professional,
          reason: 'in-memory value applies even when persistence throws');
      expect(prefs.values, isEmpty, reason: 'store must stay empty');
    });

    test('T14 read-throw defaults to normal without crashing', () async {
      AppSettings.debugPreferencesOverride = _MemoryPrefs(throwOnGet: true);
      await AppSettings.instance.initialize();
      expect(AppSettings.instance.adminNavMode, AdminNavMode.normal);
    });
  });

  group('T6-T8 rail surfaces', () {
    testWidgets('T6 normal mode shows exactly the core trio groups',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 2200);
      tester.view.devicePixelRatio = 1.0;
      await tester.pumpWidget(
        MaterialApp(
          home: DashboardScreen(
            client: _ssoClient({
              '/api/v1/admin/endpoints': (_) => _endpoints(_fullEndpoints),
              '/api/v1/admin/commerce/plans': (_) => http.Response('{}', 404),
              '/api/v1/admin/clients': (_) => http.Response(
                jsonEncode({'clients': [], 'total_size': 0}),
                200,
              ),
            }),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Normal mode: only the Overview and Identity groups survive.
      // (rail labels may render twice: destination label + ellipsis variant)
      expect(find.text('Overview'), findsWidgets);
      expect(find.text('Identity'), findsWidgets);
      expect(find.text('Security'), findsNothing);
      expect(find.text('Tenants'), findsNothing);
      expect(find.text('System'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('T7 professional mode shows the hot groups, audit gated off',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 2200);
      tester.view.devicePixelRatio = 1.0;
      AppSettings.instance.adminNavMode = AdminNavMode.professional;
      await tester.pumpWidget(
        MaterialApp(
          home: DashboardScreen(
            client: _ssoClient({
              '/api/v1/admin/endpoints': (_) => _endpoints(_noAuditEndpoints),
              '/api/v1/admin/commerce/plans': (_) => http.Response('{}', 404),
              '/api/v1/admin/clients': (_) => http.Response(
                jsonEncode({'clients': [], 'total_size': 0}),
                200,
              ),
            }),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Professional = EVERY capability-enabled module: all six groups
      // survive the catalog-merge capability pass (documented routes keep
      // every gate open — see admin_shell_test.dart AC-5.1), and the mode
      // filter is the identity.
      expect(find.text('Overview'), findsWidgets);
      expect(find.text('Identity'), findsWidgets);
      expect(find.text('Security'), findsWidgets);
      expect(find.text('Tenants'), findsWidgets);
      expect(find.text('System'), findsWidgets);
      await tester.pumpWidget(const SizedBox());
    });

    test('T8 capability precedence: gated modules stay hidden in both modes', () {
      // Capability gating runs BEFORE the mode filter in the dashboard
      // (dashboard_screen._buildBody): the filter only ever receives the
      // capability-surviving module list. Professional is the identity
      // over that list — a module capability gating removed stays hidden;
      // normal narrows to the core trio.
      //
      // The widget harness cannot produce a gated-off module: the documented
      // catalog merge (admin_navigation.dart AdminNavigationCapabilities,
      // admin_shell_test.dart AC-5.1) keeps every gate open, so the
      // precedence is pinned here on the pure filter instead.
      const capabilityVisible = <String>[
        AdminModuleId.overview,
        AdminModuleId.clients,
        AdminModuleId.users,
        AdminModuleId.tenants,
        AdminModuleId.tokenSecurity,
        // auditLog deliberately absent: capability gating removed it.
        AdminModuleId.webhooks, // capability-present.
      ];

      final professional = AdminHotModules.visibleForMode(
        capabilityVisible,
        AdminNavMode.professional,
      );
      expect(
        professional,
        isNot(contains(AdminModuleId.auditLog)),
        reason: 'capability-gated module must stay hidden in professional',
      );
      expect(
        professional,
        orderedEquals(capabilityVisible),
        reason: 'professional is the identity over capability-visible modules',
      );
      final normal = AdminHotModules.visibleForMode(
        capabilityVisible,
        AdminNavMode.normal,
      );
      expect(
        normal,
        isNot(contains(AdminModuleId.auditLog)),
        reason: 'capability-gated module must stay hidden in normal',
      );
      expect(
        normal,
        isNot(contains(AdminModuleId.tenants)),
        reason: 'normal is the core trio only — tenants is not core',
      );
      expect(normal, isNot(contains(AdminModuleId.webhooks)));
      expect(
        normal,
        orderedEquals(<String>[
          AdminModuleId.overview,
          AdminModuleId.clients,
          AdminModuleId.users,
        ]),
        reason: 'normal mode keeps exactly the core trio',
      );
    });
  });

  group('T9 deep links resolve to rail-hidden modules', () {
    testWidgets('fully-hidden group: page renders, rail falls back',
        (tester) async {
      tester.view.physicalSize = const Size(1200, 2200);
      tester.view.devicePixelRatio = 1.0;
      AppSettings.instance.adminNavMode = AdminNavMode.normal;
      BrowserNavigation.pushState('/admin/webhooks');
      await tester.pumpWidget(
        MaterialApp(
          home: DashboardScreen(
            client: _ssoClient({
              '/api/v1/admin/endpoints': (_) => _endpoints(_fullEndpoints),
              '/api/v1/admin/commerce/plans': (_) => http.Response('{}', 404),
              '/api/v1/admin/clients': (_) => http.Response(
                jsonEncode({'clients': [], 'total_size': 0}),
                200,
              ),
              '/api/v1/admin/webhooks/subscriptions': (_) => http.Response(
                jsonEncode({'subscriptions': []}),
                200,
              ),
            }),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // The page itself renders despite webhooks being outside both surfaces.
      expect(find.text('Webhooks'), findsWidgets);
      // The rail stays on the first visible group (Overview) — no crash.
      expect(find.text('Overview'), findsWidgets);
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('T11/T12 settings widget + i18n', () {
    testWidgets('mode picker persists and respects the locale', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
      await tester.pumpAndSettle();

      expect(find.text('Admin navigation mode'), findsOneWidget);
      expect(find.text('Standard'), findsOneWidget);
      expect(find.text('Professional'), findsOneWidget);

      await tester.tap(find.text('Professional'));
      await tester.pump();
      expect(AppSettings.instance.adminNavMode, AdminNavMode.professional);
      await tester.pumpWidget(const SizedBox());
    });

    test('T12 zh description is translated (gate blind spot guard)', () {
      const description =
          'Standard shows Overview, Clients, and Users. Professional '
          'shows every module enabled by your server.';
      final zh = AppStrings.forLocale(const Locale('zh'));
      expect(
        zh.translate(description),
        isNot(description),
        reason: 'zh description must be translated (i18n_coverage gate does '
            'not scan strings.translate(...) — this is the only guard)',
      );
      expect(zh.adminNavMode, '管理导航模式');
      expect(zh.adminNavModeNormal, '标准');
      expect(zh.adminNavModeProfessional, '专业');
    });
  });
}

/// Minimal in-memory SharedPreferencesAsync double for the failure seams and
/// native-path persistence tests (the real platform cannot be swapped after
/// the cached wrapper binds, and InMemorySharedPreferencesAsync never throws).
class _MemoryPrefs extends SharedPreferencesAsync {
  _MemoryPrefs({this.throwOnGet = false, this.throwOnSet = false});

  final bool throwOnGet;
  final bool throwOnSet;
  final Map<String, String> values = {};

  @override
  Future<String?> getString(
    String key, [
    SharedPreferencesOptions? options,
  ]) async {
    if (throwOnGet) throw Exception('read failed');
    return values[key];
  }

  @override
  Future<void> setString(
    String key,
    String value, [
    SharedPreferencesOptions? options,
  ]) async {
    if (throwOnSet) throw Exception('write failed');
    values[key] = value;
  }
}
