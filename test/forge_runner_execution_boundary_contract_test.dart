import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/api/forge_runner_execution_boundary.dart';
import 'package:sso_admin/api/forge_runner_execution_intent.dart';
import 'package:sso_admin/api/forge_runner_transport_admission.dart';

void main() {
  test('boundary response stays display-only and rejects drift', () {
    final request = _request();
    final response = _response(request);
    final duplicate = jsonEncode(response).replaceFirst(
      '"schema_version":"${ForgeRunnerExecutionBoundaryObservation.schema}",',
      '"schema_version":"${ForgeRunnerExecutionBoundaryObservation.schema}",'
          '"schema_version":"${ForgeRunnerExecutionBoundaryObservation.schema}",',
    );
    expect(
      () => ForgeRunnerExecutionBoundaryObservation.fromJsonText(duplicate),
      throwsFormatException,
    );
    final authority = Map<String, dynamic>.from(response);
    authority['authority'] = {
      ...Map<String, dynamic>.from(authority['authority'] as Map),
      'execution_authorized': true,
    };
    expect(
      () => ForgeRunnerExecutionBoundaryObservation.fromJson(authority),
      throwsFormatException,
    );
    final parsed = ForgeRunnerExecutionBoundaryObservation.fromJson(response);
    expect(parsed.isDisplayOnly, isTrue);
    expect(parsed.executionBoundaryReady, isTrue);
    expect(jsonEncode(parsed.toJson()), isNot(contains('fencing_token')));
    expect(jsonEncode(parsed.toJson()), isNot(contains('argv')));
    expect(jsonEncode(parsed.toJson()), isNot(contains('workspace_ref')));
  });
}

ForgeRunnerExecutionBoundaryPreviewRequest _request() {
  const digest =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
  return const ForgeRunnerExecutionBoundaryPreviewRequest(
    owner: ForgeDeviceOwner(
      issuer: 'https://id.example',
      subject: 'user-1',
      tenantID: 'tenant-1',
    ),
    conversationID: 'conversation-1',
    runID: 'run-1',
    attemptID: 'attempt-1',
    attemptState: 'accepted',
    command: ForgeRunnerExecutionCommand(
      version: 1,
      commandID: 'command-1',
      leaseProof: ForgeRunnerExecutionLeaseProof(
        attemptID: 'attempt-1',
        targetID: 'runner-a',
        epoch: 3,
        fencingToken: 'token-a',
      ),
      idempotencyKey: 'run-1:attempt-1:command-1',
      workspaceRef: 'workspace-1',
      argv: ['forge-task', '--prompt-ref', 'prompt-1'],
      timeoutMS: 5000,
      maxOutputBytes: 65536,
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
    effectState: 'not_started',
    cancellationRequested: false,
  );
}

Map<String, dynamic> _response(
  ForgeRunnerExecutionBoundaryPreviewRequest request,
) => {
  'schema_version': ForgeRunnerExecutionBoundaryObservation.schema,
  'evaluation_mode': ForgeRunnerExecutionBoundaryObservation.evaluationMode,
  'mode': 'execute',
  'owner': request.owner.toJson(),
  'conversation_id': request.conversationID,
  'run_id': request.runID,
  'attempt_id': request.attemptID,
  'attempt_state': request.attemptState,
  'command_id': request.command.commandID,
  'command_sha256': request.command.commandSHA256(),
  'target_id': request.command.leaseProof.targetID,
  'lease_epoch': request.command.leaseProof.epoch,
  'activation_allowed': true,
  'runner_authority_accepted': true,
  'dispatch_admission_ready': true,
  'transport_admission_ready': true,
  'effect_state': request.effectState,
  'effect_state_startable': true,
  'cancellation_clear': true,
  'execution_boundary_ready': true,
  'rejection_reasons': <String>[],
  'preview_only': true,
  'authority': {
    'device_identity_verified': false,
    'command_persisted': false,
    'reservation_created': false,
    'execution_authorized': false,
    'dispatch_performed': false,
    'audit_published': false,
  },
};
