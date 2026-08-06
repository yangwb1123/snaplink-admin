import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/api/sso_client.dart';
import 'package:sso_admin/screens/admin/break_glass_detail_screen.dart';
import 'package:sso_admin/screens/admin/client_detail_screen.dart';
import 'package:sso_admin/screens/admin/connection_detail_screen.dart';
import 'package:sso_admin/screens/admin/permission_detail_screen.dart';
import 'package:sso_admin/screens/admin/tenant_detail_screen.dart';
import 'package:sso_admin/screens/admin/webhook_detail_screen.dart';
import 'package:sso_admin/services/browser_navigation.dart';

SnaplinkAdminApi _adminApi(
  Map<String, http.Response Function(http.Request)> routes,
) => SnaplinkAdminApi(
  baseUrl: 'https://sso.example.test',
  accessToken: 'admin-token',
  httpClient: MockClient((request) async {
    final handler = routes[request.url.path];
    if (handler != null) return handler(request);
    return http.Response('{"error":"not found"}', 404);
  }),
);

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

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1200, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: child));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    BrowserNavigation.resetForTest();
  });

  group('ClientDetailScreen', () {
    testWidgets('renders client info and actions for a pending client', (
      tester,
    ) async {
      final client = _ssoClient({
        '/api/v1/admin/clients/portal-client': (_) => http.Response(
          jsonEncode({
            'client': {
              'id': 'portal-client',
              'name': 'Portal',
              'status': 'pending',
              'redirect_uris': ['https://app.example/cb'],
              'grant_types': ['authorization_code'],
            },
          }),
          200,
        ),
      });
      await tester.pumpWidget(
        MaterialApp(
          home: ClientDetailScreen(
            api: _adminApi({}),
            client: client,
            clientId: 'portal-client',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Portal'), findsOneWidget);
      expect(find.text('ID: portal-client'), findsOneWidget);
      expect(find.text('https://app.example/cb'), findsOneWidget);
      expect(find.text('pending'), findsOneWidget);
      expect(find.text('Approve'), findsOneWidget);
      expect(find.text('Reject'), findsOneWidget);
      expect(find.text('Rotate Secret'), findsOneWidget);
    });

    testWidgets('shows an error state with retry', (tester) async {
      var calls = 0;
      final client = _ssoClient({
        '/api/v1/admin/clients/missing': (_) {
          calls++;
          return http.Response('{"error":"not found"}', 404);
        },
      });
      await tester.pumpWidget(
        MaterialApp(
          home: ClientDetailScreen(
            api: _adminApi({}),
            client: client,
            clientId: 'missing',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Failed to load'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(calls, greaterThanOrEqualTo(1));
    });
  });

  group('TenantDetailScreen', () {
    testWidgets('renders tenant details', (tester) async {
      final api = _adminApi({
        '/api/v1/admin/tenants/tenant-a': (_) => http.Response(
          jsonEncode({
            'tenant': {
              'id': 'tenant-a',
              'name': 'Acme',
              'slug': 'acme',
              'status': 'active',
            },
          }),
          200,
        ),
      });
      final client = _ssoClient({
        '/api/v1/admin/tenants/tenant-a': (_) => http.Response(
          jsonEncode({
            'tenant': {
              'id': 'tenant-a',
              'name': 'Acme',
              'slug': 'acme',
              'status': 'active',
            },
          }),
          200,
        ),
      });
      await tester.pumpWidget(
        MaterialApp(
          home: TenantDetailScreen(
            api: api,
            client: client,
            tenantId: 'tenant-a',
            capabilities: const SnaplinkAdminCapabilities([]),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Acme'), findsWidgets);
      expect(find.textContaining('active'), findsWidgets);
    });
  });

  group('WebhookDetailScreen', () {
    testWidgets('renders subscription and its dead letters', (tester) async {
      final api = _adminApi({
        '/api/v1/admin/webhooks/subscriptions': (_) => http.Response(
          jsonEncode({
            'subscriptions': [
              {
                'id': 'sub-1',
                'url': 'https://hooks.example/cb',
                'active': true,
              },
            ],
          }),
          200,
        ),
        '/api/v1/admin/webhooks/deadletters': (_) => http.Response(
          jsonEncode({
            'deadletters': [
              {
                'id': 'msg-1',
                'subscription_id': 'sub-1',
                'event_type': 'delivery.failed',
                'error': 'timeout',
              },
              {
                'id': 'msg-2',
                'subscription_id': 'other-sub',
                'event_type': 'other.event',
                'error': 'unrelated',
              },
            ],
          }),
          200,
        ),
      });
      await _pump(
        tester,
        WebhookDetailScreen(api: api, client: _ssoClient({}), subId: 'sub-1'),
      );

      expect(find.text('Webhook: sub-1'), findsOneWidget);
      expect(find.textContaining('https://hooks.example/cb'), findsOneWidget);
      // Expand the collapsed dead-letter section.
      await tester.tap(find.textContaining('Dead Letters'));
      await tester.pumpAndSettle();
      expect(find.text('delivery.failed'), findsOneWidget);
      // Dead letters for other subscriptions are not shown.
      expect(find.text('other.event'), findsNothing);
    });

    testWidgets('reports a missing subscription', (tester) async {
      final api = _adminApi({
        '/api/v1/admin/webhooks/subscriptions': (_) =>
            http.Response(jsonEncode({'subscriptions': []}), 200),
        '/api/v1/admin/webhooks/deadletters': (_) =>
            http.Response(jsonEncode({'deadletters': []}), 200),
      });
      await tester.pumpWidget(
        MaterialApp(
          home: WebhookDetailScreen(
            api: api,
            client: _ssoClient({}),
            subId: 'missing',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Webhook subscription was not found'),
        findsOneWidget,
      );
    });
  });

  group('BreakGlassDetailScreen', () {
    testWidgets('renders a session and its derived sessions', (tester) async {
      final api = _adminApi({
        '/api/v1/admin/break-glass': (_) => http.Response(
          jsonEncode({
            'sessions': [
              {
                'id': 'grant-1',
                'target_user_id': 'user-42',
                'scope': 'readonly',
                'status': 'active',
                'reason': 'Incident',
              },
            ],
          }),
          200,
        ),
      });
      await tester.pumpWidget(
        MaterialApp(
          home: BreakGlassDetailScreen(api: api, sessionId: 'grant-1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Break-Glass Session'), findsOneWidget);
      expect(find.text('ID: grant-1'), findsOneWidget);
      expect(find.text('Incident'), findsOneWidget);
    });
  });

  group('ConnectionDetailScreen', () {
    testWidgets('renders connection details', (tester) async {
      final api = _adminApi({
        '/api/v1/admin/connections/conn-1': (_) => http.Response(
          jsonEncode({
            'id': 'conn-1',
            'type': 'oidc',
            'name': 'Okta',
            'enabled': true,
          }),
          200,
        ),
        '/api/v1/admin/connections/conn-1/health': (_) =>
            http.Response(jsonEncode({'healthy': true}), 200),
        '/api/v1/admin/connections/conn-1/domains': (_) =>
            http.Response(jsonEncode({'domains': []}), 200),
      });
      await tester.pumpWidget(
        MaterialApp(
          home: ConnectionDetailScreen(
            api: api,
            client: _ssoClient({}),
            connectionId: 'conn-1',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Okta'), findsWidgets);
      expect(find.textContaining('conn-1'), findsWidgets);
    });
  });

  group('PermissionDetailScreen', () {
    testWidgets('renders roles and assignments', (tester) async {
      final api = _adminApi({
        '/api/v1/admin/permissions/portal-client/roles': (_) => http.Response(
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
        ),
        '/api/v1/admin/permissions/portal-client/assignments': (_) =>
            http.Response(
              jsonEncode({
                'assignments': [
                  {'user_id': 'user-7', 'role_id': 'role-1'},
                ],
              }),
              200,
            ),
      });
      await tester.pumpWidget(
        MaterialApp(
          home: PermissionDetailScreen(
            api: api,
            client: _ssoClient({}),
            clientId: 'portal-client',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('billing-admin'), findsWidgets);
      await tester.tap(find.text('Assignments'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Subject: user-7'), findsOneWidget);
    });
  });
}
