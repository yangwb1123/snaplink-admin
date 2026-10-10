import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/oidc_login_api.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/screens/oidc_login/oidc_login_screen.dart';
import 'package:sso_admin/services/browser_navigation.dart';

const _authorization =
    'client_id=rp-b&response_type=code&'
    'redirect_uri=https%3A%2F%2Frp-b.example%2Fcallback&'
    'scope=openid%20b%3Aread&resource=b-api&state=b-state&nonce=b-nonce&'
    'code_challenge=bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb&'
    'code_challenge_method=S256';
const _capabilities = <String, dynamic>{
  'providers': [
    {'id': 'password', 'type': 'builtin'},
  ],
  'op_session_supported': true,
  'op_session_available': true,
};

Map<String, dynamic> _code() => {
  'code': 'b-code',
  'state': 'b-state',
  'iss': 'https://console.example',
  'redirect_uri': 'https://rp-b.example/callback',
  'redirect_uri_validated': true,
  'response_mode': 'query',
};

Finder _password() => find.byWidgetPredicate(
  (widget) =>
      widget is TextField &&
      (widget.autofillHints?.contains(AutofillHints.password) ?? false),
);

Future<List<Map<String, dynamic>>> _mount(
  WidgetTester tester, {
  String query = _authorization,
  Map<String, dynamic> capabilities = _capabilities,
  int discoveryStatus = 200,
  required Future<http.Response> Function(Map<String, dynamic>) handle,
}) async {
  final requests = <Map<String, dynamic>>[];
  final api = OidcLoginApi(
    baseUri: Uri.parse('https://console.example/login/'),
    httpClient: MockClient((request) async {
      if (request.url.path == '/branding') return http.Response('{}', 404);
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      requests.add(body);
      if (body.keys.every((key) => {'client_id', 'login_hint'}.contains(key))) {
        return http.Response(jsonEncode(capabilities), discoveryStatus);
      }
      return handle(body);
    }),
  );
  addTearDown(api.close);
  await tester.pumpWidget(
    MaterialApp(
      home: OidcLoginScreen(
        api: api,
        routeUri: Uri.parse('https://console.example/login/?$query'),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return requests;
}

void main() {
  setUp(() => BrowserNavigation.replaceState('/'));
  tearDown(() => BrowserNavigation.replaceState('/'));

  testWidgets('ordinary RP restores OP identity with its own full grant', (
    tester,
  ) async {
    final requests = await _mount(
      tester,
      handle: (body) async {
        expect(body, {
          'client_id': 'rp-b',
          'provider': '',
          'response_type': 'code',
          'redirect_uri': 'https://rp-b.example/callback',
          'scope': ['openid', 'b:read'],
          'resource': ['b-api'],
          'state': 'b-state',
          'nonce': 'b-nonce',
          'code_challenge': 'b' * 43,
          'code_challenge_method': 'S256',
          'resume_session': true,
        });
        expect(body.containsKey('credential'), isFalse);
        expect(body.containsKey('access_token'), isFalse);
        expect(body.containsKey('session_id'), isFalse);
        return http.Response(jsonEncode(_code()), 200);
      },
    );
    expect(requests.length, 2);
    expect(BrowserNavigation.currentUri.origin, 'https://rp-b.example');
    expect(BrowserNavigation.currentUri.queryParameters['code'], 'b-code');
    expect(BrowserNavigation.currentUri.queryParameters['state'], 'b-state');
  });

  for (final capabilities in [
    <String, dynamic>{'providers': _capabilities['providers']},
    {..._capabilities, 'op_session_available': false},
    {..._capabilities, 'op_session_supported': false},
  ]) {
    testWidgets('unsupported/absent identity session leaves normal login', (
      tester,
    ) async {
      final requests = await _mount(
        tester,
        capabilities: capabilities,
        handle: (_) async => throw StateError('unexpected resume'),
      );
      expect(requests.length, 1);
      expect(_password(), findsOneWidget);
      expect(BrowserNavigation.currentUri.path, '/');
    });
  }

  for (final query in [
    'prompt=login',
    'prompt=select_account',
    'max_age=0',
    'request_uri=urn%3Aietf%3Aparams%3Aoauth%3Arequest_uri%3Aone-use',
    'request=signed.request.object',
  ]) {
    testWidgets('automatic resume preserves $query boundary', (tester) async {
      final requests = await _mount(
        tester,
        query: '$_authorization&$query',
        handle: (_) async => throw StateError('unexpected resume'),
      );
      expect(requests.length, 1);
      expect(_password(), findsOneWidget);
    });
  }

  for (final error in [
    'login_required',
    'unmet_authentication_requirements',
    'passwordless_required',
    'authenticator_not_allowed',
    'authenticator_not_allowed_for_client',
  ]) {
    testWidgets('$error falls back to visible login, not RP error', (
      tester,
    ) async {
      final requests = await _mount(
        tester,
        handle: (_) async => http.Response(jsonEncode({'error': error}), 400),
      );
      expect(requests.length, 2);
      expect(_password(), findsOneWidget);
      expect(BrowserNavigation.currentUri.path, '/');
    });
  }

  testWidgets('SSO consent uses one-use continuation without password', (
    tester,
  ) async {
    final requests = await _mount(
      tester,
      handle: (body) async {
        if (body['resume_session'] == true) {
          return http.Response(
            jsonEncode({
              'error': 'consent_required',
              'consent_challenge_id': 'b-consent',
              'login_transaction_id': 'b-transaction',
              'client_name': 'App B',
              'scopes': [
                {'scope': 'openid', 'description': 'Verify identity'},
                {'scope': 'b:read', 'description': 'Read App B'},
              ],
            }),
            200,
          );
        }
        expect(body, {
          'client_id': 'rp-b',
          'login_transaction_id': 'b-transaction',
          'consent_challenge_id': 'b-consent',
          'consent_decision': 'allow',
        });
        return http.Response(jsonEncode(_code()), 200);
      },
    );
    expect(find.text('App B wants access'), findsOneWidget);
    expect(_password(), findsNothing);
    await tester.ensureVisible(find.widgetWithText(FilledButton, 'Allow'));
    await tester.tap(find.widgetWithText(FilledButton, 'Allow'));
    await tester.pumpAndSettle();
    expect(requests.length, 3);
    expect(BrowserNavigation.currentUri.queryParameters['code'], 'b-code');
  });

  testWidgets('SSO risk step-up enters the real MFA challenge', (tester) async {
    final requests = await _mount(
      tester,
      handle: (_) async => http.Response(
        '{"error":"mfa_required","mfa_challenge_id":"b-mfa",'
        '"mfa_methods":["totp"]}',
        200,
      ),
    );
    expect(requests.length, 2);
    expect(find.text('Verify your identity'), findsOneWidget);
    expect(_password(), findsNothing);
  });

  testWidgets('unavailable OP session probe is not treated as signed-out', (
    tester,
  ) async {
    final requests = await _mount(
      tester,
      capabilities: {
        ..._capabilities,
        'op_session_error': 'temporarily_unavailable',
      },
      handle: (_) async => throw StateError('unexpected resume'),
    );
    expect(requests.length, 1);
    expect(
      find.text(
        AppStrings.of(
          tester.element(find.byType(OidcLoginScreen)),
        ).networkError,
      ),
      findsOneWidget,
    );
  });

  testWidgets('failed discovery cannot authorize prompt none restoration', (
    tester,
  ) async {
    final requests = await _mount(
      tester,
      query: '$_authorization&prompt=none',
      discoveryStatus: 503,
      handle: (_) async => throw StateError('unexpected resume'),
    );
    expect(requests.length, 1);
    expect(BrowserNavigation.currentUri.path, '/');
    expect(BrowserNavigation.currentUri.queryParameters['error'], isNull);
    expect(
      find.text(
        'Snaplink did not provide a server-validated authorization '
        'continuation. No code, token, or error was redirected.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('ambiguous SSO result is not automatically replayed', (
    tester,
  ) async {
    final requests = await _mount(
      tester,
      handle: (_) async {
        throw StateError('response lost after authorization');
      },
    );
    await tester.pump(const Duration(seconds: 5));
    expect(requests.length, 2);
    expect(BrowserNavigation.currentUri.path, '/');
    expect(
      find.text(
        AppStrings.of(
          tester.element(find.byType(OidcLoginScreen)),
        ).networkError,
      ),
      findsOneWidget,
    );
  });

  testWidgets('prompt none uses the OP cookie without an RP token hint', (
    tester,
  ) async {
    final requests = await _mount(
      tester,
      query: '$_authorization&prompt=none',
      handle: (body) async {
        expect(body['prompt'], 'none');
        expect(body['resume_session'], true);
        expect(body.containsKey('id_token_hint'), isFalse);
        return http.Response(jsonEncode(_code()), 200);
      },
    );
    expect(requests.length, 2);
    expect(BrowserNavigation.currentUri.queryParameters['code'], 'b-code');
  });

  testWidgets('prompt none delivers login_required instead of showing login', (
    tester,
  ) async {
    await _mount(
      tester,
      query: '$_authorization&prompt=none',
      handle: (_) async => http.Response(
        jsonEncode({
          'error': 'login_required',
          'state': 'b-state',
          'redirect_uri': 'https://rp-b.example/callback',
          'redirect_uri_validated': true,
          'response_mode': 'query',
        }),
        400,
      ),
    );
    expect(
      BrowserNavigation.currentUri.queryParameters['error'],
      'login_required',
    );
    expect(BrowserNavigation.currentUri.queryParameters['state'], 'b-state');
  });
}
