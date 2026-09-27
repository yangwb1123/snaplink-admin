import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_session_runner_reconciliation_projection.dart';

void main() {
  final fixturePath = Platform
      .environment['FORGE_SESSION_RUNNER_RECONCILIATION_PROJECTION_FIXTURE'];

  test(
    'consumes a display-only uncertain terminal reconciliation projection',
    () {
      final projection = ForgeSessionRunnerReconciliationProjection.fromJson(
        _fixture(),
      );

      expect(projection.isDisplayOnly, isTrue);
      expect(projection.isFor('conversation-001', 'run-001'), isTrue);
      expect(projection.source.attemptCount, 2);
      expect(projection.latestAttemptID, 'attempt-002');
      expect(projection.latestCommandID, 'command-002');
      expect(projection.latestTargetID, 'runner-2');
      expect(projection.latestDispositionKind, 'uncertain');
      expect(projection.reconciliationKind, 'manual');
      expect(projection.reconciliationReason, 'uncertain_terminal_receipt');
      expect(projection.reconciliationRequired, isTrue);
      expect(projection.manualReviewRequired, isTrue);
      expect(projection.automaticRetry, isFalse);
      expect(projection.selectedTargetID, isNull);
      expect(projection.authority.isOffline, isTrue);
    },
    skip: fixturePath == null
        ? 'Run through scripts/test-forge-contracts.sh.'
        : false,
  );

  test(
    'rejects unknown, duplicate, trailing, binding, and authority drift',
    () {
      final source = File(fixturePath!).readAsStringSync();
      expect(
        () => ForgeSessionRunnerReconciliationProjection.fromJsonText(
          '$source {}',
        ),
        throwsFormatException,
      );
      expect(
        () => ForgeSessionRunnerReconciliationProjection.fromJsonText(
          source.replaceFirst(
            '"evaluation_mode": "pure_session_runner_reconciliation_projection_only",',
            '"evaluation_mode": "pure_session_runner_reconciliation_projection_only", "evaluation_mode": "pure_session_runner_reconciliation_projection_only",',
          ),
        ),
        throwsFormatException,
      );

      final unknown = _fixture()..['unexpected'] = true;
      expect(
        () => ForgeSessionRunnerReconciliationProjection.fromJson(unknown),
        throwsFormatException,
      );

      final sourceDrift = _fixture();
      final sourceSummary = Map<String, dynamic>.from(
        sourceDrift['source'] as Map,
      )..['latest_command_id'] = 'command-drift';
      sourceDrift['source'] = sourceSummary;
      expect(
        () => ForgeSessionRunnerReconciliationProjection.fromJson(sourceDrift),
        throwsFormatException,
      );

      final sourceSchemaType = _fixture();
      sourceSchemaType['source'] = Map<String, dynamic>.from(
        sourceSchemaType['source'] as Map,
      )..['schema_version'] = 7;
      expect(
        () => ForgeSessionRunnerReconciliationProjection.fromJson(
          sourceSchemaType,
        ),
        throwsFormatException,
      );

      final authority = _fixture();
      final authorityJSON = Map<String, dynamic>.from(
        authority['authority'] as Map,
      )..['dispatch_performed'] = true;
      authority['authority'] = authorityJSON;
      expect(
        () => ForgeSessionRunnerReconciliationProjection.fromJson(authority),
        throwsFormatException,
      );

      final selection = _fixture()..['selected_target_id'] = 'runner-3';
      expect(
        () => ForgeSessionRunnerReconciliationProjection.fromJson(selection),
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
  final path = Platform
      .environment['FORGE_SESSION_RUNNER_RECONCILIATION_PROJECTION_FIXTURE'];
  if (path == null) throw StateError('fixture path is required');
  return path;
}
