import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/oidc_login_api.dart';
import 'package:sso_admin/screens/oidc_login/oidc_login_screen.dart';

/// Account-flow tests that drive the hosted login screen through its
/// forgot-password, signup and email-verification views (the flows in
/// oidc_account_flow.dart), selected by the URL's `flow` parameter.
void main() {
  group('OidcLoginScreen account flows', () {
    testWidgets('forgot password submits and shows a safe message', (
      tester,
    ) async {
      var posted = <String>[];
      final api = OidcLoginApi(
        httpClient: MockClient((request) async {
          if (request.url.path == '/auth/forgot-password') {
            posted.add(request.body);
            return http.Response('{}', 200);
          }
          return http.Response('{}', 404);
        }),
      );
            tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
await tester.pumpWidget(
        MaterialApp(
          home: OidcLoginScreen(
            api: api,
            defaultClientId: 'sso-admin-console',
            routeUri: Uri.parse(
              'https://sso.example/login/?flow=forgot_password',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Reset your password'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Username or email'),
        'ada@example.com',
      );
      await tester.tap(find.text('Send reset link'));
      await tester.pumpAndSettle();

      expect(posted.single, contains('"identifier":"ada@example.com"'));
      // Anti-enumeration: the success copy never claims an account exists.
      expect(
        find.textContaining(
          'If an eligible account exists, recovery instructions have been sent.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('forgot password surfaces a 404 deployment error', (
      tester,
    ) async {
      final api = OidcLoginApi(
        httpClient: MockClient((_) async => http.Response('{}', 404)),
      );
            tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
await tester.pumpWidget(
        MaterialApp(
          home: OidcLoginScreen(
            api: api,
            defaultClientId: 'sso-admin-console',
            routeUri: Uri.parse(
              'https://sso.example/login/?flow=forgot_password',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Username or email'),
        'ada@example.com',
      );
      await tester.tap(find.text('Send reset link'));
      await tester.pumpAndSettle();

      expect(
        find.text('Password recovery is not available for this deployment.'),
        findsOneWidget,
      );
    });

    testWidgets('signup registers an account', (tester) async {
      var posted = <String>[];
      final api = OidcLoginApi(
        httpClient: MockClient((request) async {
          if (request.url.path == '/auth/register') {
            posted.add(request.body);
            return http.Response(jsonEncode({'status': 'ok'}), 200);
          }
          return http.Response('{}', 404);
        }),
      );
            tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
await tester.pumpWidget(
        MaterialApp(
          home: OidcLoginScreen(
            api: api,
            defaultClientId: 'sso-admin-console',
            routeUri: Uri.parse('https://sso.example/login/?flow=signup'),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(find.widgetWithText(TextField, 'Username'), 'ada');
      await tester.enterText(
        find.widgetWithText(TextField, 'Email (optional)'),
        'ada@example.com',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Password'),
        'long-enough-password',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Confirm password'),
        'long-enough-password',
      );
      await tester.tap(find.text('Create an account').last);
      await tester.pumpAndSettle();

      expect(posted.single, contains('"username":"ada"'));
      expect(posted.single, contains('"email":"ada@example.com"'));
    });

    testWidgets('email verification consumes the URL token', (tester) async {
      var posted = <String>[];
      final api = OidcLoginApi(
        httpClient: MockClient((request) async {
          if (request.url.path == '/auth/verify-email') {
            posted.add(request.body);
            return http.Response(jsonEncode({'status': 'ok'}), 200);
          }
          return http.Response('{}', 404);
        }),
      );
            tester.view.physicalSize = const Size(900, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
await tester.pumpWidget(
        MaterialApp(
          home: OidcLoginScreen(
            api: api,
            defaultClientId: 'sso-admin-console',
            routeUri: Uri.parse(
              'https://sso.example/login/?flow=verify_email&token=verify-token',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Verify your email'), findsOneWidget);
      await tester.tap(find.text('Verify email'));
      await tester.pumpAndSettle();

      expect(posted.single, contains('"token":"verify-token"'));
    });
  });
}
