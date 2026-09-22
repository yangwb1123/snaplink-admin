import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_execution_lease_checkpoint.dart';

void main() {
  final fixturePath =
      Platform.environment['FORGE_EXECUTION_LEASE_CHECKPOINT_FIXTURE'];

  test(
    'consumes the shared Go/Rust execution-lease checkpoint fixture',
    () {
      final path = fixturePath;
      if (path == null || path.isEmpty) return;
      final fixture = ForgeExecutionLeaseCheckpointFixture.fromJsonText(
        File(path).readAsStringSync(),
      );
      expect(fixture.schemaVersion, forgeExecutionLeaseCheckpointSchema);
      expect(
        fixture.evaluationMode,
        forgeExecutionLeaseCheckpointEvaluationMode,
      );
      expect(fixture.authority.isOffline, isTrue);
      expect(fixture.cases, hasLength(4));
      expect(fixture.cases[0].expected.accepted, isTrue);
      expect(fixture.cases[1].expected.terminal, isTrue);
      expect(fixture.cases[2].expected.uncertain, isTrue);
      expect(fixture.cases[3].expected.error, 'invalid_checkpoint');
      expect(fixture.isDisplayOnly, isTrue);
    },
    skip: fixturePath == null || fixturePath.isEmpty
        ? 'Run through scripts/test-forge-contracts.sh.'
        : false,
  );

  test('round-trips the strict display-only value', () {
    final fixture = ForgeExecutionLeaseCheckpointFixture.fromJson(_fixture());
    final decoded = ForgeExecutionLeaseCheckpointFixture.fromJson(
      jsonDecode(jsonEncode(fixture.toJson())),
    );
    expect(decoded.isDisplayOnly, isTrue);
    expect(decoded.cases.map((item) => item.name), [
      'empty_state',
      'completed_receipt_survives_restart',
      'uncertain_receipt_remains_terminal',
      'foreign_proof_rejected',
    ]);
    expect(decoded.cases.last.expected.accepted, isFalse);
  });

  test('rejects unknown fields and enabled authority', () {
    final unknown = _fixture();
    unknown['unexpected'] = true;
    expect(
      () => ForgeExecutionLeaseCheckpointFixture.fromJson(unknown),
      throwsA(isA<FormatException>()),
    );

    final enabled = _fixture();
    (enabled['authority'] as Map<String, dynamic>)['dispatch_performed'] = true;
    expect(
      () => ForgeExecutionLeaseCheckpointFixture.fromJson(enabled),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects duplicate keys before Dart map decoding', () {
    final source = jsonEncode(_fixture());
    final duplicateRoot = source.replaceFirst(
      '"schema_version":"$forgeExecutionLeaseCheckpointSchema",',
      '"schema_version":"$forgeExecutionLeaseCheckpointSchema",'
          '"schema_version":"$forgeExecutionLeaseCheckpointSchema",',
    );
    expect(duplicateRoot, isNot(source));
    expect(
      () => ForgeExecutionLeaseCheckpointFixture.fromJsonText(duplicateRoot),
      throwsA(isA<FormatException>()),
    );

    final duplicateNested = source.replaceFirst(
      '"attempt_id":"attempt-1",',
      '"attempt_id":"attempt-1","attempt_id":"attempt-1",',
    );
    expect(duplicateNested, isNot(source));
    expect(
      () => ForgeExecutionLeaseCheckpointFixture.fromJsonText(duplicateNested),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects expectation drift and foreign proof acceptance', () {
    final drift = _fixture();
    final cases = drift['cases'] as List;
    final foreign = Map<String, dynamic>.from(cases.last as Map);
    foreign['expected'] = {'accepted': true};
    drift['cases'] = [...cases.take(3), foreign];
    expect(
      () => ForgeExecutionLeaseCheckpointFixture.fromJson(drift),
      throwsA(isA<FormatException>()),
    );
  });
}

Map<String, dynamic> _fixture() {
  Map<String, dynamic> grant() => {
    'v': 1,
    'attempt_id': 'attempt-1',
    'target_id': 'runner-1',
    'epoch': 1,
    'fencing_token': 'fence-1',
    'issued_at_ms': 100,
    'expires_at_ms': 10100,
  };

  Map<String, dynamic> proof({String attemptID = 'attempt-1'}) => {
    'attempt_id': attemptID,
    'target_id': 'runner-1',
    'epoch': 1,
    'fencing_token': 'fence-1',
  };

  Map<String, dynamic> checkpoint({Object? terminal}) => {
    'schema_version': forgeExecutionLeaseCheckpointSchema,
    'evaluation_mode': forgeExecutionLeaseCheckpointEvaluationMode,
    'grant': grant(),
    'terminal': terminal,
  };

  return {
    'schema_version': forgeExecutionLeaseCheckpointSchema,
    'evaluation_mode': forgeExecutionLeaseCheckpointEvaluationMode,
    'authority': {
      'lease_issued': false,
      'terminal_persisted': false,
      'execution_authorized': false,
      'dispatch_performed': false,
      'audit_published': false,
    },
    'cases': [
      {
        'name': 'empty_state',
        'checkpoint': checkpoint(),
        'expected': {'accepted': true, 'terminal': false},
      },
      {
        'name': 'completed_receipt_survives_restart',
        'checkpoint': checkpoint(
          terminal: {
            'v': 1,
            'proof': proof(),
            'disposition': {
              'kind': 'completed',
              'receipt_sha256':
                  'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            },
            'observed_at_ms': 200,
          },
        ),
        'expected': {'accepted': true, 'terminal': true},
      },
      {
        'name': 'uncertain_receipt_remains_terminal',
        'checkpoint': checkpoint(
          terminal: {
            'v': 1,
            'proof': proof(),
            'disposition': {
              'kind': 'uncertain',
              'reason': 'transport ended after effect boundary',
            },
            'observed_at_ms': 300,
          },
        ),
        'expected': {'accepted': true, 'terminal': true, 'uncertain': true},
      },
      {
        'name': 'foreign_proof_rejected',
        'checkpoint': checkpoint(
          terminal: {
            'v': 1,
            'proof': proof(attemptID: 'foreign-attempt'),
            'disposition': {
              'kind': 'failed',
              'reason': 'runner rejected command',
            },
            'observed_at_ms': 200,
          },
        ),
        'expected': {'accepted': false, 'error': 'invalid_checkpoint'},
      },
    ],
  };
}
