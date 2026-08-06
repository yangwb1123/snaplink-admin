import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/api/sso_client.dart';
import 'package:sso_admin/screens/admin/connections_tab.dart';
import 'package:sso_admin/screens/admin/dashboard_screen.dart';
import 'package:sso_admin/screens/admin/permissions_tab.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/services/shortcut_platform.dart' as shortcut_platform;
import 'package:sso_admin/session.dart';

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

void main() {
  setUp(() {
    Session.clear();
    BrowserNavigation.resetForTest();
    shortcut_platform.resetForTest();
  });

  group('DashboardScreen', () {
    testWidgets('loads capabilities and switches modules', (tester) async {
      final client = _ssoClient({
        '/api/v1/admin/endpoints': (_) => http.Response(
          jsonEncode({
            'endpoints': [
              {
                'method': 'GET',
                'path': '/api/v1/admin/clients',
                'feature': 'core',
              },
              {
                'method': 'GET',
                'path': '/api/v1/admin/users',
                'feature': 'core',
              },
              {
                'method': 'GET',
                'path': '/api/v1/admin/tenants',
                'feature': 'core',
              },
            ],
          }),
          200,
        ),
        '/api/v1/admin/commerce/plans': (_) => http.Response('{}', 404),
        '/api/v1/admin/clients': (_) =>
            http.Response(jsonEncode({'clients': [], 'total_size': 0}), 200),
      });

      await tester.pumpWidget(
        MaterialApp(home: DashboardScreen(client: client)),
      );
      await tester.pumpAndSettle();

      // 分组导航：一级 rail 显示 6 组；组内模块在 SectionSelector。
      // 窄 rail（<1180）只显示选中项 label——未选中组标签在 Offstage，
      // 断言存在但交互需点击组图标（M3 标准行为）。
      expect(find.text('Identity'), findsOneWidget);
      expect(find.text('Security'), findsOneWidget);
      expect(find.text('Tenants'), findsOneWidget);

      // 进入 Identity 组（默认模块 clients）→ 组 tabs 出现。
      await tester.tap(find.byIcon(Icons.people_outline));
      await tester.pumpAndSettle();
      expect(find.text('Clients'), findsWidgets);

      // 切到组内 users 模块（SectionSelector chip）。
      await tester.tap(find.text('Users'));
      await tester.pumpAndSettle();

      // Dashboard teardown disposes the shared shortcut service.
      await tester.pumpWidget(const SizedBox());
    });
  });

  group('ConnectionsTab', () {
    testWidgets('lists connections for a tenant and loads details', (
      tester,
    ) async {
      final api = _api();
      tester.view.physicalSize = const Size(1200, 2600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConnectionsTab(
              api: api,
              capabilities: SnaplinkAdminCapabilities([
                SnaplinkAdminEndpoint(
                  method: 'GET',
                  path: '/api/v1/admin/connections',
                  feature: 'core',
                ),
                SnaplinkAdminEndpoint(
                  method: 'GET',
                  path: '/api/v1/admin/connections/:id',
                  feature: 'core',
                ),
              ]),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Tenant ID').first,
        'tenant-a',
      );
      await tester.tap(find.text('List connections'));
      await tester.pumpAndSettle();
      expect(find.text('conn-1'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Connection ID').first,
        'conn-1',
      );
      await tester.tap(find.text('Get connection'));
      await tester.pumpAndSettle();
      expect(find.text('conn-1'), findsNWidgets(2)); // list row + detail
    });

    testWidgets('fails closed when the family is absent', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ConnectionsTab(
              api: _api(),
              capabilities: SnaplinkAdminCapabilities([]),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(
          'Identity connection management is not enabled on this Snaplink replica.',
        ),
        findsOneWidget,
      );
    });
  });

  group('PermissionsTab', () {
    testWidgets('loads roles and assignments for a client', (tester) async {
      final api = _api();
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: PermissionsTab(
              api: api,
              capabilities: SnaplinkAdminCapabilities([
                SnaplinkAdminEndpoint(
                  method: 'GET',
                  path: '/api/v1/admin/permissions/:client_id/roles',
                  feature: 'core',
                ),
                SnaplinkAdminEndpoint(
                  method: 'GET',
                  path: '/api/v1/admin/permissions/:client_id/assignments',
                  feature: 'core',
                ),
              ]),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Client ID'),
        'portal-client',
      );
      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();

      expect(find.text('billing-admin'), findsOneWidget);
      expect(find.text('user-7'), findsOneWidget);
    });
  });
}

SnaplinkAdminApi _api() => SnaplinkAdminApi(
  baseUrl: 'https://sso.example.test',
  accessToken: 'admin-token',
  httpClient: MockClient((request) async {
    switch (request.url.path) {
      case '/api/v1/admin/connections':
        return http.Response(
          jsonEncode({
            'connections': [
              {'id': 'conn-1', 'type': 'oidc', 'enabled': true},
            ],
          }),
          200,
        );
      case '/api/v1/admin/connections/conn-1':
        return http.Response(
          jsonEncode({'id': 'conn-1', 'type': 'oidc', 'display_name': 'Okta'}),
          200,
        );
      case '/api/v1/admin/connections/conn-1/health':
        return http.Response(jsonEncode({'healthy': true}), 200);
      case '/api/v1/admin/connections/conn-1/domains':
        return http.Response(jsonEncode({'domains': []}), 200);
      case '/api/v1/admin/permissions/portal-client/roles':
        return http.Response(
          jsonEncode({
            'roles': [
              {
                'id': 'role-1',
                'name': 'billing-admin',
                'code': 'billing-admin',
              },
            ],
          }),
          200,
        );
      case '/api/v1/admin/permissions/portal-client/assignments':
        return http.Response(
          jsonEncode({
            'assignments': [
              {'user_id': 'user-7', 'role_id': 'role-1'},
            ],
          }),
          200,
        );
    }
    return http.Response('{"error":"not found"}', 404);
  }),
);
