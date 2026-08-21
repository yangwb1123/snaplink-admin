import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/screens/portal/portal_api.dart';

void main() {
  test(
    'revokes the active bearer through the Snaplink logout endpoint',
    () async {
      final api = PortalApi(
        httpClient: MockClient((request) async {
          expect(request.headers['authorization'], 'Bearer portal-token');
          if (request.url.path == '/me') {
            expect(request.method, 'GET');
            return http.Response('{}', 200);
          }
          expect(request.method, 'POST');
          expect(request.url.path, '/logout');
          return http.Response('{}', 200);
        }),
      );

      await api.login('portal-token');
      await api.logout();

      expect(api.hasToken, isTrue);
      api.signOut();
      expect(api.hasToken, isFalse);
    },
  );

  test(
    'sends delegated organization role changes as JSON PUT requests',
    () async {
      final api = PortalApi(
        httpClient: MockClient((request) async {
          if (request.url.path == '/me') return http.Response('{}', 200);
          expect(request.method, 'PUT');
          expect(request.url.path, '/me/organizations/acme/members/user-1');
          expect(request.headers['content-type'], 'application/json');
          expect(request.body, '{"role":"admin"}');
          return http.Response('', 200);
        }),
      );

      await api.login('portal-token');
      final response = await api.put('/me/organizations/acme/members/user-1', {
        'role': 'admin',
      });
      expect(response.statusCode, 200);
    },
  );

  test('retains an explicit session id for opaque token strategies', () async {
    final api = PortalApi(
      httpClient: MockClient((request) async {
        expect(request.url.path, '/me');
        return http.Response('{}', 200);
      }),
    );

    await api.login(
      'opaque-session-token',
      sessionId: 'session-42',
      clientId: 'console-client',
    );

    expect(api.currentSessionId, 'session-42');
    expect(api.currentClientId, 'console-client');
  });

  test('sends the documented confirmation shape for account erasure', () async {
    final api = PortalApi(
      httpClient: MockClient((request) async {
        if (request.url.path == '/me') return http.Response('{}', 200);
        expect(request.method, 'POST');
        expect(request.url.path, '/me/account/erase');
        expect(request.body, '{"confirm":"user-1","dry_run":false}');
        return http.Response('{}', 200);
      }),
    );

    await api.login('portal-token');
    await api.post('/me/account/erase', {
      'confirm': 'user-1',
      'dry_run': false,
    });
  });

  test('times out a portal mutation without replaying it', () async {
    var attempts = 0;
    final api = PortalApi(
      requestTimeout: const Duration(milliseconds: 5),
      httpClient: MockClient((_) async {
        attempts++;
        await Future<void>.delayed(const Duration(milliseconds: 30));
        return http.Response('{}', 200);
      }),
    );

    await expectLater(
      api.post('/me/account/erase', {'confirm': 'user-1'}),
      throwsA(isA<TimeoutException>()),
    );
    expect(attempts, 1);
  });

  // ─── B6-2 portal session-expiry rollback pin (test-only) ───
  // Spec: docs/proposals/b6-2-lib-screens-portal-session-expiry-rollback-pin-spec.md

  group('AC-1 session-expiry hook firing matrix (REQ-1)', () {
    // 7 request paths × {401, 403, 500}: a 401 fires onSessionExpired
    // exactly once, 403 (trusted-device enrollment until MFA —
    // portal_api.dart:104-107) and 500 never do. The login probe is
    // gated on a request counter, not on url.path, so the matrix is
    // path-agnostic (the SSE path /me/notifications/stream is never
    // confused with the /me probe).
    const statuses = [401, 403, 500];
    const paths = [
      'get',
      'post',
      'patch',
      'put',
      'delete',
      'deleteWithQuery',
      'notificationEvents',
    ];

    for (final path in paths) {
      for (final status in statuses) {
        test('$path with HTTP $status', () async {
          var requests = 0;
          var fired = 0;
          final api = PortalApi(
            httpClient: MockClient((request) async {
              requests++;
              // First request = the login probe (/me), always accepted.
              return requests == 1
                  ? http.Response('{}', 200)
                  : http.Response('', status);
            }),
          );
          api.onSessionExpired = () => fired++;
          await api.login('t');

          Future<void> exercise() async {
            switch (path) {
              case 'get':
                await api.get('/sessions/me');
                break;
              case 'post':
                await api.post('/me/roles');
                break;
              case 'patch':
                await api.patch('/me/roles', <String, Object>{});
                break;
              case 'put':
                await api.put('/me/roles', <String, Object>{});
                break;
              case 'delete':
                await api.delete('/sessions/me');
                break;
              case 'deleteWithQuery':
                await api.deleteWithQuery('/sessions/me', query: {'a': 'b'});
                break;
              case 'notificationEvents':
                // Drain the stream: the SSE path fires the hook inline
                // (portal_api.dart:132-133) BEFORE throwing, so the
                // hook count must be settled once the stream errors.
                await expectLater(
                  api.notificationEvents(),
                  emitsError(
                    isA<PortalApiError>().having(
                      (e) => e.status,
                      'status',
                      status,
                    ),
                  ),
                );
            }
          }

          await exercise();
          final reason = status == 401
              ? '401 must invalidate the bearer exactly once'
              : '403/500 must not fire the hook (403 = feature-gated '
                    'state, e.g. trusted-device enrollment until MFA — '
                    'portal_api.dart:104-107)';
          expect(
            requests,
            2,
            reason:
                'login probe + exactly one exercised request; $path/$status',
          );
          expect(fired, status == 401 ? 1 : 0, reason: reason);
        });
      }
    }
  });

  group('AC-2 login() rollback and re-install (REQ-2)', () {
    test('rejected and failed attempts restore the previous state', () async {
      // /me answers 200 → 500 → transport error → 200 in request order.
      final answers = <Future<http.Response> Function()>[
        () async => http.Response('{}', 200),
        () async => http.Response('', 500),
        () async => throw http.ClientException('down'),
        () async => http.Response('{}', 200),
      ];
      var i = 0;
      final api = PortalApi(
        httpClient: MockClient((_) async => answers[i++]()),
      );

      // 1. First token accepted; explicit session/client ids installed.
      await api.login('first-token', sessionId: 's-1', clientId: 'c-1');
      expect(api.hasToken, isTrue);
      expect(api.currentSessionId, 's-1');
      expect(api.currentClientId, 'c-1');

      // 2. Non-200 probe rejection → previous state restored.
      await expectLater(
        api.login('second-token'),
        throwsA(isA<PortalApiError>().having((e) => e.status, 'status', 500)),
      );
      expect(api.hasToken, isTrue);
      expect(api.currentSessionId, 's-1');
      expect(api.currentClientId, 'c-1');

      // 3. Transport error → PortalApiError(0) and state restored again.
      await expectLater(
        api.login('third-token'),
        throwsA(isA<PortalApiError>().having((e) => e.status, 'status', 0)),
      );
      expect(api.hasToken, isTrue);
      expect(api.currentSessionId, 's-1');
      expect(api.currentClientId, 'c-1');

      // 4. Accepted token installs; opaque token → JWT decode fallback
      //    returns null for both getters (portal_api.dart:65/:70).
      await api.login('good-token');
      expect(api.hasToken, isTrue);
      expect(api.currentSessionId, isNull);
      expect(api.currentClientId, isNull);
    });
  });

  group('AC-3 fetchMe / fetchListOrEmpty error semantics (REQ-3)', () {
    PortalApi apiReturning(int status) {
      // First /me request = the login probe (200); subsequent requests
      // (fetchMe/fetchListOrEmpty) answer with [status].
      var requests = 0;
      return PortalApi(
        httpClient: MockClient((request) async {
          requests++;
          return requests == 1
              ? http.Response('{}', 200)
              : http.Response('', status);
        }),
      );
    }

    test('fetchMe throws PortalApiError on 404', () async {
      final api = apiReturning(404);
      await api.login('t');
      await expectLater(
        api.fetchMe(),
        throwsA(isA<PortalApiError>().having((e) => e.status, 'status', 404)),
      );
    });

    test('fetchMe throws PortalApiError on 500', () async {
      final api = apiReturning(500);
      await api.login('t');
      await expectLater(
        api.fetchMe(),
        throwsA(isA<PortalApiError>().having((e) => e.status, 'status', 500)),
      );
    });

    test('fetchMe decodes a successful profile response', () async {
      final api = PortalApi(
        httpClient: MockClient((request) async {
          if (request.url.path == '/me' && request.method == 'GET') {
            return http.Response('{"name":"x"}', 200);
          }
          return http.Response('', 200);
        }),
      );
      await api.login('t');
      final body = await api.fetchMe();
      expect(body, {'name': 'x'});
    });

    test('fetchListOrEmpty turns a 404 into const []', () async {
      final api = apiReturning(404);
      await api.login('t');
      expect(await api.fetchListOrEmpty('/me/roles', 'roles'), isEmpty);
    });

    test('fetchListOrEmpty turns a 500 into const []', () async {
      final api = apiReturning(500);
      await api.login('t');
      expect(await api.fetchListOrEmpty('/me/roles', 'roles'), isEmpty);
    });

    test('fetchListOrEmpty turns a transport error into const []', () async {
      final api = PortalApi(
        httpClient: MockClient((request) async {
          if (request.url.path == '/me' && request.method == 'GET') {
            return http.Response('{}', 200);
          }
          throw http.ClientException('down');
        }),
      );
      await api.login('t');
      expect(await api.fetchListOrEmpty('/me/roles', 'roles'), isEmpty);
    });

    test('fetchListOrEmpty returns the keyed list on 200', () async {
      final ok = PortalApi(
        httpClient: MockClient((request) async {
          if (request.url.path == '/me' && request.method == 'GET') {
            return http.Response('{}', 200);
          }
          return http.Response('{"roles":["a"]}', 200);
        }),
      );
      await ok.login('t');
      expect(await ok.fetchListOrEmpty('/me/roles', 'roles'), ['a']);
    });
  });

  group('AC-4 JWT claim decode through the public getters (REQ-4)', () {
    String b64url(String s) => base64Url.encode(utf8.encode(s));

    Future<PortalApi> apiFor(String token) async {
      final api = PortalApi(
        httpClient: MockClient((request) async => http.Response('{}', 200)),
      );
      await api.login(token);
      return api;
    }

    test('string sid/aud claims decode', () async {
      final api = await apiFor(
        'h.${b64url('{"sid":"s-9","aud":"console-client"}')}.s',
      );
      expect(api.hasToken, isTrue);
      expect(api.currentSessionId, 's-9');
      expect(api.currentClientId, 'console-client');
    });

    test('list-valued claims yield their first element', () async {
      final api = await apiFor(
        'h.${b64url('{"sid":["s-list","s-2"],"aud":["c-1","c-2"]}')}.s',
      );
      expect(api.hasToken, isTrue);
      expect(api.currentSessionId, 's-list');
      expect(api.currentClientId, 'c-1');
    });

    test('a token without dots has no decoded claims', () async {
      final api = await apiFor('no-dots');
      expect(api.hasToken, isTrue);
      expect(api.currentSessionId, isNull);
      expect(api.currentClientId, isNull);
    });

    test('a two-part token has no decoded claims', () async {
      final api = await apiFor('two.parts');
      expect(api.hasToken, isTrue);
      expect(api.currentSessionId, isNull);
      expect(api.currentClientId, isNull);
    });

    test('a four-part token has no decoded claims', () async {
      final api = await apiFor('a.b.c.d');
      expect(api.hasToken, isTrue);
      expect(api.currentSessionId, isNull);
      expect(api.currentClientId, isNull);
    });

    test('an invalid-base64 payload has no decoded claims', () async {
      final api = await apiFor('a.!!!.c');
      expect(api.hasToken, isTrue);
      expect(api.currentSessionId, isNull);
      expect(api.currentClientId, isNull);
    });

    test('a non-JSON payload has no decoded claims', () async {
      final api = await apiFor('a.${b64url('not json')}.c');
      expect(api.hasToken, isTrue);
      expect(api.currentSessionId, isNull);
      expect(api.currentClientId, isNull);
    });

    test('a non-map JSON payload has no decoded claims', () async {
      final api = await apiFor('a.${b64url('[1,2]')}.c');
      expect(api.hasToken, isTrue);
      expect(api.currentSessionId, isNull);
      expect(api.currentClientId, isNull);
    });
  });
}
