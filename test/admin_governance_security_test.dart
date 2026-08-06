import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/screens/admin/device_security_tab.dart';
import 'package:sso_admin/screens/admin/governance_tab.dart';
import 'package:sso_admin/services/browser_navigation.dart';

SnaplinkAdminApi _api(
  Map<String, http.Response Function(http.Request)> routes,
) => SnaplinkAdminApi(
  baseUrl: 'https://sso.example.test',
  accessToken: 'admin-token',
  httpClient: MockClient((request) async {
    final handler = routes[request.url.path];
    if (handler != null) return handler(request);
    return http.Response('{"error":"not found"}', 404);
  }),
);

SnaplinkAdminCapabilities _caps(List<String> paths) =>
    SnaplinkAdminCapabilities([
      for (final path in paths)
        SnaplinkAdminEndpoint(method: 'GET', path: path, feature: 'core'),
    ]);

Future<void> _pump(WidgetTester tester, Widget child) async {
  tester.view.physicalSize = const Size(1200, 2200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    BrowserNavigation.resetForTest();
  });

  group('DeviceSecurityTab', () {
    testWidgets('loads devices, stats and security events', (tester) async {
      final api = _api({
        '/api/v1/admin/devices': (_) => http.Response(
          jsonEncode({
            'devices': [
              {'id': 'device-1', 'device_name': 'Laptop', 'trust_score': 0.9},
            ],
            'total': 1,
          }),
          200,
        ),
        '/api/v1/admin/devices/stats': (_) => http.Response(
          jsonEncode({
            'total': 1,
            'suspicious': 0,
            'trust_levels': {'very_low': 0},
            'platforms': {'linux': 1},
          }),
          200,
        ),
        '/api/v1/admin/security/activity': (_) => http.Response(
          jsonEncode({
            'events': [
              {'id': 'ev-1', 'ip': '203.0.113.9'},
            ],
          }),
          200,
        ),
      });
      await _pump(tester, DeviceSecurityTab(api: api));

      expect(find.text('Laptop'), findsOneWidget);
      expect(find.text('Fleet devices'), findsOneWidget);
    });
  });

  group('GovernanceTab', () {
    testWidgets('loads governance sections and runs a write operation', (
      tester,
    ) async {
      var written = <String>[];
      final api = _api({
        '/api/v1/admin/storage-health': (_) =>
            http.Response(jsonEncode({'database': 'ok'}), 200),
        '/api/v1/admin/config/running': (_) =>
            http.Response(jsonEncode({'issuer': 'https://sso.test'}), 200),
        '/api/v1/admin/compliance/data-map': (_) =>
            http.Response(jsonEncode({'tables': []}), 200),
        '/api/v1/admin/changes': (request) {
          if (request.method == 'POST') {
            written.add(request.body);
            return http.Response('{}', 200);
          }
          return http.Response(jsonEncode({'changes': []}), 200);
        },
        // The default governed write operation is "Set degradation mode".
        '/api/v1/admin/dr/mode': (request) {
          if (request.method == 'POST') written.add(request.body);
          return http.Response('{}', 200);
        },
      });
      await _pump(
        tester,
        GovernanceTab(
          api: api,
          capabilities: _caps([
            '/api/v1/admin/storage-health',
            '/api/v1/admin/config/running',
            '/api/v1/admin/compliance/data-map',
            '/api/v1/admin/changes',
          ]),
        ),
      );

      // The health section rendered from the loaded data.
      expect(find.text('Storage health'), findsOneWidget);
      expect(find.textContaining('database'), findsOneWidget);

      // Switch to the Write section and run a governed POST.
      await tester.tap(find.text('Write'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Request JSON'),
        '{"title":"proposal"}',
      );
      // The typed confirmation binds the method and resolved path.
      await tester.enterText(
        find.widgetWithText(TextField, 'Exact write confirmation'),
        'CONFIRM POST /api/v1/admin/dr/mode',
      );
      await tester.tap(find.text('Run Set degradation mode'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Run operation'));
      await tester.pumpAndSettle();
      expect(written.single, contains('"title":"proposal"'));
    });

    testWidgets('blocks sensitive fields in generic write payloads', (
      tester,
    ) async {
      var requests = 0;
      final api = _api({
        '/api/v1/admin/changes': (request) {
          if (request.method == 'POST') requests++;
          return http.Response('{}', 200);
        },
      });
      await _pump(
        tester,
        GovernanceTab(api: api, capabilities: _caps(['/api/v1/admin/changes'])),
      );

      await tester.tap(find.text('Write'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Request JSON'),
        '{"password":"secret"}',
      );
      await tester.tap(find.textContaining('Run').last);
      await tester.pumpAndSettle();

      expect(requests, 0);
      expect(find.textContaining('Do not include passwords'), findsOneWidget);
    });
  });
}
