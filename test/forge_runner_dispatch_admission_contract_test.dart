import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_runner_dispatch_admission.dart';
import 'package:sso_admin/api/forge_runner_execution_intent.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';

void main() {
  test(
    'parses a metadata-only admission and rejects duplicate or authority fields',
    () {
      final request = _request();
      final response = _response(request);
      final parsed = ForgeRunnerDispatchAdmission.fromJson(response);

      expect(parsed.admissionReady, isTrue);
      expect(parsed.isDisplayOnly, isTrue);
      expect(parsed.isFor('conversation-1', 'run-1', 'attempt-1'), isTrue);
      expect(parsed.authority.executionAuthorized, isFalse);
      expect(jsonEncode(response), isNot(contains('fencing_token')));
      expect(jsonEncode(response), isNot(contains('argv')));

      final duplicate = jsonEncode(response).replaceFirst(
        '"schema_version":"${ForgeRunnerDispatchAdmission.schema}",',
        '"schema_version":"${ForgeRunnerDispatchAdmission.schema}","schema_version":"${ForgeRunnerDispatchAdmission.schema}",',
      );
      expect(
        () => ForgeRunnerDispatchAdmission.fromJsonText(duplicate),
        throwsFormatException,
      );

      final authority = Map<String, dynamic>.from(response);
      authority['authority'] = {
        ...Map<String, dynamic>.from(authority['authority'] as Map),
        'execution_authorized': true,
      };
      expect(
        () => ForgeRunnerDispatchAdmission.fromJson(authority),
        throwsFormatException,
      );

      final unknown = Map<String, dynamic>.from(response)
        ..['argv'] = ['secret'];
      expect(
        () => ForgeRunnerDispatchAdmission.fromJson(unknown),
        throwsFormatException,
      );
    },
  );

  test('keeps the response binding and command digest stable', () {
    final request = _request();
    final response = _response(request);
    expect(
      ForgeRunnerDispatchAdmission.fromJson(response).commandSHA256,
      request.command.commandSHA256(),
    );

    final drift = Map<String, dynamic>.from(response)
      ..['command_sha256'] = 'b' * 64;
    expect(
      () => ForgeRunnerDispatchAdmission.fromJson(drift),
      returnsNormally,
      reason: 'The model validates shape; the API validates request binding.',
    );
  });
}

ForgeRunnerDispatchAdmissionRequest _request() {
  const proof = ForgeRunnerExecutionLeaseProof(
    attemptID: 'attempt-1',
    targetID: 'runner-a',
    epoch: 1,
    fencingToken: 'token-a',
  );
  const command = ForgeRunnerExecutionCommand(
    version: 1,
    commandID: 'command-1',
    leaseProof: proof,
    idempotencyKey: 'run-1:attempt-1:command-1',
    workspaceRef: 'workspace-1',
    argv: ['forge-task', '--prompt-ref', 'prompt-1'],
    timeoutMS: 5000,
    maxOutputBytes: 65536,
  );
  return const ForgeRunnerDispatchAdmissionRequest(
    owner: ForgeDeviceOwner(
      issuer: 'https://id.example',
      subject: 'user-1',
      tenantID: 'tenant-1',
    ),
    conversationID: 'conversation-1',
    runID: 'run-1',
    attemptID: 'attempt-1',
    attemptState: 'accepted',
    command: command,
    evaluatedAtMS: 300,
  );
}

Map<String, dynamic> _response(ForgeRunnerDispatchAdmissionRequest request) => {
  'schema_version': ForgeRunnerDispatchAdmission.schema,
  'evaluation_mode': ForgeRunnerDispatchAdmission.evaluationMode,
  'owner': request.owner.toJson(),
  'conversation_id': request.conversationID,
  'run_id': request.runID,
  'attempt_id': request.attemptID,
  'attempt_state': request.attemptState,
  'attempt_state_admissible': true,
  'command_id': request.command.commandID,
  'command_sha256': request.command.commandSHA256(),
  'target_id': request.command.leaseProof.targetID,
  'lease_epoch': request.command.leaseProof.epoch,
  'lease_issued_at_ms': 100,
  'lease_expires_at_ms': 1000,
  'evaluated_at_ms': 300,
  'lease_proof_current': true,
  'lease_active': true,
  'command_binding_valid': true,
  'admission_ready': true,
  'rejection_reasons': <String>[],
  'preview_only': true,
  'authority': {
    'device_identity_verified': false,
    'reservation_created': false,
    'execution_authorized': false,
    'dispatch_performed': false,
    'audit_published': false,
  },
};
