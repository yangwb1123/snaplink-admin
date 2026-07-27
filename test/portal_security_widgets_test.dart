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
}
