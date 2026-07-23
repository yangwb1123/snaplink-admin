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
