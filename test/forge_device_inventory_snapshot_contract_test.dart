import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/api/forge_device_inventory_snapshot.dart';

void main() {
  final fixturePath =
      Platform.environment['FORGE_INVENTORY_SNAPSHOT_CANONICAL_FIXTURE'];

  test('rejects an invalid programmatic owner declaration', () {
    final snapshot = ForgeDeviceInventorySnapshot(
      snapshotID: 'snapshot-invalid-owner',
      observedAtMS: 200000,
      owner: const ForgeDeviceOwner(
        issuer: 'https://id.example\u0080',
        subject: 'user-1',
        tenantID: 'tenant-1',
      ),
      rows: const [],
    );
    expect(
      () => canonicalizeForgeDeviceInventorySnapshot(snapshot),
      throwsA(
        isA<ForgeDeviceInventorySnapshotError>().having(
          (error) => error.code,
          'code',
          'invalid_owner',
        ),
      ),
    );
  });

  test(
    'canonicalizes the shared owner-scoped inventory snapshot fixture',
    () {
      final fixture = _object(
        jsonDecode(File(fixturePath!).readAsStringSync()),
      );
      _expectExactKeys(fixture, {
        'schema_version',
        'evaluation_mode',
        'owner_declaration_unverified',
        'inventory_declarations_unverified',
        'authority',
        'cases',
      });
      expect(
        fixture['schema_version'],
        'forge.device-inventory-snapshot-canonical/v1',
      );
      expect(fixture['evaluation_mode'], 'pure_owner_scoped_snapshot_only');
      expect(fixture['owner_declaration_unverified'], isTrue);
      expect(fixture['inventory_declarations_unverified'], isTrue);

      final authority = _object(fixture['authority']);
      _expectExactKeys(authority, {
        'identity_verified',
        'heartbeat_persisted',
        'inventory_authoritative',
        'reservation_created',
        'execution_authorized',
        'dispatch_performed',
      });
      for (final value in authority.values) {
        expect(value, isFalse);
      }

      final cases = fixture['cases'];
      if (cases is! List) {
        throw const FormatException('Expected inventory snapshot cases.');
      }
      expect(cases.length, 6);
      for (final rawCase in cases) {
        final testCase = _object(rawCase);
        _expectExactKeys(testCase, {'name', 'input', 'expected'});
        final name = testCase['name'];
        if (name is! String) {
          throw const FormatException('Expected inventory snapshot case name.');
        }
        final expected = _object(testCase['expected']);
        final snapshot = ForgeDeviceInventorySnapshot.fromJson(
          testCase['input'],
        );
        final before = snapshot.rows.toList(growable: false);
        final error = expected['error'];
        if (error != null) {
          _expectExactKeys(expected, {'error'});
          try {
            canonicalizeForgeDeviceInventorySnapshot(snapshot);
            fail('$name unexpectedly succeeded');
          } on ForgeDeviceInventorySnapshotError catch (caught) {
            expect(caught.code, error, reason: name);
          }
          continue;
        }

        _expectExactKeys(expected, {'ordered_keys', 'canonical_sha256'});
        final canonical = canonicalizeForgeDeviceInventorySnapshot(snapshot);
        expect(snapshot.rows, before, reason: '$name mutated input');
        final expectedKeys = expected['ordered_keys'];
        if (expectedKeys is! List) {
          throw const FormatException(
            'Expected ordered inventory snapshot keys.',
          );
        }
        expect(
          canonical.rows
              .map((row) => '${row.deviceID}/${row.instanceID}')
              .toList(),
          expectedKeys,
          reason: name,
        );
        expect(
          digestForgeDeviceInventorySnapshot(snapshot),
          expected['canonical_sha256'],
          reason: name,
        );
      }
    },
    skip: fixturePath == null
        ? 'Run through scripts/test-forge-contracts.sh.'
        : false,
  );
}

Map<String, dynamic> _object(Object? value) {
  if (value is! Map) {
    throw const FormatException('Expected inventory snapshot fixture object.');
  }
  return Map<String, dynamic>.from(value);
}

void _expectExactKeys(Map<String, dynamic> value, Set<String> expected) {
  expect(value.keys.toSet(), expected);
}
