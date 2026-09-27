import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_session_runner_receipt_history.dart';

void main() {
  final fixturePath =
      Platform.environment['FORGE_SESSION_RUNNER_RECEIPT_HISTORY_FIXTURE'];

  test(
    'consumes a bounded ordered failed to uncertain receipt history',
    () {
      final raw = _fixture();
      final history = ForgeSessionRunnerReceiptHistory.fromJson(raw);

      expect(history.isDisplayOnly, isTrue);
      expect(history.isFor('conversation-001', 'run-001'), isTrue);
      expect(history.receipts, hasLength(2));
      expect(
        history.receipts.map(
          (receipt) => receipt.receiptObservation.dispositionKind,
        ),
        ['failed', 'uncertain'],
      );
      expect(history.attemptCount, 2);
      expect(history.latestAttemptID, 'attempt-002');
      expect(history.latestCommandID, 'command-002');
      expect(history.latestTargetID, 'runner-2');
      expect(history.latestDispositionKind, 'uncertain');
      expect(history.reconciliationRequired, isTrue);
      expect(history.manualReviewRequired, isTrue);
      expect(history.automaticRetry, isFalse);
      expect(history.selectedTargetID, isNull);
      expect(history.authority.isOffline, isTrue);
      expect(
        history.receipts.last.receiptObservation.observedAtMS,
        greaterThan(history.receipts.first.receiptObservation.observedAtMS),
      );
    },
    skip: fixturePath == null
        ? 'Run through scripts/test-forge-contracts.sh.'
        : false,
  );

  test(
    'rejects unknown, duplicate, trailing, and authority-bearing history',
    () {
      final source = File(fixturePath!).readAsStringSync();
      expect(
        () => ForgeSessionRunnerReceiptHistory.fromJsonText('$source {}'),
        throwsFormatException,
      );
      expect(
        () => ForgeSessionRunnerReceiptHistory.fromJsonText(
          source.replaceFirst(
            '"evaluation_mode": "pure_session_runner_receipt_history_only",',
            '"evaluation_mode": "pure_session_runner_receipt_history_only", "evaluation_mode": "pure_session_runner_receipt_history_only",',
          ),
        ),
        throwsFormatException,
      );

      final unknown = _fixture()..['unexpected'] = true;
      expect(
        () => ForgeSessionRunnerReceiptHistory.fromJson(unknown),
        throwsFormatException,
      );

      final authority = _fixture();
      final authorityJSON = Map<String, dynamic>.from(
        authority['authority'] as Map,
      )..['execution_authorized'] = true;
      authority['authority'] = authorityJSON;
      expect(
        () => ForgeSessionRunnerReceiptHistory.fromJson(authority),
        throwsFormatException,
      );
    },
    skip: fixturePath == null
        ? 'Run through scripts/test-forge-contracts.sh.'
        : false,
  );

  test(
    'rejects broken owner binding, ordering, uncertain transition, and summary',
    () {
      final foreignOwner = _fixture();
      final foreignReceipts = List<dynamic>.from(
        foreignOwner['receipts'] as List,
      );
      final foreignReceipt = Map<String, dynamic>.from(
        foreignReceipts.first as Map,
      );
      foreignReceipt['owner'] = {
        'issuer': 'https://other.example',
        'subject': 'user-1',
        'tenant_id': 'tenant-1',
      };
      foreignReceipts[0] = foreignReceipt;
      foreignOwner['receipts'] = foreignReceipts;
      expect(
        () => ForgeSessionRunnerReceiptHistory.fromJson(foreignOwner),
        throwsFormatException,
      );

      final outOfOrder = _fixture();
      final outOfOrderReceipts = List<dynamic>.from(
        outOfOrder['receipts'] as List,
      );
      final second = Map<String, dynamic>.from(outOfOrderReceipts[1] as Map);
      second['receipt_observation'] = Map<String, dynamic>.from(
        second['receipt_observation'] as Map,
      )..['observed_at_ms'] = 50;
      outOfOrderReceipts[1] = second;
      outOfOrder['receipts'] = outOfOrderReceipts;
      expect(
        () => ForgeSessionRunnerReceiptHistory.fromJson(outOfOrder),
        throwsFormatException,
      );

      final uncertainFirst = _fixture();
      final uncertainReceipts = List<dynamic>.from(
        uncertainFirst['receipts'] as List,
      );
      final first = Map<String, dynamic>.from(uncertainReceipts.first as Map);
      first['receipt_observation'] =
          Map<String, dynamic>.from(first['receipt_observation'] as Map)
            ..['disposition_kind'] = 'uncertain'
            ..['uncertain'] = true
            ..['reconciliation_required'] = true
            ..['manual_review_required'] = true
            ..['follow_up'] = 'reconciliation_manual';
      uncertainReceipts[0] = first;
      uncertainFirst['receipts'] = uncertainReceipts;
      expect(
        () => ForgeSessionRunnerReceiptHistory.fromJson(uncertainFirst),
        throwsFormatException,
      );

      final completedFirst = _fixture();
      final completedReceipts = List<dynamic>.from(
        completedFirst['receipts'] as List,
      );
      final completed = Map<String, dynamic>.from(
        completedReceipts.first as Map,
      );
      completed['receipt_observation'] = Map<String, dynamic>.from(
        completed['receipt_observation'] as Map,
      )..['disposition_kind'] = 'completed';
      completedReceipts[0] = completed;
      completedFirst['receipts'] = completedReceipts;
      expect(
        () => ForgeSessionRunnerReceiptHistory.fromJson(completedFirst),
        throwsFormatException,
      );

      final summary = _fixture()..['latest_command_id'] = 'command-drift';
      expect(
        () => ForgeSessionRunnerReceiptHistory.fromJson(summary),
        throwsFormatException,
      );
    },
    skip: fixturePath == null
        ? 'Run through scripts/test-forge-contracts.sh.'
        : false,
  );
}

Map<String, dynamic> _fixture() {
  final path = fixturePathOrThrow();
  return Map<String, dynamic>.from(
    jsonDecode(File(path).readAsStringSync()) as Map,
  );
}

String fixturePathOrThrow() {
  final path =
      Platform.environment['FORGE_SESSION_RUNNER_RECEIPT_HISTORY_FIXTURE'];
  if (path == null) throw StateError('fixture path is required');
  return path;
}
