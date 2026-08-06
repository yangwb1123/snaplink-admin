@TestOn('vm')
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/oidc_login_api.dart';
import 'package:sso_admin/screens/oidc_login/oidc_login_screen.dart';
import 'package:sso_admin/services/browser_navigation.dart';

void main() {
  setUp(() => BrowserNavigation.replaceState('/'));
  tearDown(() => BrowserNavigation.replaceState('/'));

  testWidgets('PAR delivers code only to the server-attested callback', (
    tester,
  ) async {
    final api = _loginApi({
      'code': 'authorization-code',
      'state': 'server-state',
      'iss': 'https://issuer.example',
      'redirect_uri': 'https://rp.example/callback?registered=one',
      'response_mode': 'query',
      'redirect_uri_validated': true,
    });
    addTearDown(api.close);

    await _submitPassword(
      tester,
      api,
      'client_id=rp&request_uri=urn%3Aietf%3Aparams%3Aoauth%3Arequest_uri%3A1&'
      'state=attacker-state&'
      'redirect_uri=https%3A%2F%2Fattacker.example%2Fsteal',
    );

    expect(BrowserNavigation.currentUri.origin, 'https://rp.example');
    expect(BrowserNavigation.currentUri.path, '/callback');
    expect(BrowserNavigation.currentUri.queryParameters, {
      'registered': 'one',
      'code': 'authorization-code',
      'state': 'server-state',
      'iss': 'https://issuer.example',
    });
  });

  testWidgets('PAR without effective delivery metadata remains fail closed', (
    tester,
  ) async {
    final api = _loginApi({
      'code': 'authorization-code',
      'state': 'server-state',
    });
    addTearDown(api.close);

    await _submitPassword(
      tester,
      api,
      'client_id=rp&request_uri=urn%3Aietf%3Aparams%3Aoauth%3Arequest_uri%3A1&'
      'redirect_uri=https%3A%2F%2Fattacker.example%2Fsteal',
    );

    expect(BrowserNavigation.currentUri.path, '/');
    expect(find.textContaining('server-validated'), findsOneWidget);
  });

  testWidgets('plain callback never invents state omitted by the server', (
    tester,
  ) async {
    final api = _loginApi({'code': 'authorization-code'});
    addTearDown(api.close);

    await _submitPassword(
      tester,
      api,
      'client_id=rp&response_type=code&state=browser-only-state&'
      'redirect_uri=https%3A%2F%2Frp.example%2Fcallback',
    );

    expect(BrowserNavigation.currentUri.queryParameters, {
      'code': 'authorization-code',
    });
  });

  testWidgets('a successful RP login without a response fails closed', (
    tester,
  ) async {
    final api = _loginApi(const {});
    addTearDown(api.close);

    await _submitPassword(
      tester,
      api,
      'client_id=rp&response_type=code&'
      'redirect_uri=https%3A%2F%2Frp.example%2Fcallback',
    );

    expect(BrowserNavigation.currentUri.path, '/');
    expect(find.textContaining('server-validated'), findsOneWidget);
  });

  testWidgets('a first-party 2xx without an access token is not success', (
    tester,
  ) async {
    final api = _loginApi(const {});
    addTearDown(api.close);

    await _submitPassword(tester, api, 'client_id=first-party');

    expect(
      find.textContaining('did not return an access token'),
      findsOneWidget,
    );
    expect(find.text('Signed in'), findsNothing);
  });

  testWidgets(
    'plain form_post rejects an action outside the registered callback',
    (tester) async {
      final api = _htmlLoginApi('''<!doctype html>
      <form method="POST" action="https://evil.example/steal">
        <input type="hidden" name="code" value="authorization-code">
      </form>''');
      addTearDown(api.close);

      await _submitPassword(
        tester,
        api,
        'client_id=rp&response_type=code&response_mode=form_post&'
        'redirect_uri=https%3A%2F%2Frp.example%2Fcallback',
      );

      expect(BrowserNavigation.currentUri.path, '/');
      expect(find.textContaining('server-validated'), findsOneWidget);
    },
  );

  testWidgets('a JARM mode never delivers a bare authorization code', (
    tester,
  ) async {
    final api = _loginApi({
      'code': 'unsigned-code',
      'redirect_uri': 'https://rp.example/callback',
      'response_mode': 'query.jwt',
      'redirect_uri_validated': true,
    });
    addTearDown(api.close);

    await _submitPassword(
      tester,
      api,
      'client_id=rp&request_uri=urn%3Aietf%3Aparams%3Aoauth%3Arequest_uri%3A1',
    );

    expect(BrowserNavigation.currentUri.path, '/');
    expect(find.textContaining('server-validated'), findsOneWidget);
  });
}

OidcLoginApi _loginApi(Map<String, dynamic> terminalResponse) => OidcLoginApi(
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
    return http.Response(jsonEncode(terminalResponse), 200);
  }),
);

OidcLoginApi _htmlLoginApi(String html) => OidcLoginApi(
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
      html,
      200,
      headers: {'content-type': 'text/html; charset=utf-8'},
    );
  }),
);

Future<void> _submitPassword(
  WidgetTester tester,
  OidcLoginApi api,
  String query,
) async {
  await tester.pumpWidget(
    MaterialApp(
      home: OidcLoginScreen(
        api: api,
        routeUri: Uri.parse('https://console.example/login/?$query'),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextField).at(0), 'person');
  await tester.enterText(find.byType(TextField).at(1), 'password');
  await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
  await tester.pumpAndSettle();
}
