import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/api/forge_device_inventory_resource_convergence.dart';
import 'package:sso_admin/api/forge_client_instance_session_view.dart';
import 'package:sso_admin/api/forge_runner_dispatch_admission.dart';
import 'package:sso_admin/api/forge_runner_execution_intent.dart';
import 'package:sso_admin/api/forge_runner_transport_admission.dart';
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

  testWidgets('dispatch admission refreshes resources before its POST', (
    tester,
  ) async {
    final request = _dispatchRequest();
    final good = _convergence();
    final drifted = _withoutDevices(good);
    var reads = 0;
    var posts = 0;
    final store = await _credentialStore('dispatch-resource-token');
    final client = MockClient((request) async {
      if (request.method == 'POST') {
        posts++;
        return _json(_dispatchResponse(_dispatchRequest()).toJson());
      }
      return _sessionResponse(request);
    });
    addTearDown(store.clear);
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsGate(
          credentialStore: store,
          httpClient: client,
          initialConversationID: 'conversation-001',
          initialClientInstanceID: 'client-web-001',
          deviceInventoryResourceConvergenceOwner: _owner,
          deviceInventoryResourceConvergenceReader: (_) async {
            reads++;
            return reads == 1 ? good : drifted;
          },
          runnerDispatchAdmissionRequest: request,
          runnerDispatchAdmissionCandidateApiOrigin:
              'https://candidate.example',
          enableRunnerDispatchAdmissionCandidate: true,
        ),
      ),
    );
    await _settle(tester);

    expect(reads, greaterThanOrEqualTo(2));
    expect(posts, 0);
    expect(
      find.byKey(const ValueKey('forge-runner-dispatch-admission-card')),
      findsNothing,
    );
  });

  testWidgets('transport admission binds its target to the resource image', (
    tester,
  ) async {
    final request = _transportRequest();
    final good = _convergence();
    var posts = 0;
    final store = await _credentialStore('transport-resource-token');
    final client = MockClient((request) async {
      if (request.method == 'POST') {
        posts++;
        return _json(_transportResponse(_transportRequest()).toJson());
      }
      return _sessionResponse(request);
    });
    addTearDown(store.clear);
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsGate(
          credentialStore: store,
          httpClient: client,
          initialConversationID: 'conversation-001',
          initialClientInstanceID: 'client-web-001',
          clientInstanceSessionViewPreview: _sessionView(),
          clientInstanceResourceViewPreview: good.resourceView,
          runnerTransportAdmissionRequest: request,
          runnerTransportAdmissionCandidateApiOrigin:
              'https://candidate.example',
          enableRunnerTransportAdmissionCandidate: true,
        ),
      ),
    );
    await _settle(tester);

    expect(posts, 1);
  });

  testWidgets('static admission target drift stays hidden before any POST', (
    tester,
  ) async {
    final request = _dispatchRequest(targetID: 'runner-foreign');
    var posts = 0;
    final store = await _credentialStore('static-resource-token');
    final client = MockClient((request) async {
      if (request.method == 'POST') posts++;
      return _sessionResponse(request);
    });
    addTearDown(store.clear);
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsGate(
          credentialStore: store,
          httpClient: client,
          initialConversationID: 'conversation-001',
          initialClientInstanceID: 'client-web-001',
          clientInstanceResourceViewPreview: _convergence().resourceView,
          runnerDispatchAdmission: _dispatchResponse(request),
        ),
      ),
    );
    await _settle(tester);

    expect(posts, 0);
    expect(
      find.byKey(const ValueKey('forge-runner-dispatch-admission-card')),
      findsNothing,
    );
  });
}

ForgeDeviceInventoryResourceConvergence
_convergence() => ForgeDeviceInventoryResourceConvergence.fromJson(
  Map<String, dynamic>.from(
    jsonDecode(
          File(
            'docs/contracts/fixtures/forge-device-inventory-resource-convergence-v1.json',
          ).readAsStringSync(),
        )
        as Map,
  ),
);

