import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sso_admin/api/forge_client_instance_session_resource_convergence.dart';
import 'package:sso_admin/api/forge_device_inventory_models.dart';
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
_inventoryConvergence() => ForgeDeviceInventoryResourceConvergence.fromJson(
  _fixture(
    'docs/contracts/fixtures/forge-device-inventory-resource-convergence-v1.json',
  ),
);

ForgeClientInstanceSessionResourceConvergence _sessionConvergence({
  required bool matchInventory,
}) {
  final value = _fixture(
    'docs/contracts/fixtures/forge-client-instance-session-resource-convergence-v1.json',
  );
  if (matchInventory) {
    final inventory = _fixture(
      'docs/contracts/fixtures/forge-device-inventory-resource-convergence-v1.json',
    );
    final resourceView = Map<String, dynamic>.from(
      inventory['resource_view'] as Map,
    );
    value['resource_view'] = resourceView;
    (value['session_view'] as Map<String, dynamic>)['instances'] =
        List<dynamic>.from(resourceView['instances'] as List);
  }
  return ForgeClientInstanceSessionResourceConvergence.fromJson(value);
}

http.Response _json(Object value) => http.Response(
  jsonEncode(value),
  200,
  headers: const {'content-type': 'application/json'},
);

Map<String, dynamic> _ownedConversation() => {
  'conversation': {
    'id': 'conversation-001',
    'scope': {'kind': 'global'},
    'title': 'Shared journey',
    'created_at_ms': 10,
    'updated_at_ms': 20,
  },
  'aggregate_version': 1,
};

Map<String, dynamic> _prompt(String content) => {
  'id': 'prompt-journey',
  'conversation_id': 'conversation-001',
  'role': 'user',
  'content': content,
  'created_at_ms': 30,
};

Future<ForgeCredentialStore> _credentialStore() async {
  final store = ForgeCredentialStore(
    backend: MemoryForgeCredentialBackend(),
    forcePersistentStorage: true,
  );
  expect(await store.store(accessToken: 'journey-token'), isTrue);
  return store;
}

