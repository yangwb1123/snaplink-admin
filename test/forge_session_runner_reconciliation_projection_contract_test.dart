import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/api/forge_session_runner_reconciliation_projection.dart';

void main() {
  final fixturePath = Platform
      .environment['FORGE_SESSION_RUNNER_RECONCILIATION_PROJECTION_FIXTURE'];

  test('round-trips a display-only projection without shared fixtures', () {
    const owner = ForgeDeviceOwner(
      issuer: 'https://id.example',
      subject: 'user-1',
      tenantID: 'tenant-1',
    );
    const source = ForgeSessionRunnerReconciliationProjectionSource(
      schemaVersion: forgeSessionRunnerReconciliationProjectionSourceSchema,
      owner: owner,
      conversationID: 'conversation-001',
      promptID: 'prompt-001',
      runID: 'run-001',
      attemptCount: 1,
      latestAttemptID: 'attempt-001',
      latestCommandID: 'command-001',
      latestTargetID: 'runner-001',
      latestDispositionKind: 'uncertain',
      latestObservedAtMS: 42,
    );
    final projection = ForgeSessionRunnerReconciliationProjection(
      schemaVersion: forgeSessionRunnerReconciliationProjectionSchema,
      evaluationMode: forgeSessionRunnerReconciliationProjectionEvaluationMode,
      owner: owner,
      conversationID: 'conversation-001',
      promptID: 'prompt-001',
      runID: 'run-001',
      source: source,
      latestAttemptID: 'attempt-001',
      latestCommandID: 'command-001',
      latestTargetID: 'runner-001',
      latestDispositionKind: 'uncertain',
      latestObservedAtMS: 42,
      reconciliationKind: 'manual',
      reconciliationReason: 'uncertain_terminal_receipt',
      reconciliationRequired: true,
      manualReviewRequired: true,
      automaticRetry: false,
      followUp: 'reconciliation_manual',
      selectedTargetID: null,
      previewOnly: true,
      authority: const ForgeSessionRunnerReconciliationProjectionAuthority(
        identityVerified: false,
        receiptPersisted: false,
        executionAuthorized: false,
        dispatchPerformed: false,
        auditPublished: false,
      ),
    );

    final decoded = ForgeSessionRunnerReconciliationProjection.fromJsonText(
      jsonEncode(projection.toJson()),
    );

    expect(decoded.isDisplayOnly, isTrue);
    expect(decoded.isFor('conversation-001', 'run-001'), isTrue);
    expect(decoded.toJson(), projection.toJson());
  });

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
