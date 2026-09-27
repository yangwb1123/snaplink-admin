import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/screens/forge/forge_sessions_screen.dart';

void main() {
  final fixturePath =
      Platform.environment['FORGE_SESSION_RUNNER_RECEIPT_VECTORS_FIXTURE'];

  testWidgets(
    'imports session Runner receipt outcome vectors without a network write',
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
            sessionRunnerReceiptVectorsFileReader: () async => source,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(
          const ValueKey('forge-import-session-runner-receipt-vectors'),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey('forge-session-runner-receipt-vectors-panel'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('forge-session-runner-receipt-vector-completed'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('forge-session-runner-receipt-vector-failed'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(
          const ValueKey('forge-session-runner-receipt-vector-uncertain'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('manual reconciliation'), findsOneWidget);
      expect(requests, isNotEmpty);
      expect(requests.every((request) => request.startsWith('GET ')), isTrue);
      expect(
        requests.where((request) => request.contains('receipt-vectors')),
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
  // The fixture test only needs a tiny response and keeping this helper local
  // avoids coupling the widget test to another test file's private helpers.
  if (value is Map && value['conversations'] is List) {
    return '{"conversations":[],"has_more":false}';
  }
  return '{}';
}
