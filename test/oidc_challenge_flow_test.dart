import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/oidc_login_api.dart';
import 'package:sso_admin/screens/oidc_login/oidc_login_screen.dart';
import 'package:sso_admin/services/browser_navigation.dart';

/// 登录表单的用户名输入框。登录头现在包含一个 DropdownMenu 语言选择器
/// （内部也是 TextField），按类型索引不再稳定；用 autofillHints 定位。
Finder usernameField() => find.byWidgetPredicate(
  (widget) =>
      widget is TextField &&
      (widget.autofillHints?.contains(AutofillHints.username) ?? false),
);

Finder passwordField() => find.byWidgetPredicate(
  (widget) =>
      widget is TextField &&
      (widget.autofillHints?.contains(AutofillHints.password) ?? false),
);

void main() {
  setUp(() => BrowserNavigation.replaceState('/'));
  tearDown(() => BrowserNavigation.replaceState('/'));

  testWidgets('federated callback resumes once and delivers the RP code', (
    tester,
  ) async {
    final transactionId = 'A' * 43;
    var resumeRequests = 0;
    var discoveryRequests = 0;
    final api = OidcLoginApi(
      baseUri: Uri.parse('https://console.example/login/'),
      httpClient: MockClient((request) async {
        if (request.url.path == '/branding') return http.Response('{}', 404);
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (body['login_transaction_id'] == null) {
          discoveryRequests++;
          return http.Response('{}', 500);
        }
        resumeRequests++;
        expect(body, {
          'client_id': 'rp-client',
          'login_transaction_id': transactionId,
        });
        expect(BrowserNavigation.currentUri.fragment, isEmpty);
        return http.Response(
          jsonEncode({
            'code': 'federated-code',
            'state': 'original-rp-state',
            'redirect_uri': 'https://rp.example/callback',
            'response_mode': 'query',
            'redirect_uri_validated': true,
          }),
          200,
        );
      }),
    );
    addTearDown(api.close);

    await tester.pumpWidget(
      MaterialApp(
        home: OidcLoginScreen(
          api: api,
          routeUri: Uri.parse(
            'https://console.example/login/?client_id=rp-client&'
            'response_type=code&redirect_uri=https%3A%2F%2Frp.example%2Fcallback'
            '#login_transaction_id=$transactionId',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(resumeRequests, 1);
    expect(discoveryRequests, 0);
    expect(BrowserNavigation.currentUri.origin, 'https://rp.example');
    expect(BrowserNavigation.currentUri.queryParameters, {
      'code': 'federated-code',
      'state': 'original-rp-state',
    });
  });

  testWidgets('federated callback resumes into the shared MFA flow', (
    tester,
  ) async {
    final transactionId = 'B' * 43;
    var resumeRequests = 0;
    final api = OidcLoginApi(
      baseUri: Uri.parse('https://console.example/login/'),
      httpClient: MockClient((request) async {
        if (request.url.path == '/branding') return http.Response('{}', 404);
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body['login_transaction_id'], transactionId);
        resumeRequests++;
        return http.Response(
          '{"error":"mfa_required","mfa_challenge_id":"federated-mfa",'
          '"mfa_methods":["totp"]}',
          200,
        );
      }),
    );
    addTearDown(api.close);

    await tester.pumpWidget(
      MaterialApp(
        home: OidcLoginScreen(
          api: api,
          routeUri: Uri.parse(
            'https://console.example/login/?client_id=rp-client&'
            'response_type=code&redirect_uri=https%3A%2F%2Frp.example%2Fcallback'
            '#login_transaction_id=$transactionId',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(resumeRequests, 1);
    expect(BrowserNavigation.currentUri.fragment, isEmpty);
    expect(find.text('Verify your identity'), findsOneWidget);
  });

  testWidgets('consent continues only with the server transaction', (
    tester,
  ) async {
    Map<String, dynamic>? consentPayload;
    final api = OidcLoginApi(
      baseUri: Uri.parse('https://console.example/login/'),
      httpClient: MockClient((request) async {
        if (request.url.path == '/branding') return http.Response('{}', 404);
        if (request.url.path != '/auth/login') {
          return http.Response('{}', 404);
        }
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (body['credential'] == null &&
            body['login_transaction_id'] == null) {
          return http.Response(
            '{"providers":[{"id":"password","type":"builtin"}]}',
            200,
          );
        }
        if (body['credential'] != null) {
          expect(body['credential'], {
            'username': 'person',
            'password': 'primary-secret',
          });
          return http.Response(
            jsonEncode({
              'error': 'consent_required',
              'consent_challenge_id': 'consent-1',
              'login_transaction_id': 'transaction-1',
              'client_name': 'Example RP',
              'scopes': [
                {'scope': 'openid', 'description': 'Verify your identity'},
              ],
            }),
            200,
          );
        }
        consentPayload = body;
        return http.Response('{"error":"invalid_request"}', 400);
      }),
    );
    addTearDown(api.close);

    await tester.pumpWidget(
      MaterialApp(
        home: OidcLoginScreen(
          api: api,
          routeUri: Uri.parse(
            'https://console.example/login/?client_id=rp-client&'
            'response_type=code&redirect_uri=https%3A%2F%2Frp.example%2Fcb',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(usernameField(), 'person');
    await tester.enterText(passwordField(), 'primary-secret');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Example RP wants access'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Allow'));
    await tester.pumpAndSettle();

    expect(consentPayload, {
      'client_id': 'rp-client',
      'login_transaction_id': 'transaction-1',
      'consent_challenge_id': 'consent-1',
      'consent_decision': 'allow',
    });
    expect(jsonEncode(consentPayload), isNot(contains('primary-secret')));
  });

  testWidgets('missing consent transaction fails closed', (tester) async {
    var credentialRequests = 0;
    final api = OidcLoginApi(
      baseUri: Uri.parse('https://console.example/login/'),
      httpClient: MockClient((request) async {
        if (request.url.path == '/branding') return http.Response('{}', 404);
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (body['credential'] == null) {
          return http.Response(
            '{"providers":[{"id":"password","type":"builtin"}]}',
            200,
          );
        }
        credentialRequests++;
        return http.Response(
          jsonEncode({
            'error': 'consent_required',
            'consent_challenge_id': 'legacy-consent',
            'scopes': ['openid'],
          }),
          200,
        );
      }),
    );
    addTearDown(api.close);

    await tester.pumpWidget(
      MaterialApp(
        home: OidcLoginScreen(
          api: api,
          routeUri: Uri.parse(
            'https://console.example/login/?client_id=rp-client&'
            'response_type=code&redirect_uri=https%3A%2F%2Frp.example%2Fcb',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(usernameField(), 'person');
    await tester.enterText(passwordField(), 'primary-secret');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    final allow = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Allow'),
    );
    expect(allow.onPressed, isNull);
    expect(
      find.textContaining('secure authorization transaction'),
      findsOneWidget,
    );
    expect(credentialRequests, 1);
  });

  testWidgets('an ambiguous consent result cannot replay its transaction', (
    tester,
  ) async {
    var consentRequests = 0;
    final api = OidcLoginApi(
      baseUri: Uri.parse('https://console.example/login/'),
      httpClient: MockClient((request) async {
        if (request.url.path == '/branding') return http.Response('{}', 404);
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (body['credential'] == null &&
            body['login_transaction_id'] == null) {
          return http.Response(
            '{"providers":[{"id":"password","type":"builtin"}]}',
            200,
          );
        }
        if (body['credential'] != null) {
          return http.Response(
            jsonEncode({
              'error': 'consent_required',
              'consent_challenge_id': 'consent-once',
              'login_transaction_id': 'transaction-once',
              'scopes': ['openid'],
            }),
            200,
          );
        }
        consentRequests++;
        throw http.ClientException('response lost');
      }),
    );
    addTearDown(api.close);

    await tester.pumpWidget(
      MaterialApp(
        home: OidcLoginScreen(
          api: api,
          routeUri: Uri.parse(
            'https://console.example/login/?client_id=rp-client&'
            'response_type=code&redirect_uri=https%3A%2F%2Frp.example%2Fcb',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(usernameField(), 'person');
    await tester.enterText(passwordField(), 'primary-secret');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Allow'));
    await tester.pumpAndSettle();

    final allow = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Allow'),
    );
    expect(allow.onPressed, isNull);
    expect(find.textContaining('result is unknown'), findsOneWidget);
    expect(consentRequests, 1);
  });

  testWidgets('entering MFA clears the primary password', (tester) async {
    final api = OidcLoginApi(
      baseUri: Uri.parse('https://console.example/login/'),
      httpClient: MockClient((request) async {
        if (request.url.path == '/branding') return http.Response('{}', 404);
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (body['credential'] == null) {
          return http.Response(
            '{"providers":[{"id":"password","type":"builtin"}]}',
            200,
          );
        }
        return http.Response(
          '{"error":"mfa_required","mfa_challenge_id":"mfa-1",'
          '"mfa_methods":["totp"]}',
          200,
        );
      }),
    );
    addTearDown(api.close);

    await tester.pumpWidget(
      MaterialApp(
        home: OidcLoginScreen(
          api: api,
          routeUri: Uri.parse(
            'https://console.example/login/?client_id=first-party',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(usernameField(), 'person');
    await tester.enterText(passwordField(), 'primary-secret');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Verify your identity'), findsOneWidget);
    expect(find.text('Trust this device'), findsNothing);
    await tester.tap(find.widgetWithText(TextButton, 'Back'));
    await tester.pumpAndSettle();

    final password = tester.widget<TextField>(passwordField());
    expect(password.controller?.text, isEmpty);
  });

  testWidgets(
    'incomplete MFA responses fail closed before rendering a challenge',
    (tester) async {
      var mfaRequests = 0;
      final api = OidcLoginApi(
        baseUri: Uri.parse('https://console.example/login/'),
        httpClient: MockClient((request) async {
          if (request.url.path == '/branding') return http.Response('{}', 404);
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          if (body['credential'] == null) {
            return http.Response(
              '{"providers":[{"id":"password","type":"builtin"}]}',
              200,
            );
          }
          mfaRequests++;
          return http.Response(
            '{"error":"mfa_required","mfa_methods":["totp"]}',
            200,
          );
        }),
      );
      addTearDown(api.close);

      await tester.pumpWidget(
        MaterialApp(
          home: OidcLoginScreen(
            api: api,
            routeUri: Uri.parse(
              'https://console.example/login/?client_id=first-party',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(usernameField(), 'person');
      await tester.enterText(passwordField(), 'password');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(mfaRequests, 1);
      expect(find.text('Verify your identity'), findsNothing);
      expect(
        find.textContaining('incomplete verification challenge'),
        findsOneWidget,
      );
    },
  );

  testWidgets('malformed MFA methods fail closed without a type error', (
    tester,
  ) async {
    final api = OidcLoginApi(
      baseUri: Uri.parse('https://console.example/login/'),
      httpClient: MockClient((request) async {
        if (request.url.path == '/branding') return http.Response('{}', 404);
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (body['credential'] == null) {
          return http.Response(
            '{"providers":[{"id":"password","type":"builtin"}]}',
            200,
          );
        }
        return http.Response(
          '{"error":"mfa_required","mfa_methods":"totp"}',
          200,
        );
      }),
    );
    addTearDown(api.close);

    await tester.pumpWidget(
      MaterialApp(
        home: OidcLoginScreen(
          api: api,
          routeUri: Uri.parse(
            'https://console.example/login/?client_id=first-party',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.enterText(usernameField(), 'person');
    await tester.enterText(passwordField(), 'password');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Verify your identity'), findsNothing);
    expect(
      find.textContaining('incomplete verification challenge'),
      findsOneWidget,
    );
  });
}
