import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/screens/admin/scim/scim_directory_tab.dart';
import 'package:sso_admin/screens/admin/scim/scim_models.dart';

void main() {
  test('uses SCIM media type and exact list query contract', () async {
    final api = SnaplinkAdminApi(
      baseUrl: 'https://sso.example.test',
      accessToken: 'admin-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '$scimBasePath/Users');
        expect(request.url.queryParameters, {
          'filter': 'userName co "ada"',
          'startIndex': '26',
          'count': '25',
          'sortBy': 'userName',
          'sortOrder': 'descending',
        });
        expect(request.headers['accept'], scimContentType);
        expect(request.headers['authorization'], 'Bearer admin-token');
        return http.Response(
          '{"schemas":[],"totalResults":1,"startIndex":26,'
          '"itemsPerPage":1,"Resources":[{"id":"u-26"}]}',
          200,
          headers: {'content-type': scimContentType},
        );
      }),
    );

    final result = await api.get(
      '$scimBasePath/Users',
      query: const {
        'filter': 'userName co "ada"',
        'startIndex': '26',
        'count': '25',
        'sortBy': 'userName',
        'sortOrder': 'descending',
      },
    );

    expect(ScimListPage.fromJson(result).resources.single['id'], 'u-26');
  });

  test('sends structured mutation as application/scim+json', () async {
    final api = SnaplinkAdminApi(
      baseUrl: 'https://sso.example.test',
      accessToken: 'admin-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'PATCH');
        expect(request.url.path, '$scimBasePath/Users/u-1');
        expect(request.headers['content-type'], scimContentType);
        expect(request.headers['accept'], scimContentType);
        expect(jsonDecode(request.body), {
          'schemas': [scimPatchSchema],
          'Operations': [
            {'op': 'replace', 'path': 'active', 'value': false},
          ],
        });
        return http.Response(
          '{"id":"u-1","userName":"ada","active":false}',
          200,
        );
      }),
    );

    await api.patch(
      '$scimBasePath/Users/u-1',
      scimPatchBody(const [
        ScimPatchOperation(op: 'replace', path: 'active', value: false),
      ]),
      scimContentType,
    );
  });

  test('guards a SCIM write with the resource ETag', () async {
    final api = SnaplinkAdminApi(
      baseUrl: 'https://sso.example.test',
      accessToken: 'admin-token',
      httpClient: MockClient((request) async {
        expect(request.method, 'PATCH');
        expect(request.url.path, '$scimBasePath/Users/u-1');
        expect(request.headers['if-match'], 'W/"version-1"');
        expect(request.headers['content-type'], scimContentType);
        return http.Response(
          '{"id":"u-1","meta":{"version":"W/\\"version-2\\""}}',
          200,
          headers: {'etag': 'W/"version-2"'},
        );
      }),
    );

    await api.mutateIfMatch(
      method: 'PATCH',
      path: '$scimBasePath/Users/u-1',
      etag: 'W/"version-1"',
      body: scimPatchBody(const [
        ScimPatchOperation(op: 'replace', path: 'active', value: false),
      ]),
      contentType: scimContentType,
    );
  });

  test('catalog includes the complete SCIM directory route family', () {
    final routes = SnaplinkAdminOperationCatalog.endpoints
        .map((endpoint) => '${endpoint.method} ${endpoint.path}')
        .toSet();

    expect(routes, contains('GET $scimBasePath/ServiceProviderConfig'));
    expect(routes, contains('GET $scimBasePath/Schemas'));
    expect(routes, contains('POST $scimBasePath/Bulk'));
    for (final collection in const ['Users', 'Groups']) {
      expect(routes, contains('GET $scimBasePath/$collection'));
      expect(routes, contains('POST $scimBasePath/$collection'));
      for (final method in const ['GET', 'PUT', 'PATCH', 'DELETE']) {
        expect(routes, contains('$method $scimBasePath/$collection/{id}'));
      }
    }
  });

  testWidgets('renders discovery and degrades an optional Groups 404', (
    tester,
  ) async {
    var groupRequests = 0;
    final api = SnaplinkAdminApi(
      baseUrl: 'https://sso.example.test',
      accessToken: 'admin-token',
      httpClient: MockClient((request) async {
        expect(request.headers['accept'], scimContentType);
        switch (request.url.path) {
          case '$scimBasePath/ServiceProviderConfig':
            return http.Response(
              '{"patch":{"supported":true},'
              '"filter":{"supported":true,"maxResults":200},'
              '"bulk":{"supported":true,"maxOperations":1000,'
              '"maxPayloadSize":1048576},'
              '"sort":{"supported":true},"etag":{"supported":true},'
              '"authenticationSchemes":[]}',
              200,
            );
          case '$scimBasePath/Schemas':
            return http.Response(
              '{"totalResults":1,"Resources":[{"name":"User",'
              '"id":"$scimUserSchema","attributes":[]}]}',
              200,
            );
          case '$scimBasePath/Users':
            return http.Response(
              '{"totalResults":0,"startIndex":1,"itemsPerPage":0,'
              '"Resources":[]}',
              200,
            );
          case '$scimBasePath/Groups':
            groupRequests++;
            return http.Response(
              '{"schemas":[],"status":"404","detail":"not enabled"}',
              404,
            );
        }
        return http.Response('{}', 404);
      }),
    );
    const capabilities = SnaplinkAdminCapabilities([
      SnaplinkAdminEndpoint(
        method: 'GET',
        path: '$scimBasePath/ServiceProviderConfig',
        feature: 'scim',
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ScimDirectoryTab(api: api, capabilities: capabilities),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('SCIM 2.0 Directory'), findsOneWidget);
    expect(find.text('Provider capabilities'), findsOneWidget);

    await tester.tap(find.text('Groups'));
    await tester.pumpAndSettle();

    expect(groupRequests, greaterThan(0));
    expect(find.text('SCIM Groups are not enabled'), findsOneWidget);
    expect(find.text('Probe again'), findsOneWidget);
  });
}
