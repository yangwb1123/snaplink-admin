@TestOn('browser')
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/oidc_login_api.dart';
import 'package:sso_admin/screens/oidc_login/oidc_login_screen.dart';
import 'package:sso_admin/screens/oidc_login/trusted_device_token.dart';
import 'package:web/web.dart' as web;

void main() {
  testWidgets(
    'plain federated RP flow also fails closed without resume support',
    (tester) async {
      final originalLocation =
          '${web.window.location.pathname}'
          '${web.window.location.search}'
          '${web.window.location.hash}';
      final api = OidcLoginApi(
        httpClient: MockClient((request) async {
          if (request.url.path == '/branding') return http.Response('{}', 404);
          if (request.url.path == '/auth/login') {
            return http.Response(
              '{"providers":[{"id":"workforce","type":"oidc",'
              '"display_name":"Workforce","builtin":false}]}',
              200,
            );
          }
          return http.Response('{}', 404);
        }),
      );
      addTearDown(() {
        api.close();
        web.window.history.replaceState(null, '', originalLocation);
      });

      await tester.pumpWidget(
        MaterialApp(
          home: OidcLoginScreen(
            api: api,
            routeUri: Uri.parse(
              'https://console.example/login/?client_id=rp&response_type=code&'
              'redirect_uri=https%3A%2F%2Frp.example%2Fcallback',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sign in with Workforce'));
      await tester.pumpAndSettle();

      expect(find.textContaining('securely resume'), findsOneWidget);
      expect(web.window.location.href, isNot(contains('/auth/login')));
    },
  );

  testWidgets('federated PAR cannot silently degrade on an older server', (
    tester,
  ) async {
    final originalLocation =
        '${web.window.location.pathname}'
        '${web.window.location.search}'
        '${web.window.location.hash}';
    final api = OidcLoginApi(
      httpClient: MockClient((request) async {
        if (request.url.path == '/branding') return http.Response('{}', 404);
        if (request.url.path == '/auth/login') {
          return http.Response(
            '{"providers":[{"id":"workforce","type":"oidc",'
            '"display_name":"Workforce","builtin":false}]}',
            200,
          );
        }
        return http.Response('{}', 404);
      }),
    );
    addTearDown(() {
      api.close();
      web.window.history.replaceState(null, '', originalLocation);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: OidcLoginScreen(
          api: api,
          routeUri: Uri.parse(
            'https://console.example/login/?client_id=rp&'
            'request_uri=urn%3Aietf%3Aparams%3Aoauth%3Arequest_uri%3Aone',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in with Workforce'));
    await tester.pumpAndSettle();

    expect(find.textContaining('preserves the server-owned'), findsOneWidget);
    expect(web.window.location.href, isNot(contains('/auth/login')));
  });

  testWidgets('an MFA challenge evicts the declined trusted-device grant', (
    tester,
  ) async {
    const clientId = 'stale-device-client';
    TrustedDeviceToken.store(clientId, 'stale-device-grant');
    addTearDown(() => TrustedDeviceToken.clear(clientId));
    final api = OidcLoginApi(
      httpClient: MockClient((request) async {
        if (request.url.path == '/branding') return http.Response('{}', 404);
        if (request.url.path == '/auth/login') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if (body['credential'] == null) {
            return http.Response(
              '{"providers":[{"id":"password","type":"builtin"}]}',
              200,
            );
          }
          expect(body['device_token'], 'stale-device-grant');
          return http.Response(
            '{"error":"mfa_required","mfa_challenge_id":"mfa-1",'
            '"mfa_methods":["totp"]}',
            200,
          );
        }
        return http.Response('{}', 404);
      }),
    );
    addTearDown(api.close);

    await tester.pumpWidget(
      MaterialApp(
        home: OidcLoginScreen(
          api: api,
          routeUri: Uri.parse(
            'https://console.example/login/?client_id=$clientId',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), 'person');
    await tester.enterText(find.byType(TextField).at(1), 'password');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Verify your identity'), findsOneWidget);
    expect(find.text('Trust this device'), findsOneWidget);
    expect(TrustedDeviceToken.read(clientId), isNull);
  });

  testWidgets('URL device credential is scrubbed and never submitted', (
    tester,
  ) async {
    final originalLocation =
        '${web.window.location.pathname}'
        '${web.window.location.search}'
        '${web.window.location.hash}';
    var credentialRequests = 0;
    final api = OidcLoginApi(
      httpClient: MockClient((request) async {
        if (request.url.path == '/branding') return http.Response('{}', 404);
        if (request.url.path == '/auth/login') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body, isNot(contains('device_token')));
          if (body['credential'] == null) {
            return http.Response(
              '{"providers":[{"id":"password","type":"builtin"}]}',
              200,
            );
          }
          credentialRequests++;
          return http.Response('{"error":"invalid_grant"}', 400);
        }
        return http.Response('{}', 404);
      }),
    );
    addTearDown(() {
      api.close();
      web.window.history.replaceState(null, '', originalLocation);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: OidcLoginScreen(
          api: api,
          routeUri: Uri.parse(
            'https://console.example/login/?client_id=url-token-client&'
            'device_token=bearer-secret&scope=openid#sensitive-fragment',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(web.window.location.pathname, '/login/');
    expect(
      web.window.location.search,
      '?client_id=url-token-client&scope=openid',
    );
    expect(web.window.location.hash, isEmpty);
    expect(web.window.location.href, isNot(contains('bearer-secret')));

    await tester.enterText(find.byType(TextField).at(0), 'user');
    await tester.enterText(find.byType(TextField).at(1), 'password');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(credentialRequests, 1);
  });

  testWidgets('password reset scrubs its verifier before submitting', (
    tester,
  ) async {
    final originalLocation =
        '${web.window.location.pathname}'
        '${web.window.location.search}'
        '${web.window.location.hash}';
    var resetRequests = 0;
    final api = OidcLoginApi(
      httpClient: MockClient((request) async {
        if (request.url.path == '/branding') return http.Response('{}', 404);
        if (request.url.path == '/auth/reset-password') {
          resetRequests++;
          expect(jsonDecode(request.body), {
            'token': 'reset-secret',
            'new_password': 'replacement-password',
          });
          return http.Response('{}', 200);
        }
        return http.Response('{}', 404);
      }),
    );
    addTearDown(() {
      api.close();
      web.window.history.replaceState(null, '', originalLocation);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: OidcLoginScreen(
          api: api,
          routeUri: Uri.parse(
            'https://console.example/login/?flow=reset&token=reset-secret&'
            'client_id=client-1#sensitive-fragment',
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.enterText(
      find.byType(TextField).at(0),
      'replacement-password',
    );
    await tester.enterText(
      find.byType(TextField).at(1),
      'replacement-password',
    );
    await tester.tap(find.text('Update password'));
    await tester.pumpAndSettle();

    expect(resetRequests, 1);
    expect(find.text('Password updated'), findsOneWidget);
    expect(find.text('Update password'), findsNothing);
    expect(web.window.location.pathname, '/login/');
    expect(web.window.location.search, '?client_id=client-1');
    expect(web.window.location.hash, isEmpty);
    expect(web.window.location.href, isNot(contains('reset-secret')));
  });

  testWidgets('email verification consumes and scrubs its verifier', (
    tester,
  ) async {
    final originalLocation =
        '${web.window.location.pathname}'
        '${web.window.location.search}'
        '${web.window.location.hash}';
    var verificationRequests = 0;
    final api = OidcLoginApi(
      httpClient: MockClient((request) async {
        if (request.url.path == '/branding') return http.Response('{}', 404);
        if (request.url.path == '/auth/verify-email') {
          verificationRequests++;
          expect(jsonDecode(request.body), {'token': 'verify-secret'});
          return http.Response('{}', 200);
        }
        return http.Response('{}', 404);
      }),
    );
    addTearDown(() {
      api.close();
      web.window.history.replaceState(null, '', originalLocation);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: OidcLoginScreen(
          api: api,
          routeUri: Uri.parse(
            'https://console.example/login/?flow=verify_email&'
            'token=verify-secret&source=signup#sensitive-fragment',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Verify email'));
    await tester.pumpAndSettle();

    expect(verificationRequests, 1);
    expect(find.text('Email verified'), findsOneWidget);
    expect(web.window.location.search, '?source=signup');
    expect(web.window.location.href, isNot(contains('verify-secret')));
  });

  testWidgets('magic link is removed before its one login attempt', (
    tester,
  ) async {
    final originalLocation =
        '${web.window.location.pathname}'
        '${web.window.location.search}'
        '${web.window.location.hash}';
    var loginRequests = 0;
    final api = OidcLoginApi(
      httpClient: MockClient((request) async {
        if (request.url.path == '/branding') return http.Response('{}', 404);
        if (request.url.path == '/auth/login') {
          loginRequests++;
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['client_id'], 'client-1');
          expect(body['credential'], {
            'email': 'user@example.test',
            'code': 'magic-secret',
          });
          return http.Response('{"error":"invalid_grant"}', 400);
        }
        return http.Response('{}', 404);
      }),
    );
    addTearDown(() {
      api.close();
      web.window.history.replaceState(null, '', originalLocation);
    });

    await tester.pumpWidget(
      MaterialApp(
        home: OidcLoginScreen(
          api: api,
          routeUri: Uri.parse(
            'https://console.example/login/?flow=magiclink&'
            'token=magic-secret&email=user%40example.test&client_id=client-1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(loginRequests, 1);
    expect(web.window.location.search, '?client_id=client-1');
    expect(web.window.location.href, isNot(contains('magic-secret')));
    expect(web.window.location.href, isNot(contains('user%40example.test')));
  });
}
