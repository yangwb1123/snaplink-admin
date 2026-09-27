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
import 'package:sso_admin/api/forge_run_attempt_lease_dispatch_preflight.dart';
import 'package:sso_admin/api/forge_runner_dispatch_plan_preview.dart';
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

  testWidgets('fetched dispatch-plan hides every foreign runner target', (
    tester,
  ) async {
    await _pumpGate(
      tester,
      resourceRunnerID: 'runner-local',
      fetchedPreview: _preview(targetID: 'runner-foreign'),
    );

    expect(
      find.byKey(const ValueKey('forge-runner-dispatch-plan-preview-card')),
      findsNothing,
    );
  });

  testWidgets('static dispatch-plan hides every foreign runner target', (
    tester,
  ) async {
    await _pumpGate(
      tester,
      resourceRunnerID: 'runner-local',
      staticPreview: _preview(targetID: 'runner-foreign'),
    );

    expect(
      find.byKey(const ValueKey('forge-runner-dispatch-plan-preview-card')),
      findsNothing,
    );
  });

  testWidgets('visible dispatch-plan keeps candidates in the resource image', (
    tester,
  ) async {
    await _pumpGate(
      tester,
      resourceRunnerID: 'runner-1',
      staticPreview: _preview(targetID: 'runner-1'),
    );

    expect(
      find.byKey(const ValueKey('forge-runner-dispatch-plan-preview-card')),
      findsOneWidget,
    );
    expect(find.text('Runner dispatch-plan preview'), findsOneWidget);
    expect(find.text('Preview only · no dispatch performed'), findsOneWidget);
  });

  testWidgets('dispatch-plan remains compatible without a resource reader', (
    tester,
  ) async {
    await _pumpGate(
      tester,
      staticPreview: _preview(targetID: 'runner-unobserved'),
    );

    expect(
      find.byKey(const ValueKey('forge-runner-dispatch-plan-preview-card')),
      findsOneWidget,
    );
  });
}

