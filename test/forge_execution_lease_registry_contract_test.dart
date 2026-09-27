import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_scheduler_selection_lease.dart';

void main() {
  final fixturePath =
      Platform.environment['FORGE_EXECUTION_LEASE_REGISTRY_FIXTURE'];

  test(
    'consumes the shared strict scheduler lease receipt fixture',
    () {
      final path = fixturePath;
      if (path == null || path.isEmpty) return;
      final lease = ForgeSchedulerSelectionLease.fromJsonText(
        File(path).readAsStringSync(),
      );
      expect(lease.schemaVersion, ForgeSchedulerSelectionLease.schema);
      expect(lease.mode, ForgeSchedulerSelectionLease.evaluationMode);
      expect(lease.owner.tenantID, 'tenant-a');
      expect(lease.deviceID, 'device-a');
      expect(lease.instanceID, 'runner-a');
      expect(lease.grant.epoch, 1);
      expect(lease.authority.placementSelected, isTrue);
      expect(lease.authority.executionAuthorized, isFalse);
      expect(lease.isFor('conversation-1', 'run-1', 'attempt-1'), isTrue);
    },
    skip: fixturePath == null || fixturePath.isEmpty
        ? 'Run through scripts/test-forge-contracts.sh.'
        : false,
  );

  test('rejects unknown, duplicate, binding, and authority mutations', () {
    final canonical = jsonEncode(_lease());
    final unknown = _lease()..['unexpected'] = true;
    expect(
      () => ForgeSchedulerSelectionLease.fromJson(unknown),
      throwsA(isA<FormatException>()),
    );

    final duplicate = canonical.replaceFirst(
      '"schema_version":"${ForgeSchedulerSelectionLease.schema}",',
      '"schema_version":"${ForgeSchedulerSelectionLease.schema}",'
          '"schema_version":"${ForgeSchedulerSelectionLease.schema}",',
    );
    expect(
      () => ForgeSchedulerSelectionLease.fromJsonText(duplicate),
      throwsA(isA<FormatException>()),
    );

    final binding = _lease();
    (binding['grant'] as Map<String, dynamic>)['target_id'] = 'runner-b';
    expect(
      () => ForgeSchedulerSelectionLease.fromJson(binding),
      throwsA(isA<FormatException>()),
    );

    final authority = _lease();
    (authority['authority'] as Map<String, dynamic>)['dispatch_performed'] =
        true;
    expect(
      () => ForgeSchedulerSelectionLease.fromJson(authority),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects trailing JSON', () {
    expect(
      () => ForgeSchedulerSelectionLease.fromJsonText(
        '${jsonEncode(_lease())} true',
      ),
      throwsA(isA<FormatException>()),
    );
  });
}

Map<String, dynamic> _lease() => {
  'schema_version': ForgeSchedulerSelectionLease.schema,
  'evaluation_mode': ForgeSchedulerSelectionLease.evaluationMode,
  'owner': {
    'issuer': 'https://id.example',
    'subject': 'user-a',
    'tenant_id': 'tenant-a',
  },
  'conversation_id': 'conversation-1',
  'run_id': 'run-1',
  'attempt_id': 'attempt-1',
  'device_id': 'device-a',
  'instance_id': 'runner-a',
  'inventory_revision': 7,
  'generation': 3,
  'heartbeat_sequence': 12,
  'grant': {
    'v': 1,
    'attempt_id': 'attempt-1',
    'target_id': 'runner-a',
    'epoch': 1,
    'fencing_token': 'fence-token-a',
    'issued_at_ms': 1800000000000,
    'expires_at_ms': 1800000030000,
  },
  'replayed': false,
  'authority': {
    'placement_selected': true,
    'reservation_created': true,
    'lease_issued': true,
    'execution_authorized': false,
    'dispatch_performed': false,
    'audit_published': false,
  },
};
