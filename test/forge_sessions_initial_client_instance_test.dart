import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sso_admin/api/forge_client_instance_session_resource_convergence.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/api/forge_device_inventory_resource_convergence.dart';
import 'package:sso_admin/api/forge_prompt_append_receipt.dart';
import 'package:sso_admin/screens/forge/forge_sessions_gate.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/services/forge_credential_store.dart';
import 'package:sso_admin/session.dart';

import 'support/memory_forge_credential_backend.dart';

const _owner = ForgeDeviceOwner(
  issuer: 'https://id.example',
  subject: 'user-1',
  tenantID: 'tenant-1',
);

Map<String, dynamic> _fixture(String path) =>
    Map<String, dynamic>.from(jsonDecode(File(path).readAsStringSync()) as Map);

ForgeDeviceInventoryResourceConvergence
_inventory() => ForgeDeviceInventoryResourceConvergence.fromJson(
  _fixture(
    'docs/contracts/fixtures/forge-device-inventory-resource-convergence-v1.json',
  ),
);

ForgeClientInstanceSessionResourceConvergence _pair() {
  final value = _fixture(
    'docs/contracts/fixtures/forge-client-instance-session-resource-convergence-v1.json',
  );
  final inventory = _fixture(
    'docs/contracts/fixtures/forge-device-inventory-resource-convergence-v1.json',
  );
  final resource = Map<String, dynamic>.from(inventory['resource_view'] as Map);
  value['resource_view'] = resource;
  (value['session_view'] as Map<String, dynamic>)['instances'] =
      List<dynamic>.from(resource['instances'] as List);
  return ForgeClientInstanceSessionResourceConvergence.fromJson(value);
}

ForgeClientInstanceSessionResourceConvergence _pairForSessions(
  List<String> sessionIDs,
) {
  final value =
      jsonDecode(jsonEncode(_pair().toJson())) as Map<String, dynamic>;
  final row = {
    'instance_id': 'client-web-001',
    'client_kind': 'web',
    'session_ids': sessionIDs,
    'observed_at_ms': 200500,
    'status': 'active',
  };
  (value['session_view'] as Map<String, dynamic>)['instances'] = [row];
  (value['resource_view'] as Map<String, dynamic>)['instances'] = [row];
  return ForgeClientInstanceSessionResourceConvergence.fromJson(value);
}

Map<String, dynamic> _owned(String id, String title) => {
  'conversation': {
    'id': id,
    'scope': {'kind': 'global'},
    'title': title,
    'created_at_ms': 10,
    'updated_at_ms': 20,
  },
  'aggregate_version': 1,
};

Map<String, dynamic> _prompt(String content) => {
  'id': 'prompt-initial-instance',
  'conversation_id': 'conversation-001',
  'role': 'user',
  'content': content,
  'created_at_ms': 31,
};

http.Response _json(Object value) => http.Response(
  jsonEncode(value),
  200,
  headers: const {'content-type': 'application/json'},
);

