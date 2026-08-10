import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/services/admin_oauth_resources.dart';
import 'package:sso_admin/sso_client.dart';

/// REQ-2 / AC-1 exactly-once harness for the `SSOAdminClient` leg (design
/// §3.1, D5/D6).
///
/// Closes the S1 gap: `test/sso_client_test.dart:10-27` asserts the
/// `/auth/login` body shape inside the MockClient handler but never counts
/// requests, so a second credential-bearing POST would pass silently. This
/// harness records every request and gates the total count:
/// one `login()` ⇒ exactly one credential-bearing `POST /auth/login`; two
/// `login()` calls ⇒ cumulative 2 (the unit-level "无重复" pin, mirroring
/// the hosted-leg retry pin at `test/oidc_login_screen_client_id_test.dart:155`).
///
/// The recording client is strict by construction (D5): `SSOAdminClient.login`
/// performs no probe, so any request that is not a credential-bearing
/// `POST /auth/login` fails the test immediately — a hypothetical probe or a
/// non-login call can never be masked by a post-hoc filter.
class _LoginHarness {
  _LoginHarness() {
    client = MockClient((request) async {
      if (request.method != 'POST' || request.url.path != '/auth/login') {
        fail(
          'login() must not issue ${request.method} ${request.url.path} — '
          'SSOAdminClient.login performs no probe and no other request '
          '(D5/F5)',
        );
      }
      final decoded = jsonDecode(request.body);
      if (decoded is! Map<String, dynamic> ||
          decoded['credential'] is! Map) {
        fail(
          'POST /auth/login without a credential map — a credential-less '
          'probe is forbidden (D5/D9 parity)',
        );
      }
      recorded.add(
        _RecordedLogin(
          method: request.method,
          path: request.url.path,
          body: decoded,
        ),
      );
      return http.Response('{"access_token":"admin-token"}', 200);
    });
  }

  late final MockClient client;

  /// Every credential-bearing `POST /auth/login` sent through [client].
  final List<_RecordedLogin> recorded = [];
}

class _RecordedLogin {
  const _RecordedLogin({
    required this.method,
    required this.path,
    required this.body,
  });

  final String method;
  final String path;
  final Map<String, dynamic> body;
}

/// The AC-1 exactly-one gate. Shared by the acceptance tests and the binding
/// meta-tests below, so the property "the assert cannot pass while a second
/// credential-bearing POST occurs" is executed, not just intended.
void _expectExactlyOneCredentialLogin(
  List<_RecordedLogin> recorded, {
  String? reason,
}) {
  expect(
    recorded.length,
    1,
    reason:
        reason ??
        'exactly one credential-bearing POST /auth/login per login() — '
            'found ${recorded.length}',
  );
  expect(recorded.single.method, 'POST',
      reason: 'the single request must be a POST');
  expect(recorded.single.path, '/auth/login',
      reason: 'the single request must target /auth/login');
}

/// The AC-1 cumulative-2 gate: two `login()` calls ⇒ exactly two requests
/// (one per call — never 1-then-0 and never 2-in-one).
void _expectCumulativeTwo(List<_RecordedLogin> recorded) {
  expect(
    recorded.length,
    2,
    reason: 'two login() calls must yield exactly two requests (cumulative '
        '2, one per call) — found ${recorded.length}',
  );
}

