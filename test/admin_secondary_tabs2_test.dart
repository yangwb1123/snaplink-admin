import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/screens/admin/admin_live_events_tab.dart';
import 'package:sso_admin/screens/admin/authz_check_tab.dart';
import 'package:sso_admin/screens/admin/local_users_tab.dart';
import 'package:sso_admin/screens/admin/network_policies_tab.dart';
import 'package:sso_admin/screens/admin/privacy_compliance_tab.dart';
import 'package:sso_admin/screens/admin/usage_analytics_tab.dart';
import 'package:sso_admin/services/browser_navigation.dart';

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

SnaplinkAdminCapabilities _caps(List<String> paths) =>
    SnaplinkAdminCapabilities([
      for (final path in paths)
        SnaplinkAdminEndpoint(method: 'GET', path: path, feature: 'core'),
    ]);

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1200, 2600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  await tester.pumpAndSettle();
}

Finder _dialogField() => find.descendant(
  of: find.byType(AlertDialog),
  matching: find.byType(TextField),
);

void main() {
  setUp(() {
    BrowserNavigation.resetForTest();
  });

  group('AuthzCheckTab', () {
    testWidgets('runs a ReBAC check from JSON input', (tester) async {
      var checked = <String>[];
      final api = _api({
        '/api/v1/admin/rebac/check': (request) {
          checked.add(request.url.query);
          return http.Response(jsonEncode({'allowed': true}), 200);
        },
      });
      await _pump(
        tester,
        AuthzCheckTab(
          api: api,
          capabilities: _caps(['/api/v1/admin/rebac/check']),
        ),
      );

      await tester.enterText(
        find.byType(TextField).first,
        jsonEncode({
          'object': 'client:portal',
          'relation': 'manage',
          'subject': 'user:admin',
        }),
      );
      await tester.tap(find.text('Check ReBAC'));
      await tester.pumpAndSettle();

      expect(checked.single, contains('object=client%3Aportal'));
      expect(checked.single, contains('relation=manage'));
      expect(checked.single, contains('subject=user%3Aadmin'));
      // The result renders as pretty-printed JSON in a SelectableText.
      expect(find.textContaining('"allowed": true'), findsOneWidget);
    });

    testWidgets('rejects invalid JSON without a request', (tester) async {
      var requests = 0;
      final api = _api({
        '/api/v1/admin/rebac/check': (_) {
          requests++;
          return http.Response('{}', 200);
        },
      });
      await _pump(
        tester,
        AuthzCheckTab(
          api: api,
          capabilities: _caps(['/api/v1/admin/rebac/check']),
        ),
      );

      await tester.enterText(find.byType(TextField).first, 'not-json');
      await tester.tap(find.text('Check ReBAC'));
      await tester.pumpAndSettle();

      expect(requests, 0);
      expect(find.text('Invalid JSON or request failed.'), findsOneWidget);
    });

    testWidgets('runs a WASM authorization check', (tester) async {
      var posted = <String>[];
      final api = _api({
        '/api/v1/admin/wasmauthz/check': (request) {
          posted.add(request.body);
          return http.Response(jsonEncode({'decision': 'allow'}), 200);
        },
      });
      await _pump(
        tester,
        AuthzCheckTab(
          api: api,
          capabilities: SnaplinkAdminCapabilities([
            SnaplinkAdminEndpoint(
              method: 'POST',
              path: '/api/v1/admin/wasmauthz/check',
              feature: 'core',
            ),
          ]),
        ),
      );

      await tester.enterText(
        find.byType(TextField).last,
        jsonEncode({'principal': 'user-1', 'action': 'read'}),
      );
      await tester.tap(find.text('Check WASM'));
      await tester.pumpAndSettle();

      expect(posted.single, contains('"principal":"user-1"'));
      expect(find.textContaining('"decision": "allow"'), findsOneWidget);
    });
  });

  group('UsageAnalyticsTab', () {
    testWidgets('loads top tenants and token usage', (tester) async {
      final api = _api({
        '/api/v1/admin/usage/top-tenants': (_) => http.Response(
          jsonEncode({
            'tenants': [
              {'tenant_id': 'tenant-a', 'logins': 42, 'tokens_issued': 7},
            ],
          }),
          200,
        ),
        '/api/v1/admin/tokens/usage': (_) =>
            http.Response(jsonEncode({'total': 5, 'by_client': {}}), 200),
      });
      await _pump(
        tester,
        UsageAnalyticsTab(
          api: api,
          capabilities: _caps([
            '/api/v1/admin/usage/top-tenants',
            '/api/v1/admin/tokens/usage',
          ]),
        ),
      );

      expect(find.text('tenant-a'), findsOneWidget);
      expect(find.textContaining('42 logins'), findsOneWidget);
    });

    testWidgets('shows a fallback when no usage endpoint is available', (
      tester,
    ) async {
      await _pump(
        tester,
        UsageAnalyticsTab(api: _api({}), capabilities: _caps([])),
      );
      // The documented usage routes exist in the catalog, so the tab reports
      // that their data is unavailable rather than pretending success.
      expect(find.textContaining('Some usage data is unavailable'), findsOne);
    });
  });

  group('NetworkPoliciesTab', () {
    testWidgets('lists policies and opens the create dialog', (tester) async {
      var created = <String>[];
      final api = _api({
        '/api/v1/netpolicy/policies': (request) {
          if (request.method == 'POST') {
            created.add(request.body);
            return http.Response('{}', 201);
          }
          return http.Response(
            jsonEncode({
              'policies': [
                {'name': 'block-all', 'action': 'deny'},
              ],
            }),
            200,
          );
        },
      });
      await _pump(
        tester,
        NetworkPoliciesTab(
          api: api,
          capabilities: _caps(['/api/v1/netpolicy/policies']),
        ),
      );

      expect(find.text('block-all'), findsOneWidget);
      await tester.tap(find.text('Add policy'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Policy name'),
        'block-admin',
      );
      await tester.tap(find.text('Apply policy'));
      await tester.pumpAndSettle();
      expect(created.single, contains('"name":"block-admin"'));
    });
  });

  group('PrivacyComplianceTab', () {
    testWidgets('previews erasure then commits with typed confirmation', (
      tester,
    ) async {
      final erasePosts = <String>[];
      final api = _api({
        '/api/v1/compliance/users/subject-1/export': (_) =>
            http.Response('{}', 200),
        '/api/v1/compliance/users/subject-1/erase': (request) {
          erasePosts.add(request.body);
          return http.Response(
            jsonEncode({'user_deleted': true, 'sessions_destroyed': 2}),
            200,
          );
        },
      });
      await _pump(
        tester,
        PrivacyComplianceTab(api: api, capabilities: _caps([])),
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'User ID'),
        'subject-1',
      );

      // Committing without a fresh preview is blocked at the button level
      // (fail-closed: the commit handler cannot run before a dry-run).
      final commitButton = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Commit erasure'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(commitButton.onPressed, isNull);

      // Preview first, then commit with typed confirmation.
      await tester.tap(find.text('Preview erasure'));
      await tester.pumpAndSettle();
      expect(erasePosts.first, contains('"dry_run":true'));

      await tester.tap(find.text('Commit erasure'));
      await tester.pumpAndSettle();
      expect(find.text('Permanently erase subject data?'), findsOneWidget);
      await tester.enterText(_dialogField(), 'subject-1');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Erase subject'));
      await tester.pumpAndSettle();
      expect(erasePosts.last, contains('"dry_run":false'));
    });
  });

  group('LocalUsersTab', () {
    testWidgets('lists local users and paginates', (tester) async {
      final queries = <String>[];
      final api = _api({
        '/api/v1/admin/local-users': (request) {
          queries.add(request.url.query);
          return http.Response(
            jsonEncode({
              'users': [
                {'id': 'local-1', 'username': 'local-1'},
              ],
              'total': 30,
            }),
            200,
          );
        },
      });
      await _pump(
        tester,
        LocalUsersTab(
          api: api,
          capabilities: _caps(['/api/v1/admin/local-users']),
        ),
      );

      expect(find.text('local-1'), findsOneWidget);
      expect(queries.first, contains('page=1&limit=25'));
      await tester.tap(find.byIcon(Icons.chevron_right).last);
      await tester.pumpAndSettle();
      expect(queries.last, contains('page=2'));
    });
  });

  group('AdminLiveEventsTab', () {
    testWidgets('fails closed when the stream is not advertised', (
      tester,
    ) async {
      await _pump(
        tester,
        AdminLiveEventsTab(api: _api({}), endpoints: const []),
      );
      expect(find.textContaining('not listed by this replica'), findsOneWidget);
    });
  });
}