Future<void> _pump(WidgetTester tester) async {
  for (var index = 0; index < 14; index++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

Future<ForgeCredentialStore> _credentialStore() async {
  final store = ForgeCredentialStore(
    backend: MemoryForgeCredentialBackend(),
    forcePersistentStorage: true,
  );
  expect(await store.store(accessToken: 'initial-instance-token'), isTrue);
  return store;
}

void main() {
  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  setUp(() {
    BrowserNavigation.resetForTest();
    Session.clear();
  });

  tearDown(BrowserNavigation.resetForTest);

  testWidgets(
    'initial instance selection filters before private Prompt reads and writes',
    (tester) async {
      final store = await _credentialStore();
      final pair = _pair();
      final inventory = _inventory();
      var promptWritten = false;
      var submitCalls = 0;
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        final path = request.url.path;
        if (path == '/api/v1/conversations') {
          return _json({
            'conversations': [
              _owned('conversation-001', 'Web session'),
              _owned('conversation-002', 'Mobile session'),
            ],
            'has_more': false,
          });
        }
        if (path.endsWith('/prompts')) {
          final conversationID = path.split('/')[4];
          if (conversationID != 'conversation-001') {
            throw StateError('Hidden instance Prompt history was requested.');
          }
          return _json({
            'conversation_id': conversationID,
            'prompts': promptWritten
                ? [_prompt('instance-bound prompt')]
                : <Object>[],
            'has_more': false,
          });
        }
        if (path.endsWith('/runs')) {
          final conversationID = path.split('/')[4];
          if (conversationID != 'conversation-001') {
            throw StateError('Hidden instance Run history was requested.');
          }
          return _json({
            'conversation_id': conversationID,
            'runs': <Object>[],
            'has_more': false,
          });
        }
        throw StateError('Unexpected Forge request: ${request.method} $path');
      });
      addTearDown(client.close);
      addTearDown(store.clear);

      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsGate(
            credentialStore: store,
            httpClient: client,
            initialClientInstanceID: 'client-web-001',
            clientInstanceSessionResourceConvergenceOwner: _owner,
            clientInstanceSessionResourceConvergenceReader: (_) async => pair,
            deviceInventoryResourceConvergenceOwner: _owner,
            deviceInventoryResourceConvergenceReader: (_) async => inventory,
            promptAppendReceiptOwner: _owner,
            promptAppendReceiptSubmitter:
                ({
                  required owner,
                  required conversationID,
                  required content,
                  required expectedVersion,
                  required idempotencyKey,
                }) async {
                  submitCalls++;
                  promptWritten = true;
                  return ForgePromptAppendReceiptObservation.fromInput(
                    owner: owner,
                    conversationID: conversationID,
                    expectedVersion: expectedVersion,
                    content: content,
                    idempotencyKey: idempotencyKey,
                    promptID: 'prompt-initial-instance',
                    createdAtMS: 31,
                    replayed: false,
                  );
                },
            requireDeviceInventoryResourceConvergenceForPromptAppend: true,
          ),
        ),
      );
      await _pump(tester);
      await tester.drag(find.byType(ListView), const Offset(0, -5000));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('forge-conversation-conversation-001')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('forge-conversation-conversation-002')),
        findsNothing,
      );
      expect(
        requests.where((request) => request.url.path.endsWith('/prompts')),
        hasLength(1),
      );

      final promptField = find.byType(TextField).last;
      await tester.enterText(promptField, 'instance-bound prompt');
      await tester.tap(find.widgetWithText(FilledButton, 'Append prompt'));
      await _pump(tester);

      expect(submitCalls, 1);
      expect(find.text('instance-bound prompt'), findsOneWidget);
      expect(
        find.text('Prompt stored. It has not started a task.'),
        findsOneWidget,
      );
      expect(
        requests.where((request) => request.url.path.endsWith('/prompts')),
        hasLength(2),
      );
    },
  );

  testWidgets('refreshes the selected projection before a Prompt write', (
    tester,
  ) async {
    final store = await _credentialStore();
    final visiblePair = _pairForSessions(['conversation-001']);
    final revokedPair = _pairForSessions(const []);
    var pairCalls = 0;
    var submitCalls = 0;
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      final path = request.url.path;
      if (path == '/api/v1/conversations') {
        return _json({
          'conversations': [_owned('conversation-001', 'Web session')],
          'has_more': false,
        });
      }
      if (path.endsWith('/prompts')) {
        return _json({
          'conversation_id': 'conversation-001',
          'prompts': <Object>[],
          'has_more': false,
        });
      }
      if (path.endsWith('/runs')) {
        return _json({
          'conversation_id': 'conversation-001',
          'runs': <Object>[],
          'has_more': false,
        });
      }
      throw StateError('Unexpected Forge request: ${request.method} $path');
    });
    addTearDown(client.close);
    addTearDown(store.clear);

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsGate(
          credentialStore: store,
          httpClient: client,
          initialClientInstanceID: 'client-web-001',
          clientInstanceSessionResourceConvergenceOwner: _owner,
          clientInstanceSessionResourceConvergenceReader: (_) async {
            pairCalls++;
            return pairCalls == 1 ? visiblePair : revokedPair;
          },
          promptAppendReceiptOwner: _owner,
          promptAppendReceiptSubmitter:
              ({
                required owner,
                required conversationID,
                required content,
                required expectedVersion,
                required idempotencyKey,
              }) async {
                submitCalls++;
                return ForgePromptAppendReceiptObservation.fromInput(
                  owner: owner,
                  conversationID: conversationID,
                  expectedVersion: expectedVersion,
                  content: content,
                  idempotencyKey: idempotencyKey,
                  promptID: 'prompt-revoked',
                  createdAtMS: 31,
                  replayed: false,
                );
              },
        ),
      ),
    );
    await _pump(tester);
    await tester.drag(find.byType(ListView), const Offset(0, -5000));
    await tester.pumpAndSettle();

    final promptField = find.byType(TextField).last;
    await tester.enterText(promptField, 'must stay local');
    await tester.tap(find.widgetWithText(FilledButton, 'Append prompt'));
    await _pump(tester);

    expect(pairCalls, 2);
    expect(submitCalls, 0);
    expect(
      requests.where((request) => request.url.path.endsWith('/prompts')),
      hasLength(1),
    );
    expect(
      find.text('Prompt stored. It has not started a task.'),
      findsNothing,
    );
  });

  testWidgets(
    'refreshes the selected projection before owner Prompt and Run reads',
    (tester) async {
      final store = await _credentialStore();
      final initialPair = _pairForSessions(['conversation-001']);
      final revokedPair = _pairForSessions(const []);
      var pairCalls = 0;
      final events = <String>[];
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        final path = request.url.path;
        if (path == '/api/v1/conversations') {
          events.add('conversations');
          return _json({
            'conversations': [_owned('conversation-001', 'Web session')],
            'has_more': false,
          });
        }
        if (path == '/api/v1/conversation-changes') {
          events.add('changes');
          final cursor = int.parse(
            request.url.queryParameters['after_cursor']!,
          );
          return _json({
            'after_cursor': cursor,
            'scanned_through_cursor': cursor,
            'has_more': false,
            'changes': <Object>[],
          });
        }
        if (path.endsWith('/prompts')) {
          events.add('prompts');
          return _json({
            'conversation_id': 'conversation-001',
            'prompts': <Object>[],
            'has_more': false,
          });
        }
        if (path.endsWith('/runs')) {
          events.add('runs');
          return _json({
            'conversation_id': 'conversation-001',
            'runs': <Object>[],
            'has_more': false,
          });
        }
        throw StateError('Unexpected Forge request: ${request.method} $path');
      });
      addTearDown(client.close);
      addTearDown(store.clear);

      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsGate(
            credentialStore: store,
            httpClient: client,
            initialClientInstanceID: 'client-web-001',
            clientInstanceSessionResourceConvergenceOwner: _owner,
            clientInstanceSessionResourceConvergenceReader: (_) async {
              pairCalls++;
              events.add('pair-$pairCalls');
              return pairCalls == 1 ? initialPair : revokedPair;
            },
          ),
        ),
      );
      await _pump(tester);

      expect(
        requests.where((request) => request.url.path.endsWith('/prompts')),
        hasLength(1),
      );
      events.clear();

      await tester.tap(find.byTooltip('Refresh'));
      await _pump(tester);

      expect(pairCalls, 2);
      expect(events.indexOf('pair-2'), lessThan(events.indexOf('changes')));
      expect(
        events.indexOf('pair-2'),
        lessThan(events.indexOf('conversations')),
      );
      expect(
        requests.where((request) => request.url.path.endsWith('/prompts')),
        hasLength(1),
      );
      expect(
        requests.where((request) => request.url.path.endsWith('/runs')),
        hasLength(1),
      );
      expect(
        find.byKey(const ValueKey('forge-conversation-conversation-001')),
        findsNothing,
      );
    },
  );
}
