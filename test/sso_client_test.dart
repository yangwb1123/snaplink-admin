import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/sso_client.dart';

void main() {
  test('direct Admin login requests the default OAuth resources', () async {
    final client = SSOAdminClient(
      'https://sso.example.test',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/auth/login');
        expect(jsonDecode(request.body), {
          'provider': 'password',
          'client_id': 'sso-admin-console',
          'scope': ['openid', 'profile', 'admin:read', 'admin:write'],
          'resource': ['billing-api', 'stripe-adapter-api'],
          'credential': {'username': 'admin', 'password': 'password'},
        });
        return http.Response('{"access_token":"admin-token"}', 200);
      }),
    );

    await client.login('admin', 'password');

    expect(client.isLoggedIn, isTrue);
  });

  test('preserves list paging, order, and filter query parameters', () async {
    var requestNumber = 0;
    final client = SSOAdminClient(
      'https://sso.example.test',
      httpClient: MockClient((request) async {
        requestNumber++;
        if (requestNumber == 1) {
          expect(request.method, 'POST');
          expect(request.url.path, '/auth/login');
          return http.Response('{"access_token":"admin-token"}', 200);
        }
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/admin/clients');
        expect(request.headers['authorization'], 'Bearer admin-token');
        expect(request.url.queryParameters, {
          'page_token': 'cursor-100',
          'page_size': '25',
          'order_by': '-name',
          'filter': 'active:true',
        });
        return http.Response(
          jsonEncode({
            'clients': [
              {'id': 'portal', 'name': 'Portal'},
            ],
            'next_page_token': 'cursor-125',
            'total_size': 172,
          }),
          200,
        );
      }),
    );
    await client.login('admin', 'password');

    final page = await client.listClients(
      pageToken: 'cursor-100',
      pageSize: 25,
      orderBy: '-name',
      filter: 'active:true',
    );

    expect(page.items.single['id'], 'portal');
    expect(page.nextPageToken, 'cursor-125');
    expect(page.totalSize, 172);
  });

  test('pages tenant lists using Snaplink tenant filter fields', () async {
    var requestNumber = 0;
    final client = SSOAdminClient(
      'https://sso.example.test',
      httpClient: MockClient((request) async {
        requestNumber++;
        if (requestNumber == 1) {
          return http.Response('{"access_token":"admin-token"}', 200);
        }
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/admin/tenants');
        expect(request.url.queryParameters, {
          'page_size': '25',
          'order_by': 'slug',
          'filter': 'status:active',
        });
        return http.Response(
          jsonEncode({
            'tenants': [
              {'id': 'acme', 'slug': 'acme', 'status': 'active'},
            ],
            'total_size': 1,
          }),
          200,
        );
      }),
    );
    await client.login('admin', 'password');

    final page = await client.listTenants(
      pageSize: 25,
      orderBy: 'slug',
      filter: 'status:active',
    );

    expect(page.items.single['slug'], 'acme');
    expect(page.nextPageToken, isNull);
    expect(page.totalSize, 1);
  });

  test('fetches a connection by id', () async {
    var reqNum = 0;
    final client = SSOAdminClient(
      'https://sso.example.test',
      httpClient: MockClient((request) async {
        reqNum++;
        if (reqNum == 1) {
          return http.Response('{"access_token":"admin-token"}', 200);
        }
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/admin/connections/oidc-provider');
        expect(request.headers['authorization'], 'Bearer admin-token');
        return http.Response(
          jsonEncode({
            'id': 'oidc-provider',
            'name': 'OIDC Provider',
            'status': 'active',
          }),
          200,
        );
      }),
    );
    await client.login('admin', 'password');
    final conn = await client.getConnection('oidc-provider');
    expect(conn['id'], 'oidc-provider');
    expect(conn['name'], 'OIDC Provider');
  });

  test('filters a break-glass session from the collection route', () async {
    var reqNum = 0;
    final client = SSOAdminClient(
      'https://sso.example.test',
      httpClient: MockClient((request) async {
        reqNum++;
        if (reqNum == 1) {
          return http.Response('{"access_token":"admin-token"}', 200);
        }
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/admin/break-glass');
        return http.Response(
          jsonEncode({
            'sessions': [
              {'id': 'other', 'status': 'active'},
              {'id': 'session-123', 'status': 'pending', 'requested_by': 'ops'},
            ],
          }),
          200,
        );
      }),
    );
    await client.login('admin', 'password');
    final s = await client.getBreakGlassSession('session-123');
    expect(s['id'], 'session-123');
    expect(s['status'], 'pending');
  });

  test('filters a webhook subscription from the collection route', () async {
    var reqNum = 0;
    final client = SSOAdminClient(
      'https://sso.example.test',
      httpClient: MockClient((request) async {
        reqNum++;
        if (reqNum == 1) {
          return http.Response('{"access_token":"admin-token"}', 200);
        }
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/admin/webhooks/subscriptions');
        return http.Response(
          jsonEncode({
            'subscriptions': [
              {
                'id': 'webhook-1',
                'url': 'https://hook.example.com/callback',
                'disabled': false,
              },
            ],
          }),
          200,
        );
      }),
    );
    await client.login('admin', 'password');
    final w = await client.getWebhookSubscription('webhook-1');
    expect(w['id'], 'webhook-1');
    expect(w['disabled'], false);
  });

  test('fetches a domain by hostname', () async {
    var reqNum = 0;
    final client = SSOAdminClient(
      'https://sso.example.test',
      httpClient: MockClient((request) async {
        reqNum++;
        if (reqNum == 1) {
          return http.Response('{"access_token":"admin-token"}', 200);
        }
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/admin/domains/example.com');
        return http.Response(
          jsonEncode({'hostname': 'example.com', 'verified': true}),
          200,
        );
      }),
    );
    await client.login('admin', 'password');
    final d = await client.getDomain('example.com');
    expect(d['hostname'], 'example.com');
    expect(d['verified'], true);
  });

  test('filters a crypto key by key_id from the inventory route', () async {
    var reqNum = 0;
    final client = SSOAdminClient(
      'https://sso.example.test',
      httpClient: MockClient((request) async {
        reqNum++;
        if (reqNum == 1) {
          return http.Response('{"access_token":"admin-token"}', 200);
        }
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/admin/crypto/keys');
        return http.Response(
          jsonEncode({
            'keys': [
              {'key_id': 'key-1', 'algorithm': 'RS256', 'status': 'active'},
            ],
          }),
          200,
        );
      }),
    );
    await client.login('admin', 'password');
    final k = await client.getCryptoKey('key-1');
    expect(k['key_id'], 'key-1');
    expect(k['status'], 'active');
  });

  test('prefers an active credential version from the inventory', () async {
    var reqNum = 0;
    final client = SSOAdminClient(
      'https://sso.example.test',
      httpClient: MockClient((request) async {
        reqNum++;
        if (reqNum == 1) {
          return http.Response('{"access_token":"admin-token"}', 200);
        }
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/admin/credentials');
        return http.Response(
          jsonEncode({
            'credentials': [
              {
                'id': 'webhook_hmac/v2',
                'type': 'webhook_hmac',
                'status': 'retiring',
              },
              {
                'id': 'webhook_hmac/v3',
                'type': 'webhook_hmac',
                'status': 'active',
              },
            ],
          }),
          200,
        );
      }),
    );
    await client.login('admin', 'password');

    final credential = await client.getCredential('webhook_hmac');

    expect(credential['id'], 'webhook_hmac/v3');
  });

  test('filters access policies by stable policy name', () async {
    var reqNum = 0;
    final client = SSOAdminClient(
      'https://sso.example.test',
      httpClient: MockClient((request) async {
        reqNum++;
        if (reqNum == 1) {
          return http.Response('{"access_token":"admin-token"}', 200);
        }
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/admin/access-policies');
        return http.Response(
          jsonEncode({
            'policies': [
              {'name': 'restrict-admin-access', 'enabled': true},
            ],
          }),
          200,
        );
      }),
    );
    await client.login('admin', 'password');

    final policy = await client.getAccessPolicy('restrict-admin-access');

    expect(policy['enabled'], true);
  });

  test('updates a connection through the collection upsert route', () async {
    var reqNum = 0;
    final client = SSOAdminClient(
      'https://sso.example.test',
      httpClient: MockClient((request) async {
        reqNum++;
        if (reqNum == 1) {
          return http.Response('{"access_token":"admin-token"}', 200);
        }
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/admin/connections');
        expect(jsonDecode(request.body), {
          'id': 'oidc-provider',
          'tenant_id': 'tenant-1',
          'type': 'oidc',
        });
        return http.Response(
          '{"id":"oidc-provider","tenant_id":"tenant-1","type":"oidc"}',
          200,
        );
      }),
    );
    await client.login('admin', 'password');

    final connection = await client.updateConnection('oidc-provider', {
      'id': 'must-not-win',
      'tenant_id': 'tenant-1',
      'type': 'oidc',
    });

    expect(connection['id'], 'oidc-provider');
  });

  test('fetches a threat policy by id', () async {
    var reqNum = 0;
    final client = SSOAdminClient(
      'https://sso.example.test',
      httpClient: MockClient((request) async {
        reqNum++;
        if (reqNum == 1) {
          return http.Response('{"access_token":"admin-token"}', 200);
        }
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/admin/threat-policies/policy-1');
        return http.Response(
          jsonEncode({
            'id': 'policy-1',
            'name': 'Block anomalous IPs',
            'enabled': true,
          }),
          200,
        );
      }),
    );
    await client.login('admin', 'password');
    final p = await client.getThreatPolicy('policy-1');
    expect(p['id'], 'policy-1');
    expect(p['enabled'], true);
  });

  test('encodes tenant IDs when changing status', () async {
    var requestNumber = 0;
    final client = SSOAdminClient(
      'https://sso.example.test',
      httpClient: MockClient((request) async {
        requestNumber++;
        if (requestNumber == 1) {
          return http.Response('{"access_token":"admin-token"}', 200);
        }
        expect(request.method, 'POST');
        expect(
          request.url.path,
          '/api/v1/admin/tenants/acme%20west%2F1:set-status',
        );
        expect(jsonDecode(request.body), {'status': 'suspended'});
        return http.Response(
          '{"credential_revocation":{"complete":true,'
          '"refresh_tokens_revoked":2,"sessions_revoked":1,"results":[]}}',
          200,
        );
      }),
    );
    await client.login('admin', 'password');

    final response = await client.setTenantStatus('acme west/1', 'suspended');
    expect(response['credential_revocation'], isA<Map>());
  });

  test(
    'bounds a core mutation without replaying an ambiguous timeout',
    () async {
      var requestNumber = 0;
      final client = SSOAdminClient(
        'https://sso.example.test',
        requestTimeout: const Duration(milliseconds: 10),
        httpClient: MockClient((request) async {
          requestNumber++;
          if (request.url.path == '/auth/login') {
            return http.Response('{"access_token":"admin-token"}', 200);
          }
          await Future<void>.delayed(const Duration(milliseconds: 50));
          return http.Response('{}', 200);
        }),
      );
      await client.login('admin', 'password');

      await expectLater(
        client.deleteClient('client-1'),
        throwsA(isA<TimeoutException>()),
      );

      expect(client.requestTimeout, const Duration(milliseconds: 10));
      expect(requestNumber, 2);
    },
  );

  test('a 401 expires the in-memory session and notifies the gate', () async {
    var requestNumber = 0;
    var unauthorizedCalls = 0;
    final client = SSOAdminClient(
      'https://sso.example.test',
      onUnauthorized: () => unauthorizedCalls++,
      httpClient: MockClient((_) async {
        requestNumber++;
        return requestNumber == 1
            ? http.Response('{"access_token":"admin-token"}', 200)
            : http.Response('{"error":"invalid_token"}', 401);
      }),
    );
    await client.login('admin', 'password');

    await expectLater(
      client.listClients(),
      throwsA(isA<SSOError>().having((error) => error.status, 'status', 401)),
    );

    expect(client.isLoggedIn, isFalse);
    expect(unauthorizedCalls, 1);
  });

  test('admin access probe uses the read-only runtime inventory', () async {
    var requestNumber = 0;
    final client = SSOAdminClient(
      'https://sso.example.test',
      httpClient: MockClient((request) async {
        requestNumber++;
        if (requestNumber == 1) {
          return http.Response('{"access_token":"admin-token"}', 200);
        }
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/admin/endpoints');
        expect(request.headers['authorization'], 'Bearer admin-token');
        return http.Response('{"status":"ok","endpoints":[]}', 200);
      }),
    );
    await client.login('admin', 'password');

    await client.probeAdminAccess();

    expect(requestNumber, 2);
    expect(client.isLoggedIn, isTrue);
  });

  test('a 403 preserves a valid under-scoped session', () async {
    var requestNumber = 0;
    var unauthorizedCalls = 0;
    final client = SSOAdminClient(
      'https://sso.example.test',
      onUnauthorized: () => unauthorizedCalls++,
      httpClient: MockClient((_) async {
        requestNumber++;
        return requestNumber == 1
            ? http.Response('{"access_token":"admin-token"}', 200)
            : http.Response('{"error":"insufficient_scope"}', 403);
      }),
    );
    await client.login('admin', 'password');

    await expectLater(
      client.listClients(),
      throwsA(isA<SSOError>().having((error) => error.status, 'status', 403)),
    );

    expect(client.isLoggedIn, isTrue);
    expect(unauthorizedCalls, 0);
  });
}