Future<void> _pump(WidgetTester tester) async {
  for (var index = 0; index < 12; index++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
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
    'explicit journey blocks Prompt append when session and inventory observations drift',
    (tester) async {
      final store = await _credentialStore();
      final inventory = _inventoryConvergence();
      final session = _sessionConvergence(matchInventory: false);
      var submitCalls = 0;
      final client = MockClient((request) async {
        final path = request.url.path;
        if (path == '/api/v1/conversations') {
          return _json({
            'conversations': [_ownedConversation()],
            'has_more': false,
          });
        }
        if (path.endsWith('/conversations/conversation-001/prompts')) {
          return _json({
            'conversation_id': 'conversation-001',
            'prompts': <Object>[],
            'has_more': false,
          });
        }
        if (path.endsWith('/conversations/conversation-001/runs')) {
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
            clientInstanceSessionResourceConvergenceOwner: _owner,
            clientInstanceSessionResourceConvergenceReader: (_) async =>
                session,
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
                  return ForgePromptAppendReceiptObservation.fromInput(
                    owner: owner,
                    conversationID: conversationID,
                    expectedVersion: expectedVersion,
                    content: content,
                    idempotencyKey: idempotencyKey,
                    promptID: 'prompt-journey',
                    createdAtMS: 31,
                    replayed: false,
                  );
                },
            requireDeviceInventoryResourceConvergenceForPromptAppend: true,
          ),
        ),
      );
      await _pump(tester);
      final conversation = find.byKey(
        const ValueKey('forge-conversation-conversation-001'),
      );
      await tester.scrollUntilVisible(
        conversation,
        500,
        scrollable: find.byType(Scrollable).first,
      );
      expect(conversation, findsOneWidget);
      await tester.tap(conversation);
      await _pump(tester);

      final promptField = find.byType(TextField).last;
      await tester.enterText(promptField, 'blocked by drift');
      final appendButton = find.widgetWithText(FilledButton, 'Append prompt');
      expect(appendButton, findsOneWidget);
      expect(tester.widget<FilledButton>(appendButton).onPressed, isNull);
      expect(
        find.text(
          'Prompt append is disabled because session/resource and inventory/resource observations do not converge.',
        ),
        findsOneWidget,
      );
      expect(submitCalls, 0);
    },
  );

  testWidgets(
    'matching explicit journey enables the content-free Prompt receipt append',
    (tester) async {
      final store = await _credentialStore();
      final inventory = _inventoryConvergence();
      final session = _sessionConvergence(matchInventory: true);
      var promptWritten = false;
      var submitCalls = 0;
      final client = MockClient((request) async {
        final path = request.url.path;
        if (path == '/api/v1/conversations') {
          return _json({
            'conversations': [_ownedConversation()],
            'has_more': false,
          });
        }
        if (path.endsWith('/conversations/conversation-001/prompts')) {
          return _json({
            'conversation_id': 'conversation-001',
            'prompts': promptWritten ? [_prompt('journey prompt')] : <Object>[],
            'has_more': false,
          });
        }
        if (path.endsWith('/conversations/conversation-001/runs')) {
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
            clientInstanceSessionResourceConvergenceOwner: _owner,
            clientInstanceSessionResourceConvergenceReader: (_) async =>
                session,
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
                    promptID: 'prompt-journey',
                    createdAtMS: 31,
                    replayed: false,
                  );
                },
            requireDeviceInventoryResourceConvergenceForPromptAppend: true,
          ),
        ),
      );
      await _pump(tester);
      final conversation = find.byKey(
        const ValueKey('forge-conversation-conversation-001'),
      );
      await tester.scrollUntilVisible(
        conversation,
        500,
        scrollable: find.byType(Scrollable).first,
      );
      expect(conversation, findsOneWidget);
      await tester.tap(conversation);
      await _pump(tester);

      final promptField = find.byType(TextField).last;
      await tester.enterText(promptField, 'journey prompt');
      final appendButton = find.widgetWithText(FilledButton, 'Append prompt');
      expect(appendButton, findsOneWidget);
      expect(tester.widget<FilledButton>(appendButton).onPressed, isNotNull);
      await tester.tap(appendButton);
      await _pump(tester);

      expect(submitCalls, 1);
      expect(find.text('journey prompt'), findsOneWidget);
      expect(
        find.text('Prompt stored. It has not started a task.'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'Prompt append refreshes the composed inventory/resource proof before POST',
    (tester) async {
      final store = await _credentialStore();
      final inventory = _inventoryConvergence();
      final session = _sessionConvergence(matchInventory: true);
      final driftedJSON = inventory.toJson();
      final driftedResource = Map<String, dynamic>.from(
        driftedJSON['resource_view']! as Map,
      );
      final driftedInstances = (driftedResource['instances']! as List)
          .map((entry) => Map<String, dynamic>.from(entry as Map))
          .toList(growable: true);
      driftedInstances[0]['status'] = 'idle';
      driftedResource['instances'] = driftedInstances;
      driftedJSON['resource_view'] = driftedResource;
      final drifted = ForgeDeviceInventoryResourceConvergence.fromJson(
        driftedJSON,
      );
      var convergenceReads = 0;
      var submitCalls = 0;
      final client = MockClient((request) async {
        final path = request.url.path;
        if (path == '/api/v1/conversations') {
          return _json({
            'conversations': [_ownedConversation()],
            'has_more': false,
          });
        }
        if (path.endsWith('/conversations/conversation-001/prompts')) {
          return _json({
            'conversation_id': 'conversation-001',
            'prompts': <Object>[],
            'has_more': false,
          });
        }
        if (path.endsWith('/conversations/conversation-001/runs')) {
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
            clientInstanceSessionResourceConvergenceOwner: _owner,
            clientInstanceSessionResourceConvergenceReader: (_) async =>
                session,
            deviceInventoryResourceConvergenceOwner: _owner,
            deviceInventoryResourceConvergenceReader: (_) async {
              convergenceReads++;
              return convergenceReads == 1 ? inventory : drifted;
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
                    promptID: 'prompt-journey',
                    createdAtMS: 31,
                    replayed: false,
                  );
                },
            requireDeviceInventoryResourceConvergenceForPromptAppend: true,
          ),
        ),
      );
      await _pump(tester);
      final conversation = find.byKey(
        const ValueKey('forge-conversation-conversation-001'),
      );
      await tester.scrollUntilVisible(
        conversation,
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(conversation);
      await _pump(tester);

      final promptField = find.byType(TextField).last;
      await tester.enterText(promptField, 'refresh before write');
      final appendButton = find.widgetWithText(FilledButton, 'Append prompt');
      expect(appendButton, findsOneWidget);
      expect(tester.widget<FilledButton>(appendButton).onPressed, isNotNull);
      await tester.tap(appendButton);
      await _pump(tester);

      expect(convergenceReads, greaterThanOrEqualTo(2));
      expect(submitCalls, 0);
      expect(
        find.text(
          'Prompt append blocked by inventory/resource observation drift. No request was sent.',
        ),
        findsOneWidget,
      );
    },
  );
}
