import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sso_admin/api/forge_client_instance_resource_view.dart';
import 'package:sso_admin/api/forge_client_instance_session_view.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/api/forge_device_inventory_v2_models.dart';
import 'package:sso_admin/api/forge_runner_execution_intent.dart';
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

http.Response _json(Object value) => http.Response(
  jsonEncode(value),
  200,
  headers: const {'content-type': 'application/json'},
);

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

  testWidgets('explicit Gate posts one Runner execution-intent preview', (
    tester,
  ) async {
    final request = _request();
    final store = await _credentialStore('intent-token');
    final requests = <http.Request>[];
    final client = MockClient((incoming) async {
      requests.add(incoming);
      if (incoming.method == 'GET' &&
          incoming.url.path == '/api/v1/conversations') {
        return _json({
          'conversations': [_conversation()],
          'has_more': false,
        });
      }
      if (incoming.method == 'GET' &&
          incoming.url.path ==
              '/api/v1/conversations/conversation-001/prompts') {
        return _json({
          'conversation_id': 'conversation-001',
          'prompts': <Object>[],
          'has_more': false,
        });
      }
      if (incoming.method == 'GET' &&
          incoming.url.path == '/api/v1/conversations/conversation-001/runs') {
        return _json({
          'conversation_id': 'conversation-001',
          'runs': [_run()],
          'has_more': false,
        });
      }
      if (incoming.method == 'GET' &&
          incoming.url.path ==
              '/api/v1/conversations/conversation-001/runs/run-001/timeline') {
        return _json({
          'conversation_id': 'conversation-001',
          'run_id': 'run-001',
          'after_sequence': 0,
          'scanned_through_sequence': 0,
          'has_more': false,
          'events': <Object>[],
        });
      }
      if (incoming.method == 'POST' &&
          incoming.url.path ==
              '/api/v1/conversations/conversation-001/runs/run-001/'
                  'runner-execution-intent/preview') {
        expect(incoming.headers['authorization'], 'Bearer intent-token');
        final received = _requestFromJson(jsonDecode(incoming.body));
        expect(
          jsonEncode(observeForgeRunnerExecutionIntent(received).toJson()),
          jsonEncode(observeForgeRunnerExecutionIntent(request).toJson()),
        );
        return _json(observeForgeRunnerExecutionIntent(request).toJson());
      }
      throw StateError(
        'Unexpected Forge request: ${incoming.method} ${incoming.url}',
      );
    });
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsGate(
          credentialStore: store,
          httpClient: client,
          runnerExecutionIntentRequest: request,
          runnerExecutionIntentCandidateApiOrigin: 'https://candidate.example',
          enableRunnerExecutionIntentCandidate: true,
        ),
      ),
    );
    await _settle(tester);
    await tester.drag(find.byType(ListView), const Offset(0, -4000));
    await tester.pumpAndSettle();
    expect(find.text('Runner execution intent preview'), findsOneWidget);
    expect(find.text(request.command.leaseProof.fencingToken), findsNothing);
    expect(find.text(request.command.workspaceRef), findsNothing);
    expect(find.text(request.command.argv.first), findsNothing);
    expect(
      requests.where(
        (value) => value.url.path.endsWith('runner-execution-intent/preview'),
      ),
      hasLength(1),
    );
  });

  testWidgets('default Gate keeps Runner execution-intent request-free', (
    tester,
  ) async {
    final store = await _credentialStore('default-intent-token');
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/api/v1/conversations') {
        return _json({'conversations': <Object>[], 'has_more': false});
      }
      throw StateError('Default Gate contacted candidate: $request');
    });
    addTearDown(client.close);
    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsGate(
          credentialStore: store,
          httpClient: client,
          runnerExecutionIntentRequest: _request(),
        ),
      ),
    );
    await _settle(tester);
    expect(
      requests.where(
        (request) =>
            request.url.path.endsWith('runner-execution-intent/preview'),
      ),
      isEmpty,
    );
  });

  testWidgets(
    'execution-intent candidate rereads the selected projection and inventory before POST',
    (tester) async {
      final request = _request();
      final store = await _credentialStore('intent-refresh-token');
      final events = <String>[];
      final requests = <http.Request>[];
      final inventory = _inventory(_owner);
      final resource = _resourceViewWithDevice(_owner);
      final client = MockClient((incoming) async {
        requests.add(incoming);
        if (incoming.method == 'GET' &&
            incoming.url.path == '/api/v1/conversations') {
          return _json({
            'conversations': [_conversation()],
            'has_more': false,
          });
        }
        if (incoming.method == 'GET' &&
            incoming.url.path ==
                '/api/v1/conversations/conversation-001/prompts') {
          return _json({
            'conversation_id': 'conversation-001',
            'prompts': <Object>[],
            'has_more': false,
          });
        }
        if (incoming.method == 'GET' &&
            incoming.url.path ==
                '/api/v1/conversations/conversation-001/runs') {
          return _json({
            'conversation_id': 'conversation-001',
            'runs': [_run()],
            'has_more': false,
          });
        }
        if (incoming.method == 'GET' &&
            incoming.url.path ==
                '/api/v1/conversations/conversation-001/runs/run-001/timeline') {
          return _json({
            'conversation_id': 'conversation-001',
            'run_id': 'run-001',
            'after_sequence': 0,
            'scanned_through_sequence': 0,
            'has_more': false,
            'events': <Object>[],
          });
        }
        if (incoming.method == 'POST' &&
            incoming.url.path ==
                '/api/v1/conversations/conversation-001/runs/run-001/'
                    'runner-execution-intent/preview') {
          events.add('candidate');
          return _json(observeForgeRunnerExecutionIntent(request).toJson());
        }
        throw StateError(
          'Unexpected Forge request: ${incoming.method} ${incoming.url}',
        );
      });
      addTearDown(client.close);

      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsGate(
            credentialStore: store,
            httpClient: client,
            initialClientInstanceID: 'client-web-001',
            clientInstanceSessionViewOwner: _owner,
            clientInstanceSessionViewReader: (_) async {
              events.add('session');
              return _sessionView(_owner);
            },
            clientInstanceResourceViewOwner: _owner,
            clientInstanceResourceViewReader: (_) async {
              events.add('resource');
              return resource;
            },
            deviceInventoryOwner: _owner,
            deviceInventoryV2Reader: (_) async {
              events.add('inventory');
              return inventory;
            },
            runnerExecutionIntentRequest: request,
            runnerExecutionIntentCandidateApiOrigin:
                'https://candidate.example',
            enableRunnerExecutionIntentCandidate: true,
          ),
        ),
      );
      await _settle(tester);

      final candidateIndex = events.lastIndexOf('candidate');
      expect(candidateIndex, greaterThanOrEqualTo(4));
      expect(events[candidateIndex - 4], 'session');
      expect(events[candidateIndex - 3], 'resource');
      expect(events[candidateIndex - 2], 'inventory');
      expect(events[candidateIndex - 1], 'resource');
      expect(
        events.where((event) => event == 'session').length,
        greaterThan(1),
      );
      expect(
        events.where((event) => event == 'resource').length,
        greaterThan(2),
      );
      expect(
        events.where((event) => event == 'inventory').length,
        greaterThan(0),
      );
      expect(
        requests.where(
          (value) => value.url.path.endsWith('runner-execution-intent/preview'),
        ),
        hasLength(1),
      );
    },
  );

  testWidgets(
    'execution-intent candidate stays closed when the refreshed resource drifts',
    (tester) async {
      final request = _request();
      final store = await _credentialStore('intent-drift-token');
      final requests = <http.Request>[];
      final inventory = _inventory(_owner);
      final resource = _resourceViewWithDevice(_owner);
      final driftedJSON = resource.toJson();
      final driftedDevices = (driftedJSON['devices']! as List)
          .map((entry) => Map<String, dynamic>.from(entry as Map))
          .toList(growable: true);
      driftedDevices[0]['revision'] = 4;
      driftedJSON['devices'] = driftedDevices;
      final drifted = ForgeClientInstanceResourceView.fromJson(driftedJSON);
      var resourceReads = 0;
      var inventoryReads = 0;
      var candidateCalls = 0;
      final client = MockClient((incoming) async {
        requests.add(incoming);
        if (incoming.method == 'GET' &&
            incoming.url.path == '/api/v1/conversations') {
          return _json({
            'conversations': [_conversation()],
            'has_more': false,
          });
        }
        if (incoming.method == 'GET' &&
            incoming.url.path ==
                '/api/v1/conversations/conversation-001/prompts') {
          return _json({
            'conversation_id': 'conversation-001',
            'prompts': <Object>[],
            'has_more': false,
          });
        }
        if (incoming.method == 'GET' &&
            incoming.url.path ==
                '/api/v1/conversations/conversation-001/runs') {
          return _json({
            'conversation_id': 'conversation-001',
            'runs': [_run()],
            'has_more': false,
          });
        }
        if (incoming.method == 'GET' &&
            incoming.url.path ==
                '/api/v1/conversations/conversation-001/runs/run-001/timeline') {
          return _json({
            'conversation_id': 'conversation-001',
            'run_id': 'run-001',
            'after_sequence': 0,
            'scanned_through_sequence': 0,
            'has_more': false,
            'events': <Object>[],
          });
        }
        if (incoming.method == 'POST' &&
            incoming.url.path ==
                '/api/v1/conversations/conversation-001/runs/run-001/'
                    'runner-execution-intent/preview') {
          candidateCalls++;
          return _json(observeForgeRunnerExecutionIntent(request).toJson());
        }
        throw StateError(
          'Unexpected Forge request: ${incoming.method} ${incoming.url}',
        );
      });
      addTearDown(client.close);

      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsGate(
            credentialStore: store,
            httpClient: client,
            initialClientInstanceID: 'client-web-001',
            clientInstanceSessionViewOwner: _owner,
            clientInstanceSessionViewReader: (_) async => _sessionView(_owner),
            clientInstanceResourceViewOwner: _owner,
            clientInstanceResourceViewReader: (_) async {
              resourceReads++;
              return resourceReads < 3 ? resource : drifted;
            },
            deviceInventoryOwner: _owner,
            deviceInventoryV2Reader: (_) async {
              inventoryReads++;
              return inventory;
            },
            runnerExecutionIntentRequest: request,
            runnerExecutionIntentCandidateApiOrigin:
                'https://candidate.example',
            enableRunnerExecutionIntentCandidate: true,
          ),
        ),
      );
      await _settle(tester);

      expect(resourceReads, greaterThanOrEqualTo(3));
      expect(inventoryReads, greaterThan(0));
      expect(candidateCalls, 0);
      expect(
        requests.where(
          (value) => value.url.path.endsWith('runner-execution-intent/preview'),
        ),
        isEmpty,
      );
    },
  );
}

