import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/screens/admin/snaplink_admin_api.dart';

void main() {
  group('SnaplinkAdminCapabilities', () {
    const endpoints = [
      SnaplinkAdminEndpoint(
        method: 'GET',
        path: '/api/v1/admin/tenants/:id/members',
        feature: 'admin_api',
      ),
      SnaplinkAdminEndpoint(
        method: 'POST',
        path: '/api/v1/admin/tenants/:id/invitations',
        feature: 'admin_api',
      ),
    ];

    test('matches a route by exact method and wire path', () {
      final capabilities = SnaplinkAdminCapabilities(endpoints);

      expect(
        capabilities.has('get', '/api/v1/admin/tenants/:id/members'),
        isTrue,
      );
      expect(
        capabilities.has('PUT', '/api/v1/admin/tenants/:id/members'),
        isFalse,
      );
      expect(
        capabilities.hasAnyPathPrefix('/api/v1/admin/tenants/:id/'),
        isTrue,
      );
      expect(capabilities.featureCounts, {'admin_api': 2});
    });

    test(
      'resolves only documented path parameters and URL-encodes their values',
      () {
        const endpoint = SnaplinkAdminEndpoint(
          method: 'DELETE',
          path: '/api/v1/admin/tenants/:id/invitations/:email',
          feature: 'admin_api',
        );

        expect(endpoint.pathParameters, ['id', 'email']);
        expect(
          endpoint.resolvePath({
            'id': 'acme west',
            'email': 'person+ops@example.test',
          }),
          '/api/v1/admin/tenants/acme%20west/invitations/person%2Bops%40example.test',
        );
        expect(() => endpoint.resolvePath({'id': 'acme'}), throwsArgumentError);
      },
    );

    test('keeps custom-verb suffixes while resolving OpenAPI parameters', () {
      const endpoint = SnaplinkAdminEndpoint(
        method: 'POST',
        path: '/api/v1/admin/tenants/{id}:set-status',
        feature: 'documented',
      );

      expect(endpoint.pathParameters, ['id']);
      expect(
        endpoint.resolvePath({'id': 'acme'}),
        '/api/v1/admin/tenants/acme:set-status',
      );
    });

    test('keeps the documented Snaplink management surface available', () {
      final routes = SnaplinkAdminOperationCatalog.endpoints
          .map((endpoint) => '${endpoint.method} ${endpoint.path}')
          .toSet();

      expect(routes, contains('POST /api/v1/admin/break-glass'));
      expect(routes, contains('GET /api/v1/clients/{id}'));
      expect(routes, contains('POST /api/v1/admin/snapshots/{id}:restore'));
      expect(
        routes,
        contains('PUT /api/v1/admin/permissions/{client_id}/menus'),
      );
      expect(routes, contains('PATCH /api/v1/scim/v2/Users/{id}'));
      expect(routes.length, SnaplinkAdminOperationCatalog.endpoints.length);
    });
  });

  test('reads Snaplink runtime endpoint inventory', () async {
    final client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.url.path, '/api/v1/admin/endpoints');
      expect(request.headers['authorization'], 'Bearer admin-token');
      return http.Response(
        '{"status":"ok","endpoints":[{"method":"GET","path":"/api/v1/admin/endpoints","feature":"admin_api"}]}',
        200,
      );
    });
    final api = SnaplinkAdminApi(
      baseUrl: 'https://sso.example.test',
      accessToken: 'admin-token',
      httpClient: client,
    );

    final endpoints = await api.listEndpoints();

    expect(endpoints, hasLength(1));
    expect(endpoints.single.path, '/api/v1/admin/endpoints');
  });

  test(
    'supports the SCIM content type required by the documented API',
    () async {
      final api = SnaplinkAdminApi(
        baseUrl: 'https://sso.example.test',
        accessToken: 'admin-token',
        httpClient: MockClient((request) async {
          expect(request.headers['content-type'], 'application/scim+json');
          expect(request.headers['accept'], 'application/scim+json');
          return http.Response('{}', 200);
        }),
      );

      await api.post('/api/v1/scim/v2/Users', {
        'userName': 'operator',
      }, 'application/scim+json');
    },
  );

  test('keeps the embedded API documentation response as text', () async {
    final api = SnaplinkAdminApi(
      baseUrl: 'https://sso.example.test',
      accessToken: 'admin-token',
      httpClient: MockClient((request) async {
        expect(request.headers['authorization'], 'Bearer admin-token');
        expect(request.headers['accept'], contains('text/html'));
        return http.Response('<html><title>Snaplink</title></html>', 200);
      }),
    );

    final document = await api.getText('/api/v1/admin/docs');

    expect(document, contains('<title>Snaplink</title>'));
  });

  test(
    'keeps a tenant export as an attachment, including multi-status data',
    () async {
      final api = SnaplinkAdminApi(
        baseUrl: 'https://sso.example.test',
        accessToken: 'admin-token',
        httpClient: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/api/v1/admin/tenants/acme/export');
          expect(
            request.headers['accept'],
            contains('application/octet-stream'),
          );
          return http.Response.bytes(
            [0x50, 0x4b, 0x03, 0x04],
            207,
            headers: {
              'content-type': 'application/zip',
              'content-disposition':
                  "attachment; filename*=UTF-8''acme%20export.zip",
            },
          );
        }),
      );

      final export = await api.postDownload(
        '/api/v1/admin/tenants/acme/export',
      );

      expect(export.bytes, [0x50, 0x4b, 0x03, 0x04]);
      expect(export.contentType, 'application/zip');
      expect(export.filename, 'acme export.zip');
    },
  );

  test(
    'keeps structured failure details and signals expired admin sessions',
    () async {
      var unauthorizedCalls = 0;
      final api = SnaplinkAdminApi(
        baseUrl: 'https://sso.example.test',
        accessToken: 'expired-token',
        onUnauthorized: () => unauthorizedCalls++,
        httpClient: MockClient(
          (_) async => http.Response(
            '{"error":"invalid_token","error_description":"Expired"}',
            401,
          ),
        ),
      );

      await expectLater(
        api.get('/api/v1/admin/endpoints'),
        throwsA(
          isA<SnaplinkAdminApiError>()
              .having((error) => error.status, 'status', 401)
              .having((error) => error.code, 'code', 'invalid_token'),
        ),
      );
      expect(unauthorizedCalls, 1);
    },
  );

  test('keeps durable operation ID from gRPC error details', () async {
    final api = SnaplinkAdminApi(
      baseUrl: 'https://sso.example.test',
      accessToken: 'admin-token',
      httpClient: MockClient(
        (_) async => http.Response(
          '{"code":13,"message":"restore failed","details":['
          '{"@type":"type.googleapis.com/google.rpc.ErrorInfo",'
          '"reason":"OPERATION_FAILED","metadata":{'
          '"operation_id":"op_restore_42",'
          '"operation_url":"/api/v1/admin/operations/op_restore_42"}}]}',
          500,
        ),
      ),
    );

    await expectLater(
      api.post('/api/v1/admin/snapshots/snap-1:restore', const {}),
      throwsA(
        isA<SnaplinkAdminApiError>().having(
          (error) => error.operationId,
          'operation ID',
          'op_restore_42',
        ),
      ),
    );
  });

  test('downloads a subject export without decoding its PII JSON', () async {
    final api = SnaplinkAdminApi(
      baseUrl: 'https://sso.example.test',
      accessToken: 'admin-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/compliance/users/ada/export');
        expect(request.url.queryParameters['format'], 'portable');
        expect(request.headers['accept'], contains('application/octet-stream'));
        return http.Response.bytes(
          [0x7b, 0x22, 0x73, 0x75, 0x62, 0x6a, 0x65, 0x63, 0x74, 0x22, 0x7d],
          200,
          headers: {'content-type': 'application/json'},
        );
      }),
    );

    final export = await api.getDownload(
      '/api/v1/compliance/users/ada/export',
      query: const {'format': 'portable'},
    );

    expect(export.contentType, 'application/json');
    expect(export.bytes, isNotEmpty);
  });

  test('keeps a valid but under-scoped admin session on a 403', () async {
    var unauthorizedCalls = 0;
    final api = SnaplinkAdminApi(
      baseUrl: 'https://sso.example.test',
      accessToken: 'read-only-token',
      onUnauthorized: () => unauthorizedCalls++,
      httpClient: MockClient(
        (_) async => http.Response(
          '{"error":"insufficient_scope","error_description":"admin:write required"}',
          403,
        ),
      ),
    );

    await expectLater(
      api.post('/api/v1/admin/snapshots', const {}),
      throwsA(
        isA<SnaplinkAdminApiError>().having(
          (error) => error.status,
          'status',
          403,
        ),
      ),
    );
    expect(unauthorizedCalls, 0);
  });

  test('parses a bearer-authenticated admin event stream', () async {
    final api = SnaplinkAdminApi(
      baseUrl: 'https://sso.example.test',
      accessToken: 'admin-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.headers['accept'], 'text/event-stream');
        expect(request.headers['authorization'], 'Bearer admin-token');
        expect(request.url.queryParameters['event_types'], 'login,logout');
        expect(request.headers['last-event-id'], 'previous');
        return http.Response(
          'id: 41\nevent: login\ndata: {"id":"41","actor":"operator"}\n\n'
          'id: 42\ndata: {"id":"42","tenant":"acme"}\n\n',
          200,
          headers: {'content-type': 'text/event-stream'},
        );
      }),
    );

    final events = await api
        .streamAdminEvents(eventTypes: 'login,logout', lastEventId: 'previous')
        .toList();

    expect(events, hasLength(2));
    expect(events.first.id, '41');
    expect(events.first.type, 'login');
    expect(events.first.data['actor'], 'operator');
    expect(events.last.type, 'message');
    expect(events.last.data['tenant'], 'acme');
  });
}
