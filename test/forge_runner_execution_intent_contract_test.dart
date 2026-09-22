import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_runner_execution_intent.dart';

void main() {
  test('consumes a strict preview-only Runner execution envelope', () {
    final value = _envelope();
    final observation = ForgeRunnerExecutionIntentObservation.fromJson(value);

    expect(observation.schemaVersion, forgeRunnerExecutionIntentSchema);
    expect(observation.evaluationMode, 'pure_runner_binding_only');
    expect(observation.conversationID, 'conversation-1');
    expect(observation.runID, 'run-1');
    expect(observation.attemptID, 'attempt-1');
    expect(observation.commandID, 'command-1');
    expect(observation.targetID, 'runner-1');
    expect(observation.commandSHA256, 'a' * 64);
    expect(observation.selectedTargetID, isNull);
    expect(observation.isDisplayOnly, isTrue);
    expect(jsonEncode(observation.toJson()), jsonEncode(value));
  });

  test('fails closed on unknown fields, selected targets, and authority', () {
    final unknown = _envelope()..['unexpected'] = true;
    expect(
      () => ForgeRunnerExecutionIntentObservation.fromJson(unknown),
      throwsA(isA<FormatException>()),
    );

    final selected = _envelope()..['selected_target_id'] = 'runner-1';
    expect(
      () => ForgeRunnerExecutionIntentObservation.fromJson(selected),
      throwsA(isA<FormatException>()),
    );

    final authority = _envelope();
    (authority['authority'] as Map<String, dynamic>)['execution_authorized'] =
        true;
    expect(
      () => ForgeRunnerExecutionIntentObservation.fromJson(authority),
      throwsA(isA<FormatException>()),
    );
  });
}

Map<String, dynamic> _envelope() => {
  'schema_version': forgeRunnerExecutionIntentSchema,
  'evaluation_mode': forgeRunnerExecutionIntentEvaluationMode,
  'owner': {
    'issuer': 'https://id.example',
    'subject': 'user-1',
    'tenant_id': 'tenant-1',
  },
  'conversation_id': 'conversation-1',
  'prompt_id': 'prompt-1',
  'run_id': 'run-1',
  'attempt_id': 'attempt-1',
  'command_id': 'command-1',
  'target_id': 'runner-1',
  'command_sha256': 'a' * 64,
  'idempotency_key': 'run-1:attempt-1:command-1',
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