ForgeRunnerExecutionIntentRequest _request() {
  const conversationID = 'conversation-001';
  const promptID = 'prompt-001';
  const runID = 'run-001';
  const attemptID = 'attempt-001';
  const commandID = 'command-001';
  const targetID = 'runner-a';
  final idempotencyKey = '$runID:$attemptID:$commandID';
  final command = ForgeRunnerExecutionCommand(
    version: 1,
    commandID: commandID,
    leaseProof: const ForgeRunnerExecutionLeaseProof(
      attemptID: attemptID,
      targetID: targetID,
      epoch: 1,
      fencingToken: 'fence-a',
    ),
    idempotencyKey: idempotencyKey,
    workspaceRef: 'workspace-001',
    argv: const ['forge-task', '--prompt-ref', promptID],
    timeoutMS: 5000,
    maxOutputBytes: 65536,
  );
  return ForgeRunnerExecutionIntentRequest(
    owner: _owner,
    conversationID: conversationID,
    prompt: const ForgeRunnerExecutionPromptReceipt(
      promptID: promptID,
      conversationID: conversationID,
      role: 'user',
      acceptedAtMS: 200,
      intentID: 'intent-001',
      initialEventID: 'event-001',
      initialEventSequence: 1,
      initialEventType: 'submitted',
      replayed: false,
    ),
    run: const ForgeRunnerExecutionRunReference(
      runID: runID,
      conversationID: conversationID,
      promptID: promptID,
      createdAtMS: 200,
      latestSequence: 5,
      status: 'nonterminal',
    ),
    binding: ForgeRunnerExecutionIntentBinding(
      conversationID: conversationID,
      promptID: promptID,
      runID: runID,
      attemptID: attemptID,
      commandID: commandID,
      targetID: targetID,
      commandSHA256: command.commandSHA256(),
      idempotencyKey: idempotencyKey,
      selectedTargetID: null,
    ),
    command: command,
  );
}

