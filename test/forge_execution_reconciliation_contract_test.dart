import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_execution_reconciliation_observation.dart';

void main() {
  final fixturePath =
      Platform.environment['FORGE_EXECUTION_RECONCILIATION_FIXTURE'];

  test(
    'consumes the canonical Forge execution reconciliation cases',
    () {
      final root =
          jsonDecode(File(fixturePath!).readAsStringSync())
              as Map<String, dynamic>;
      expect(
        root['schema_version'],
        forgeExecutionReconciliationObservationSchema,
      );
      expect(
        root['evaluation_mode'],
        forgeExecutionReconciliationObservationEvaluationMode,
      );
      expect(
        (root['authority'] as Map<String, dynamic>).values,
        everyElement(isFalse),
      );

      final cases = root['cases'] as List<dynamic>;
      expect(cases, hasLength(6));
      for (final rawCase in cases) {
        final testCase = rawCase as Map<String, dynamic>;
        final inputJSON = testCase['input'] as Map<String, dynamic>;
        final expected = testCase['expected'] as Map<String, dynamic>;
        if (expected['accepted'] == false) {
          expect(
            () => ForgeExecutionReconciliationInput.fromJson(inputJSON),
            throwsA(isA<FormatException>()),
            reason: testCase['name'] as String,
          );
          continue;
        }
        final input = ForgeExecutionReconciliationInput.fromJson(inputJSON);
        final observation = observeForgeExecutionReconciliation(input);
        expect(observation.isDisplayOnly, isTrue);
        expect(observation.leaseActive, expected['lease_active']);
        expect(observation.terminalObserved, expected['terminal_observed']);
        expect(
          observation.terminalDisposition,
          expected['terminal_disposition'],
        );
        expect(
          observation.terminalStateAligned,
          expected['terminal_state_aligned'],
        );
        expect(observation.nextObservation, expected['next_observation']);
        expect(
          observation.reconciliationRequired,
          expected['reconciliation_required'],
        );
        final roundTrip = ForgeExecutionReconciliationObservation.fromJson(
          observation.toJson(),
        );
        expect(roundTrip.toJson(), observation.toJson());
      }
    },
    skip: fixturePath == null
        ? 'Run through scripts/test-forge-contracts.sh.'
        : false,
  );

  test('rejects unknown fields, duplicate fields, authority, and unsafe ints', () {
    final input = _input();
    final unknown = input.toJson()..['unexpected'] = true;
    expect(
      () => ForgeExecutionReconciliationInput.fromJson(unknown),
      throwsA(isA<FormatException>()),
    );

    final duplicateRoot = jsonEncode(
      input.toJson(),
    ).replaceFirst('"owner":', '"owner":');
    final duplicateSource = duplicateRoot.replaceFirst(
      RegExp(r'\{"issuer"'),
      '{"issuer"',
    );
    // Build explicit duplicate JSON so the test exercises the raw decoder;
    // map decoding alone cannot preserve duplicate members.
    const duplicate =
        '{"owner":{"issuer":"https://id.example.test","issuer":"https://id.example.test",'
        '"subject":"user-1","tenant_id":"tenant-1"},'
        '"conversation_id":"conversation-1","run_id":"run-1","attempt_id":"attempt-1",'
        '"command_id":"command-1","target_id":"runner-1","run_status":"nonterminal",'
        '"attempt_state":"running","lease":{"v":1,"attempt_id":"attempt-1",'
        '"target_id":"runner-1","epoch":1,"fencing_token":"fence-1",'
        '"issued_at_ms":100,"expires_at_ms":10100},"observed_at_ms":200,"terminal":null}';
    expect(duplicateSource, isNotEmpty);
    expect(
      () => ForgeExecutionReconciliationInput.fromJsonText(duplicate),
      throwsA(isA<FormatException>()),
    );

    final unsafe = input.toJson()..['observed_at_ms'] = 9007199254740992;
    expect(
      () => ForgeExecutionReconciliationInput.fromJson(unsafe),
      throwsA(isA<FormatException>()),
    );

    final output = observeForgeExecutionReconciliation(input).toJson();
    (output['authority'] as Map<String, dynamic>)['dispatch_performed'] = true;
    expect(
      () => ForgeExecutionReconciliationObservation.fromJson(output),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects classification and binding drift in observations', () {
    final input = _input();
    final output = observeForgeExecutionReconciliation(input).toJson();
    output['next_observation'] = 'lease_expired_without_terminal';
    expect(
      () => ForgeExecutionReconciliationObservation.fromJson(output),
      throwsA(isA<FormatException>()),
    );

    final terminalInput = _input(
      terminal: {
        'v': 1,
        'proof': {
          'attempt_id': 'attempt-1',
          'target_id': 'runner-1',
          'epoch': 1,
          'fencing_token': 'fence-1',
        },
        'disposition': {
          'kind': 'completed',
          'receipt_sha256':
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        },
        'observed_at_ms': 200,
      },
      attemptState: 'running',
    );
    final conflict = observeForgeExecutionReconciliation(terminalInput);
    expect(conflict.nextObservation, 'terminal_state_conflict');
    expect(conflict.reconciliationRequired, isTrue);
  });
}

ForgeExecutionReconciliationInput _input({
  String attemptState = 'running',
  Map<String, dynamic>? terminal,
}) => ForgeExecutionReconciliationInput.fromJson({
  'owner': {
    'issuer': 'https://id.example.test',
    'subject': 'user-1',
    'tenant_id': 'tenant-1',
  },
  'conversation_id': 'conversation-1',
  'run_id': 'run-1',
  'attempt_id': 'attempt-1',
  'command_id': 'command-1',
  'target_id': 'runner-1',
  'run_status': 'nonterminal',
  'attempt_state': attemptState,
  'lease': {
    'v': 1,
    'attempt_id': 'attempt-1',
    'target_id': 'runner-1',
    'epoch': 1,
    'fencing_token': 'fence-1',
    'issued_at_ms': 100,
    'expires_at_ms': 10100,
  },
  'observed_at_ms': 200,
  'terminal': terminal,
});
