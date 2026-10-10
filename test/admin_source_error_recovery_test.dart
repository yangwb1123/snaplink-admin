import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/screens/admin/distributed_cluster_panel.dart';
import 'package:sso_admin/screens/admin/health_tab.dart';
import 'package:sso_admin/screens/admin/privacy_compliance_tab.dart';

import 'fixtures/admin_page_fixture.dart';

SnaplinkAdminApi _api(Future<http.Response> Function(http.Request) handler) =>
    SnaplinkAdminApi(
      baseUrl: 'https://sso.test',
      accessToken: 'fixture',
      httpClient: MockClient(handler),
    )..maxRetries = 0;

Future<void> _pump(WidgetTester tester, Widget page) async {
  tester.view.physicalSize = const Size(1400, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(home: Scaffold(body: page)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('health retains successful data and exposes optional source errors', (
    tester,
  ) async {
    final api = _api((request) async {
      if (request.url.path.endsWith('/storage-health')) {
        return http.Response(
          '{"error":{"code":"storage_unavailable","message":"fixture storage down"}}',
          503,
        );
      }
      if (request.url.path == '/readyz') {
        return http.Response(
          '{"error":{"code":"forbidden","message":"fixture readiness denied"}}',
          403,
        );
      }
      return http.Response(jsonEncode(responses[request.url.path]), 200);
    });
    await _pump(tester, HealthTab(api: api));
    expect(find.textContaining('fixture storage down'), findsOneWidget);
    expect(find.textContaining('fixture readiness denied'), findsOneWidget);
    expect(find.text('Storage Health'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('cluster probes use the network and do not call 502 unauthorized', (
    tester,
  ) async {
    var probes = 0;
    final api = _api((request) async {
      if (request.url.path == '/api/v1/admin/endpoints') {
        probes++;
        return http.Response(
          '{"error":{"code":"upstream_unavailable","message":"fixture unreachable"}}',
          502,
        );
      }
      return http.Response(jsonEncode(responses[request.url.path]), 200);
    });
    await _pump(tester, DistributedClusterPanel(api: api));
    await tester.tap(find.text('Run Cluster Self-Test'));
    await tester.pumpAndSettle();
    expect(probes, 5);
    expect(find.text('5 of 5 probes failed'), findsOneWidget);
    expect(find.textContaining('probes unauthorized'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  for (final dryRun in [true, false]) {
    testWidgets(
      'retention ${dryRun ? 'preview is retryable' : 'mutation is not replayed by Retry'}',
      (tester) async {
        final requests = <http.Request>[];
        final api = _api((request) async {
          requests.add(request);
          expect(jsonDecode(request.body), {'dry_run': dryRun});
          return http.Response(
            '{"error":{"code":"upstream_unavailable","message":"fixture retention unavailable"}}',
            503,
          );
        });
        await _pump(
          tester,
          PrivacyComplianceTab(
            api: api,
            capabilities: SnaplinkAdminCapabilities(
              SnaplinkAdminOperationCatalog.endpoints,
            ),
          ),
        );
        await tester.tap(
          find.text(dryRun ? 'Preview sweep' : 'Run governed sweep'),
        );
        await tester.pumpAndSettle();
        if (!dryRun) {
          await tester.enterText(find.byType(TextField).last, 'RUN RETENTION');
          await tester.pumpAndSettle();
          await tester.tap(find.widgetWithText(FilledButton, 'Run sweep'));
          await tester.pumpAndSettle();
        }
        expect(requests.length, 1);
        expect(
          find.textContaining('fixture retention unavailable'),
          findsOneWidget,
        );
        if (dryRun) {
          await tester.tap(find.text('Retry'));
          await tester.pumpAndSettle();
          expect(requests.length, 2);
        } else {
          expect(find.text('Retry'), findsNothing);
        }
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }
}