ForgeRunnerExecutionIntentRequest _requestFromJson(Object? value) {
  final json = Map<String, dynamic>.from(value as Map);
  final prompt = Map<String, dynamic>.from(json['prompt_receipt'] as Map);
  final run = Map<String, dynamic>.from(json['run_reference'] as Map);
  final binding = Map<String, dynamic>.from(json['execution_intent'] as Map);
  final command = Map<String, dynamic>.from(json['command'] as Map);
  final proof = Map<String, dynamic>.from(command['lease_proof'] as Map);
  return ForgeRunnerExecutionIntentRequest(
    owner: ForgeDeviceOwner.fromJson(json['owner']),
    conversationID: json['conversation_id'] as String,
    prompt: ForgeRunnerExecutionPromptReceipt(
      promptID: prompt['prompt_id'] as String,
      conversationID: prompt['conversation_id'] as String,
      role: prompt['role'] as String,
      acceptedAtMS: prompt['accepted_at_ms'] as int,
      intentID: prompt['intent_id'] as String,
      initialEventID: prompt['initial_event_id'] as String,
      initialEventSequence: prompt['initial_event_sequence'] as int,
      initialEventType: prompt['initial_event_type'] as String,
      replayed: prompt['replayed'] as bool,
    ),
    run: ForgeRunnerExecutionRunReference(
      runID: run['run_id'] as String,
      conversationID: run['conversation_id'] as String,
      promptID: run['prompt_id'] as String,
      createdAtMS: run['created_at_ms'] as int,
      latestSequence: run['latest_sequence'] as int,
      status: run['status'] as String,
    ),
    binding: ForgeRunnerExecutionIntentBinding(
      conversationID: binding['conversation_id'] as String,
      promptID: binding['prompt_id'] as String,
      runID: binding['run_id'] as String,
      attemptID: binding['attempt_id'] as String,
      commandID: binding['command_id'] as String,
      targetID: binding['target_id'] as String,
      commandSHA256: binding['command_sha256'] as String,
      idempotencyKey: binding['idempotency_key'] as String,
      selectedTargetID: binding['selected_target_id'] as String?,
    ),
    command: ForgeRunnerExecutionCommand(
      version: command['v'] as int,
      commandID: command['command_id'] as String,
      leaseProof: ForgeRunnerExecutionLeaseProof(
        attemptID: proof['attempt_id'] as String,
        targetID: proof['target_id'] as String,
        epoch: proof['epoch'] as int,
        fencingToken: proof['fencing_token'] as String,
      ),
      idempotencyKey: command['idempotency_key'] as String,
      workspaceRef: command['workspace_ref'] as String,
      argv: List<String>.from(command['argv'] as List),
      timeoutMS: command['timeout_ms'] as int,
      maxOutputBytes: command['max_output_bytes'] as int,
    ),
  );
}

