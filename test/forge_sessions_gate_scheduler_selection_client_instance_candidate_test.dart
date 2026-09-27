import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/forge_client_instance_resource_view.dart';
import 'package:sso_admin/api/forge_client_instance_session_view.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/api/forge_device_inventory_resource_convergence.dart';
import 'package:sso_admin/api/forge_device_inventory_v2_models.dart';
import 'package:sso_admin/api/forge_device_placement.dart';
import 'package:sso_admin/api/forge_client_instance_session_resource_convergence.dart';
import 'package:sso_admin/api/forge_scheduler_selection_preview.dart';
import 'package:sso_admin/screens/forge/forge_sessions_gate.dart';
import 'package:sso_admin/screens/forge/forge_sessions_screen.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/services/forge_credential_store.dart';
import 'package:sso_admin/session.dart';

import 'support/memory_forge_credential_backend.dart';

void main() {
  setUp(BrowserNavigation.resetForTest);
  tearDown(() {
    BrowserNavigation.resetForTest();
    Session.clear();
  });

  testWidgets(
    'scheduler preview reads the selected instance pair before its POST',
    (tester) async {
      final owner = _owner();
      final store = await _credentialStore('scheduler-instance-token');
      final events = <String>[];
      final sessionFixture = _sessionView(owner, 'conversation-visible');
      final resourceFixture = _resourceView(owner, 'conversation-visible');
      expect(
        forgeClientInstanceSessionResourceObservationsConverged(
          sessionFixture,
          resourceFixture,
        ),
        isTrue,
      );
      final client = MockClient((request) async {
        if (request.method == 'GET' &&
            request.url.path == '/api/v1/conversations') {
          return _json({
            'conversations': [_conversation('conversation-visible')],
            'has_more': false,
          });
        }
        if (request.method == 'GET' &&
            request.url.path ==
                '/api/v1/conversations/conversation-visible/prompts') {
          return _json({
            'conversation_id': 'conversation-visible',
            'prompts': <Object>[],
            'has_more': false,
          });
        }
        if (request.method == 'GET' &&
            request.url.path ==
                '/api/v1/conversations/conversation-visible/runs') {
          return _json({
            'conversation_id': 'conversation-visible',
            'runs': [_run('run-visible')],
            'has_more': false,
          });
        }
        if (request.method == 'GET' &&
            request.url.path ==
                '/api/v1/conversations/conversation-visible/runs/run-visible/timeline') {
          return _json({
            'conversation_id': 'conversation-visible',
            'run_id': 'run-visible',
            'after_sequence': 0,
            'scanned_through_sequence': 0,
            'has_more': false,
            'events': <Object>[],
          });
        }
        if (request.method == 'POST' &&
            request.url.path == '/api/v1/device-placement/scheduler-preview') {
          events.add('preview');
          return _json(_preview().toJson());
        }
        throw StateError('Unexpected Forge request: $request');
      });
      addTearDown(client.close);
      addTearDown(store.clear);

      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsGate(
            credentialStore: store,
            httpClient: client,
            initialConversationID: 'conversation-visible',
            initialClientInstanceID: 'client-web-001',
            clientInstanceSessionViewOwner: owner,
            clientInstanceSessionViewReader: (_) async {
              events.add('session');
              return sessionFixture;
            },
            clientInstanceResourceViewOwner: owner,
            clientInstanceResourceViewReader: (_) async {
              events.add('resource');
              return resourceFixture;
            },
            schedulerSelectionPreviewRequest: _request(),
            schedulerSelectionPreviewCandidateApiOrigin:
                'https://candidate.example',
            enableSchedulerSelectionPreviewCandidate: true,
          ),
        ),
      );
      await _settle(tester);

      expect(events, isNotEmpty);
      final previewIndex = events.lastIndexOf('preview');
      expect(previewIndex, greaterThanOrEqualTo(2));
      expect(events[previewIndex - 2], 'session');
      expect(events[previewIndex - 1], 'resource');
      expect(events.where((event) => event == 'preview'), hasLength(1));
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'scheduler preview stays closed when the selected instance hides the run',
    (tester) async {
      final owner = _owner();
      final store = await _credentialStore('scheduler-hidden-instance-token');
      final events = <String>[];
      final client = MockClient((request) async {
        if (request.method == 'GET' &&
            request.url.path == '/api/v1/conversations') {
          return _json({
            'conversations': [_conversation('conversation-hidden')],
            'has_more': false,
          });
        }
        if (request.method == 'POST' &&
            request.url.path == '/api/v1/device-placement/scheduler-preview') {
          events.add('preview');
          throw StateError('hidden instance must not reach scheduler preview');
        }
        if (request.method == 'GET' && request.url.path.contains('/prompts')) {
          return _json({
            'conversation_id': 'conversation-hidden',
            'prompts': <Object>[],
            'has_more': false,
          });
        }
        if (request.method == 'GET' && request.url.path.contains('/runs')) {
          return _json({
            'conversation_id': 'conversation-hidden',
            'runs': <Object>[],
            'has_more': false,
          });
        }
        throw StateError('Unexpected Forge request: $request');
      });
      addTearDown(client.close);
      addTearDown(store.clear);

      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsGate(
            credentialStore: store,
            httpClient: client,
            initialClientInstanceID: 'client-web-001',
            clientInstanceSessionViewOwner: owner,
            clientInstanceSessionViewReader: (_) async {
              events.add('session');
              return _sessionView(owner, 'conversation-visible');
            },
            clientInstanceResourceViewOwner: owner,
            clientInstanceResourceViewReader: (_) async {
              events.add('resource');
              return _resourceView(owner, 'conversation-visible');
            },
            schedulerSelectionPreviewRequest: _request(
              conversationID: 'conversation-hidden',
              runID: 'run-hidden',
            ),
            schedulerSelectionPreviewCandidateApiOrigin:
                'https://candidate.example',
            enableSchedulerSelectionPreviewCandidate: true,
          ),
        ),
      );
      await _settle(tester);

      expect(events.where((event) => event == 'preview'), isEmpty);
      expect(find.text('Scheduler selection preview'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'scheduler preview rejects a target absent from the resource observation',
    (tester) async {
      final owner = _owner();
      final store = await _credentialStore('scheduler-target-drift-token');
      final events = <String>[];
      final client = MockClient((request) async {
        if (request.method == 'GET' &&
            request.url.path == '/api/v1/conversations') {
          return _json({
            'conversations': [_conversation('conversation-visible')],
            'has_more': false,
          });
        }
        if (request.method == 'GET' && request.url.path.contains('/prompts')) {
          return _json({
            'conversation_id': 'conversation-visible',
            'prompts': <Object>[],
            'has_more': false,
          });
        }
        if (request.method == 'GET' &&
            request.url.path.contains('/runs/run-visible/timeline')) {
          return _json({
            'conversation_id': 'conversation-visible',
            'run_id': 'run-visible',
            'after_sequence': 0,
            'scanned_through_sequence': 0,
            'has_more': false,
            'events': <Object>[],
          });
        }
        if (request.method == 'GET' && request.url.path.contains('/runs')) {
          return _json({
            'conversation_id': 'conversation-visible',
            'runs': [_run('run-visible')],
            'has_more': false,
          });
        }
        if (request.method == 'POST' &&
            request.url.path == '/api/v1/device-placement/scheduler-preview') {
          events.add('preview');
          return _json(
            _preview(
              selectedDeviceID: 'device-foreign',
              selectedInstanceID: 'runner-foreign',
            ).toJson(),
          );
        }
        throw StateError('Unexpected Forge request: $request');
      });
      addTearDown(client.close);
      addTearDown(store.clear);

      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsGate(
            credentialStore: store,
            httpClient: client,
            initialConversationID: 'conversation-visible',
            initialClientInstanceID: 'client-web-001',
            clientInstanceSessionViewOwner: owner,
            clientInstanceSessionViewReader: (_) async =>
                _sessionView(owner, 'conversation-visible'),
            clientInstanceResourceViewOwner: owner,
            clientInstanceResourceViewReader: (_) async =>
                _resourceViewWithDevice(owner, 'conversation-visible'),
            schedulerSelectionPreviewRequest: _request(),
            schedulerSelectionPreviewCandidateApiOrigin:
                'https://candidate.example',
            enableSchedulerSelectionPreviewCandidate: true,
          ),
        ),
      );
      await _settle(tester);

      expect(events, contains('preview'));
      expect(
        find.byKey(const ValueKey('forge-scheduler-selection-preview-panel')),
        findsNothing,
      );
      expect(find.text('device-foreign'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets('static scheduler preview stays hidden when its target is absent', (
    tester,
  ) async {
    final owner = _owner();
    final store = await _credentialStore('scheduler-static-drift-token');
    final client = MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations') {
        return _json({
          'conversations': [_conversation('conversation-visible')],
          'has_more': false,
        });
      }
      if (request.method == 'GET' && request.url.path.contains('/prompts')) {
        return _json({
          'conversation_id': 'conversation-visible',
          'prompts': <Object>[],
          'has_more': false,
        });
      }
      if (request.method == 'GET' &&
          request.url.path ==
              '/api/v1/conversations/conversation-visible/runs') {
        return _json({
          'conversation_id': 'conversation-visible',
          'runs': [_run('run-visible')],
          'has_more': false,
        });
      }
      if (request.method == 'GET' &&
          request.url.path ==
              '/api/v1/conversations/conversation-visible/runs/run-visible/timeline') {
        return _json({
          'conversation_id': 'conversation-visible',
          'run_id': 'run-visible',
          'after_sequence': 0,
          'scanned_through_sequence': 0,
          'has_more': false,
          'events': <Object>[],
        });
      }
      throw StateError('Unexpected Forge request: $request');
    });
    addTearDown(client.close);
    addTearDown(store.clear);

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: 'scheduler-static-token',
          apiOrigin: 'https://forge.example',
          credentialStore: store,
          httpClient: client,
          initialConversationID: 'conversation-visible',
          initialClientInstanceID: 'client-web-001',
          clientInstanceSessionViewOwner: owner,
          clientInstanceSessionViewReader: (_) async =>
              _sessionView(owner, 'conversation-visible'),
          clientInstanceResourceViewOwner: owner,
          clientInstanceResourceViewReader: (_) async =>
              _resourceViewWithDevice(owner, 'conversation-visible'),
          schedulerSelectionPreview: _preview(
            selectedDeviceID: 'device-foreign',
            selectedInstanceID: 'runner-foreign',
          ),
        ),
      ),
    );
    await _settle(tester);

    expect(
      find.byKey(const ValueKey('forge-scheduler-selection-preview-panel')),
      findsNothing,
    );
    expect(find.text('device-foreign'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets(
    'scheduler preview forces a fresh inventory/resource pair before POST',
    (tester) async {
      final owner = _owner();
      final store = await _credentialStore('scheduler-refresh-token');
      final events = <String>[];
      final inventory = _inventory(owner);
      final resource = _resourceViewWithDevice(owner, 'conversation-visible');
      expect(
        forgeDeviceInventoryAndResourceObservationsConverged(
          inventory,
          resource,
        ),
        isTrue,
      );
      final client = MockClient((request) async {
        if (request.method == 'GET' &&
            request.url.path == '/api/v1/conversations') {
          return _json({
            'conversations': [_conversation('conversation-visible')],
            'has_more': false,
          });
        }
        if (request.method == 'GET' &&
            request.url.path ==
                '/api/v1/conversations/conversation-visible/prompts') {
          return _json({
            'conversation_id': 'conversation-visible',
            'prompts': <Object>[],
            'has_more': false,
          });
        }
        if (request.method == 'GET' &&
            request.url.path ==
                '/api/v1/conversations/conversation-visible/runs') {
          return _json({
            'conversation_id': 'conversation-visible',
            'runs': [_run('run-visible')],
            'has_more': false,
          });
        }
        if (request.method == 'GET' &&
            request.url.path ==
                '/api/v1/conversations/conversation-visible/runs/run-visible/timeline') {
          return _json({
            'conversation_id': 'conversation-visible',
            'run_id': 'run-visible',
            'after_sequence': 0,
            'scanned_through_sequence': 0,
            'has_more': false,
            'events': <Object>[],
          });
        }
        if (request.method == 'POST' &&
            request.url.path == '/api/v1/device-placement/scheduler-preview') {
          events.add('preview');
          return _json(_preview().toJson());
        }
        throw StateError('Unexpected Forge request: $request');
      });
      addTearDown(client.close);
      addTearDown(store.clear);

      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsGate(
            credentialStore: store,
            httpClient: client,
            initialConversationID: 'conversation-visible',
            initialClientInstanceID: 'client-web-001',
            clientInstanceSessionViewOwner: owner,
            clientInstanceSessionViewReader: (_) async =>
                _sessionView(owner, 'conversation-visible'),
            clientInstanceResourceViewOwner: owner,
            clientInstanceResourceViewReader: (_) async {
              events.add('resource');
              return resource;
            },
            deviceInventoryOwner: owner,
            deviceInventoryV2Reader: (_) async {
              events.add('inventory');
              return inventory;
            },
            schedulerSelectionPreviewRequest: _request(),
            schedulerSelectionPreviewCandidateApiOrigin:
                'https://candidate.example',
            enableSchedulerSelectionPreviewCandidate: true,
          ),
        ),
      );
      await _settle(tester);

      final previewIndex = events.lastIndexOf('preview');
      expect(previewIndex, greaterThanOrEqualTo(2));
      expect(events.sublist(previewIndex - 2, previewIndex), [
        'inventory',
        'resource',
      ]);
      expect(
        events.where((event) => event == 'inventory').length,
        greaterThan(1),
      );
      expect(
        events.where((event) => event == 'resource').length,
        greaterThan(1),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );

  testWidgets(
    'scheduler preview blocks when the forced resource refresh drifts',
    (tester) async {
      final owner = _owner();
      final store = await _credentialStore('scheduler-refresh-drift-token');
      final inventory = _inventory(owner);
      final resource = _resourceViewWithDevice(owner, 'conversation-visible');
      final driftedJSON = resource.toJson();
      final driftedDevices = (driftedJSON['devices']! as List)
          .map((entry) => Map<String, dynamic>.from(entry as Map))
          .toList(growable: true);
      driftedDevices[0]['revision'] = 4;
      driftedJSON['devices'] = driftedDevices;
      final drifted = ForgeClientInstanceResourceView.fromJson(driftedJSON);
      var resourceReads = 0;
      var inventoryReads = 0;
      var previewCalls = 0;
      final client = MockClient((request) async {
        if (request.method == 'GET' &&
            request.url.path == '/api/v1/conversations') {
          return _json({
            'conversations': [_conversation('conversation-visible')],
            'has_more': false,
          });
        }
        if (request.method == 'GET' &&
            request.url.path ==
                '/api/v1/conversations/conversation-visible/prompts') {
          return _json({
            'conversation_id': 'conversation-visible',
            'prompts': <Object>[],
            'has_more': false,
          });
        }
        if (request.method == 'GET' &&
            request.url.path ==
                '/api/v1/conversations/conversation-visible/runs') {
          return _json({
            'conversation_id': 'conversation-visible',
            'runs': [_run('run-visible')],
            'has_more': false,
          });
        }
        if (request.method == 'GET' &&
            request.url.path ==
                '/api/v1/conversations/conversation-visible/runs/run-visible/timeline') {
          return _json({
            'conversation_id': 'conversation-visible',
            'run_id': 'run-visible',
            'after_sequence': 0,
            'scanned_through_sequence': 0,
            'has_more': false,
            'events': <Object>[],
          });
        }
        if (request.method == 'POST' &&
            request.url.path == '/api/v1/device-placement/scheduler-preview') {
          previewCalls++;
          return _json(_preview().toJson());
        }
        throw StateError('Unexpected Forge request: $request');
      });
      addTearDown(client.close);
      addTearDown(store.clear);

      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsGate(
            credentialStore: store,
            httpClient: client,
            initialConversationID: 'conversation-visible',
            initialClientInstanceID: 'client-web-001',
            clientInstanceSessionViewOwner: owner,
            clientInstanceSessionViewReader: (_) async =>
                _sessionView(owner, 'conversation-visible'),
            clientInstanceResourceViewOwner: owner,
            clientInstanceResourceViewReader: (_) async {
              resourceReads++;
              return resourceReads < 3 ? resource : drifted;
            },
            deviceInventoryOwner: owner,
            deviceInventoryV2Reader: (_) async {
              inventoryReads++;
              return inventory;
            },
            schedulerSelectionPreviewRequest: _request(),
            schedulerSelectionPreviewCandidateApiOrigin:
                'https://candidate.example',
            enableSchedulerSelectionPreviewCandidate: true,
          ),
        ),
      );
      await _settle(tester);

      expect(resourceReads, greaterThanOrEqualTo(3));
      expect(inventoryReads, greaterThanOrEqualTo(2));
      expect(previewCalls, 0);
    },
  );
}

