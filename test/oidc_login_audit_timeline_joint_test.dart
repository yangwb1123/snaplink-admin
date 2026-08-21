@TestOn('vm')
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/audit_read_client.dart';
import 'package:sso_admin/api/oidc_login_api.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/api/sso_client.dart';
import 'package:sso_admin/screens/admin/audit_log_tab.dart';
import 'package:sso_admin/screens/oidc_login/oidc_login_screen.dart';
import 'package:sso_admin/services/local_storage.dart';

/// B6-1 AC-1 Phase B: one backend mock serves both the hosted login and the
/// server-fed audit timeline. The timeline row is evidence only because it
/// comes from the audit response; the login client never writes the local
/// debug ring.
class _JointHarness {
  _JointHarness() {
    final client = MockClient((request) async {
      paths.add(request.url.path);

      if (request.method == 'GET' && request.url.path == '/branding') {
        return http.Response('{}', 404);
      }
      if (request.method == 'GET' &&
          request.url.path == AuditReadClient.eventsPath) {
        return http.Response(
          jsonEncode({
            'events': [
              {
                'id': 'login-event-1',
                'type': 'auth.login.success',
                'outcome': 'success',
                'timestamp': '2026-08-20T12:00:00Z',
                'actor_id': 'user-1',
                'client_id': SSOAdminClient.firstPartyClientId,
                'tenant_id': 'tenant-1',
              },
            ],
            'count': 1,
          }),
          200,
        );
      }
      if (request.method == 'POST' && request.url.path == '/auth/login') {
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (body['credential'] is Map) {
          credentialPosts++;
          lastClientId = body['client_id'] as String?;
          return http.Response(
            jsonEncode({'access_token': 't', 'session_id': 's'}),
            200,
          );
        }
        probePosts++;
        return http.Response('{}', 404);
      }
      return http.Response('{}', 404);
    });
    loginApi = OidcLoginApi(
      baseUri: Uri.parse('https://sso.example/'),
      httpClient: client,
    );
    adminApi = SnaplinkAdminApi(
      baseUrl: 'https://sso.example',
      accessToken: 't',
      httpClient: client,
    );
  }

  late final OidcLoginApi loginApi;
  late final SnaplinkAdminApi adminApi;
  final List<String> paths = [];
  int credentialPosts = 0;
  int probePosts = 0;
  String? lastClientId;
}

Future<void> _pumpLogin(WidgetTester tester, OidcLoginApi api) async {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      home: OidcLoginScreen(
        api: api,
        defaultClientId: SSOAdminClient.firstPartyClientId,
        routeUri: Uri.parse('https://sso.example/login/'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _submitLogin(WidgetTester tester) async {
  await tester.enterText(
    find.widgetWithText(TextField, 'Username'),
    'ada@example.com',
  );
  await tester.enterText(find.widgetWithText(TextField, 'Password'), 'pw');
  await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
  await tester.pumpAndSettle();
}

void main() {
  group('OIDC login → server audit timeline joint contract', () {
    testWidgets(
      'one backend mock proves the login row is server truth',
      (tester) async {
        LocalStorage.removeItem('sso_audit_log');
        addTearDown(() => LocalStorage.removeItem('sso_audit_log'));

        final harness = _JointHarness();
        addTearDown(harness.loginApi.close);

        await _pumpLogin(tester, harness.loginApi);
        await _submitLogin(tester);

        expect(harness.probePosts, 1);
        expect(harness.credentialPosts, 1);
        expect(harness.lastClientId, SSOAdminClient.firstPartyClientId);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: AuditLogTab(
                api: harness.adminApi,
                capabilities: SnaplinkAdminCapabilities([
                  SnaplinkAdminEndpoint(
                    method: 'GET',
                    path: AuditReadClient.eventsPath,
                    feature: 'core',
                  ),
                ]),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('auth.login.success'), findsOneWidget);
        expect(find.text('1 entries'), findsOneWidget);
        expect(find.textContaining('tenant-1'), findsOneWidget);
        expect(LocalStorage.keys(), isNot(contains('sso_audit_log')));

        expect(
          harness.paths.toSet(),
          {
            '/branding',
            '/auth/login',
            AuditReadClient.eventsPath,
          },
        );
        expect(
          harness.paths.where((path) => path == '/auth/login'),
          hasLength(2),
          reason: 'one mount probe plus one credential-bearing login',
        );
        expect(
          harness.paths.where((path) => path == AuditReadClient.eventsPath),
          hasLength(1),
        );
      },
    );
  });
}