Map<String, dynamic> _conversation() => {
  'conversation': {
    'id': 'conversation-001',
    'scope': {'kind': 'global'},
    'title': 'Intent test',
    'created_at_ms': 100,
    'updated_at_ms': 100,
  },
  'aggregate_version': 1,
};

Map<String, dynamic> _run() => {
  'run_id': 'run-001',
  'prompt_id': 'prompt-001',
  'created_at_ms': 200,
  'latest_sequence': 5,
  'status': 'nonterminal',
};

ForgeClientInstanceSessionView _sessionView(ForgeDeviceOwner owner) =>
    ForgeClientInstanceSessionView.fromJson({
      'schema_version': forgeClientInstanceSessionViewSchema,
      'evaluation_mode': forgeClientInstanceSessionViewEvaluationMode,
      'owner_declaration': owner.toJson(),
      'owner_declaration_unverified': true,
      'instances': [
        {
          'instance_id': 'client-web-001',
          'client_kind': 'web',
          'session_ids': ['conversation-001'],
          'observed_at_ms': 1,
          'status': 'active',
        },
      ],
      'read_only': true,
      'authority': const ForgeClientInstanceSessionViewAuthority.offline()
          .toJson(),
    });

ForgeClientInstanceResourceView _resourceView(ForgeDeviceOwner owner) =>
    ForgeClientInstanceResourceView.fromJson({
      'schema_version': forgeClientInstanceResourceViewSchema,
      'evaluation_mode': forgeClientInstanceResourceViewEvaluationMode,
      'owner_declaration': owner.toJson(),
      'owner_declaration_unverified': true,
      'instances': [
        {
          'instance_id': 'client-web-001',
          'client_kind': 'web',
          'session_ids': ['conversation-001'],
          'observed_at_ms': 1,
          'status': 'active',
        },
      ],
      'devices': <Object>[],
      'device_attributes_unverified': true,
      'read_only': true,
      'authority': const ForgeClientInstanceSessionViewAuthority.offline()
          .toJson(),
    });

