import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/screens/admin/user_support_tab.dart';

void main() {
  testWidgets('clears a lockout with client_id and login identifier', (
    tester,
  ) async {
    Map<String, dynamic>? postedBody;
    final api = SnaplinkAdminApi(
      baseUrl: 'https://sso.example.test',
      accessToken: 'admin-token',
      httpClient: MockClient((request) async {
        if (request.method == 'POST') {
          expect(request.url.path, '/api/v1/admin/account-lockout/clear');
          postedBody = Map<String, dynamic>.from(
            jsonDecode(request.body) as Map,
          );
          return http.Response('', 204);
        }
        expect(request.method, 'GET');
        return http.Response('{}', 200);
      }),
    );
    const capabilities = SnaplinkAdminCapabilities([
      SnaplinkAdminEndpoint(
        method: 'POST',
        path: '/api/v1/admin/account-lockout/clear',
        feature: 'admin_api',
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UserSupportTab(api: api, capabilities: capabilities),
        ),
      ),
    );
    expect(find.byKey(const Key('lockout-client-id')), findsOneWidget);
    expect(find.byKey(const Key('lockout-identifier')), findsOneWidget);
    await tester.enterText(
      find.byKey(const Key('lockout-client-id')),
      'portal-client',
    );
    await tester.enterText(
      find.byKey(const Key('lockout-identifier')),
      'alice@example.com',
    );
    final clearButton = find.byKey(const Key('clear-account-lockout'));
    await tester.ensureVisible(clearButton);
    await tester.tap(clearButton);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear lockout'));
    await tester.pumpAndSettle();

    expect(postedBody, {
      'client_id': 'portal-client',
      'identifier': 'alice@example.com',
    });
    expect(postedBody, isNot(contains('user_id')));
  });
}
