import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sso_admin/api/forge_run_execution_evidence.dart';
import 'package:sso_admin/screens/forge/forge_sessions_screen.dart';

http.Response _json(Object value) => http.Response(
  jsonEncode(value),
  200,
  headers: const {'content-type': 'application/json'},
);

Future<void> _settle(WidgetTester tester) async {
  for (var index = 0; index < 8; index++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

ForgeRunExecutionEvidence _evidence({
  String conversationID = 'conversation-1',
  String runID = 'run-1',
  bool contentIncluded = false,
  bool uncertain = false,
  bool reconciliationRequired = false,
}) => ForgeRunExecutionEvidence(
  ownerRef: '21444e9222fa722f4b05e8a353e2e840594863c941bba4c2222b3c22bb198ba5',
  conversationID: conversationID,
  runID: runID,
  promptID: 'prompt-1',
  runStatus: 'completed',
  attemptID: 'attempt-1',
  targetID: 'runner-1',
  commandID: 'command-1',
  commandSHA256: 'a' * 64,
  dispositionKind: uncertain ? 'uncertain' : 'completed',
  receiptObservedAtMS: 300,
  uncertain: uncertain,
  reconciliationRequired: reconciliationRequired,
  metadataObserved: true,
  contentIncluded: contentIncluded,
  authority: const ForgeRunExecutionEvidenceAuthority.offline(),
);

http.Client _client() => MockClient((request) async {
  if (request.method == 'GET' && request.url.path == '/api/v1/conversations') {
    return _json({
      'conversations': [
        {
          'conversation': {
            'id': 'conversation-1',
            'scope': {'kind': 'global'},
            'title': 'Shared work',
            'created_at_ms': 1,
            'updated_at_ms': 2,
          },
          'aggregate_version': 1,
        },
      ],
      'has_more': false,
    });
  }
  if (request.method == 'GET' &&
      request.url.path == '/api/v1/conversations/conversation-1/prompts') {
    return _json({
      'conversation_id': 'conversation-1',
      'prompts': <Object>[],
      'has_more': false,
    });
  }
  if (request.method == 'GET' &&
      request.url.path == '/api/v1/conversations/conversation-1/runs') {
    return _json({
      'conversation_id': 'conversation-1',
      'runs': [
        {
          'run_id': 'run-1',
          'prompt_id': 'prompt-1',
          'created_at_ms': 10,
          'latest_sequence': 2,
          'status': 'completed',
        },
      ],
      'has_more': false,
    });
  }
  if (request.method == 'GET' &&
      request.url.path ==
          '/api/v1/conversations/conversation-1/runs/run-1/timeline') {
    return _json({
      'conversation_id': 'conversation-1',
      'run_id': 'run-1',
      'after_sequence': 0,
      'scanned_through_sequence': 2,
      'has_more': false,
      'events': [
        {'seq': 1, 'emitted_at_ms': 11, 'type': 'run_started'},
        {'seq': 2, 'emitted_at_ms': 12, 'type': 'run_finished'},
      ],
    });
  }
  throw StateError(
    'Unexpected Forge request: ${request.method} ${request.url}',
  );
});

void main() {
  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('renders strict metadata-only evidence for the selected Run', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: 'forge-bearer',
          apiOrigin: 'https://forge.example',
          httpClient: _client(),
          runExecutionEvidence: _evidence(
            uncertain: true,
            reconciliationRequired: true,
          ),
        ),
      ),
    );
    await _settle(tester);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('forge-run-execution-evidence-card')),
      500,
      scrollable: find.byType(Scrollable).first,
    );

    final card = find.byKey(
      const ValueKey('forge-run-execution-evidence-card'),
    );
    expect(card, findsOneWidget);
    expect(find.text('Run execution evidence preview'), findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.text('run-1')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('uncertain')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('true')),
      findsWidgets,
    );
    expect(find.text('secret prompt body'), findsNothing);
  });

  testWidgets('does not render evidence for a foreign selected Run', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: 'forge-bearer',
          apiOrigin: 'https://forge.example',
          httpClient: _client(),
          runExecutionEvidence: _evidence(runID: 'run-foreign'),
        ),
      ),
    );
    await _settle(tester);
    expect(
      find.byKey(const ValueKey('forge-run-execution-evidence-card')),
      findsNothing,
    );
  });

  testWidgets('strict re-decode hides content-bearing injected evidence', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: 'forge-bearer',
          apiOrigin: 'https://forge.example',
          httpClient: _client(),
          runExecutionEvidence: _evidence(contentIncluded: true),
        ),
      ),
    );
    await _settle(tester);
    expect(
      find.byKey(const ValueKey('forge-run-execution-evidence-card')),
      findsNothing,
    );
  });
}
