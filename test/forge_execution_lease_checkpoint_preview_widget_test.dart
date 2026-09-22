import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/forge_execution_lease_checkpoint.dart';
import 'package:sso_admin/screens/forge/forge_execution_lease_checkpoint_preview_card.dart';
import 'package:sso_admin/screens/forge/forge_sessions_screen.dart';

void main() {
  testWidgets('renders the checkpoint as metadata without proof material', (
    tester,
  ) async {
    final fixture = ForgeExecutionLeaseCheckpointFixture.fromJson(_fixture());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ForgeExecutionLeaseCheckpointPreviewCard(fixture: fixture),
          ),
        ),
      ),
    );

    expect(
      find.byKey(
        const ValueKey('forge-execution-lease-checkpoint-preview-card'),
      ),
      findsOneWidget,
    );
    expect(
      find.text('Execution lease checkpoint local preview'),
      findsOneWidget,
    );
    expect(find.text('attempt-1'), findsOneWidget);
    expect(find.text('empty_state'), findsOneWidget);
    expect(find.text('uncertain_receipt_remains_terminal'), findsOneWidget);
    expect(find.text('fence-1'), findsNothing);
    expect(
      find.text(
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      ),
      findsNothing,
    );
    expect(find.text('transport ended after effect boundary'), findsNothing);
    expect(find.byType(ButtonStyleButton), findsNothing);
    expect(find.byType(IconButton), findsNothing);
  });

  testWidgets(
    'renders through shared Forge Sessions without a device request',
    (tester) async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/v1/conversations') {
          return http.Response(
            jsonEncode({'conversations': [], 'has_more': false}),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/v1/conversation-changes') {
          return http.Response(
            jsonEncode({
              'after_cursor': 0,
              'scanned_through_cursor': 0,
              'has_more': false,
              'changes': [],
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        throw StateError('Unexpected Forge request: ${request.url}');
      });
      addTearDown(client.close);

      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsScreen(
            accessToken: 'fixture-access',
            apiOrigin: 'https://forge.example',
            httpClient: client,
            executionLeaseCheckpointPreview:
                ForgeExecutionLeaseCheckpointFixture.fromJson(_fixture()),
          ),
        ),
      );
      for (var count = 0; count < 8; count++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }

      expect(
        find.byKey(
          const ValueKey('forge-execution-lease-checkpoint-preview-card'),
        ),
        findsOneWidget,
      );
      expect(
        requests.where((request) => request.url.path.contains('/devices')),
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets('imports a bounded checkpoint file into shared Forge Sessions', (
    tester,
  ) async {
    final client = MockClient((request) async {
      if (request.url.path == '/api/v1/conversations') {
        return http.Response(
          jsonEncode({'conversations': [], 'has_more': false}),
          200,
          headers: const {'content-type': 'application/json'},
        );
      }
      if (request.url.path == '/api/v1/conversation-changes') {
        return http.Response(
          jsonEncode({
            'after_cursor': 0,
            'scanned_through_cursor': 0,
            'has_more': false,
            'changes': [],
          }),
          200,
          headers: const {'content-type': 'application/json'},
        );
      }
      throw StateError('Unexpected Forge request: ${request.url}');
    });
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: 'fixture-access',
          apiOrigin: 'https://forge.example',
          httpClient: client,
          executionLeaseCheckpointFileReader: () async =>
              jsonEncode(_fixture()),
        ),
      ),
    );
    for (var count = 0; count < 8; count++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }

    expect(
      find.byKey(
        const ValueKey('forge-execution-lease-checkpoint-import-card'),
      ),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('forge-import-execution-lease-checkpoint')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(
        const ValueKey('forge-execution-lease-checkpoint-preview-card'),
      ),
      findsOneWidget,
    );
    expect(find.text('foreign_proof_rejected'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}

Map<String, dynamic> _fixture() {
  Map<String, dynamic> grant() => {
    'v': 1,
    'attempt_id': 'attempt-1',
    'target_id': 'runner-1',
    'epoch': 1,
    'fencing_token': 'fence-1',
    'issued_at_ms': 100,
    'expires_at_ms': 10100,
  };

  Map<String, dynamic> proof() => {
    'attempt_id': 'attempt-1',
    'target_id': 'runner-1',
    'epoch': 1,
    'fencing_token': 'fence-1',
  };

  Map<String, dynamic> checkpoint({Object? terminal}) => {
    'schema_version': forgeExecutionLeaseCheckpointSchema,
    'evaluation_mode': forgeExecutionLeaseCheckpointEvaluationMode,
    'grant': grant(),
    'terminal': terminal,
  };

  return {
    'schema_version': forgeExecutionLeaseCheckpointSchema,
    'evaluation_mode': forgeExecutionLeaseCheckpointEvaluationMode,
    'authority': {
      'lease_issued': false,
      'terminal_persisted': false,
      'execution_authorized': false,
      'dispatch_performed': false,
      'audit_published': false,
    },
    'cases': [
      {
        'name': 'empty_state',
        'checkpoint': checkpoint(),
        'expected': {'accepted': true},
      },
      {
        'name': 'completed_receipt_survives_restart',
        'checkpoint': checkpoint(
          terminal: {
            'v': 1,
            'proof': proof(),
            'disposition': {
              'kind': 'completed',
              'receipt_sha256':
                  'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            },
            'observed_at_ms': 200,
          },
        ),
        'expected': {'accepted': true, 'terminal': true},
      },
      {
        'name': 'uncertain_receipt_remains_terminal',
        'checkpoint': checkpoint(
          terminal: {
            'v': 1,
            'proof': proof(),
            'disposition': {
              'kind': 'uncertain',
              'reason': 'transport ended after effect boundary',
            },
            'observed_at_ms': 300,
          },
        ),
        'expected': {'accepted': true, 'terminal': true, 'uncertain': true},
      },
      {
        'name': 'foreign_proof_rejected',
        'checkpoint': checkpoint(
          terminal: {
            'v': 1,
            'proof': {...proof(), 'attempt_id': 'foreign-attempt'},
            'disposition': {
              'kind': 'failed',
              'reason': 'runner rejected command',
            },
            'observed_at_ms': 200,
          },
        ),
        'expected': {'accepted': false, 'error': 'invalid_checkpoint'},
      },
    ],
  };
}