void main() {
  group('SSOAdminClient.login exactly-once emission (REQ-2 / AC-1)', () {
    test('login() issues exactly one credential-bearing POST /auth/login',
        () async {
      final harness = _LoginHarness();
      final client = SSOAdminClient(
        'https://sso.example.test',
        httpClient: harness.client,
      );

      await client.login('admin', 'password');

      _expectExactlyOneCredentialLogin(harness.recorded);
      expect(client.isLoggedIn, isTrue,
          reason: 'the access_token from the single response installs the '
              'session');
    });

    test(
      'the single request carries the credential body with the '
      'first-party client id (F4/F6) — scalar asserts, credential value '
      'never enters a diff',
      () async {
        final harness = _LoginHarness();
        final client = SSOAdminClient(
          'https://sso.example.test',
          httpClient: harness.client,
        );

        await client.login('admin', 'password');

        // Scalar asserts (D9-parity style, hardened per the security
        // review): exact values for every non-secret field; the password is
        // asserted as a non-empty String only, so its value can never
        // appear in a failure diff (whole-map equality would render the
        // credential on mismatch). The client_id site is the compile-time
        // constant reference (constant-mode, zero literals — the census
        // isEmpty branch stays green; REQ-2 two-state rule).
        final body = harness.recorded.single.body;
        expect(body['provider'], 'password');
        expect(body['client_id'], SSOAdminClient.firstPartyClientId);
        expect(body['scope'], ['openid', 'profile', 'admin:read', 'admin:write']);
        expect(body['resource'], AdminOAuthResources.values);
        final credential = body['credential'];
        expect(credential, isA<Map<String, dynamic>>(),
            reason: 'the credential must be a map');
        final credentialMap = credential as Map<String, dynamic>;
        expect(credentialMap['username'], 'admin');
        expect(credentialMap['password'], isA<String>(),
            reason: 'the password must be a string');
        expect((credentialMap['password'] as String).isNotEmpty, isTrue,
            reason: 'the password must be non-empty — only its shape, '
                'never its value, may enter an assertion diff');
      },
    );

    test(
      'the strict recording client trips on any non-login or '
      'credential-less request (no probe, F5)',
      () async {
        final harness = _LoginHarness();

        // A hypothetical probe GET (hosted-leg-style mount probe) must fail
        // the harness — SSOAdminClient.login performs none.
        await expectLater(
          harness.client.get(Uri.parse('https://sso.example.test/me')),
          throwsA(isA<TestFailure>()),
        );
        // A credential-less POST to the same path (probe shape) must fail too.
        await expectLater(
          harness.client.post(
            Uri.parse('https://sso.example.test/auth/login'),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode({'client_id': 'drifted-client'}),
          ),
          throwsA(isA<TestFailure>()),
        );
      },
    );

    test(
      'a second login() adds exactly one more request (cumulative 2, '
      'per-call bounded)',
      () async {
        final harness = _LoginHarness();
        final client = SSOAdminClient(
          'https://sso.example.test',
          httpClient: harness.client,
        );

        await client.login('admin', 'password');
        expect(harness.recorded.length, 1,
            reason: 'first login must issue exactly one request');
        await client.login('admin', 'password');
        expect(harness.recorded.length, 2,
            reason: 'second login must issue exactly one more request — '
                '1-then-0 and 2-in-one both fail here');

        _expectCumulativeTwo(harness.recorded);
      },
    );

    test(
      'binding: the exactly-one gate cannot pass while a second '
      'credential-bearing POST occurs',
      () {
        // Zero-request login: must be rejected.
        expect(
          () => _expectExactlyOneCredentialLogin(const []),
          throwsA(isA<TestFailure>()),
        );
        // Two credential-bearing POST /auth/login (a doubled emission): the
        // gate must be red — this is exactly the S1 gap closed (a second
        // POST can never pass silently).
        const doubled = [
          _RecordedLogin(method: 'POST', path: '/auth/login', body: {
            'provider': 'password',
            'client_id': 'x',
            'credential': {'username': 'admin', 'password': 'password'},
          }),
          _RecordedLogin(method: 'POST', path: '/auth/login', body: {
            'provider': 'password',
            'client_id': 'x',
            'credential': {'username': 'admin', 'password': 'password'},
          }),
        ];
        expect(
          () => _expectExactlyOneCredentialLogin(doubled),
          throwsA(isA<TestFailure>()),
        );
      },
    );

    test(
      'binding: the cumulative-2 gate rejects a third request and a '
      'dropped second login',
      () {
        const one = _RecordedLogin(method: 'POST', path: '/auth/login', body: {
          'provider': 'password',
          'client_id': 'x',
          'credential': {'username': 'admin', 'password': 'password'},
        });
        expect(
          () => _expectCumulativeTwo(const [one]),
          throwsA(isA<TestFailure>()),
        );
        expect(
          () => _expectCumulativeTwo(const [one, one, one]),
          throwsA(isA<TestFailure>()),
        );
      },
    );
  });
}
