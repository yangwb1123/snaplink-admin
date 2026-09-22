import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_runner_dispatch_plan_preview.dart';
import 'package:sso_admin/screens/agent/forge_runner_dispatch_plan_preview_card.dart';

Map<String, dynamic> fixture() => {
  'schema_version': 'forge.runner-dispatch-plan-preview/v1',
  'evaluation_mode': 'pure_dispatch_plan_preview_only',
  'owner_declaration': {
    'issuer': 'https://id.example',
    'subject': 'user-1',
    'tenant_id': 'tenant-1',
  },
  'conversation_id': 'conversation-001',
  'run_id': 'run-001',
  'attempt_id': 'attempt-001',
  'attempt_state': 'accepted',
  'attempt_state_admissible': true,
  'command_id': 'command-001',
  'command_sha256':
      '42ed02a535113450e6f2cc757fb9b4e2cce6143724274191bbae159e9ea8de7a',
  'intent_target_id': 'runner-1',
  'lease_epoch': 1,
  'lease_active': true,
  'evaluated_at_ms': 200500,
  'candidate_count': 2,
  'declarative_ready_count': 1,
  'candidates': [
    {
      'target_id': 'runner-1',
      'attributes_unverified': true,
      'matches_requirements': true,
      'lease_target_match': true,
      'lease_active': true,
      'attempt_state_admissible': true,
      'declarative_ready': true,
      'reasons': [],
    },
    {
      'target_id': 'runner-2',
      'attributes_unverified': true,
      'matches_requirements': true,
      'lease_target_match': false,
      'lease_active': true,
      'attempt_state_admissible': true,
      'declarative_ready': false,
      'reasons': ['lease_target_mismatch'],
    },
  ],
  'selected_target_id': null,
  'preview_only': true,
  'reservation_created': false,
  'execution_authorized': false,
  'dispatch_performed': false,
  'authority': {
    'device_identity_verified': false,
    'attempt_persisted': false,
    'reservation_created': false,
    'execution_authorized': false,
    'dispatch_performed': false,
    'audit_published': false,
  },
};

void main() {
  test('accepts the dispatch-plan fixture as display-only metadata', () {
    final model = ForgeRunnerDispatchPlanPreview.fromJson(fixture());
    expect(model.conversationID, 'conversation-001');
    expect(model.runID, 'run-001');
    expect(model.attemptID, 'attempt-001');
    expect(model.commandSHA256, startsWith('42ed02a5'));
    expect(model.candidateCount, 2);
    expect(model.declarativeReadyCount, 1);
    expect(model.candidates.first.declarativeReady, isTrue);
    expect(model.candidates.last.reasons, ['lease_target_mismatch']);
    expect(model.selectedTargetID, isNull);
    expect(model.isFor('conversation-001', 'run-001'), isTrue);
    expect(model.isDisplayOnly, isTrue);
  });

  test('consumes the canonical cross-language fixture when provided', () {
    final path = Platform.environment['FORGE_RUNNER_DISPATCH_PLAN_FIXTURE'];
    if (path == null || path.isEmpty) return;
    final model = ForgeRunnerDispatchPlanPreview.fromJsonText(
      File(path).readAsStringSync(),
    );
    expect(model.evaluationMode, 'pure_dispatch_plan_preview_only');
    expect(model.candidates.length, model.candidateCount);
    expect(model.declarativeReadyCount, 1);
    expect(model.selectedTargetID, isNull);
    expect(model.authority.values, everyElement(isFalse));
  });

  test(
    'rejects authority, selection, candidate drift, unknown, and duplicate fields',
    () {
      final authority = fixture();
      authority['authority'] = {
        ...(authority['authority'] as Map<String, dynamic>),
        'dispatch_performed': true,
      };
      expect(
        () => ForgeRunnerDispatchPlanPreview.fromJson(authority),
        throwsFormatException,
      );

      final selected = fixture()..['selected_target_id'] = 'runner-1';
      expect(
        () => ForgeRunnerDispatchPlanPreview.fromJson(selected),
        throwsFormatException,
      );

      final candidateDrift = fixture();
      final candidates = (candidateDrift['candidates'] as List)
          .cast<Map<String, dynamic>>();
      candidateDrift['candidates'] = [
        {...candidates.first, 'attributes_unverified': false},
        candidates.last,
      ];
      expect(
        () => ForgeRunnerDispatchPlanPreview.fromJson(candidateDrift),
        throwsFormatException,
      );

      final unknown = fixture()..['unexpected'] = true;
      expect(
        () => ForgeRunnerDispatchPlanPreview.fromJson(unknown),
        throwsFormatException,
      );

      final duplicate = jsonEncode(fixture()).replaceFirst(
        '"run_id":"run-001"',
        '"run_id":"run-001","run_id":"run-002"',
      );
      expect(
        () => ForgeRunnerDispatchPlanPreview.fromJsonText(duplicate),
        throwsFormatException,
      );
    },
  );

  testWidgets('card displays metadata without an action control', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ForgeRunnerDispatchPlanPreviewCard(
          preview: ForgeRunnerDispatchPlanPreview.fromJson(fixture()),
        ),
      ),
    );
    expect(find.textContaining('run-001'), findsOneWidget);
    expect(find.textContaining('attempt-001'), findsOneWidget);
    expect(find.textContaining('epoch 1'), findsOneWidget);
    expect(find.text('Preview only · no dispatch performed'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsNothing);
  });
}
