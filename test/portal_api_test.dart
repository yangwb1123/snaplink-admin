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
}
