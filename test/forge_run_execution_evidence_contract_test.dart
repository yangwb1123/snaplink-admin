import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_run_execution_evidence.dart';

void main() {
  final fixturePath =
      Platform.environment['FORGE_RUN_EXECUTION_EVIDENCE_FIXTURE'];

  test('consumes the shared content-free execution evidence fixture', () {
    if (fixturePath == null || fixturePath.isEmpty) return;
    final value = jsonDecode(File(fixturePath).readAsStringSync());
    final evidence = ForgeRunExecutionEvidence.fromJson(value);

    expect(
      evidence.ownerRef,
      '21444e9222fa722f4b05e8a353e2e840594863c941bba4c2222b3c22bb198ba5',
    );
    expect(evidence.dispositionKind, 'completed');
    expect(evidence.isDisplayOnly, isTrue);
    expect(jsonEncode(evidence.toJson()), jsonEncode(value));
  });

  test('fails closed on raw content, unknown fields, and authority', () {
    final unknown = _fixture()..['prompt'] = 'raw prompt';
    expect(
      () => ForgeRunExecutionEvidence.fromJson(unknown),
      throwsA(isA<FormatException>()),
    );

    final content = _fixture()..['content_included'] = true;
    expect(
      () => ForgeRunExecutionEvidence.fromJson(content),
      throwsA(isA<FormatException>()),
    );

    final authority = _fixture();
    (authority['authority'] as Map<String, dynamic>)['execution_authorized'] =
        true;
    expect(
      () => ForgeRunExecutionEvidence.fromJson(authority),
      throwsA(isA<FormatException>()),
    );
  });
}

Map<String, dynamic> _fixture() => {
  'api_version': forgeRunExecutionEvidenceSchema,
  'evaluation_mode': forgeRunExecutionEvidenceEvaluationMode,
  'owner_ref':
      '21444e9222fa722f4b05e8a353e2e840594863c941bba4c2222b3c22bb198ba5',
  'conversation_id': 'conversation-001',
  'run_id': 'run-001',
  'prompt_id': 'prompt-001',
  'run_status': 'nonterminal',
  'attempt_id': 'attempt-001',
  'target_id': 'runner-1',
  'command_id': 'command-001',
  'command_sha256':
      '42ed02a535113450e6f2cc757fb9b4e2cce6143724274191bbae159e9ea8de7a',
  'disposition_kind': 'completed',
  'receipt_observed_at_ms': 300,
  'uncertain': false,
  'reconciliation_required': false,
  'metadata_observed': true,
  'content_included': false,
  'authority': {
    'identity_verified': false,
    'owner_authorized': false,
    'run_authoritative': false,
    'receipt_persisted': false,
    'reservation_created': false,
    'execution_authorized': false,
    'dispatch_performed': false,
    'audit_published': false,
  },
};
