import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_session_runner_receipt_observation.dart';

void main() {
  final fixturePath =
      Platform.environment['FORGE_SESSION_RUNNER_RECEIPT_CONTRACT_FIXTURE'];

  test(
    'consumes and round-trips the strict session Runner receipt fixture',
    () {
      final fixture = _fixture();
      final observation = ForgeSessionRunnerReceiptObservation.fromJson(
        fixture,
      );

      expect(
        observation.schemaVersion,
        forgeSessionRunnerReceiptObservationSchema,
      );
      expect(
        observation.evaluationMode,
        forgeSessionRunnerReceiptObservationEvaluationMode,
      );
      expect(observation.conversationID, 'conversation-001');
      expect(observation.promptID, 'prompt-001');
      expect(observation.runID, 'run-001');
      expect(observation.receiptObservation.attemptID, 'attempt-001');
      expect(observation.receiptObservation.commandID, 'command-001');
      expect(observation.receiptObservation.targetID, 'runner-1');
      expect(observation.receiptObservation.dispositionKind, 'completed');
      expect(observation.receiptObservation.observedAtMS, 300);
      expect(observation.selectedTargetID, isNull);
      expect(observation.authority.isOffline, isTrue);
      expect(observation.isDisplayOnly, isTrue);
      expect(observation.isFor('conversation-001', 'run-001'), isTrue);
      expect(jsonEncode(observation.toJson()), jsonEncode(fixture));
    },
    skip: fixturePath == null
        ? 'Run through scripts/test-forge-contracts.sh.'
        : false,
  );

  test(
    'fails closed on unknown fields, selected targets, and authority',
    () {
      final unknown = _fixture()..['unexpected'] = true;
      expect(
        () => ForgeSessionRunnerReceiptObservation.fromJson(unknown),
        throwsA(isA<FormatException>()),
      );

      final selected = _fixture()..['selected_target_id'] = 'runner-1';
      expect(
        () => ForgeSessionRunnerReceiptObservation.fromJson(selected),
        throwsA(isA<FormatException>()),
      );

      final authority = _fixture();
      (authority['authority'] as Map<String, dynamic>)['dispatch_performed'] =
          true;
      expect(
        () => ForgeSessionRunnerReceiptObservation.fromJson(authority),
        throwsA(isA<FormatException>()),
      );

      final receipt = _fixture();
      (receipt['receipt_observation'] as Map<String, dynamic>)['unexpected'] =
          true;
      expect(
        () => ForgeSessionRunnerReceiptObservation.fromJson(receipt),
        throwsA(isA<FormatException>()),
      );
    },
    skip: fixturePath == null
        ? 'Run through scripts/test-forge-contracts.sh.'
        : false,
  );
}

Map<String, dynamic> _fixture() {
  final path =
      Platform.environment['FORGE_SESSION_RUNNER_RECEIPT_CONTRACT_FIXTURE'];
  if (path == null) throw StateError('fixture path is required');
  return Map<String, dynamic>.from(
    jsonDecode(File(path).readAsStringSync()) as Map,
  );
}
