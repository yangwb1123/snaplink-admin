import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_pending_write_recovery.dart';

void main() {
  final fixturePath =
      Platform.environment['FORGE_PENDING_WRITE_RECOVERY_CONTRACT_FIXTURE'];

  test(
    'consumes the shared pending-write recovery metadata fixture',
    () {
      final root = Map<String, dynamic>.from(
        jsonDecode(File(fixturePath!).readAsStringSync()) as Map,
      );
      _assertFixture(root);
    },
    skip: fixturePath == null
        ? 'Run through scripts/test-forge-contracts.sh.'
        : false,
  );

  test('metadata excludes Prompt, title, and scope bytes', () {
    final metadata = ForgePendingWriteRecoveryMetadata.fromJson({
      'operation': 'append_prompt',
      'conversation_id': 'conversation-1',
      'expected_version': 2,
      'idempotency_key': 'stable-key',
      'state': 'unconfirmed',
      'attempted_at_ms': null,
      'last_observed_at_ms': null,
    });
    expect(
      metadata.toJson().keys,
      containsAll(<String>{
        'operation',
        'conversation_id',
        'expected_version',
        'idempotency_key',
        'state',
        'attempted_at_ms',
        'last_observed_at_ms',
      }),
    );
    expect(metadata.toJson().keys, isNot(contains('content')));
    expect(metadata.toJson().keys, isNot(contains('title')));
    expect(metadata.toJson().keys, isNot(contains('scope')));
  });

  test('rejects unknown fields and a new-key duplicate path', () {
    expect(
      () => ForgePendingWriteRecoveryMetadata.fromJson({
        'operation': 'append_prompt',
        'conversation_id': 'conversation-1',
        'expected_version': 2,
        'idempotency_key': 'stable-key',
        'state': 'unconfirmed',
        'attempted_at_ms': null,
        'last_observed_at_ms': null,
        'content': 'must not be carried',
      }),
      throwsA(isA<FormatException>()),
    );
    final metadata = ForgePendingWriteRecoveryMetadata.fromJson({
      'operation': 'append_prompt',
      'conversation_id': 'conversation-1',
      'expected_version': 2,
      'idempotency_key': 'stable-key',
      'state': 'unconfirmed',
      'attempted_at_ms': null,
      'last_observed_at_ms': null,
    });
    final projection = projectForgePendingWriteRecovery(metadata);
    expect(projection.pending, isTrue);
    expect(projection.unconfirmed, isTrue);
    expect(projection.sameKeyRequired, isTrue);
    expect(projection.reconcileBeforeRetry, isTrue);
  });
}

void _assertFixture(Map<String, dynamic> root) {
  _exactKeys(root, {'schema_version', 'evaluation_mode', 'authority', 'cases'});
  expect(root['schema_version'], forgePendingWriteRecoverySchema);
  expect(root['evaluation_mode'], forgePendingWriteRecoveryEvaluationMode);
  final authority = Map<String, dynamic>.from(root['authority'] as Map);
  _exactKeys(authority, {
    'body_included',
    'run_created',
    'network_contacted',
    'persistence_written',
  });
  expect(authority['body_included'], isFalse);
  expect(authority['run_created'], isFalse);
  expect(authority['network_contacted'], isFalse);
  expect(authority['persistence_written'], isFalse);
  final cases = root['cases'];
  expect(cases, isA<List>());
  expect(cases, hasLength(6));
  for (final raw in cases! as List) {
    final testCase = Map<String, dynamic>.from(raw as Map);
    _exactKeys(testCase, {'name', 'metadata', 'expected'});
    final metadata = ForgePendingWriteRecoveryMetadata.fromJson(
      testCase['metadata'],
    );
    final expected = Map<String, dynamic>.from(testCase['expected'] as Map);
    final accepted = expected['accepted'];
    expect(accepted, isA<bool>());
    if (accepted == false) {
      _exactKeys(expected, {'accepted', 'error'});
      expect(
        () => projectForgePendingWriteRecovery(metadata),
        throwsA(
          isA<ForgePendingWriteRecoveryError>().having(
            (error) => error.code,
            'code',
            expected['error'],
          ),
        ),
      );
      continue;
    }
    _exactKeys(expected, {
      'accepted',
      'operation',
      'conversation_id',
      'expected_version',
      'idempotency_key',
      'state',
      'pending',
      'unconfirmed',
      'retry_allowed',
      'same_key_required',
      'reconcile_before_retry',
      'attempted_at_ms',
      'last_observed_at_ms',
    });
    final actual = projectForgePendingWriteRecovery(metadata);
    expect(actual.schemaVersion, forgePendingWriteRecoverySchema);
    expect(actual.evaluationMode, forgePendingWriteRecoveryEvaluationMode);
    expect(actual.metadata.operation, expected['operation']);
    expect(actual.metadata.conversationID, expected['conversation_id']);
    expect(
      actual.metadata.expectedVersion,
      _bigIntOrNull(expected['expected_version']),
    );
    expect(actual.metadata.idempotencyKey, expected['idempotency_key']);
    expect(actual.metadata.state, expected['state']);
    expect(actual.pending, expected['pending']);
    expect(actual.unconfirmed, expected['unconfirmed']);
    expect(actual.retryAllowed, expected['retry_allowed']);
    expect(actual.sameKeyRequired, expected['same_key_required']);
    expect(actual.reconcileBeforeRetry, expected['reconcile_before_retry']);
    expect(
      actual.metadata.attemptedAtMS,
      _bigIntOrNull(expected['attempted_at_ms']),
    );
    expect(
      actual.metadata.lastObservedAtMS,
      _bigIntOrNull(expected['last_observed_at_ms']),
    );
  }
}

BigInt? _bigIntOrNull(Object? value) {
  if (value == null) return null;
  return BigInt.from(value as int);
}

void _exactKeys(Map<String, dynamic> json, Set<String> expected) {
  if (json.length != expected.length ||
      json.keys.any((key) => !expected.contains(key))) {
    throw const FormatException('Unexpected Forge pending-write fields.');
  }
}
