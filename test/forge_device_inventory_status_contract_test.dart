import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_device_inventory_status.dart';

void main() {
  final fixturePath =
      Platform.environment['FORGE_INVENTORY_STATUS_CONTRACT_FIXTURE'];

  test(
    'consumes the shared pure inventory status projection fixture',
    () {
      final fixture = _object(
        jsonDecode(File(fixturePath!).readAsStringSync()),
      );
      _expectExactKeys(fixture, {
        'schema_version',
        'evaluation_mode',
        'stale_after_ms',
        'authority',
        'cases',
      });
      expect(
        fixture['schema_version'],
        'forge.device-inventory-status-contract/v1',
      );
      expect(fixture['evaluation_mode'], 'pure_projection_only');
      final staleAfterMS = _integer(fixture['stale_after_ms']);
      expect(staleAfterMS, forgeDeviceInventoryDefaultStaleAfterMS);

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
        throw const FormatException('Expected inventory status cases.');
      }
      expect(cases.length, 11);
      for (final rawCase in cases) {
        final testCase = _object(rawCase);
        _expectExactKeys(testCase, {'name', 'input', 'expected'});
        final name = testCase['name'];
        if (name is! String) {
          throw const FormatException('Expected inventory status case name.');
        }
        final expected = _object(testCase['expected']);
        final observation = ForgeDeviceInventoryStatusObservation.fromJson(
          testCase['input'],
        );
        final error = expected['error'];
        if (error != null) {
          _expectExactKeys(expected, {'error'});
          expect(
            () => projectForgeDeviceInventoryStatus(
              observation,
              staleAfterMS: staleAfterMS,
            ),
            throwsA(
              isA<ForgeDeviceInventoryStatusError>().having(
                (value) => value.code,
                'code',
                error,
              ),
            ),
            reason: name,
          );
          continue;
        }
        _expectExactKeys(expected, {'status', 'fresh', 'declared_eligible'});
        final projection = projectForgeDeviceInventoryStatus(
          observation,
          staleAfterMS: staleAfterMS,
        );
        expect(projection.status, expected['status'], reason: name);
        expect(projection.fresh, expected['fresh'], reason: name);
        expect(
          projection.declaredEligible,
          expected['declared_eligible'],
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
    throw const FormatException('Expected inventory status fixture object.');
  }
  return Map<String, dynamic>.from(value);
}

void _expectExactKeys(Map<String, dynamic> value, Set<String> expected) {
  expect(value.keys.toSet(), expected);
}

int _integer(Object? value) {
  if (value is! int) {
    throw const FormatException('Expected inventory status fixture integer.');
  }
  return value;
}
