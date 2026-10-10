import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/screens/admin/authz_check_tab.dart';
import 'package:sso_admin/screens/admin/token_exchange_tab.dart';

SnaplinkAdminApi _api(Future<http.Response> Function(http.Request) send) =>
    SnaplinkAdminApi(
      baseUrl: 'https://sso.test',
      accessToken: 'fixture',
      httpClient: MockClient(send),
    )..maxRetries = 0;

Future<void> _pump(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(1400, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: page)));
  await tester.pumpAndSettle();
}

const _wasmCaps = SnaplinkAdminCapabilities([
  SnaplinkAdminEndpoint(
    method: 'POST',
    path: '/api/v1/admin/wasmauthz/check',
    feature: 'fixture',
  ),
]);

void main() {
  testWidgets(
    'WASM form starts with the published subject/action/resource shape',
    (tester) async {
      final api = _api(
        (_) async =>
            http.Response('{"allowed":false,"reason":"fixture denial"}', 200),
      );
      await _pump(tester, AuthzCheckTab(api: api, capabilities: _wasmCaps));
      final field = tester.widget<TextField>(find.byType(TextField));
      final body = jsonDecode(field.controller!.text) as Map;
      expect(body.keys, containsAll(['subject', 'action', 'resource']));
      expect(body['resource'], isA<String>());
      expect(body, isNot(contains('principal')));
    },
  );

  testWidgets(
    'WASM sends only the actual read-check contract and renders deny',
    (tester) async {
      final requests = <http.Request>[];
      final api = _api((request) async {
        requests.add(request);
        return http.Response(
          '{"allowed":false,"reason":"fixture denial"}',
          200,
        );
      });
      await _pump(tester, AuthzCheckTab(api: api, capabilities: _wasmCaps));
      final body = {
        'subject': 'user:alice',
        'action': 'read',
        'resource': 'doc:1',
        'context': {'tenant': 'fixture'},
      };
      await tester.enterText(find.byType(TextField), jsonEncode(body));
      await tester.tap(find.text('Check WASM'));
      await tester.pumpAndSettle();
      expect(requests.single.url.path, '/api/v1/admin/wasmauthz/check');
      expect(jsonDecode(requests.single.body), body);
      expect(find.textContaining('"allowed": false'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  for (final invalid in [
    {'principal': 'user:alice', 'action': 'read', 'resource': {}},
    {'subject': 'user:alice', 'action': 'read', 'resource': {}},
    {
      'subject': 'user:alice',
      'action': 'read',
      'resource': 'doc:1',
      'context': {
        'role': ['admin'],
      },
    },
  ]) {
    testWidgets('invalid WASM shape is rejected before HTTP: $invalid', (
      tester,
    ) async {
      var calls = 0;
      final api = _api((_) async {
        calls++;
        return http.Response('{"allowed":true}', 200);
      });
      await _pump(tester, AuthzCheckTab(api: api, capabilities: _wasmCaps));
      await tester.enterText(find.byType(TextField), jsonEncode(invalid));
      await tester.tap(find.text('Check WASM'));
      await tester.pumpAndSettle();
      expect(calls, 0);
      expect(find.text('Retry'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'ReBAC refresh reads a changed policy decision, not a cached allow',
    (tester) async {
      var calls = 0;
      final api = _api((request) async {
        calls++;
        expect(request.url.queryParameters, {
          'object': 'doc:1',
          'relation': 'viewer',
          'subject': 'user:alice',
        });
        return http.Response(jsonEncode({'allowed': calls == 1}), 200);
      });
      const caps = SnaplinkAdminCapabilities([
        SnaplinkAdminEndpoint(
          method: 'GET',
          path: '/api/v1/admin/rebac/check',
          feature: 'fixture',
        ),
      ]);
      await _pump(tester, AuthzCheckTab(api: api, capabilities: caps));
      await tester.enterText(
        find.byType(TextField),
        '{"object":"doc:1","relation":"viewer","subject":"user:alice"}',
      );
      await tester.tap(find.text('Check ReBAC'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Check ReBAC'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.textContaining('"allowed": false'), findsOneWidget);
    },
  );

  testWidgets(
    'published token chain fields are visible and JTI is encoded once',
    (tester) async {
      final requests = <http.Request>[];
      final api = _api((request) async {
        requests.add(request);
        return http.Response(
          jsonEncode({
            'status': 'ok',
            'jti': 'leaf/a',
            'chain': [
              {
                'jti': 'leaf/a',
                'parent_jti': 'parent-1',
                'subject_id': 'alice',
                'actor_subject': 'service-b',
                'client_id': 'client-b',
                'chain_depth': 1,
                'recorded_at': '2026-01-02T03:04:05Z',
              },
            ],
          }),
          200,
        );
      });
      await _pump(
        tester,
        TokenExchangeTab(
          api: api,
          capabilities: const SnaplinkAdminCapabilities([]),
        ),
      );
      await tester.enterText(find.byType(TextField), 'leaf/a');
      await tester.tap(find.byTooltip('Search'));
      await tester.pumpAndSettle();
      expect(
        requests.single.url.toString(),
        'https://sso.test/api/v1/admin/tokenexchange/chains/leaf%2Fa',
      );
      for (final value in [
        'alice',
        'service-b',
        'parent-1',
        '2026-01-02T03:04:05Z',
      ]) {
        expect(find.text(value), findsWidgets);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('null token chain is empty, not a fabricated envelope hop', (
    tester,
  ) async {
    final api = _api(
      (_) async =>
          http.Response('{"status":"ok","jti":"missing","chain":null}', 200),
    );
    await _pump(
      tester,
      TokenExchangeTab(
        api: api,
        capabilities: const SnaplinkAdminCapabilities([]),
      ),
    );
    await tester.enterText(find.byType(TextField), 'missing');
    await tester.tap(find.byTooltip('Search'));
    await tester.pumpAndSettle();
    expect(
      find.text('No exchange chain found for this token.'),
      findsOneWidget,
    );
    expect(find.text('Hop 1'), findsNothing);
  });

  testWidgets('editing ReBAC input invalidates an in-flight policy result', (
    tester,
  ) async {
    final old = Completer<http.Response>();
    final api = _api(
      (request) async => request.url.queryParameters['subject'] == 'old'
          ? old.future
          : http.Response('{"allowed":false,"reason":"new subject"}', 200),
    );
    const caps = SnaplinkAdminCapabilities([
      SnaplinkAdminEndpoint(
        method: 'GET',
        path: '/api/v1/admin/rebac/check',
        feature: 'fixture',
      ),
    ]);
    await _pump(tester, AuthzCheckTab(api: api, capabilities: caps));
    await tester.enterText(
      find.byType(TextField),
      '{"object":"doc:1","relation":"viewer","subject":"old"}',
    );
    await tester.tap(find.text('Check ReBAC'));
    await tester.pump();
    await tester.enterText(
      find.byType(TextField),
      '{"object":"doc:1","relation":"viewer","subject":"new"}',
    );
    await tester.pump();
    await tester.tap(find.text('Check ReBAC'));
    await tester.pumpAndSettle();
    old.complete(http.Response('{"allowed":true,"reason":"old subject"}', 200));
    await tester.pumpAndSettle();
    expect(find.textContaining('new subject'), findsOneWidget);
    expect(find.textContaining('old subject'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'editing JTI invalidates a late chain and refresh reads the network',
    (tester) async {
      final old = Completer<http.Response>();
      var calls = 0;
      final api = _api((request) async {
        if (request.url.path.endsWith('/old')) return old.future;
        calls++;
        return http.Response(
          jsonEncode({
            'chain': [
              {'jti': 'new', 'subject_id': 'subject-$calls'},
            ],
          }),
          200,
        );
      });
      await _pump(
        tester,
        TokenExchangeTab(
          api: api,
          capabilities: const SnaplinkAdminCapabilities([]),
        ),
      );
      await tester.enterText(find.byType(TextField), 'old');
      await tester.tap(find.byTooltip('Search'));
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'new');
      await tester.pump();
      await tester.tap(find.byTooltip('Search'));
      await tester.pumpAndSettle();
      old.complete(
        http.Response(
          '{"chain":[{"jti":"old","subject_id":"stale subject"}]}',
          200,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('subject-1'), findsOneWidget);
      expect(find.text('stale subject'), findsNothing);
      await tester.tap(find.byTooltip('Refresh'));
      await tester.pumpAndSettle();
      expect(calls, 2);
      expect(find.text('subject-2'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'invalid token chain collection reports a source error instead of crashing build',
    (tester) async {
      final api = _api(
        (_) async => http.Response('{"chain":["malformed hop"]}', 200),
      );
      await _pump(
        tester,
        TokenExchangeTab(
          api: api,
          capabilities: const SnaplinkAdminCapabilities([]),
        ),
      );
      await tester.enterText(find.byType(TextField), 'token-one');
      await tester.tap(find.byTooltip('Search'));
      await tester.pumpAndSettle();
      expect(find.textContaining('invalid chain'), findsOneWidget);
      expect(find.text('Hop 1'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