Future<void> _pumpGate(
  WidgetTester tester, {
  String? resourceRunnerID,
  ForgeRunnerDispatchPlanPreview? staticPreview,
  ForgeRunnerDispatchPlanPreview? fetchedPreview,
}) async {
  final store = await _credentialStore('resource-binding-token');
  final client = MockClient(_forgeResponse);
  addTearDown(store.clear);
  addTearDown(client.close);
  tester.view.physicalSize = const Size(1280, 5000);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    MaterialApp(
      home: ForgeSessionsGate(
        credentialStore: store,
        httpClient: client,
        initialConversationID: 'conversation-001',
        clientInstanceResourceViewPreview: resourceRunnerID == null
            ? null
            : _resourceView(resourceRunnerID),
        runnerDispatchPlanPreview: staticPreview,
        runnerDispatchPlanPreviewRequest: fetchedPreview == null
            ? null
            : _request(),
        runnerDispatchPlanPreviewReader: fetchedPreview == null
            ? null
            : (_) async => fetchedPreview,
      ),
    ),
  );
  await _settle(tester);
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
  for (var index = 0; index < 10; index++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

Future<http.Response> _forgeResponse(http.Request request) async {
  if (request.method != 'GET') {
    throw StateError('Unexpected Forge method: ${request.method}');
  }
  if (request.url.path == '/api/v1/conversations') {
    return _json({
      'conversations': [_conversation()],
      'has_more': false,
    });
  }
  if (request.url.path.endsWith('/prompts')) {
    return _json({
      'conversation_id': 'conversation-001',
      'prompts': <Object>[],
      'has_more': false,
    });
  }
  if (request.url.path.endsWith('/runs/run-001/timeline')) {
    return _json({
      'conversation_id': 'conversation-001',
      'run_id': 'run-001',
      'after_sequence': 0,
      'scanned_through_sequence': 0,
      'has_more': false,
      'events': <Object>[],
    });
  }
  if (request.url.path.endsWith('/runs')) {
    return _json({
      'conversation_id': 'conversation-001',
      'runs': [_run()],
      'has_more': false,
    });
  }
  throw StateError('Unexpected Forge path: ${request.url.path}');
}

http.Response _json(Object value) => http.Response(
  jsonEncode(value),
  200,
  headers: const {'content-type': 'application/json'},
);

Map<String, dynamic> _conversation() => {
  'conversation': {
    'id': 'conversation-001',
    'scope': {'kind': 'global'},
    'title': 'Dispatch resource binding',
    'created_at_ms': 1,
    'updated_at_ms': 2,
  },
  'aggregate_version': 1,
};

Map<String, dynamic> _run() => {
  'run_id': 'run-001',
  'prompt_id': 'prompt-001',
  'created_at_ms': 10,
  'latest_sequence': 1,
  'status': 'nonterminal',
};

ForgeClientInstanceResourceView _resourceView(String runnerInstanceID) =>
    ForgeClientInstanceResourceView.fromJson({
      'schema_version': forgeClientInstanceResourceViewSchema,
      'evaluation_mode': forgeClientInstanceResourceViewEvaluationMode,
      'owner_declaration': _owner.toJson(),
      'owner_declaration_unverified': true,
      'instances': <Object>[],
      'devices': [_resourceDevice(runnerInstanceID)],
      'device_attributes_unverified': true,
      'read_only': true,
      'authority': const ForgeClientInstanceSessionViewAuthority.offline()
          .toJson(),
    });

Map<String, dynamic> _resourceDevice(String runnerInstanceID) => {
  'device_id': 'device-a',
  'runner_instance_id': runnerInstanceID,
  'owner': _owner.toJson(),
  'revision': 1,
  'generation': 1,
  'heartbeat_sequence': 1,
  'observed_at_ms': 100,
  'approval_state': 'approved',
  'cordon_state': 'clear',
  'reservation_state': 'none',
  'liveness': 'online',
  'os': 'linux',
  'architecture': 'amd64',
  'cpu_cores': 4,
  'available_cpu_cores': 4,
  'memory_bytes': 4096,
  'available_memory_bytes': 4096,
  'storage_bytes': 8192,
  'available_storage_bytes': 8192,
  'gpu_count': 0,
  'available_gpu_memory_bytes': 0,
};

ForgeRunnerDispatchPlanPreview _preview({required String targetID}) =>
    ForgeRunnerDispatchPlanPreview.fromJson({
      'schema_version': 'forge.runner-dispatch-plan-preview/v1',
      'evaluation_mode': 'pure_dispatch_plan_preview_only',
      'owner_declaration': _owner.toJson(),
      'conversation_id': 'conversation-001',
      'run_id': 'run-001',
      'attempt_id': 'attempt-001',
      'attempt_state': 'accepted',
      'attempt_state_admissible': true,
      'command_id': 'command-001',
      'command_sha256': _digest(),
      'intent_target_id': 'runner-1',
      'lease_epoch': 1,
      'lease_active': true,
      'evaluated_at_ms': 1800000000000,
      'candidate_count': 1,
      'declarative_ready_count': targetID == 'runner-1' ? 1 : 0,
      'candidates': [
        {
          'target_id': targetID,
          'attributes_unverified': true,
          'matches_requirements': true,
          'lease_target_match': targetID == 'runner-1',
          'lease_active': true,
          'attempt_state_admissible': true,
          'declarative_ready': targetID == 'runner-1',
          'reasons': targetID == 'runner-1'
              ? <String>[]
              : ['lease_target_mismatch'],
        },
      ],
      'selected_target_id': null,
      'preview_only': true,
      'reservation_created': false,
      'execution_authorized': false,
      'dispatch_performed': false,
      'authority': {
        'device_identity_verified': false,
        'attempt_persisted': false,
        'reservation_created': false,
        'execution_authorized': false,
        'dispatch_performed': false,
        'audit_published': false,
      },
    });

ForgeRunAttemptLeaseDispatchPreflightRequest _request() =>
    ForgeRunAttemptLeaseDispatchPreflightRequest.fromJson({
      'owner': _owner.toJson(),
      'conversation_id': 'conversation-001',
      'run_id': 'run-001',
      'run_status': 'nonterminal',
      'dispatch_plan': {
        'attempt_state': 'accepted',
        'placement_request': _placement(),
        'runner_execution_intent': _intent(),
        'lease': {
          'v': 1,
          'attempt_id': 'attempt-001',
          'target_id': 'runner-1',
          'epoch': 1,
          'fencing_token': 'fence-001',
          'issued_at_ms': 1799999999000,
          'expires_at_ms': 1800000005000,
        },
      },
    });

Map<String, dynamic> _placement() => {
  'schema_version': 'forge.device-placement-dry-run/v1',
  'evaluated_at_ms': 1800000000000,
  'owner': _owner.toJson(),
  'max_snapshot_age_ms': 60000,
  'requirements': {
    'os': 'linux',
    'architecture': 'amd64',
    'min_cpu_cores': 1,
    'min_memory_bytes': 1024,
    'min_storage_bytes': 1024,
    'runtime': 'oci',
    'gpu': {'required': false, 'min_memory_bytes': 0, 'runtime': ''},
    'data_residency_zones': ['us-west'],
    'minimum_trust_zone': 'standard',
    'sandbox_floor': 'container',
    'concurrency_slots': 1,
  },
  'devices': [_placementDevice()],
};

Map<String, dynamic> _placementDevice() => {
  'device_id': 'device-a',
  'owner': _owner.toJson(),
  'approval_state': 'approved',
  'cordon_state': 'clear',
  'liveness': 'online',
  'snapshot_observed_at_ms': 1799999999000,
  'lease_expires_at_ms': 1800000060000,
  'os': 'linux',
  'architecture': 'amd64',
  'available_cpu_cores': 8,
  'available_memory_bytes': 16384,
  'available_storage_bytes': 8192,
  'runtimes': ['oci'],
  'gpu': {'present': false, 'memory_bytes': 0, 'runtime': ''},
  'data_residency_zones': ['us-west'],
  'trust_zone': 'high',
  'sandbox_levels': ['container'],
  'concurrency_limit': 4,
  'active_concurrency': 1,
};

Map<String, dynamic> _intent() => {
  'schema_version': 'forge.runner-execution-intent/v1',
  'evaluation_mode': 'pure_runner_binding_only',
  'owner': _owner.toJson(),
  'conversation_id': 'conversation-001',
  'prompt_id': 'prompt-001',
  'run_id': 'run-001',
  'attempt_id': 'attempt-001',
  'command_id': 'command-001',
  'target_id': 'runner-1',
  'command_sha256': _digest(),
  'idempotency_key': 'run-001:attempt-001:command-001',
  'prompt_run_binding_valid': true,
  'runner_command_binding_valid': true,
  'preview_only': true,
  'selected_target_id': null,
  'authority': {
    'device_identity_verified': false,
    'command_persisted': false,
    'reservation_created': false,
    'execution_authorized': false,
    'dispatch_performed': false,
    'audit_published': false,
  },
};

String _digest() => List<String>.filled(64, 'a').join();