ForgeClientInstanceSessionView _sessionView() {
  final value = Map<String, dynamic>.from(
    jsonDecode(
          File(
            'docs/contracts/fixtures/forge-client-instance-session-resource-convergence-v1.json',
          ).readAsStringSync(),
        )
        as Map,
  );
  return ForgeClientInstanceSessionView.fromJson(value['session_view']);
}

ForgeDeviceInventoryResourceConvergence _withoutDevices(
  ForgeDeviceInventoryResourceConvergence source,
) {
  final value = source.toJson();
  (value['inventory'] as Map<String, dynamic>)['devices'] = <Object>[];
  (value['resource_view'] as Map<String, dynamic>)['devices'] = <Object>[];
  return ForgeDeviceInventoryResourceConvergence.fromJson(value);
}

Future<http.Response> _sessionResponse(http.Request request) async {
  final path = request.url.path;
  if (request.method != 'GET') {
    throw StateError('Unexpected non-candidate request: ${request.method}');
  }
  if (path == '/api/v1/conversations') {
    return _json({
      'conversations': [_conversation()],
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
  if (path.endsWith('/runs/run-001/timeline')) {
    return _json({
      'conversation_id': 'conversation-001',
      'run_id': 'run-001',
      'after_sequence': 0,
      'scanned_through_sequence': 0,
      'has_more': false,
      'events': <Object>[],
    });
  }
  if (path.endsWith('/runs')) {
    return _json({
      'conversation_id': 'conversation-001',
      'runs': [_run()],
      'has_more': false,
    });
  }
  throw StateError('Unexpected Forge session path: $path');
}

http.Response _json(Object value) => http.Response(
  jsonEncode(value),
  200,
  headers: const {'content-type': 'application/json'},
);

ForgeRunnerDispatchAdmissionRequest _dispatchRequest({
  String targetID = 'runner-a',
}) => ForgeRunnerDispatchAdmissionRequest(
  owner: _owner,
  conversationID: 'conversation-001',
  runID: 'run-001',
  attemptID: 'attempt-001',
  attemptState: 'accepted',
  command: ForgeRunnerExecutionCommand(
    version: 1,
    commandID: 'command-001',
    leaseProof: ForgeRunnerExecutionLeaseProof(
      attemptID: 'attempt-001',
      targetID: targetID,
      epoch: 1,
      fencingToken: 'fence-a',
    ),
    idempotencyKey: 'run-001:attempt-001:command-001',
    workspaceRef: 'workspace-001',
    argv: const ['forge-task', '--prompt-ref', 'prompt-001'],
    timeoutMS: 5000,
    maxOutputBytes: 65536,
  ),
  evaluatedAtMS: 300,
);

ForgeRunnerDispatchAdmission _dispatchResponse(
  ForgeRunnerDispatchAdmissionRequest request,
) => ForgeRunnerDispatchAdmission(
  schemaVersion: ForgeRunnerDispatchAdmission.schema,
  mode: ForgeRunnerDispatchAdmission.evaluationMode,
  owner: request.owner,
  conversationID: request.conversationID,
  runID: request.runID,
  attemptID: request.attemptID,
  attemptState: request.attemptState,
  attemptStateAdmissible: true,
  commandID: request.command.commandID,
  commandSHA256: request.command.commandSHA256(),
  targetID: request.command.leaseProof.targetID,
  leaseEpoch: request.command.leaseProof.epoch,
  leaseIssuedAtMS: 100,
  leaseExpiresAtMS: 1000,
  evaluatedAtMS: request.evaluatedAtMS,
  leaseProofCurrent: true,
  leaseActive: true,
  commandBindingValid: true,
  admissionReady: true,
  rejectionReasons: const [],
  previewOnly: true,
  authority: const ForgeRunnerDispatchAdmissionAuthority(
    deviceIdentityVerified: false,
    reservationCreated: false,
    executionAuthorized: false,
    dispatchPerformed: false,
    auditPublished: false,
  ),
);

ForgeRunnerTransportAdmissionRequest _transportRequest() {
  const digest =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
  return const ForgeRunnerTransportAdmissionRequest(
    owner: _owner,
    conversationID: 'conversation-001',
    runID: 'run-001',
    attemptID: 'attempt-001',
    attemptState: 'accepted',
    command: ForgeRunnerExecutionCommand(
      version: 1,
      commandID: 'command-001',
      leaseProof: ForgeRunnerExecutionLeaseProof(
        attemptID: 'attempt-001',
        targetID: 'runner-a',
        epoch: 1,
        fencingToken: 'fence-a',
      ),
      idempotencyKey: 'run-001:attempt-001:command-001',
      workspaceRef: 'workspace-001',
      argv: ['forge-task', '--prompt-ref', 'prompt-001'],
      timeoutMS: 5000,
      maxOutputBytes: 65536,
    ),
    lease: ForgeRunnerTransportLease(
      targetID: 'runner-a',
      epoch: 1,
      issuedAtMS: 100,
      expiresAtMS: 1000,
      current: true,
      active: true,
    ),
    transport: ForgeRunnerTransportObservation(
      method: 'POST',
      path: '/api/v1/runners/runner-a/dispatch',
      timestamp: 300,
      nonce: 'nonce-a',
      payloadSHA256: digest,
      payloadBytes: 256,
      replayChecked: true,
    ),
    expectedPayloadSHA256: digest,
    evaluatedAtMS: 300,
  );
}

ForgeRunnerTransportAdmission _transportResponse(
  ForgeRunnerTransportAdmissionRequest request,
) => ForgeRunnerTransportAdmission.fromJson({
  'schema_version': ForgeRunnerTransportAdmission.schema,
  'evaluation_mode': ForgeRunnerTransportAdmission.evaluationMode,
  'owner': request.owner.toJson(),
  'conversation_id': request.conversationID,
  'run_id': request.runID,
  'attempt_id': request.attemptID,
  'attempt_state': request.attemptState,
  'attempt_state_admissible': true,
  'command_id': request.command.commandID,
  'command_sha256': request.command.commandSHA256(),
  'target_id': request.command.leaseProof.targetID,
  'lease_epoch': request.lease.epoch,
  'lease_issued_at_ms': request.lease.issuedAtMS,
  'lease_expires_at_ms': request.lease.expiresAtMS,
  'evaluated_at_ms': request.evaluatedAtMS,
  'transport_method': request.transport.method,
  'transport_path': request.transport.path,
  'transport_timestamp': request.transport.timestamp,
  'transport_nonce': request.transport.nonce,
  'transport_payload_sha256': request.transport.payloadSHA256,
  'transport_payload_bytes': request.transport.payloadBytes,
  'transport_replay_checked': request.transport.replayChecked,
  'lease_proof_current': true,
  'lease_active': true,
  'command_binding_valid': true,
  'transport_binding_valid': true,
  'admission_ready': true,
  'rejection_reasons': <String>[],
  'preview_only': true,
  'authority': {
    'device_identity_verified': false,
    'transport_authenticated': false,
    'reservation_created': false,
    'execution_authorized': false,
    'dispatch_performed': false,
    'audit_published': false,
  },
});

Map<String, dynamic> _conversation() => {
  'conversation': {
    'id': 'conversation-001',
    'scope': {'kind': 'global'},
    'title': 'Admission resource binding',
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

Future<void> _settle(WidgetTester tester) async {
  for (var index = 0; index < 12; index++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

Future<ForgeCredentialStore> _credentialStore(String token) async {
  final store = ForgeCredentialStore(
    backend: MemoryForgeCredentialBackend(),
    forcePersistentStorage: true,
  );
  expect(await store.store(accessToken: token), isTrue);
  return store;
}
