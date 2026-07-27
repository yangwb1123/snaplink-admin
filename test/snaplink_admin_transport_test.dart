import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/services/event_bus.dart';

void main() {
  test(
    'retries a transient GET and keeps the default 30 second timeout',
    () async {
      var attempts = 0;
      final api = SnaplinkAdminApi(
        baseUrl: 'https://sso.example.test',
        accessToken: 'admin-token',
        httpClient: MockClient((_) async {
          attempts++;
          return attempts == 1
              ? http.Response('{"error":"temporarily_unavailable"}', 503)
              : http.Response('{"status":"ok"}', 200);
        }),
      );
      api.maxRetries = 2;

      final result = await api.get(
        '/api/v1/admin/endpoints',
        forceRefresh: true,
      );

      expect(result['status'], 'ok');
      expect(attempts, 2);
      expect(api.requestTimeout, const Duration(seconds: 30));
    },
  );

  test(
    'a queried refresh does not leak its cache bypass to the next GET',
    () async {
      var attempts = 0;
      final api = SnaplinkAdminApi(
        baseUrl: 'https://sso.example.test',
        accessToken: 'admin-token',
        httpClient: MockClient((request) async {
          attempts++;
          return http.Response(
            request.url.path.endsWith('/users')
                ? '{"users":[]}'
                : '{"cached":true}',
            200,
          );
        }),
      );

      await api.get('/api/v1/admin/endpoints');
      api.skipCache();
      await api.get('/api/v1/admin/users', query: const {'page_size': '25'});
      final cached = await api.get('/api/v1/admin/endpoints');

      expect(cached['cached'], isTrue);
      expect(attempts, 2);
    },
  );

  test('does not automatically replay a failed mutation', () async {
    var attempts = 0;
    final api = SnaplinkAdminApi(
      baseUrl: 'https://sso.example.test',
      accessToken: 'admin-token',
      httpClient: MockClient((_) async {
        attempts++;
        return http.Response('{"error":"temporarily_unavailable"}', 503);
      }),
    );

    await expectLater(
      api.post('/api/v1/admin/clients', {'id': 'client-1'}),
      throwsA(
        isA<SnaplinkAdminApiError>().having(
          (error) => error.status,
          'status',
          503,
        ),
      ),
    );
    expect(attempts, 1);
  });

  test('times out but never replays an ambiguous mutation', () async {
    var attempts = 0;
    final api = SnaplinkAdminApi(
      baseUrl: 'https://sso.example.test',
      accessToken: 'admin-token',
      requestTimeout: const Duration(milliseconds: 1),
      httpClient: MockClient((_) async {
        attempts++;
        await Future<void>.delayed(const Duration(milliseconds: 20));
        return http.Response('{}', 200);
      }),
    );
    api.maxRetries = 3;

    await expectLater(
      api.patch('/api/v1/admin/clients/client-1', {'name': 'Updated'}),
      throwsA(isA<TimeoutException>()),
    );
    expect(attempts, 1);
  });

  test('preserves SCIM error type and detail', () async {
    final api = SnaplinkAdminApi(
      baseUrl: 'https://sso.example.test',
      accessToken: 'admin-token',
      httpClient: MockClient(
        (_) async => http.Response(
          '{"schemas":["urn:ietf:params:scim:api:messages:2.0:Error"],'
          '"status":"412","scimType":"mutability",'
          '"detail":"The resource version has changed."}',
          412,
          headers: {'content-type': 'application/scim+json'},
        ),
      ),
    );

    await expectLater(
      api.get('/api/v1/scim/v2/Users/user-1', forceRefresh: true),
      throwsA(
        isA<SnaplinkAdminApiError>()
            .having((error) => error.status, 'status', 412)
            .having((error) => error.code, 'code', 'mutability')
            .having(
              (error) => error.description,
              'description',
              'The resource version has changed.',
            ),
      ),
    );
  });

  test(
    'publishes the mutated domain rather than the admin path segment',
    () async {
      final api = SnaplinkAdminApi(
        baseUrl: 'https://sso.example.test',
        accessToken: 'admin-token',
        httpClient: MockClient((_) async => http.Response('{}', 200)),
      );
      DataChangedEvent? received;
      final subscription = EventBus().on<DataChangedEvent>().listen(
        (event) => received = event,
      );

      await api.put('/api/v1/admin/clients/client-1', {'name': 'Updated'});

      expect(received?.resourceType, 'clients');
      expect(received?.changeType, ChangeType.updated);
      await subscription.cancel();
    },
  );
}
