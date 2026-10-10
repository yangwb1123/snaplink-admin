import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';

void main() {
  test(
    'HTML/scalar/array 200 responses are not successful empty data',
    () async {
      for (final payload in [
        '<html>private proxy page</html>',
        'null',
        '[]',
        '42',
      ]) {
        var calls = 0;
        final api = SnaplinkAdminApi(
          baseUrl: 'https://sso.example.test',
          accessToken: 'fixture',
          httpClient: MockClient((_) async {
            calls++;
            return http.Response(payload, 200);
          }),
        );
        for (var attempt = 0; attempt < 2; attempt++) {
          await expectLater(
            api.get('/api/v1/admin/clients'),
            throwsA(
              isA<SnaplinkAdminApiError>()
                  .having((error) => error.code, 'code', 'invalid_response')
                  .having((error) => error.data, 'no response body', isEmpty),
            ),
          );
        }
        expect(calls, 2, reason: 'invalid payloads are not cached or retried');
        expect(api.cacheSize, 0);
      }
    },
  );

  test(
    'malformed inventory is unknown, not a successful disabled inventory',
    () async {
      for (final payload in [
        <String, dynamic>{},
        {'endpoints': null},
        {'endpoints': {}},
        {
          'endpoints': ['not an endpoint'],
        },
        {
          'endpoints': [{}],
        },
        {
          'endpoints': [
            {'method': 'GET', 'path': 'not-an-absolute-path'},
          ],
        },
      ]) {
        final api = SnaplinkAdminApi(
          baseUrl: 'https://sso.example.test',
          accessToken: 'fixture',
          httpClient: MockClient(
            (_) async => http.Response(jsonEncode(payload), 200),
          ),
        );
        await expectLater(
          api.listEndpoints(),
          throwsA(
            isA<SnaplinkAdminApiError>().having(
              (error) => error.code,
              'invalid inventory',
              'invalid_response',
            ),
          ),
        );
      }
    },
  );

  test('explicitly empty runtime inventory is valid', () async {
    final api = SnaplinkAdminApi(
      baseUrl: 'https://sso.example.test',
      accessToken: 'fixture',
      httpClient: MockClient(
        (_) async => http.Response('{"endpoints":[]}', 200),
      ),
    );
    expect(await api.listEndpoints(), isEmpty);
  });

  test(
    'capability refresh bypasses the previous successful inventory cache',
    () async {
      var calls = 0;
      final api = SnaplinkAdminApi(
        baseUrl: 'https://sso.example.test',
        accessToken: 'fixture',
        httpClient: MockClient((_) async {
          calls++;
          return http.Response(
            calls == 1
                ? '{"endpoints":[]}'
                : '{"endpoints":[{"method":"GET","path":"/api/v1/admin/connections"}]}',
            200,
          );
        }),
      );
      expect(await api.listEndpoints(), isEmpty);
      expect(await api.listEndpoints(), isEmpty);
      final refreshed = await api.listEndpoints(forceRefresh: true);
      expect(refreshed.single.path, '/api/v1/admin/connections');
      expect(calls, 2);
    },
  );

  test('nested proxy errors retain their code and actionable message', () async {
    final api = SnaplinkAdminApi(
      baseUrl: 'https://sso.example.test',
      accessToken: 'fixture',
      httpClient: MockClient(
        (_) async => http.Response(
          '{"error":{"code":"billing_unconfigured","message":"Configure the Billing upstream."}}',
          503,
        ),
      ),
    )..maxRetries = 0;
    await expectLater(
      api.get('/api/v1/admin/commerce/plans'),
      throwsA(
        isA<SnaplinkAdminApiError>()
            .having((error) => error.code, 'code', 'billing_unconfigured')
            .having(
              (error) => error.toString(),
              'message',
              'Configure the Billing upstream.',
            ),
      ),
    );
  });

  test('upstream HTML error status remains authoritative', () async {
    var unauthorizedCalls = 0;
    final api = SnaplinkAdminApi(
      baseUrl: 'https://sso.example.test',
      accessToken: 'fixture',
      onUnauthorized: () => unauthorizedCalls++,
      httpClient: MockClient(
        (_) async => http.Response('<html>private</html>', 403),
      ),
    );
    await expectLater(
      api.get('/api/v1/admin/clients'),
      throwsA(
        isA<SnaplinkAdminApiError>()
            .having((error) => error.status, 'status', 403)
            .having(
              (error) => error.toString(),
              'no HTML',
              isNot(contains('private')),
            ),
      ),
    );
    expect(unauthorizedCalls, 0);
  });

  test('an invalid mutation response never causes automatic replay', () async {
    var calls = 0;
    final api = SnaplinkAdminApi(
      baseUrl: 'https://sso.example.test',
      accessToken: 'fixture',
      httpClient: MockClient((_) async {
        calls++;
        return http.Response('<html>proxy page</html>', 200);
      }),
    );
    await expectLater(
      api.post('/api/v1/admin/clients', {'name': 'original'}),
      throwsA(isA<SnaplinkAdminApiError>()),
    );
    expect(calls, 1);
  });

  test('empty 204 mutation responses remain supported', () async {
    final api = SnaplinkAdminApi(
      baseUrl: 'https://sso.example.test',
      accessToken: 'fixture',
      httpClient: MockClient((_) async => http.Response('', 204)),
    );
    expect(await api.delete('/api/v1/admin/clients/client-1'), isEmpty);
  });
}