ForgeDeviceOwner _owner() => ForgeDeviceOwner.fromJson({
  'issuer': 'https://id.example',
  'subject': 'user-a',
  'tenant_id': 'tenant-a',
});

ForgeSchedulerSelectionPreviewRequest _request({
  String conversationID = 'conversation-visible',
  String runID = 'run-visible',
}) => ForgeSchedulerSelectionPreviewRequest(
  conversationID: conversationID,
  runID: runID,
  attemptID: 'attempt-visible',
  requirements: const ForgeDevicePlacementRequirements(
    os: 'linux',
    architecture: 'amd64',
    minCPUCores: 1,
    minMemoryBytes: 1,
    minStorageBytes: 1,
    runtime: 'oci',
    gpu: ForgeDevicePlacementGpuRequirement(
      required: false,
      minMemoryBytes: 0,
      runtime: '',
    ),
    dataResidencyZones: ['us-west'],
    minimumTrustZone: 'standard',
    sandboxFloor: 'container',
    concurrencySlots: 1,
  ),
);

ForgeSchedulerSelectionPreview _preview({
  String selectedDeviceID = 'device-a',
  String selectedInstanceID = 'runner-a',
}) => ForgeSchedulerSelectionPreview(
  schemaVersion: ForgeSchedulerSelectionPreview.schema,
  mode: ForgeSchedulerSelectionPreview.evaluationMode,
  owner: const ForgeDeviceOwner(
    issuer: 'https://id.example',
    subject: 'user-a',
    tenantID: 'tenant-a',
  ),
  conversationID: 'conversation-visible',
  runID: 'run-visible',
  attemptID: 'attempt-visible',
  evaluatedAtMS: 1800000000000,
  candidateCount: 1,
  eligibleCandidateCount: 1,
  selectionAvailable: true,
  selectionReason: 'first_sorted_eligible_candidate',
  selectedDeviceID: selectedDeviceID,
  selectedInstanceID: selectedInstanceID,
  previewOnly: true,
  authority: const ForgeSchedulerSelectionAuthority(
    placementSelected: false,
    reservationCreated: false,
    leaseIssued: false,
    executionAuthorized: false,
    dispatchPerformed: false,
    auditPublished: false,
  ),
);

