import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_attempt_request_preview.dart';

void main() {
  final fixturePath = Platform.environment['FORGE_ATTEMPT_REQUEST_FIXTURE'];

  test(
    'consumes the shared Attempt request fixture as an offline value',
    () {
      final path = fixturePath;
      if (path == null) return;
      final fixture = ForgeAttemptRequestPreviewFixture.fromJsonText(
        File(path).readAsStringSync(),
      );
      expect(fixture.schemaVersion, forgeAttemptRequestSchema);
      expect(fixture.evaluationMode, forgeAttemptRequestEvaluationMode);
      expect(fixture.authority.isOffline, isTrue);
      expect(fixture.cases, hasLength(18));
      expect(fixture.cases.first.name, 'valid_normalizes_order');
      expect(fixture.cases.first.accepted, isTrue);
      expect(fixture.cases.first.requestedEffects, ['read.repo', 'write.file']);
      expect(fixture.cases.first.approvalRecordIDs, [
        'approval.a',
        'approval.b',
      ]);
      expect(fixture.cases.where((value) => !value.accepted), hasLength(17));
    },
    skip: fixturePath == null
        ? 'Run through scripts/test-forge-contracts.sh.'
        : false,
  );

  test(
    'rejects unknown fields, enabled authority, duplicate cases, and keys',
    () {
      final value = _fixture();
      value['unexpected'] = true;
      expect(
        () => ForgeAttemptRequestPreviewFixture.fromJson(value),
        throwsFormatException,
      );

      final authority = _fixture();
      (authority['authority'] as Map<String, dynamic>)['dispatch_performed'] =
          true;
      expect(
        () => ForgeAttemptRequestPreviewFixture.fromJson(authority),
        throwsFormatException,
      );

      final duplicate = _fixture();
      final cases = duplicate['cases'] as List<dynamic>;
      cases.add(cases.first);
      expect(
        () => ForgeAttemptRequestPreviewFixture.fromJson(duplicate),
        throwsFormatException,
      );

      expect(
        () => ForgeAttemptRequestPreviewFixture.fromJsonText(
          '{"schema_version":"forge.attempt-request/v1",'
          '"schema_version":"forge.attempt-request/v1"}',
        ),
        throwsFormatException,
      );
    },
  );

  test('rejects unsorted normalized effects and invalid request fields', () {
    final value = _fixture();
    final first = Map<String, dynamic>.from(
      (value['cases'] as List<dynamic>).first as Map,
    );
    final expected = Map<String, dynamic>.from(first['expected'] as Map);
    expected['requested_effects'] = ['write.file', 'read.repo'];
    first['expected'] = expected;
    final mutableCases = List<dynamic>.from(value['cases'] as List<dynamic>);
    mutableCases[0] = first;
    value['cases'] = mutableCases;
    expect(
      () => ForgeAttemptRequestPreviewFixture.fromJson(value),
      throwsFormatException,
    );
  });
}

Map<String, dynamic> _fixture() => {
  'schema_version': forgeAttemptRequestSchema,
  'evaluation_mode': forgeAttemptRequestEvaluationMode,
  'authority': {
    'device_identity_verified': false,
    'references_resolved': false,
    'request_persisted': false,
    'reservation_created': false,
    'execution_authorized': false,
    'dispatch_performed': false,
    'audit_published': false,
  },
  'cases': [
    {
      'name': 'valid',
      'request': _request(),
      'expected': {
        'accepted': true,
        'error': '',
        'initial_state': 'requested',
        'requested_effects': ['read.repo'],
        'approval_record_ids': ['approval.a'],
      },
    },
  ],
};

Map<String, dynamic> _request() => {
  'scope_ref': {
    'action_id': null,
    'attempt_id': 'attempt',
    'change_id': 'change',
    'objective_id': 'objective',
    'project_id': 'project',
    'project_snapshot_id': 'snapshot',
    'session_id': null,
    'space_id': 'space',
    'turn_id': null,
    'work_graph_id': 'graph',
    'work_item_id': 'item',
  },
  'attempt_ref': {'entity_id': 'attempt', 'entity_type': 'attempt'},
  'work_item_ref': {'entity_id': 'item', 'entity_type': 'work_item'},
  'project_ref': {'entity_id': 'project', 'entity_type': 'project'},
  'project_snapshot_ref': {
    'entity_id': 'snapshot',
    'entity_type': 'project_snapshot',
  },
  'control_versions': {
    'objective_version': 1,
    'change_version': 1,
    'work_graph_version': 1,
    'work_item_version': 1,
  },
  'executor': {
    'actor_ref': {'actor_id': 'actor', 'actor_type': 'agent'},
    'adapter_id': 'adapter',
    'adapter_version': '1',
  },
  'context_artifact_ref': null,
  'workspace_capability_ref': null,
  'grant_ref': null,
  'approval_refs': [
    {
      'record_id': 'approval.a',
      'record_sha256': 'digest',
      'record_type': 'approval',
    },
  ],
  'requested_effects': ['read.repo'],
  'budget': {
    'max_duration_ms': 1,
    'max_cost_usd_micros': 1,
    'max_model_calls': 1,
    'max_tool_calls': 1,
    'max_input_tokens': 1,
    'max_output_tokens': 1,
    'max_output_bytes': 1,
    'max_network_bytes': 1,
  },
  'timeout_ms': 1,
  'idempotency_key': 'attempt-key',
};
