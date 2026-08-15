import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/portal_api.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/screens/admin/tenant_organizations_tab.dart';
import 'package:sso_admin/screens/admin/admin_route.dart';
import 'package:sso_admin/screens/portal/portal_export_download.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/screens/oidc_login/trusted_device_token.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';

SnaplinkAdminApi _api(
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

void main() {
  setUp(() {
    BrowserNavigation.resetForTest();
  });

  group('AdminBreadcrumb', () {
    testWidgets('renders a module trail from the current route', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdminBreadcrumb(trailing: ['user-1', 'Sessions']),
          ),
        ),
      );
      // Without a matching module route the breadcrumb renders the trailing
      // segments or a fallback without throwing.
      expect(find.byType(AdminBreadcrumb), findsOneWidget);
    });

    testWidgets('derives the trail from the in-memory route (R21)', (
      tester,
    ) async {
      BrowserNavigation.resetForTest();
      AdminRoute.go(
        'clients',
        resourceId: 'client-abc',
        subresource: 'sessions',
      );
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: AdminBreadcrumb())),
      );
      // Group → module → resource → sub-resource, all from the current URL.
      expect(find.text('Identity'), findsOneWidget);
      expect(find.text('Clients'), findsOneWidget);
      expect(find.text('client-abc'), findsOneWidget);
      expect(find.text('Sessions'), findsOneWidget);
    });

    testWidgets('overrideModule relabels only the module crumb (R21)', (
      tester,
    ) async {
      BrowserNavigation.resetForTest();
      AdminRoute.go('scim-directory');
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AdminBreadcrumb(overrideModule: 'SCIM Directory'),
          ),
        ),
      );
      // Group level is preserved and the module crumb is relabeled — the
      // old behavior replaced the group crumb and duplicated the module.
      expect(find.text('Identity'), findsOneWidget);
      expect(find.text('SCIM Directory'), findsOneWidget);
    });
  });

  group('TenantOrganizationsTab', () {
    testWidgets('loads members and invitations for a tenant', (tester) async {
      final api = _api({
        '/api/v1/admin/tenants/tenant-a/members': (_) => http.Response(
          jsonEncode({
            'members': [
              {'user_id': 'user-1', 'role': 'admin'},
            ],
          }),
          200,
        ),
        '/api/v1/admin/tenants/tenant-a/invitations': (_) => http.Response(
          jsonEncode({
            'invitations': [
              {'email': 'invitee@example.com', 'status': 'pending'},
            ],
          }),
          200,
        ),
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TenantOrganizationsTab(
              api: api,
              capabilities: SnaplinkAdminCapabilities([
                SnaplinkAdminEndpoint(
                  method: 'GET',
                  path: '/api/v1/admin/tenants/:id/members',
                  feature: 'core',
                ),
                SnaplinkAdminEndpoint(
                  method: 'GET',
                  path: '/api/v1/admin/tenants/:id/invitations',
                  feature: 'core',
                ),
              ]),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Tenant ID'),
        'tenant-a',
      );
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(find.text('user-1'), findsOneWidget);
      expect(find.text('invitee@example.com'), findsOneWidget);
    });
  });

  group('TrustedDeviceToken', () {
    test('is a no-op on the VM (browser-only storage)', () {
      expect(TrustedDeviceToken.read('client-1'), isNull);
      // Must not throw.
      TrustedDeviceToken.store('client-1', 'token');
      TrustedDeviceToken.clear('client-1');
      TrustedDeviceToken.store('', 'token');
    });
  });

  group('PortalExportDownload', () {
    test('returns false on the VM (no browser download)', () {
      final started = downloadPortalExport(http.Response('{"data":1}', 200));
      expect(started, isFalse);
    });
  });

  group('PortalApi export wiring', () {
    test('portal API exposes the export endpoint contract', () async {
      var requested = false;
      final api = PortalApi(
        httpClient: MockClient((request) async {
          if (request.url.path == '/me') {
            return http.Response('{"sub":"user-1"}', 200);
          }
          if (request.url.path == '/me/data-export') {
            requested = true;
            return http.Response('{"export":"ok"}', 200);
          }
          return http.Response('{}', 404);
        }),
      );
      await api.login('bearer');
      final response = await api.get('/me/data-export');
      expect(requested, isTrue);
      expect(response.statusCode, 200);
      expect(PortalApi.decode(response), {'export': 'ok'});
    });
  });
}
