import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/sso_client.dart';

void main() {
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
          jsonEncode({'id': 'oidc-provider', 'name': 'OIDC Provider', 'status': 'active'}),
          200,
        );
      }),
    );
    await client.login('admin', 'password');
    final conn = await client.getConnection('oidc-provider');
    expect(conn['id'], 'oidc-provider');
    expect(conn['name'], 'OIDC Provider');
  });

  test('fetches a break-glass session by id', () async {
    var reqNum = 0;
    final client = SSOAdminClient(
      'https://sso.example.test',
      httpClient: MockClient((request) async {
        reqNum++;
        if (reqNum == 1) {
          return http.Response('{"access_token":"admin-token"}', 200);
        }
        expect(request.method, 'GET');
        expect(
          request.url.path,
          '/api/v1/admin/break-glass/session-123',
        );
        return http.Response(
          jsonEncode({'id': 'session-123', 'status': 'pending', 'requested_by': 'ops'}),
          200,
        );
      }),
    );
    await client.login('admin', 'password');
    final s = await client.getBreakGlassSession('session-123');
    expect(s['id'], 'session-123');
    expect(s['status'], 'pending');
  });

  test('fetches a webhook subscription by id', () async {
    var reqNum = 0;
    final client = SSOAdminClient(
      'https://sso.example.test',
      httpClient: MockClient((request) async {
        reqNum++;
        if (reqNum == 1) {
          return http.Response('{"access_token":"admin-token"}', 200);
        }
        expect(request.method, 'GET');
        expect(
          request.url.path,
          '/api/v1/admin/webhooks/subscriptions/webhook-1',
        );
        return http.Response(
          jsonEncode({'id': 'webhook-1', 'url': 'https://hook.example.com/callback', 'active': true}),
          200,
        );
      }),
    );
    await client.login('admin', 'password');
    final w = await client.getWebhookSubscription('webhook-1');
    expect(w['id'], 'webhook-1');
    expect(w['active'], true);
  });

  test('fetches a domain by hostname', () async {
    var reqNum = 0;
    final client = SSOAdminClient(
      'https://sso.example.test',
      httpClient: MockClient((request) async {
        reqNum++;
        if (reqNum == 1) return http.Response('{"access_token":"admin-token"}', 200);
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/admin/domains/example.com');
        return http.Response(jsonEncode({'hostname': 'example.com', 'verified': true}), 200);
      }),
    );
    await client.login('admin', 'password');
    final d = await client.getDomain('example.com');
    expect(d['hostname'], 'example.com');
    expect(d['verified'], true);
  });

  test('fetches a crypto key by id', () async {
    var reqNum = 0;
    final client = SSOAdminClient(
      'https://sso.example.test',
      httpClient: MockClient((request) async {
        reqNum++;
        if (reqNum == 1) return http.Response('{"access_token":"admin-token"}', 200);
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/admin/crypto/keys/key-1');
        return http.Response(jsonEncode({'kid': 'key-1', 'algorithm': 'RS256', 'status': 'active'}), 200);
      }),
    );
    await client.login('admin', 'password');
    final k = await client.getCryptoKey('key-1');
    expect(k['kid'], 'key-1');
    expect(k['status'], 'active');
  });

  test('fetches a threat policy by id', () async {
    var reqNum = 0;
    final client = SSOAdminClient(
      'https://sso.example.test',
      httpClient: MockClient((request) async {
        reqNum++;
        if (reqNum == 1) return http.Response('{"access_token":"admin-token"}', 200);
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/admin/threat-policies/policy-1');
        return http.Response(jsonEncode({'id': 'policy-1', 'name': 'Block anomalous IPs', 'enabled': true}), 200);
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
        return http.Response('{}', 200);
      }),
    );
    await client.login('admin', 'password');

    await client.setTenantStatus('acme west/1', 'suspended');
  });
}
