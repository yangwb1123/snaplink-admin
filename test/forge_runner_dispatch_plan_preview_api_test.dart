import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/forge_conversations_api.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/api/forge_run_attempt_lease_dispatch_preflight.dart';
import 'package:sso_admin/api/forge_runner_dispatch_plan_preview.dart';

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

void main() {
  test('posts one owner and path-bound display-only preview', () async {
    final plan = _plan();
    final requests = <http.Request>[];
    final api = ForgeConversationsApi(
      baseUrl: 'https://candidate.example',
      accessToken: 'forge-bearer',
      httpClient: MockClient((request) async {
        requests.add(request);
        expect(request.method, 'POST');
        expect(
          request.url.path,
          '/api/v1/conversations/conversation-001/runs/run-001/'
          'runner-dispatch-plan-preview',
        );
        expect(request.url.query, isEmpty);
        expect(request.headers['authorization'], 'Bearer forge-bearer');
        expect(request.headers['content-type'], 'application/json');
        expect(request.headers.containsKey('idempotency-key'), isFalse);
        expect(jsonDecode(request.body), plan.toJson());
        return _json(_preview().toJson());
      }),
    );
    addTearDown(api.close);

    final result = await api.previewRunnerDispatchPlan(
      owner: _owner,
      conversationID: 'conversation-001',
      runID: 'run-001',
      dispatchPlan: plan,
      candidateOrigin: 'https://candidate.example/',
    );

    expect(requests, hasLength(1));
    expect(result.isFor('conversation-001', 'run-001'), isTrue);
    expect(result.isDisplayOnly, isTrue);
    expect(result.selectedTargetID, isNull);
    expect(result.authority.values, everyElement(isFalse));
  });

  test('does not replay the candidate POST after a 401', () async {
    var calls = 0;
    var refreshes = 0;
    final api = ForgeConversationsApi(
      baseUrl: 'https://candidate.example',
      accessToken: 'expired-token',
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
      api.previewRunnerDispatchPlan(
        owner: _owner,
        conversationID: 'conversation-001',
        runID: 'run-001',
        dispatchPlan: _plan(),
        candidateOrigin: 'https://candidate.example',
      ),
      throwsA(
        isA<ForgeConversationsApiException>()
            .having((error) => error.statusCode, 'status', 401)
            .having((error) => error.message, 'message', contains('private')),
      ),
    );
    expect(calls, 1);
    expect(refreshes, 0);
  });

  test('rejects origin and request binding before issuing a POST', () async {
    var calls = 0;
    final api = ForgeConversationsApi(
      baseUrl: 'https://candidate.example',
      accessToken: 'forge-bearer',
      httpClient: MockClient((_) async {
        calls++;
        return _json(_preview().toJson());
      }),
    );
    addTearDown(api.close);

    await expectLater(
      api.previewRunnerDispatchPlan(
        owner: _owner,
        conversationID: 'conversation-001',
        runID: 'run-001',
        dispatchPlan: _plan(),
        candidateOrigin: 'https://other.example',
      ),
      throwsFormatException,
    );

    final foreignIntent = _intent(runID: 'run-foreign')
      ..['idempotency_key'] = 'run-foreign:attempt-001:command-001';
    final foreignPlan = ForgeRunAttemptLeaseDispatchPlan.fromJson(
      _plan().toJson()..['runner_execution_intent'] = foreignIntent,
    );
    await expectLater(
      api.previewRunnerDispatchPlan(
        owner: _owner,
        conversationID: 'conversation-001',
        runID: 'run-001',
        dispatchPlan: foreignPlan,
        candidateOrigin: 'https://candidate.example',
      ),
      throwsFormatException,
    );
    expect(calls, 0);
  });

  test('rejects response identity drift and authority', () async {
    final plan = _plan();
    final foreignApi = ForgeConversationsApi(
      baseUrl: 'https://candidate.example',
      accessToken: 'forge-bearer',
      httpClient: MockClient((_) async {
        final body = _preview().toJson()..['run_id'] = 'run-foreign';
        return _json(body);
      }),
    );
    addTearDown(foreignApi.close);
    await expectLater(
      foreignApi.previewRunnerDispatchPlan(
        owner: _owner,
        conversationID: 'conversation-001',
        runID: 'run-001',
        dispatchPlan: plan,
        candidateOrigin: 'https://candidate.example',
      ),
      throwsA(isA<FormatException>()),
    );

    final authorityApi = ForgeConversationsApi(
      baseUrl: 'https://candidate.example',
      accessToken: 'forge-bearer',
      httpClient: MockClient((_) async {
        final body = _preview().toJson();
        body['authority'] = {
          ...(body['authority'] as Map<String, dynamic>),
          'dispatch_performed': true,
        };
        return _json(body);
      }),
    );
    addTearDown(authorityApi.close);
    await expectLater(
      authorityApi.previewRunnerDispatchPlan(
        owner: _owner,
        conversationID: 'conversation-001',
        runID: 'run-001',
        dispatchPlan: plan,
        candidateOrigin: 'https://candidate.example',
      ),
      throwsA(isA<FormatException>()),
    );
  });
}

ForgeRunAttemptLeaseDispatchPlan _plan() =>
    ForgeRunAttemptLeaseDispatchPlan.fromJson({
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
    });

ForgeRunnerDispatchPlanPreview _preview() =>
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
      'command_sha256':
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
      'intent_target_id': 'runner-1',
      'lease_epoch': 1,
      'lease_active': true,
      'evaluated_at_ms': 1800000000000,
      'candidate_count': 1,
      'declarative_ready_count': 1,
      'candidates': [
        {
          'target_id': 'runner-1',
          'attributes_unverified': true,
          'matches_requirements': true,
          'lease_target_match': true,
          'lease_active': true,
          'attempt_state_admissible': true,
          'declarative_ready': true,
          'reasons': <String>[],
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

Map<String, dynamic> _intent({String runID = 'run-001'}) => {
  'schema_version': 'forge.runner-execution-intent/v1',
  'evaluation_mode': 'pure_runner_binding_only',
  'owner': _owner.toJson(),
  'conversation_id': 'conversation-001',
  'prompt_id': 'prompt-001',
  'run_id': runID,
  'attempt_id': 'attempt-001',
  'command_id': 'command-001',
  'target_id': 'runner-1',
  'command_sha256':
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  'idempotency_key': '$runID:attempt-001:command-001',
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
