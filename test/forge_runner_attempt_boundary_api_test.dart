import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/forge_conversations_api.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/api/forge_runner_attempt_boundary.dart';
import 'package:sso_admin/api/forge_runner_execution_boundary.dart';
import 'package:sso_admin/api/forge_runner_execution_intent.dart';
import 'package:sso_admin/api/forge_runner_transport_admission.dart';

const _owner = ForgeDeviceOwner(
  issuer: 'https://id.example',
  subject: 'user-1',
  tenantID: 'tenant-1',
);

void main() {
  test(
    'posts one authenticated Attempt boundary preview without retry',
    () async {
      final request = _request();
      var calls = 0;
      final api = ForgeConversationsApi(
        baseUrl: 'https://candidate.example',
        accessToken: 'attempt-token',
        httpClient: MockClient((incoming) async {
          calls++;
          expect(incoming.method, 'POST');
          expect(
            incoming.url.path,
            '/api/v1/conversations/conversation-1/runs/run-1/'
            'runner-attempt-boundary/preview',
          );
          expect(incoming.headers['authorization'], 'Bearer attempt-token');
          final received = ForgeRunnerAttemptBoundaryPreviewRequest.fromJson(
            jsonDecode(incoming.body),
          );
          expect(received.toJson(), request.toJson());
          return _json(_response(request));
        }),
      );
      addTearDown(api.close);

      final observation = await api.previewRunnerAttemptBoundary(
        request: request,
        candidateOrigin: 'https://candidate.example/',
      );
      expect(calls, 1);
      expect(observation.attemptBoundaryReady, isTrue);
      expect(observation.isDisplayOnly, isTrue);
    },
  );

  test(
    'rejects response drift, origin drift, and unauthorized retry',
    () async {
      final request = _request();
      var calls = 0;
      final mismatch = ForgeConversationsApi(
        baseUrl: 'https://candidate.example',
        accessToken: 'attempt-token',
        httpClient: MockClient((_) async {
          calls++;
          final response = _response(request)..['target_id'] = 'runner-other';
          return _json(response);
        }),
      );
      addTearDown(mismatch.close);
      await expectLater(
        mismatch.previewRunnerAttemptBoundary(
          request: request,
          candidateOrigin: 'https://candidate.example',
        ),
        throwsFormatException,
      );
      expect(calls, 1);

      final origin = ForgeConversationsApi(
        baseUrl: 'https://candidate.example',
        accessToken: 'attempt-token',
        httpClient: MockClient((_) async {
          fail('origin drift reached HTTP');
        }),
      );
      addTearDown(origin.close);
      await expectLater(
        origin.previewRunnerAttemptBoundary(
          request: request,
          candidateOrigin: 'https://other.example',
        ),
        throwsFormatException,
      );

      var unauthorizedCalls = 0;
      final unauthorized = ForgeConversationsApi(
        baseUrl: 'https://candidate.example',
        accessToken: 'attempt-token',
        httpClient: MockClient((_) async {
          unauthorizedCalls++;
          return _json({
            'code': 'invalid_token',
            'message': 'expired',
          }, status: 401);
        }),
      );
      addTearDown(unauthorized.close);
      await expectLater(
        unauthorized.previewRunnerAttemptBoundary(
          request: request,
          candidateOrigin: 'https://candidate.example',
        ),
        throwsA(isA<ForgeConversationsApiException>()),
      );
      expect(unauthorizedCalls, 1);
    },
  );
}

http.Response _json(Map<String, dynamic> value, {int status = 200}) =>
    http.Response(
      jsonEncode(value),
      status,
      headers: const {'content-type': 'application/json'},
    );

ForgeRunnerAttemptBoundaryPreviewRequest _request() {
  const digest =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
  return const ForgeRunnerAttemptBoundaryPreviewRequest(
    executionBoundary: ForgeRunnerExecutionBoundaryPreviewRequest(
      owner: _owner,
      conversationID: 'conversation-1',
      runID: 'run-1',
      attemptID: 'attempt-1',
      attemptState: 'accepted',
      command: ForgeRunnerExecutionCommand(
        version: 1,
        commandID: 'command-1',
        leaseProof: ForgeRunnerExecutionLeaseProof(
          attemptID: 'attempt-1',
          targetID: 'runner-1',
          epoch: 1,
          fencingToken: 'fence-1',
        ),
        idempotencyKey: 'run-1:attempt-1:command-1',
        workspaceRef: 'workspace-1',
        argv: ['forge-task', '--prompt-ref', 'prompt-1'],
        timeoutMS: 5000,
        maxOutputBytes: 65536,
      ),
      transport: ForgeRunnerTransportObservation(
        method: 'POST',
        path: '/api/v1/runners/runner-1/dispatch',
        timestamp: 300,
        nonce: 'nonce-1',
        payloadSHA256: digest,
        payloadBytes: 256,
        replayChecked: true,
      ),
      expectedPayloadSHA256: digest,
      effectState: 'not_started',
      cancellationRequested: false,
    ),
    transition: 'begin_starting',
  );
}

Map<String, dynamic> _response(
  ForgeRunnerAttemptBoundaryPreviewRequest request,
) => {
  'schema_version': ForgeRunnerAttemptBoundaryObservation.schema,
  'evaluation_mode': ForgeRunnerAttemptBoundaryObservation.evaluationMode,
  'owner': request.owner.toJson(),
  'conversation_id': request.conversationID,
  'run_id': request.runID,
  'attempt_id': request.attemptID,
  'command_id': request.command.commandID,
  'target_id': request.command.leaseProof.targetID,
  'lease_epoch': request.command.leaseProof.epoch,
  'current_attempt_state': request.attemptState,
  'next_attempt_state': 'starting',
  'transition': request.transition,
  'execution_boundary_ready': true,
  'attempt_transition_valid': true,
  'attempt_transition_dispatchable': true,
  'attempt_boundary_ready': true,
  'rejection_reasons': <String>[],
  'preview_only': true,
  'authority': {
    'attempt_persisted': false,
    'reservation_created': false,
    'execution_authorized': false,
    'dispatch_performed': false,
    'audit_published': false,
  },
};