ForgeClientInstanceResourceView _resourceViewWithDevice(
  ForgeDeviceOwner owner,
) {
  final value = _resourceView(owner).toJson();
  value['devices'] = [
    {
      'device_id': 'device-a',
      'runner_instance_id': 'runner-a',
      'owner': owner.toJson(),
      'revision': 3,
      'generation': 2,
      'heartbeat_sequence': 4,
      'observed_at_ms': 150000,
      'approval_state': 'approved',
      'cordon_state': 'clear',
      'reservation_state': 'none',
      'liveness': 'online',
      'os': 'linux',
      'architecture': 'amd64',
      'cpu_cores': 8,
      'available_cpu_cores': 8,
      'memory_bytes': 16384,
      'available_memory_bytes': 16384,
      'storage_bytes': 8192,
      'available_storage_bytes': 8192,
      'gpu_count': 0,
      'available_gpu_memory_bytes': 0,
    },
  ];
  return ForgeClientInstanceResourceView.fromJson(value);
}

ForgeDeviceInventoryPageV2 _inventory(ForgeDeviceOwner owner) =>
    ForgeDeviceInventoryPageV2.fromJson({
      'schema_version': forgeDeviceInventoryV2Schema,
      'evaluation_mode': forgeDeviceInventoryV2EvaluationMode,
      'evaluated_at_ms': 200000,
      'owner_declaration': owner.toJson(),
      'owner_declaration_unverified': true,
      'inventory_declarations_unverified': true,
      'notice': forgeDeviceInventoryV2Notice,
      'devices': [
        {
          'instance_id': 'runner-a',
          'revision': 3,
          'generation': 2,
          'heartbeat_sequence': 4,
          'device': {
            'device_id': 'device-a',
            'owner': owner.toJson(),
            'approval_state': 'approved',
            'cordon_state': 'clear',
            'reservation_state': 'none',
            'liveness': 'online',
            'snapshot_observed_at_ms': 150000,
            'lease_expires_at_ms': 210000,
            'os': 'linux',
            'architecture': 'amd64',
            'available_cpu_cores': 8,
            'available_memory_bytes': 16384,
            'available_storage_bytes': 8192,
            'runtimes': ['oci'],
            'gpus': <Object>[],
            'data_residency_zones': <Object>[],
            'trust_zone': 'unknown',
            'sandbox_levels': <Object>[],
            'concurrency_limit': 0,
            'active_concurrency': 0,
          },
        },
      ],
      'execution_authorized': false,
      'reservation_created': false,
      'dispatch_performed': false,
    });

Future<ForgeCredentialStore> _credentialStore(String token) async {
  final store = ForgeCredentialStore(
    backend: MemoryForgeCredentialBackend(),
    forcePersistentStorage: true,
  );
  expect(await store.store(accessToken: token), isTrue);
  return store;
}

Future<void> _settle(WidgetTester tester) async {
  for (var index = 0; index < 10; index++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}
