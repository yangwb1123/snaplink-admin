import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_runner_attempt_boundary.dart';

void main() {
  final fixturePath =
      Platform.environment['FORGE_RUNNER_ATTEMPT_BOUNDARY_FIXTURE'];

  test(
    'consumes the canonical Runner Attempt boundary fixture',
    () {
      final source = File(fixturePath!).readAsStringSync();
      final observation = ForgeRunnerAttemptBoundaryObservation.fromJsonText(
        source,
      );
      expect(
        ForgeRunnerAttemptBoundaryObservation.schema,
        forgeRunnerAttemptBoundarySchema,
      );
      expect(
        ForgeRunnerAttemptBoundaryObservation.evaluationMode,
        forgeRunnerAttemptBoundaryEvaluationMode,
      );
      expect(observation.conversationID, 'conversation-1');
      expect(observation.runID, 'run-1');
      expect(observation.attemptID, 'attempt-1');
      expect(observation.commandID, 'command-1');
      expect(observation.targetID, 'runner-1');
      expect(observation.attemptBoundaryReady, isTrue);
      expect(observation.isDisplayOnly, isTrue);
      expect(
        observation.toJson(),
        equals(jsonDecode(source) as Map<String, dynamic>),
      );
    },
    skip: fixturePath == null,
  );

  test('fails closed on wire, lifecycle, and authority drift', () {
    final unknown = _fixture()..['unexpected'] = true;
    expect(
      () => ForgeRunnerAttemptBoundaryObservation.fromJson(unknown),
      throwsFormatException,
    );

    final duplicate = jsonEncode(_fixture()).replaceFirst(
      '"schema_version":"$forgeRunnerAttemptBoundarySchema",',
      '"schema_version":"$forgeRunnerAttemptBoundarySchema",'
          '"schema_version":"$forgeRunnerAttemptBoundarySchema",',
    );
    expect(
      () => ForgeRunnerAttemptBoundaryObservation.fromJsonText(duplicate),
      throwsFormatException,
    );

    final trailing = '${jsonEncode(_fixture())} {}';
    expect(
      () => ForgeRunnerAttemptBoundaryObservation.fromJsonText(trailing),
      throwsFormatException,
    );

    final authority = _fixture();
    (authority['authority'] as Map<String, dynamic>)['dispatch_performed'] =
        true;
    expect(
      () => ForgeRunnerAttemptBoundaryObservation.fromJson(authority),
      throwsFormatException,
    );

    final lifecycle = _fixture()..['next_attempt_state'] = 'running';
    expect(
      () => ForgeRunnerAttemptBoundaryObservation.fromJson(lifecycle),
      throwsFormatException,
    );
  });

  test('keeps legal non-dispatchable lifecycle edges observable', () {
    final value = _fixture()
      ..['current_attempt_state'] = 'running'
      ..['next_attempt_state'] = 'completed'
      ..['transition'] = 'observe_completed'
      ..['attempt_transition_dispatchable'] = false
      ..['attempt_boundary_ready'] = false
      ..['rejection_reasons'] = ['attempt_transition_not_dispatchable'];
    final observation = ForgeRunnerAttemptBoundaryObservation.fromJson(value);
    expect(observation.attemptTransitionValid, isTrue);
    expect(observation.attemptTransitionDispatchable, isFalse);
    expect(observation.attemptBoundaryReady, isFalse);
    expect(observation.rejectionReasons, [
      'attempt_transition_not_dispatchable',
    ]);
    expect(observation.isDisplayOnly, isTrue);
    expect(jsonEncode(observation.toJson()), isNot(contains('argv')));
    expect(jsonEncode(observation.toJson()), isNot(contains('fencing_token')));
  });
}

Map<String, dynamic> _fixture() => {
  'schema_version': forgeRunnerAttemptBoundarySchema,
  'evaluation_mode': forgeRunnerAttemptBoundaryEvaluationMode,
  'owner': {
    'issuer': 'https://id.example',
    'subject': 'user-1',
    'tenant_id': 'tenant-1',
  },
  'conversation_id': 'conversation-1',
  'run_id': 'run-1',
  'attempt_id': 'attempt-1',
  'command_id': 'command-1',
  'target_id': 'runner-1',
  'lease_epoch': 1,
  'current_attempt_state': 'accepted',
  'next_attempt_state': 'starting',
  'transition': 'begin_starting',
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
