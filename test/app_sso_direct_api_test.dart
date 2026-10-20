import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/sso_client.dart';
import 'package:sso_admin/services/admin_oauth_resources.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/session.dart';

void main() {
  setUp(() {
    Session.clear();
    BrowserNavigation.resetForTest();
  });
  tearDown(() {
    Session.clear();
    BrowserNavigation.resetForTest();
  });

  test('direct password API installs only its caller-local token', () async {
    final requests = <http.Request>[];
    final transport = MockClient((request) async {
      requests.add(request);
      if (request.method == 'POST') {
        expect(request.url.path, '/auth/login');
        expect(request.headers.containsKey('authorization'), isFalse);
        expect(jsonDecode(request.body), {
          'provider': 'password',
          'client_id': SSOAdminClient.firstPartyClientId,
          'scope': ['openid', 'profile', 'admin:read', 'admin:write'],
          if (AdminOAuthResources.values.isNotEmpty)
            'resource': AdminOAuthResources.values,
          'credential': {
            'username': 'fixture-user',
            'password': 'fixture-password',
          },
        });
        return http.Response('{"access_token":"fixture-a-access"}', 200);
      }
      return http.Response('{}', 200);
    });
    addTearDown(transport.close);
    final a = SSOAdminClient(
      'https://op.example.invalid',
      httpClient: transport,
    );
    final b = SSOAdminClient(
      'https://op.example.invalid',
      httpClient: transport,
    );
    final location = BrowserNavigation.currentUri;
    Session.store('fixture-existing-session');

    await a.login('fixture-user', 'fixture-password');
    expect(a.isLoggedIn, isTrue);
    expect(b.isLoggedIn, isFalse);
    expect(Session.read(), 'fixture-existing-session');
    expect(Session.readForClient(SSOAdminClient.firstPartyClientId), isNull);
    expect(BrowserNavigation.currentUri, location);
    expect(requests, hasLength(1));

    await b.probeAdminAccess();
    expect(requests.last.headers.containsKey('authorization'), isFalse);
    await a.probeAdminAccess();
    expect(requests.last.headers['authorization'], 'Bearer fixture-a-access');
    expect(requests.where((request) => request.method == 'POST'), hasLength(1));
    expect(b.isLoggedIn, isFalse);
  });

  test(
    'unknown direct login result is not replayed or installed late',
    () async {
      final response = Completer<http.Response>();
      var calls = 0;
      final transport = MockClient((request) {
        calls++;
        return response.future;
      });
      addTearDown(transport.close);
      final client = SSOAdminClient(
        'https://op.example.invalid',
        httpClient: transport,
        requestTimeout: const Duration(milliseconds: 1),
      );
      await expectLater(
        client.login('fixture-user', 'fixture-password'),
        throwsA(isA<TimeoutException>()),
      );
      response.complete(
        http.Response('{"access_token":"fixture-late-access"}', 200),
      );
      await Future<void>.delayed(Duration.zero);
      expect(calls, 1);
      expect(client.isLoggedIn, isFalse);
      expect(Session.read(), isNull);
    },
  );
}
