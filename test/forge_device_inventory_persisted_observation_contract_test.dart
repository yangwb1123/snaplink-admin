import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_device_inventory_models.dart';

void main() {
  final fixturePath =
      Platform.environment['FORGE_INVENTORY_PERSISTED_OBSERVATION_FIXTURE'];

  test(
    'consumes the Rust persisted-observation shared inventory envelope',
    () {
      final root = Map<String, dynamic>.from(
        jsonDecode(File(fixturePath!).readAsStringSync()) as Map,
      );
      expect(root.keys.toSet(), {
        'schema_version',
        'evaluation_mode',
        'evaluation_owner',
        'evaluated_at_ms',
        'authority',
        'states',
        'expected',
      });
      expect(
        root['schema_version'],
        'forge.device-inventory-persisted-observation/v1',
      );
      expect(
        root['evaluation_mode'],
        'pure_persisted_inventory_to_observation',
      );
      expect(root['authority'], {
        'identity_verified': false,
        'heartbeat_persisted': false,
        'inventory_authoritative': false,
        'reservation_created': false,
        'execution_authorized': false,
        'dispatch_performed': false,
      });

      final page = ForgeDeviceInventoryPage.fromJson(root['expected']);
      expect(page.evaluationMode, 'offline_static_only');
      expect(page.evaluatedAtMS, root['evaluated_at_ms']);
      expect(page.owner.issuer, 'issuer');
      expect(page.owner.subject, 'user');
      expect(page.owner.tenantID, 'tenant');
      expect(page.devices, hasLength(2));
      expect(page.devices.first.instanceID, 'runner-a');
      expect(page.devices.first.device.deviceID, 'device-a');
      expect(page.devices.first.device.approvalState, 'pending');
      expect(page.devices.first.device.liveness, 'offline');
      expect(page.devices.first.device.availableCPUCores, 7);
      expect(page.devices.first.device.availableMemoryBytes, 8192);
      expect(page.devices.first.device.availableStorageBytes, 51200);
      expect(page.devices.last.instanceID, 'runner-b');
      expect(page.devices.last.device.liveness, 'online');
      expect(page.executionAuthorized, isFalse);
      expect(page.reservationCreated, isFalse);
      expect(page.dispatchPerformed, isFalse);
    },
    skip: fixturePath == null
        ? 'Run through scripts/test-forge-contracts.sh.'
        : false,
  );

  test(
    'rejects a persisted-observation expected envelope authority mutation',
    () {
      final root = Map<String, dynamic>.from(
        jsonDecode(File(fixturePath!).readAsStringSync()) as Map,
      );
      final expected = Map<String, dynamic>.from(root['expected'] as Map);
      expected['execution_authorized'] = true;
      expect(
        () => ForgeDeviceInventoryPage.fromJson(expected),
        throwsFormatException,
      );
    },
    skip: fixturePath == null
        ? 'Run through scripts/test-forge-contracts.sh.'
        : false,
  );
}
