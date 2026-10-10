import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/screens/admin/scim/scim_discovery_panel.dart';
import 'package:sso_admin/screens/admin/scim/scim_models.dart';
import 'package:sso_admin/screens/admin/scim/scim_resource_browser.dart';

SnaplinkAdminApi _api(Future<http.Response> Function(http.Request) send) =>
    SnaplinkAdminApi(
      baseUrl: 'https://sso.test',
      accessToken: 'fixture',
      httpClient: MockClient(send),
    )..maxRetries = 0;
http.Response _json(Object value) => http.Response(jsonEncode(value), 200);
Widget _host(Widget page) => MaterialApp(home: Scaffold(body: page));
void _large(WidgetTester tester) {
  tester.view.physicalSize = const Size(1400, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets(
    'SCIM refresh and explicit filter use native query fields and current data',
    (tester) async {
      _large(tester);
      final requests = <http.Request>[];
      final api = _api((request) async {
        requests.add(request);
        expect(request.method, 'GET');
        expect(request.headers['accept'], scimContentType);
        expect(request.url.path, '$scimBasePath/Users');
        return _json({
          'totalResults': 1,
          'startIndex': 1,
          'itemsPerPage': 1,
          'Resources': [
            {
              'id': 'user-${requests.length}',
              'userName': 'directory-${requests.length}',
            },
          ],
        });
      });
      await tester.pumpWidget(
        _host(ScimResourceBrowser(api: api, kind: ScimResourceKind.users)),
      );
      await tester.pumpAndSettle();
      expect(find.text('directory-1'), findsOneWidget);
      await tester.tap(find.byTooltip('Refresh'));
      await tester.pumpAndSettle();
      expect(requests.length, 2);
      expect(find.text('directory-2'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'SCIM search filter'),
        'userName co "alice"',
      );
      await tester.tap(find.text('Apply filters'));
      await tester.pumpAndSettle();
      expect(requests.last.url.queryParameters, {
        'startIndex': '1',
        'count': '50',
        'filter': 'userName co "alice"',
      });
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'reused SCIM browser cannot apply a late Users response to Groups',
    (tester) async {
      _large(tester);
      final old = Completer<http.Response>();
      final api = _api(
        (request) async => request.url.path.endsWith('/Users')
            ? old.future
            : _json({
                'Resources': [
                  {'id': 'group-one', 'displayName': 'New group'},
                ],
                'totalResults': 1,
                'startIndex': 1,
                'itemsPerPage': 1,
              }),
      );
      await tester.pumpWidget(
        _host(ScimResourceBrowser(api: api, kind: ScimResourceKind.users)),
      );
      await tester.pump();
      await tester.pumpWidget(
        _host(ScimResourceBrowser(api: api, kind: ScimResourceKind.groups)),
      );
      await tester.pumpAndSettle();
      old.complete(
        _json({
          'Resources': [
            {'id': 'old-user', 'userName': 'Old directory user'},
          ],
        }),
      );
      await tester.pumpAndSettle();
      expect(find.text('New group'), findsOneWidget);
      expect(find.text('Old directory user'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'SCIM discovery retains provider data and exposes a refresh Schemas 403',
    (tester) async {
      _large(tester);
      var configCalls = 0, schemaCalls = 0;
      final api = _api((request) async {
        if (request.url.path.endsWith('/ServiceProviderConfig')) {
          configCalls++;
          return _json({
            'patch': {'supported': true},
            'filter': {'supported': true},
          });
        }
        schemaCalls++;
        return schemaCalls == 1
            ? _json({'Resources': []})
            : http.Response(
                '{"error":{"code":"forbidden","message":"schema access denied"}}',
                403,
              );
      });
      await tester.pumpWidget(_host(ScimDiscoveryPanel(api: api)));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Refresh discovery'));
      await tester.pumpAndSettle();
      expect(configCalls, 2);
      expect(schemaCalls, 2);
      expect(find.text('Provider capabilities'), findsOneWidget);
      expect(
        find.textContaining('Schemas: SCIM request failed (403)'),
        findsOneWidget,
      );
      expect(find.textContaining('schema access denied'), findsOneWidget);
      expect(find.text('No resource schemas advertised.'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'initial optional Schemas failure is not a disabled SCIM provider',
    (tester) async {
      _large(tester);
      final api = _api(
        (request) async => request.url.path.endsWith('/ServiceProviderConfig')
            ? _json({
                'patch': {'supported': true},
              })
            : http.Response('{"error":"not_found"}', 404),
      );
      await tester.pumpWidget(_host(ScimDiscoveryPanel(api: api)));
      await tester.pumpAndSettle();
      expect(find.text('Provider capabilities'), findsOneWidget);
      expect(
        find.textContaining('Schemas: SCIM request failed (404)'),
        findsOneWidget,
      );
      expect(find.text('SCIM is not enabled'), findsNothing);
    },
  );

  test('zero-length SCIM page cannot offer a nonadvancing Next action', () {
    final page = ScimListPage.fromJson({
      'Resources': [],
      'totalResults': 20,
      'startIndex': 1,
      'itemsPerPage': 0,
    });
    expect(page.hasNext, isFalse);
  });
  for (final value in [
    null,
    {},
    ['invalid resource'],
  ]) {
    test('invalid SCIM Resources is a contract error, not empty: $value', () {
      expect(
        () => ScimListPage.fromJson({'Resources': value}),
        throwsA(
          isA<SnaplinkAdminApiError>().having(
            (error) => error.code,
            'code',
            'invalid_scim_response',
          ),
        ),
      );
    });
  }
}
