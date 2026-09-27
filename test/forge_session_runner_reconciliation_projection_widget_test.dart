import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/screens/forge/forge_sessions_screen.dart';

void main() {
  final fixturePath = Platform
      .environment['FORGE_SESSION_RUNNER_RECONCILIATION_PROJECTION_FIXTURE'];

  testWidgets(
    'imports a local reconciliation projection without a projection request',
    (tester) async {
      final source = File(fixturePath!).readAsStringSync();
      final requests = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsScreen(
            accessToken: 'forge-bearer',
            apiOrigin: 'https://forge.example',
            httpClient: MockClient((request) async {
              requests.add('${request.method} ${request.url.path}');
              if (request.url.path == '/api/v1/conversations') {
                return http.Response(
                  '{"conversations":[],"has_more":false}',
                  200,
                  headers: const {'content-type': 'application/json'},
                );
              }
              throw StateError('Unexpected Forge request: ${request.url}');
            }),
            sessionRunnerReconciliationProjectionFileReader: () async => source,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey(
            'forge-import-session-runner-reconciliation-projection',
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey(
            'forge-session-runner-reconciliation-projection-panel',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey(
            'forge-session-runner-reconciliation-projection-latest',
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey(
            'forge-session-runner-reconciliation-projection-boundary',
          ),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('automatic retry disabled'), findsOneWidget);
      expect(requests, isNotEmpty);
      expect(requests.every((request) => request.startsWith('GET ')), isTrue);
      expect(
        requests.where((request) => request.contains('runner-reconciliation')),
        isEmpty,
      );
    },
    skip: fixturePath == null,
  );
}
