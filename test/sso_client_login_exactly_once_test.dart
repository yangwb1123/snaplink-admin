// test/sso_client_login_exactly_once_test.dart
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/sso_client.dart';

/// Direct-leg counting harness: counts credential-bearing POST /auth/login
/// dispatches of SSOAdminClient.login (D9 filter, mirroring the hosted-leg
/// _LoginHarness). Reads/probe return 200 {} unless [authExpired] flips.
/// Invariant: the exercised flows (login/probe/read/401-expiry) issue exactly
/// one POST total — the scripted credential-bearing /auth/login. ANY other
/// POST (credential-less /auth/login, refresh-grant on any path, extra
/// endpoint) increments [probePosts] and throws, so it reddens the test
/// deterministically instead of hiding in an unasserted bucket.
class _DirectLoginHarness {
  _DirectLoginHarness(List<String> script) : script = List.of(script) {
    client = SSOAdminClient(
      'https://sso.example.test',
      onUnauthorized: () => unauthorizedCalls++,
      httpClient: MockClient((request) async {
        if (request.method == 'POST' && request.url.path == '/auth/login') {
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          final isLogin = body['credential'] is Map; // D9 filter
          if (isLogin) {
            loginPosts++;
            lastClientId = body['client_id'] as String?;
            lastUsername = (body['credential'] as Map)['username'] as String?;
            if (script.removeAt(0) == 'fail') {
              return http.Response(
                jsonEncode({'error': 'invalid_credentials'}),
                401,
              );
            }
            return http.Response(jsonEncode({'access_token': 't'}), 200);
          }
          probePosts++; // credential-less POST — mount-probe analog (parity)
          throw StateError(
            'unscripted POST ${request.url.path} (probePosts=$probePosts)',
          );
        } else if (request.method == 'POST') {
          // POST to any other path (e.g. a refresh-grant endpoint): also an
          // unscripted dispatch — same deterministic red.
          probePosts++;
          throw StateError(
            'unscripted POST ${request.url.path} (probePosts=$probePosts)',
          );
        } else if (request.method == 'GET' && authExpired) {
          return http.Response(jsonEncode({'error': 'invalid_token'}), 401);
        }
        // Probe, reads, and anything else: absence shape (200 {}).
        return http.Response('{}', 200);
      }),
    );
  }

  final List<String> script;
  late final SSOAdminClient client;
  int loginPosts = 0;
  int probePosts = 0;
  int unauthorizedCalls = 0;
  bool authExpired = false; // when true, authenticated GETs return 401
  String? lastClientId;
  String? lastUsername;
}

void main() {
  // Test 1 — exactly one credential-bearing POST per login().
  test('direct login dispatches exactly one credential-bearing POST', () async {
    final h = _DirectLoginHarness(['ok']);
    await h.client.login('admin', 'password');
    expect(h.loginPosts, 1);
    expect(h.probePosts, 0); // no credential-less /auth/login echo
    expect(h.lastClientId, SSOAdminClient.firstPartyClientId);
    expect(h.lastUsername, 'admin');
  });

  // Test 2 — two sequential logins → cumulative 2 (retry-after-401 mirror).
  test('failed login then retry dispatches cumulative 2', () async {
    final h = _DirectLoginHarness(['fail', 'ok']);
    await expectLater(
      h.client.login('admin', 'password'),
      throwsA(isA<SSOError>().having((e) => e.status, 'status', 401)),
    );
    await h.client.login('admin', 'password');
    expect(h.loginPosts, 2);
    expect(h.lastClientId, SSOAdminClient.firstPartyClientId);
  });

  // Test 3 — probe/read/401-expiry paths add zero login POSTs.
  test('probe, read, and 401 expiry add zero login POSTs', () async {
    final h = _DirectLoginHarness(['ok']);
    await h.client.login('admin', 'password');
    expect(h.loginPosts, 1);

    await h.client.probeAdminAccess(); // GET /api/v1/admin/endpoints
    await h.client.listClients(); // GET /api/v1/admin/clients

    h.authExpired = true; // next authenticated read → 401
    await expectLater(
      h.client.listClients(),
      throwsA(isA<SSOError>().having((e) => e.status, 'status', 401)),
    );

    expect(h.loginPosts, 1); // no renewal, no re-login
    expect(h.probePosts, 0); // no credential-less POST anywhere
    expect(h.unauthorizedCalls, 1); // session cleared exactly once
  });
}
