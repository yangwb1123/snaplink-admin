import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/forge_conversations_api.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/api/forge_runner_execution_boundary.dart';
import 'package:sso_admin/api/forge_runner_execution_intent.dart';
import 'package:sso_admin/api/forge_runner_transport_admission.dart';

void main() {
  test(
    'posts one server-owned execution-boundary preview without retry',
    () async {
      final request = _request();
      var calls = 0;
      final api = ForgeConversationsApi(
        baseUrl: 'https://candidate.example',
        accessToken: 'boundary-token',
        httpClient: MockClient((http.Request incoming) async {
          calls++;
          expect(incoming.method, 'POST');
          expect(
            incoming.url.path,
            '/api/v1/conversations/conversation-1/runs/run-1/'
            'runner-execution-boundary/preview',
          );
          expect(incoming.headers['authorization'], 'Bearer boundary-token');
          final received = ForgeRunnerExecutionBoundaryPreviewRequest.fromJson(
            jsonDecode(incoming.body),
          );
          expect(received.toJson(), request.toJson());
          return _json(_response(request));
        }),
      );
      addTearDown(api.close);

      final observation = await api.previewRunnerExecutionBoundary(
        request: request,
        candidateOrigin: 'https://candidate.example/',
      );
      expect(calls, 1);
      expect(observation.executionBoundaryReady, isTrue);
      expect(observation.isDisplayOnly, isTrue);
    },
  );

  test('rejects response binding or authority drift', () async {
    final request = _request();
    final mismatch = ForgeConversationsApi(
      baseUrl: 'https://candidate.example',
      accessToken: 'boundary-token',
      httpClient: MockClient((_) async {
        final response = _response(request)..['target_id'] = 'runner-b';
        return _json(response);
      }),
    );
    addTearDown(mismatch.close);
    await expectLater(
      mismatch.previewRunnerExecutionBoundary(
        request: request,
        candidateOrigin: 'https://candidate.example',
      ),
      throwsFormatException,
    );

    final authority = ForgeConversationsApi(
      baseUrl: 'https://candidate.example',
      accessToken: 'boundary-token',
      httpClient: MockClient((_) async {
        final response = _response(request);
        (response['authority'] as Map<String, dynamic>)['dispatch_performed'] =
            true;
        return _json(response);
      }),
    );
    addTearDown(authority.close);
    await expectLater(
      authority.previewRunnerExecutionBoundary(
        request: request,
        candidateOrigin: 'https://candidate.example',
      ),
      throwsFormatException,
    );
  });
}

http.Response _json(Map<String, dynamic> value) => http.Response(
  jsonEncode(value),
  200,
  headers: const {'content-type': 'application/json'},
);

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
