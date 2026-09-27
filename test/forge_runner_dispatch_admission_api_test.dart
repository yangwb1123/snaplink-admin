import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/forge_conversations_api.dart';
import 'package:sso_admin/api/forge_runner_dispatch_admission.dart';
import 'package:sso_admin/api/forge_runner_execution_intent.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';

void main() {
  test(
    'posts one owner-bound admission preview without retry or idempotency',
    () async {
      final request = _request();
      var calls = 0;
      final api = ForgeConversationsApi(
        baseUrl: 'https://candidate.example',
        accessToken: 'admission-token',
        httpClient: MockClient((http.Request incoming) async {
          calls++;
          expect(incoming.method, 'POST');
          expect(
            incoming.url.path,
            '/api/v1/conversations/conversation-1/runs/run-1/runner-dispatch-admission/preview',
          );
          expect(incoming.headers['idempotency-key'], isNull);
          expect(
            ForgeRunnerDispatchAdmissionRequest.fromJson(
              jsonDecode(incoming.body),
            ).toJson(),
            request.toJson(),
          );
          return http.Response(
            jsonEncode(_response(request)),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(api.close);

      final admission = await api.previewRunnerDispatchAdmission(
        request: request,
        candidateOrigin: 'https://candidate.example/',
      );
      expect(calls, 1);
      expect(admission.admissionReady, isTrue);
      expect(admission.isDisplayOnly, isTrue);
    },
  );

  test('rejects response binding drift', () async {
    final request = _request();
    final api = ForgeConversationsApi(
      baseUrl: 'https://candidate.example',
      accessToken: 'admission-token',
      httpClient: MockClient((_) async {
        final response = _response(request)..['target_id'] = 'runner-b';
        return http.Response(
          jsonEncode(response),
          200,
          headers: const {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(api.close);

    await expectLater(
      api.previewRunnerDispatchAdmission(
        request: request,
        candidateOrigin: 'https://candidate.example',
      ),
      throwsFormatException,
    );
  });
}

ForgeRunnerDispatchAdmissionRequest _request() =>
    const ForgeRunnerDispatchAdmissionRequest(
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
          epoch: 1,
          fencingToken: 'token-a',
        ),
        idempotencyKey: 'run-1:attempt-1:command-1',
        workspaceRef: 'workspace-1',
        argv: ['forge-task', '--prompt-ref', 'prompt-1'],
        timeoutMS: 5000,
        maxOutputBytes: 65536,
      ),
      evaluatedAtMS: 300,
    );

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
