import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/screens/portal/portal_api.dart';
import 'package:sso_admin/screens/portal/security_activity_tab.dart';

void main() {
  testWidgets('optional activity requests fail independently', (tester) async {
    final api = PortalApi(
      httpClient: MockClient((request) async {
        if (request.url.path == '/me/security/activity') {
          return http.Response('{}', 500);
        }
        if (request.url.path == '/me/login-history') {
          return http.Response(
            '{"login_history":[{"id":"login-1","success":true,'
            '"device":"Chrome on macOS"}]}',
            200,
          );
        }
        return http.Response('{}', 404);
      }),
    );

    await tester.pumpWidget(MaterialApp(home: SecurityActivityTab(api: api)));
    await tester.pumpAndSettle();

    expect(find.text('Could not load security activity.'), findsOneWidget);
    expect(find.text('Successful login'), findsOneWidget);
    expect(find.textContaining('Chrome on macOS'), findsOneWidget);
  });

  testWidgets('Activity tab issues only /me BFF paths — never the audit trio', (
    tester,
  ) async {
    // B6-1 AC-2(b): the portal Activity tab must never call the audit trio
    // (`/api/v1/audit/events|facets|events/{id}`) — the timeline read
    // belongs to SnaplinkAdminApi via AuditReadClient. The recorded path
    // set is the authoritative gate; the `fail()` inside the handler is a
    // fast-fail diagnostic only (the tab's catch-all swallows it into its
    // error banner, so the set assertion below is what actually fails on an
    // audit request).
    final paths = <String>[];
    final api = PortalApi(
      httpClient: MockClient((request) async {
        paths.add(request.url.path);
        if (request.url.path.startsWith('/api/v1/audit')) {
          fail(
            'portal Activity tab must never call the audit trio: '
            '${request.url.path}',
          );
        }
        if (request.url.path == '/me/security/activity') {
          return http.Response('{"events":[]}', 200);
        }
        if (request.url.path == '/me/login-history') {
          return http.Response('{"login_history":[]}', 200);
        }
        return http.Response('{}', 404);
      }),
    );

    await tester.pumpWidget(MaterialApp(home: SecurityActivityTab(api: api)));
    await tester.pumpAndSettle();
    expect(
      paths,
      unorderedEquals(['/me/security/activity', '/me/login-history']),
    );
  });
}
