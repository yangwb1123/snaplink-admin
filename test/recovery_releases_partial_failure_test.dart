import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/screens/admin/recovery_releases_tab.dart';

void main() {
  testWidgets('optional recovery reads fail independently', (tester) async {
    final api = SnaplinkAdminApi(
      baseUrl: 'https://sso.example',
      accessToken: 'token',
      httpClient: MockClient((request) async {
        if (request.url.path == '/api/v1/admin/snapshots') {
          return http.Response(
            jsonEncode({
              'items': [
                {
                  'snapshot_id': 'snapshot-safe-1',
                  'codec': 'sealed',
                  'size_bytes': 42,
                  'schema_version': 1,
                },
              ],
            }),
            200,
          );
        }
        return http.Response('{}', 404);
      }),
    )..maxRetries = 1;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecoveryReleasesTab(
            api: api,
            capabilities: const SnaplinkAdminCapabilities([]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('snapshot-safe-1'), findsOneWidget);
    expect(find.textContaining('Releases: not enabled'), findsOneWidget);
    expect(find.text('No registered releases.'), findsOneWidget);
  });

  testWidgets('renders durable operation steps and compensation failures', (
    tester,
  ) async {
    final api = SnaplinkAdminApi(
      baseUrl: 'https://sso.example',
      accessToken: 'token',
      httpClient: MockClient((request) async {
        if (request.url.path == '/api/v1/admin/operations') {
          return http.Response(
            jsonEncode({
              'operations': [
                {
                  'id': 'op_rollback_1',
                  'kind': 'release_rollback',
                  'target': 'release-7',
                  'state': 'failed',
                  'steps': [
                    {
                      'name': 'apply_release',
                      'state': 'failed',
                      'error': 'probe failed',
                    },
                  ],
                  'compensations': [
                    {
                      'name': 'restore_previous_release',
                      'state': 'failed',
                      'error': 'pinner unavailable',
                    },
                  ],
                },
              ],
            }),
            200,
          );
        }
        return http.Response('{}', 404);
      }),
    )..maxRetries = 1;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecoveryReleasesTab(
            api: api,
            capabilities: const SnaplinkAdminCapabilities([]),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('op_rollback_1'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -500));
    await tester.pumpAndSettle();
    await tester.tap(find.text('op_rollback_1'));
    await tester.pumpAndSettle();
    expect(find.textContaining('apply_release · failed'), findsOneWidget);
    expect(
      find.textContaining('restore_previous_release · failed'),
      findsOneWidget,
    );
    expect(find.text('pinner unavailable'), findsOneWidget);
  });
}
