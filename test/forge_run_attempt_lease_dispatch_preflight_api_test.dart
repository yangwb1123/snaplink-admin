import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/forge_conversations_api.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/api/forge_run_attempt_lease_dispatch_preflight.dart';

const _owner = ForgeDeviceOwner(
  issuer: 'https://id.example',
  subject: 'user-1',
  tenantID: 'tenant-1',
);

http.Response _json(Object value, {int status = 200}) => http.Response(
  jsonEncode(value),
  status,
  headers: const {'content-type': 'application/json'},
);

http.Response _raw(String value, {int status = 200}) => http.Response(
  value,
  status,
  headers: const {'content-type': 'application/json'},
);

void main() {
  test('consumes the canonical typed request fixture when provided', () {
    final path = Platform
        .environment['FORGE_RUN_ATTEMPT_LEASE_DISPATCH_PREFLIGHT_REQUEST_FIXTURE'];
    if (path == null || path.isEmpty) return;
    final request = ForgeRunAttemptLeaseDispatchPreflightRequest.fromJson(
      jsonDecode(File(path).readAsStringSync()),
    );
    expect(request.conversationID, 'conversation-001');
    expect(request.runID, 'run-001');
    expect(request.dispatchPlan.attemptState, 'accepted');
  });

  test('posts one path-bound metadata request', () async {
    final request = _request();
    final response = _response(request);
    final sent = <http.Request>[];
    final api = ForgeConversationsApi(
      baseUrl: 'https://forge.example',
      accessToken: 'forge-bearer',
      httpClient: MockClient((value) async {
        sent.add(value);
        return _json(response);
      }),
    );
    addTearDown(api.close);

    final observation = await api.previewRunAttemptLeaseDispatchPreflight(
      request: request,
    );

    expect(observation.conversationId, 'conversation-001');
    expect(observation.runId, 'run-001');
    expect(observation.selectedTargetId, isNull);
    expect(observation.authority.values, everyElement(isFalse));
    expect(sent, hasLength(1));
    expect(sent.single.method, 'POST');
    expect(
      sent.single.url.path,
      '/api/v1/conversations/conversation-001/runs/run-001/'
      'attempt-lease-dispatch-preflight/preview',
    );
    expect(sent.single.headers['authorization'], 'Bearer forge-bearer');
    expect(jsonDecode(sent.single.body), request.toJson());
  });

  test('does not replay the POST after a 401', () async {
    var calls = 0;
    var refreshes = 0;
    final api = ForgeConversationsApi(
      baseUrl: 'https://forge.example',
      accessToken: 'forge-bearer',
      refreshAccessToken: (_) async {
        refreshes++;
        return 'rotated-token';
      },
      httpClient: MockClient((_) async {
        calls++;
        return _json({
          'code': 'unauthorized',
          'message': 'private',
        }, status: 401);
      }),
    );
    addTearDown(api.close);

    await expectLater(
      api.previewRunAttemptLeaseDispatchPreflight(request: _request()),
      throwsA(
        isA<ForgeConversationsApiException>()
            .having((error) => error.statusCode, 'status', 401)
            .having((error) => error.message, 'message', contains('private')),
      ),
    );
    expect(calls, 1);
    expect(refreshes, 0);
  });

  test('rejects response binding, authority, and duplicate keys', () async {
    final request = _request();
    final foreign = _response(request)..['run_id'] = 'run-foreign';
    final foreignApi = ForgeConversationsApi(
      baseUrl: 'https://forge.example',
      accessToken: 'token',
      httpClient: MockClient((_) async => _json(foreign)),
    );
    addTearDown(foreignApi.close);
    await expectLater(
      foreignApi.previewRunAttemptLeaseDispatchPreflight(request: request),
      throwsA(isA<FormatException>()),
    );

    final duplicateApi = ForgeConversationsApi(
      baseUrl: 'https://forge.example',
      accessToken: 'token',
      httpClient: MockClient(
        (_) async => _raw(
          '{"schema_version":"forge.run-attempt-lease-dispatch-preflight/v1",'
          '"schema_version":"forge.run-attempt-lease-dispatch-preflight/v1"}',
        ),
      ),
    );
    addTearDown(duplicateApi.close);
    await expectLater(
      duplicateApi.previewRunAttemptLeaseDispatchPreflight(request: request),
      throwsA(isA<ForgeConversationsApiException>()),
    );
  });

  test('rejects nested owner drift before any request', () async {
    var calls = 0;
    final json = _request().toJson();
    (json['dispatch_plan'] as Map)['placement_request']['owner'] = {
      ..._owner.toJson(),
      'subject': 'foreign',
    };
    final api = ForgeConversationsApi(
      baseUrl: 'https://forge.example',
      accessToken: 'token',
      httpClient: MockClient((_) async {
        calls++;
        return _json(_response(_request()));
      }),
    );
    addTearDown(api.close);
    expect(
      () => ForgeRunAttemptLeaseDispatchPreflightRequest.fromJson(json),
      throwsA(isA<FormatException>()),
    );
    expect(calls, 0);
  });
}

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
  'command_sha256':
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
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
  'devices': [_device('runner-1')],
};

Map<String, dynamic> _device(String id) => {
  'device_id': id,
  'owner': _owner.toJson(),
  'approval_state': 'approved',
  'cordon_state': 'clear',
  'liveness': 'online',
  'snapshot_observed_at_ms': 1799999999000,
  'lease_expires_at_ms': 1800000060000,
  'os': 'linux',
  'architecture': 'amd64',
  'available_cpu_cores': 4,
  'available_memory_bytes': 8192,
  'available_storage_bytes': 65536,
  'runtimes': ['oci'],
  'gpu': {'present': false, 'memory_bytes': 0, 'runtime': ''},
  'data_residency_zones': ['us-west'],
  'trust_zone': 'standard',
  'sandbox_levels': ['container'],
  'concurrency_limit': 4,
  'active_concurrency': 0,
};

Map<String, dynamic> _response(
  ForgeRunAttemptLeaseDispatchPreflightRequest request,
) => {
  'schema_version': 'forge.run-attempt-lease-dispatch-preflight/v1',
  'evaluation_mode': 'pure_run_attempt_lease_dispatch_preflight',
  'owner': request.owner.toJson(),
  'conversation_id': request.conversationID,
  'run_id': request.runID,
  'run_status': request.runStatus,
  'run_state_admissible': true,
  'attempt_id': 'attempt-001',
  'attempt_state': 'accepted',
  'attempt_state_admissible': true,
  'command_id': 'command-001',
  'intent_target_id': 'runner-1',
  'lease_epoch': 1,
  'lease_active': true,
  'evaluated_at_ms': 1800000000000,
  'candidate_count': 1,
  'declarative_ready_count': 1,
  'declarative_preflight_ready': true,
  'rejection_reasons': const <String>[],
  'selected_target_id': null,
  'preview_only': true,
  'authority': {
    'identity_verified': false,
    'run_authoritative': false,
    'attempt_persisted': false,
    'lease_issued': false,
    'reservation_created': false,
    'execution_authorized': false,
    'dispatch_performed': false,
    'audit_published': false,
  },
};
