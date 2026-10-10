import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/screens/admin/admin_route.dart';
import 'package:sso_admin/screens/admin/dashboard_navigation_entries.dart';
import 'package:sso_admin/screens/admin/dashboard_page_resolution.dart';
import 'package:sso_admin/screens/admin/tenant_detail_screen.dart';
import 'package:sso_admin/screens/admin/user_detail_screen.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/services/operator_persona.dart';

import 'fixtures/admin_page_fixture.dart';

void main() {
  setUp(BrowserNavigation.resetForTest);
  final cases = <(String, String, String, List<String>, String?)>[
    (
      'clients',
      'client-1',
      '',
      ['/api/v1/admin/clients/client-1'],
      'https://app.example.test/callback',
    ),
    for (final section in ['sessions', 'consents', 'mfa', 'lifecycle'])
      (
        'users',
        'user-1',
        section,
        ['/api/v1/admin/users/user-1', '/api/v1/admin/users/user-1/$section'],
        section == 'sessions' ? 'session-1' : null,
      ),
    (
      'users',
      'user-1',
      'device-security',
      [
        '/api/v1/admin/users/user-1',
        '/api/v1/admin/users/user-1/devices',
        '/api/v1/admin/users/user-1/login-history',
      ],
      null,
    ),
    for (final section in ['members', 'invitations', 'usage'])
      (
        'tenants',
        'tenant-1',
        section,
        [
          '/api/v1/admin/tenants/tenant-1',
          '/api/v1/admin/tenants/tenant-1/$section',
        ],
        section == 'invitations' ? 'invite@example.test' : null,
      ),
    (
      'tenants',
      'tenant-1',
      'branding',
      ['/api/v1/admin/tenants/tenant-1', '/api/v1/admin/branding'],
      null,
    ),
    (
      'permissions',
      'client-1',
      'roles',
      ['/api/v1/admin/permissions/client-1/roles'],
      'viewer',
    ),
    (
      'permissions',
      'client-1',
      'assignments',
      ['/api/v1/admin/permissions/client-1/assignments'],
      'user-1',
    ),
    (
      'connections',
      'connection-1',
      '',
      [
        '/api/v1/admin/connections/connection-1',
        '/api/v1/admin/connections/connection-1/health',
      ],
      null,
    ),
    (
      'webhooks',
      'webhook-1',
      'deadletters',
      [
        '/api/v1/admin/webhooks/subscriptions',
        '/api/v1/admin/webhooks/deadletters',
      ],
      'fixture delivery failure',
    ),
  ];
  for (final (module, id, section, paths, text) in cases) {
    testWidgets('detail data contract: /admin/$module/$id/$section', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1400, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      BrowserNavigation.pushState(
        AdminRoute.url(module, resourceId: id, subresource: section),
      );
      final fixture = AdminPageFixture();
      final navigation = buildDashboardNavigationEntries(
        client: fixture.client,
        api: fixture.api,
        endpoints: SnaplinkAdminOperationCatalog.endpoints,
        capabilitiesError: null,
        onRefresh: () {},
        strings: AppStrings.forLocale(const Locale('en')),
        commerceAvailable: false,
        commerceProbeError: null,
      );
      final page = resolveDashboardPage(
        route: AdminRoute.current(),
        entries: navigation.entries,
        selectedModule: module,
        api: fixture.api,
        client: fixture.client,
        capabilities: navigation.capabilities,
        capabilitySnapshot: navigation.capabilitySnapshot,
        persona: OperatorPersona.general,
      );
      final errorHandler = FlutterError.onError;
      await tester.pumpWidget(MaterialApp(home: page));
      await tester.pumpAndSettle();
      // Restore before assertions: an expectation failure must not leave the
      // ErrorBoundary's global handler installed in the Flutter test harness.
      FlutterError.onError = errorHandler;
      expect(tester.takeException(), isNull);
      expect(fixture.unhandled, isEmpty);
      expect(
        fixture.paths,
        unorderedEquals(paths),
        reason: 'Only the visible resource may load',
      );
      expect(find.textContaining('Failed to load'), findsNothing);
      expect(find.textContaining('This view failed'), findsNothing);
      expect(find.textContaining('Something went wrong'), findsNothing);
      expect(find.textContaining('unavailable'), findsNothing);
      if (text != null) expect(find.textContaining(text), findsWidgets);
      if (module == 'permissions' && section == 'assignments') {
        expect(find.textContaining('viewer'), findsWidgets);
      }
      await tester.pumpWidget(const SizedBox());
      fixture.transport.close();
    });
  }

  testWidgets(
    'published user sessions remain usable when REST inventory omits RPC routes',
    (tester) async {
      final fixture = AdminPageFixture();
      const capabilities = SnaplinkAdminCapabilities([
        SnaplinkAdminEndpoint(
          method: 'GET',
          path: '/api/v1/admin/dr/status',
          feature: 'fixture',
        ),
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: UserDetailScreen(
            api: fixture.api,
            client: fixture.client,
            userId: 'user-1',
            capabilities: capabilities,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('session-1'), findsOneWidget);
      expect(fixture.paths, [
        '/api/v1/admin/users/user-1',
        '/api/v1/admin/users/user-1/sessions',
      ]);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'tenant metadata survives a known inventory with no optional tabs',
    (tester) async {
      final fixture = AdminPageFixture();
      const capabilities = SnaplinkAdminCapabilities([
        SnaplinkAdminEndpoint(
          method: 'GET',
          path: '/api/v1/admin/dr/status',
          feature: 'fixture',
        ),
      ]);
      await tester.pumpWidget(
        MaterialApp(
          home: TenantDetailScreen(
            api: fixture.api,
            client: fixture.client,
            tenantId: 'tenant-1',
            capabilities: capabilities,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Contract tenant'), findsWidgets);
      expect(fixture.paths, ['/api/v1/admin/tenants/tenant-1']);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