Map<String, dynamic> _conversation(String id) => {
  'conversation': {
    'id': id,
    'scope': {'kind': 'global'},
    'title': 'Scheduler preview instance test',
    'created_at_ms': 1,
    'updated_at_ms': 2,
  },
  'aggregate_version': 1,
};

Map<String, dynamic> _run(String id) => {
  'run_id': id,
  'prompt_id': 'prompt-visible',
  'created_at_ms': 10,
  'latest_sequence': 1,
  'status': 'nonterminal',
};

ForgeClientInstanceSessionView _sessionView(
  ForgeDeviceOwner owner,
  String sessionID,
) => ForgeClientInstanceSessionView.fromJson({
  'schema_version': forgeClientInstanceSessionViewSchema,
  'evaluation_mode': forgeClientInstanceSessionViewEvaluationMode,
  'owner_declaration': owner.toJson(),
  'owner_declaration_unverified': true,
  'instances': [
    {
      'instance_id': 'client-web-001',
      'client_kind': 'web',
      'session_ids': [sessionID],
      'observed_at_ms': 1,
      'status': 'active',
    },
  ],
  'read_only': true,
  'authority': const ForgeClientInstanceSessionViewAuthority.offline().toJson(),
});

ForgeClientInstanceResourceView _resourceView(
  ForgeDeviceOwner owner,
  String sessionID,
) => ForgeClientInstanceResourceView.fromJson({
  'schema_version': forgeClientInstanceResourceViewSchema,
  'evaluation_mode': forgeClientInstanceResourceViewEvaluationMode,
  'owner_declaration': owner.toJson(),
  'owner_declaration_unverified': true,
  'instances': [
    {
      'instance_id': 'client-web-001',
      'client_kind': 'web',
      'session_ids': [sessionID],
      'observed_at_ms': 1,
      'status': 'active',
    },
  ],
  'devices': <Object>[],
  'device_attributes_unverified': true,
  'read_only': true,
  'authority': const ForgeClientInstanceSessionViewAuthority.offline().toJson(),
});

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

ForgeClientInstanceResourceView _resourceViewWithDevice(
  ForgeDeviceOwner owner,
  String sessionID,
) {
  final value = _resourceView(owner, sessionID).toJson();
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

Future<ForgeCredentialStore> _credentialStore(String token) async {
  final store = ForgeCredentialStore(
    backend: MemoryForgeCredentialBackend(),
    forcePersistentStorage: true,
  );
  expect(await store.store(accessToken: token), isTrue);
  return store;
}

Future<void> _settle(WidgetTester tester) async {
  for (var index = 0; index < 20; index++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
}

http.Response _json(Object value, {int status = 200}) => http.Response(
  jsonEncode(value),
  status,
  headers: const {'content-type': 'application/json'},
);
