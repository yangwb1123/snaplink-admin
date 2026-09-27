import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/screens/forge/forge_sessions_screen.dart';

void main() {
  final fixturePath =
      Platform.environment['FORGE_SESSION_RUNNER_RECEIPT_HISTORY_FIXTURE'];

  testWidgets(
    'imports local session Runner receipt history without a history request',
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
                return _json({'conversations': [], 'has_more': false});
              }
              throw StateError('Unexpected Forge request: ${request.url}');
            }),
            sessionRunnerReceiptHistoryFileReader: () async => source,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey('forge-import-session-runner-receipt-history'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey('forge-session-runner-receipt-history-panel'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('forge-session-runner-receipt-history-summary'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('forge-session-runner-receipt-history-attempt-001'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('forge-session-runner-receipt-history-attempt-002'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey(
            'forge-session-runner-receipt-history-manual-reconciliation',
          ),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('automatic retry disabled'), findsOneWidget);
      expect(requests, isNotEmpty);
      expect(requests.every((request) => request.startsWith('GET ')), isTrue);
      expect(
        requests.where((request) => request.contains('receipt-history')),
        isEmpty,
      );
    },
    skip: fixturePath == null,
  );
}

http.Response _json(Object value) => http.Response(
  _encode(value),
  200,
  headers: const {'content-type': 'application/json'},
);

String _encode(Object value) {
  if (value is Map && value['conversations'] is List) {
    return '{"conversations":[],"has_more":false}';
  }
  return '{}';
}
