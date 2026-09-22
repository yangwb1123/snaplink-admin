import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sso_admin/api/forge_run_observed.dart';
import 'package:sso_admin/screens/forge/forge_sessions_gate.dart';
import 'package:sso_admin/screens/forge/forge_sessions_screen.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/services/forge_credential_store.dart';
import 'package:sso_admin/session.dart';

import 'support/memory_forge_credential_backend.dart';

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

ForgeRunObserved _observed({
  String conversationID = 'conversation-1',
  String runID = 'run-1',
  int latestSequence = 2,
  bool contentIncluded = false,
  ForgeRunObservedAuthority authority =
      const ForgeRunObservedAuthority.offline(),
}) => ForgeRunObserved(
  ownerRef: '21444e9222fa722f4b05e8a353e2e840594863c941bba4c2222b3c22bb198ba5',
  conversationID: conversationID,
  runID: runID,
  promptID: 'prompt-1',
  createdAtMS: 10,
  latestSequence: latestSequence,
  status: 'completed',
  metadataObserved: true,
  contentIncluded: contentIncluded,
  authority: authority,
);

http.Client _client({
  List<Uri>? observationRequestURLs,
  List<String?>? observationAuthorization,
  bool includeChangeFeed = false,
  bool dynamicTimeline = false,
}) => MockClient((request) async {
  if (request.method == 'GET' &&
      request.url.path.endsWith('/runs/run-1/observation')) {
    observationRequestURLs?.add(request.url);
    observationAuthorization?.add(request.headers['authorization']);
    return _json(_observed().toJson());
  }
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
    final afterSequence = dynamicTimeline
        ? int.parse(request.url.queryParameters['after_sequence'] ?? '0')
        : 0;
    return _json({
      'conversation_id': 'conversation-1',
      'run_id': 'run-1',
      'after_sequence': afterSequence,
      'scanned_through_sequence': 2,
      'has_more': false,
      'events': afterSequence == 0
          ? [
              {'seq': 1, 'emitted_at_ms': 11, 'type': 'run_started'},
              {'seq': 2, 'emitted_at_ms': 12, 'type': 'run_finished'},
            ]
          : <Object>[],
    });
  }
  if (includeChangeFeed &&
      request.method == 'GET' &&
      request.url.path == '/api/v1/conversation-changes') {
    final afterCursor = int.parse(
      request.url.queryParameters['after_cursor'] ?? '0',
    );
    return _json({
      'after_cursor': afterCursor,
      'scanned_through_cursor': afterCursor,
      'has_more': false,
      'changes': <Object>[],
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

  setUp(() => BrowserNavigation.resetForTest());

  tearDown(() {
    BrowserNavigation.resetForTest();
    Session.clear();
  });

  testWidgets('renders strict metadata for the selected Run', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: 'forge-bearer',
          apiOrigin: 'https://forge.example',
          httpClient: _client(),
          runObserved: _observed(),
        ),
      ),
    );
    await _settle(tester);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('forge-run-observed-card')),
      500,
      scrollable: find.byType(Scrollable).first,
    );

    final card = find.byKey(const ValueKey('forge-run-observed-card'));
    expect(card, findsOneWidget);
    expect(find.text('Run metadata observation'), findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.text('run-1')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: card, matching: find.text('completed')),
      findsOneWidget,
    );
    expect(find.text('secret prompt body'), findsNothing);
  });

  testWidgets('Gate forwards the observer to the selected Run card', (
    tester,
  ) async {
    final backend = MemoryForgeCredentialBackend();
    final credentialStore = ForgeCredentialStore(
      backend: backend,
      forcePersistentStorage: true,
    );
    expect(await credentialStore.store(accessToken: 'gate-bearer'), isTrue);

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsGate(
          credentialStore: credentialStore,
          httpClient: _client(),
          runObserved: _observed(),
        ),
      ),
    );
    await _settle(tester);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('forge-run-observed-card')),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(const ValueKey('forge-run-observed-card')),
      findsOneWidget,
    );
  });

  testWidgets('Gate forwards the observer reader to the selected Run card', (
    tester,
  ) async {
    final backend = MemoryForgeCredentialBackend();
    final credentialStore = ForgeCredentialStore(
      backend: backend,
      forcePersistentStorage: true,
    );
    expect(
      await credentialStore.store(accessToken: 'gate-reader-bearer'),
      isTrue,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsGate(
          credentialStore: credentialStore,
          httpClient: _client(),
          runObservedReader: (_, _) async => _observed(),
        ),
      ),
    );
    await _settle(tester);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('forge-run-observed-card')),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.byKey(const ValueKey('forge-run-observed-card')),
      findsOneWidget,
    );
  });

  testWidgets(
    'Gate candidate reader performs one authenticated metadata read',
    (tester) async {
      final backend = MemoryForgeCredentialBackend();
      final credentialStore = ForgeCredentialStore(
        backend: backend,
        forcePersistentStorage: true,
      );
      expect(
        await credentialStore.store(accessToken: 'gate-candidate-bearer'),
        isTrue,
      );
      final observationRequestURLs = <Uri>[];
      final observationAuthorization = <String?>[];

      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsGate(
            credentialStore: credentialStore,
            httpClient: _client(
              observationRequestURLs: observationRequestURLs,
              observationAuthorization: observationAuthorization,
            ),
            enableRunObservedCandidate: true,
            runObservedCandidateApiOrigin: 'https://forge.example',
          ),
        ),
      );
      await _settle(tester);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('forge-run-observed-card')),
        500,
        scrollable: find.byType(Scrollable).first,
      );

      expect(
        find.byKey(const ValueKey('forge-run-observed-card')),
        findsOneWidget,
      );
      expect(observationRequestURLs, [
        Uri.parse(
          'https://forge.example/api/v1/conversations/conversation-1/runs/'
          'run-1/observation',
        ),
      ]);
      expect(observationAuthorization, ['Bearer gate-candidate-bearer']);
    },
  );

  testWidgets('Gate leaves the candidate observer request-free by default', (
    tester,
  ) async {
    final backend = MemoryForgeCredentialBackend();
    final credentialStore = ForgeCredentialStore(
      backend: backend,
      forcePersistentStorage: true,
    );
    expect(
      await credentialStore.store(accessToken: 'gate-default-bearer'),
      isTrue,
    );
    final observationRequestURLs = <Uri>[];

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsGate(
          credentialStore: credentialStore,
          httpClient: _client(observationRequestURLs: observationRequestURLs),
        ),
      ),
    );
    await _settle(tester);

    expect(observationRequestURLs, isEmpty);
    expect(find.byKey(const ValueKey('forge-run-observed-card')), findsNothing);
  });

  testWidgets('injected reader refreshes selected Run metadata', (
    tester,
  ) async {
    var reads = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: 'forge-bearer',
          apiOrigin: 'https://forge.example',
          httpClient: _client(),
          runObservedReader: (conversationID, runID) async {
            expect(conversationID, 'conversation-1');
            expect(runID, 'run-1');
            reads++;
            return _observed(latestSequence: reads + 1);
          },
        ),
      ),
    );
    await _settle(tester);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('forge-run-observed-card')),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(reads, 1);
    expect(find.text('2'), findsWidgets);

    await tester.tap(find.byIcon(Icons.refresh).last);
    await _settle(tester);
    expect(reads, greaterThanOrEqualTo(2));
    expect(find.text('${reads + 1}'), findsWidgets);
  });

  testWidgets('scheduled change sync refreshes selected Run metadata', (
    tester,
  ) async {
    var reads = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: 'forge-bearer',
          apiOrigin: 'https://forge.example',
          httpClient: _client(includeChangeFeed: true, dynamicTimeline: true),
          runObservedReader: (_, _) async {
            reads++;
            return _observed(latestSequence: reads + 1);
          },
        ),
      ),
    );
    await _settle(tester);
    expect(reads, 1);

    // The timer path calls _syncChanges directly; it does not pass through
    // the manual/resume refresh that already uses force=true.
    await tester.pump(const Duration(seconds: 16));
    await _settle(tester);

    expect(reads, greaterThanOrEqualTo(2));
  });

  testWidgets('reader hides content-bearing observations', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: 'forge-bearer',
          apiOrigin: 'https://forge.example',
          httpClient: _client(),
          runObservedReader: (_, _) async => _observed(contentIncluded: true),
        ),
      ),
    );
    await _settle(tester);

    expect(find.byKey(const ValueKey('forge-run-observed-card')), findsNothing);
    expect(find.text('Forge returned an invalid response.'), findsOneWidget);
  });

  testWidgets('reader keeps the last value when refresh fails', (tester) async {
    var reads = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: 'forge-bearer',
          apiOrigin: 'https://forge.example',
          httpClient: _client(),
          runObservedReader: (_, _) async {
            reads++;
            if (reads > 1) throw StateError('temporary observer outage');
            return _observed(latestSequence: 2);
          },
        ),
      ),
    );
    await _settle(tester);
    await tester.tap(find.byIcon(Icons.refresh).last);
    await _settle(tester);
    expect(
      find.byKey(const ValueKey('forge-run-observed-stale')),
      findsOneWidget,
    );
    expect(
      find.text('Could not load Run metadata observation.'),
      findsOneWidget,
    );
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('forge-run-observed-card')),
      500,
      scrollable: find.byType(Scrollable).first,
    );

    expect(reads, greaterThanOrEqualTo(2));
    expect(
      find.byKey(const ValueKey('forge-run-observed-card')),
      findsOneWidget,
    );
  });

  testWidgets('does not render an observer for a foreign Run', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: 'forge-bearer',
          apiOrigin: 'https://forge.example',
          httpClient: _client(),
          runObserved: _observed(runID: 'run-foreign'),
        ),
      ),
    );
    await _settle(tester);
    expect(find.byKey(const ValueKey('forge-run-observed-card')), findsNothing);
  });

  testWidgets('strict re-decode hides content or authority claims', (
    tester,
  ) async {
    final content = _observed(contentIncluded: true);
    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: 'forge-bearer',
          apiOrigin: 'https://forge.example',
          httpClient: _client(),
          runObserved: content,
        ),
      ),
    );
    await _settle(tester);
    expect(find.byKey(const ValueKey('forge-run-observed-card')), findsNothing);

    final authority = _observed(
      authority: const ForgeRunObservedAuthority(
        identityVerified: false,
        ownerAuthorized: false,
        runAuthoritative: false,
        persistenceAttested: false,
        contentProvenanceVerified: false,
        reservationCreated: false,
        executionAuthorized: true,
        dispatchPerformed: false,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: 'forge-bearer',
          apiOrigin: 'https://forge.example',
          httpClient: _client(),
          runObserved: authority,
        ),
      ),
    );
    await _settle(tester);
    expect(find.byKey(const ValueKey('forge-run-observed-card')), findsNothing);
  });
}
