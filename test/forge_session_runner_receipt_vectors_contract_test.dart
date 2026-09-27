import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_session_runner_receipt_observation.dart';
import 'package:sso_admin/api/forge_session_runner_receipt_vectors.dart';

void main() {
  final fixturePath =
      Platform.environment['FORGE_SESSION_RUNNER_RECEIPT_VECTORS_FIXTURE'];

  test(
    'consumes completed, failed, and uncertain session Runner receipt vectors',
    () {
      final fixture = _fixture();
      final typed = ForgeSessionRunnerReceiptVectors.fromJson(fixture);
      expect(typed.isDisplayOnly, isTrue);
      expect(typed.vectors.map((vector) => vector.name), [
        'completed',
        'failed',
        'uncertain',
      ]);
      _exactKeys(fixture, {
        'schema_version',
        'evaluation_mode',
        'authority',
        'vectors',
      });
      expect(
        fixture['schema_version'],
        'forge.session-runner-receipt-vectors/v1',
      );
      expect(
        fixture['evaluation_mode'],
        'pure_session_runner_receipt_vectors_only',
      );
      expect(fixture['authority'], {
        'identity_verified': false,
        'receipt_persisted': false,
        'execution_authorized': false,
        'dispatch_performed': false,
        'audit_published': false,
      });

      final vectors = fixture['vectors'] as List<dynamic>;
      expect(vectors, hasLength(3));
      final names = <String>{};
      for (final raw in vectors) {
        final vector = Map<String, dynamic>.from(raw as Map);
        _exactKeys(vector, {'name', 'observation', 'expected'});
        final name = vector['name'] as String;
        expect(names.add(name), isTrue);
        final expected = Map<String, dynamic>.from(vector['expected'] as Map);
        _exactKeys(expected, {
          'command_id',
          'command_sha256',
          'attempt_id',
          'target_id',
          'disposition_kind',
          'observed_at_ms',
          'uncertain',
          'reconciliation_required',
          'manual_review_required',
          'automatic_retry',
          'follow_up',
        });
        final observation = ForgeSessionRunnerReceiptObservation.fromJson(
          vector['observation'],
        );
        expect(observation.isDisplayOnly, isTrue);
        expect(observation.selectedTargetID, isNull);
        final receipt = observation.receiptObservation;
        expect(receipt.commandID, expected['command_id']);
        expect(receipt.commandSHA256, expected['command_sha256']);
        expect(receipt.attemptID, expected['attempt_id']);
        expect(receipt.targetID, expected['target_id']);
        expect(receipt.dispositionKind, expected['disposition_kind']);
        expect(receipt.observedAtMS, expected['observed_at_ms']);
        expect(receipt.uncertain, expected['uncertain']);
        expect(
          receipt.reconciliationRequired,
          expected['reconciliation_required'],
        );
        expect(
          receipt.manualReviewRequired,
          expected['manual_review_required'],
        );
        expect(receipt.automaticRetry, expected['automatic_retry']);
        expect(receipt.followUp, expected['follow_up']);
      }
      expect(names, {'completed', 'failed', 'uncertain'});
    },
    skip: fixturePath == null
        ? 'Run through scripts/test-forge-contracts.sh.'
        : false,
  );

  test(
    'typed vector import rejects duplicate, trailing, and authority drift',
    () {
      final source = File(fixturePath!).readAsStringSync();
      expect(
        () => ForgeSessionRunnerReceiptVectors.fromJsonText('$source {}'),
        throwsFormatException,
      );
      expect(
        () => ForgeSessionRunnerReceiptVectors.fromJsonText(
          source.replaceFirst(
            '"evaluation_mode": "pure_session_runner_receipt_vectors_only",',
            '"evaluation_mode": "pure_session_runner_receipt_vectors_only", "evaluation_mode": "pure_session_runner_receipt_vectors_only",',
          ),
        ),
        throwsFormatException,
      );
      final authority = _fixture();
      final authorityJSON = Map<String, dynamic>.from(
        authority['authority'] as Map,
      )..['execution_authorized'] = true;
      authority['authority'] = authorityJSON;
      expect(
        () => ForgeSessionRunnerReceiptVectors.fromJson(authority),
        throwsFormatException,
      );
    },
    skip: fixturePath == null
        ? 'Run through scripts/test-forge-contracts.sh.'
        : false,
  );

  test(
    'fails closed on vector metadata, selected target, and uncertain retry drift',
    () {
      final unknown = _fixture()..['unexpected'] = true;
      expect(
        () => _decodeVectorFixture(unknown),
        throwsA(isA<FormatException>()),
      );

      final selected = _fixture();
      final vectors = selected['vectors'] as List<dynamic>;
      final first = Map<String, dynamic>.from(vectors.first as Map);
      final observation = Map<String, dynamic>.from(first['observation'] as Map)
        ..['selected_target_id'] = 'runner-1';
      first['observation'] = observation;
      vectors[0] = first;
      expect(
        () =>
            ForgeSessionRunnerReceiptObservation.fromJson(first['observation']),
        throwsA(isA<FormatException>()),
      );

      final retry = _fixture();
      final retryVectors = retry['vectors'] as List<dynamic>;
      final uncertain = Map<String, dynamic>.from(retryVectors[2] as Map);
      final uncertainObservation = Map<String, dynamic>.from(
        uncertain['observation'] as Map,
      );
      final receipt = Map<String, dynamic>.from(
        uncertainObservation['receipt_observation'] as Map,
      )..['automatic_retry'] = true;
      uncertainObservation['receipt_observation'] = receipt;
      expect(
        () =>
            ForgeSessionRunnerReceiptObservation.fromJson(uncertainObservation),
        throwsA(isA<FormatException>()),
      );

      expect(
        () => jsonDecode('${jsonEncode(_fixture())} {}'),
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
      Platform.environment['FORGE_SESSION_RUNNER_RECEIPT_VECTORS_FIXTURE'];
  if (path == null) throw StateError('fixture path is required');
  return _decodeVectorFixture(
    Map<String, dynamic>.from(jsonDecode(File(path).readAsStringSync()) as Map),
  );
}

Map<String, dynamic> _decodeVectorFixture(Map<String, dynamic> json) {
  _exactKeys(json, {
    'schema_version',
    'evaluation_mode',
    'authority',
    'vectors',
  });
  final authority = Map<String, dynamic>.from(json['authority'] as Map);
  _exactKeys(authority, {
    'identity_verified',
    'receipt_persisted',
    'execution_authorized',
    'dispatch_performed',
    'audit_published',
  });
  if (authority.values.any((value) => value != false)) {
    throw const FormatException('Session receipt vector authority is enabled.');
  }
  return json;
}

void _exactKeys(Map<String, dynamic> json, Set<String> expected) {
  if (!json.keys.toSet().containsAll(expected) ||
      json.keys.toSet().difference(expected).isNotEmpty) {
    throw const FormatException(
      'Unknown or missing session receipt vector field.',
    );
  }
}
