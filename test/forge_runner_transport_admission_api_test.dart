import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/forge_conversations_api.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/api/forge_runner_execution_intent.dart';
import 'package:sso_admin/api/forge_runner_transport_admission.dart';

void main() {
  test(
    'posts one authenticated transport admission preview without retry',
    () async {
      final request = _request();
      var calls = 0;
      final api = ForgeConversationsApi(
        baseUrl: 'https://candidate.example',
        accessToken: 'transport-token',
        httpClient: MockClient((http.Request incoming) async {
          calls++;
          expect(incoming.method, 'POST');
          expect(
            incoming.url.path,
            '/api/v1/conversations/conversation-1/runs/run-1/'
            'runner-transport-admission/preview',
          );
          expect(incoming.headers['authorization'], 'Bearer transport-token');
          expect(incoming.headers['idempotency-key'], isNull);
          expect(
            ForgeRunnerTransportAdmissionRequest.fromJson(
              jsonDecode(incoming.body),
            ).toJson(),
            request.toJson(),
          );
          return _json(_response(request));
        }),
      );
      addTearDown(api.close);

      final admission = await api.previewRunnerTransportAdmission(
        request: request,
        candidateOrigin: 'https://candidate.example/',
      );

      expect(calls, 1);
      expect(admission.admissionReady, isTrue);
      expect(admission.transportBindingValid, isTrue);
      expect(admission.isDisplayOnly, isTrue);
    },
  );

  test('rejects candidate origin drift before issuing a request', () async {
    var calls = 0;
    final api = ForgeConversationsApi(
      baseUrl: 'https://candidate.example',
      accessToken: 'transport-token',
      httpClient: MockClient((_) async {
        calls++;
        return _json(_response(_request()));
      }),
    );
    addTearDown(api.close);

    await expectLater(
      api.previewRunnerTransportAdmission(
        request: _request(),
        candidateOrigin: 'https://other.example',
      ),
      throwsFormatException,
    );
    expect(calls, 0);
  });

  test('rejects response binding or authority drift', () async {
    final request = _request();
    final mismatch = ForgeConversationsApi(
      baseUrl: 'https://candidate.example',
      accessToken: 'transport-token',
      httpClient: MockClient((_) async {
        final response = _response(request)..['target_id'] = 'runner-b';
        return _json(response);
      }),
    );
    addTearDown(mismatch.close);
    await expectLater(
      mismatch.previewRunnerTransportAdmission(
        request: request,
        candidateOrigin: 'https://candidate.example',
      ),
      throwsFormatException,
    );

    final authority = ForgeConversationsApi(
      baseUrl: 'https://candidate.example',
      accessToken: 'transport-token',
      httpClient: MockClient((_) async {
        final response = _response(request);
        (response['authority'] as Map<String, dynamic>)['dispatch_performed'] =
            true;
        return _json(response);
      }),
    );
    addTearDown(authority.close);
    await expectLater(
      authority.previewRunnerTransportAdmission(
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

ForgeRunnerTransportAdmissionRequest _request() {
  const payloadDigest =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
  return const ForgeRunnerTransportAdmissionRequest(
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
    lease: ForgeRunnerTransportLease(
      targetID: 'runner-a',
      epoch: 3,
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
      payloadSHA256: payloadDigest,
      payloadBytes: 256,
      replayChecked: true,
    ),
    expectedPayloadSHA256: payloadDigest,
    evaluatedAtMS: 300,
  );
}

Map<String, dynamic> _response(ForgeRunnerTransportAdmissionRequest request) =>
    {
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
    };
