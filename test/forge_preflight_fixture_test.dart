import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_preflight_fixture.dart';
import 'package:sso_admin/screens/agent/forge_preflight_fixture_card.dart';

Map<String, dynamic> fixture() => {
  'schema_version': 'forge.run-attempt-lease-dispatch-preflight/v1',
  'evaluation_mode': 'pure_run_attempt_lease_dispatch_preflight',
  'owner': {
    'issuer': 'https://id.example',
    'subject': 'user-1',
    'tenant_id': 'tenant-1',
  },
  'conversation_id': 'conversation-001',
  'run_id': 'run-001',
  'run_status': 'nonterminal',
  'run_state_admissible': true,
  'attempt_id': 'attempt-001',
  'attempt_state': 'accepted',
  'attempt_state_admissible': true,
  'command_id': 'command-001',
  'intent_target_id': 'runner-1',
  'lease_epoch': 1,
  'lease_active': true,
  'evaluated_at_ms': 200500,
  'candidate_count': 2,
  'declarative_ready_count': 1,
  'declarative_preflight_ready': true,
  'rejection_reasons': [],
  'selected_target_id': null,
  'preview_only': true,
  'authority': {
    'identity_verified': false,
    'run_authoritative': false,
    'attempt_persisted': false,
    'lease_issued': false,
    'reservation_created': false,
    'execution_authorized': false,
    'dispatch_performed': false,
    'audit_published': false,
  },
};

void main() {
  test(
    'accepts the contract fixture and exposes run, attempt, lease metadata',
    () {
      final model = ForgePreflightFixture.fromJson(fixture());
      expect(model.runId, 'run-001');
      expect(model.attemptId, 'attempt-001');
      expect(model.leaseEpoch, 1);
      expect(model.selectedTargetId, isNull);
      expect(model.authority.values, everyElement(isFalse));
    },
  );

  test('consumes the canonical cross-language fixture', () {
    final path = Platform
        .environment['FORGE_RUN_ATTEMPT_LEASE_DISPATCH_PREFLIGHT_FIXTURE'];
    if (path == null || path.isEmpty) return;
    final model = ForgePreflightFixture.fromJsonText(
      File(path).readAsStringSync(),
    );
    expect(model.evaluationMode, ForgePreflightFixture.expectedEvaluationMode);
    expect(model.declarativePreflightReady, isTrue);
    expect(model.selectedTargetId, isNull);
    expect(model.authority.values, everyElement(isFalse));
  });

  test(
    'rejects unknown fields, duplicate keys, authority, and selected target',
    () {
      final unknown = fixture()..['unexpected'] = true;
      expect(
        () => ForgePreflightFixture.fromJson(unknown),
        throwsFormatException,
      );
      final authority = fixture()
        ..['authority'] = {
          ...fixture()['authority'] as Map,
          'dispatch_performed': true,
        };
      expect(
        () => ForgePreflightFixture.fromJson(authority),
        throwsFormatException,
      );
      final selected = fixture()..['selected_target_id'] = 'runner-1';
      expect(
        () => ForgePreflightFixture.fromJson(selected),
        throwsFormatException,
      );
      final text = jsonEncode(fixture()).replaceFirst(
        '"run_id":"run-001"',
        '"run_id":"run-001","run_id":"run-002"',
      );
      expect(
        () => ForgePreflightFixture.fromJsonText(text),
        throwsFormatException,
      );
    },
  );

  testWidgets('card displays preview metadata without an action control', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ForgePreflightFixtureCard(
          fixture: ForgePreflightFixture.fromJson(fixture()),
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
