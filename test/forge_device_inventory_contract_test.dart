import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_device_inventory_models.dart';

void main() {
  final fixturePath = Platform.environment['FORGE_INVENTORY_CONTRACT_FIXTURE'];

  test(
    'accepts the offline read-only device inventory observation fixture',
    () {
      final root = jsonDecode(File(fixturePath!).readAsStringSync());
      final page = ForgeDeviceInventoryPage.fromJson(root);

      expect(page.evaluationMode, 'offline_static_only');
      expect(page.evaluatedAtMS, 200000);
      expect(page.owner.tenantID, 'tenant-1');
      expect(page.ownerDeclarationUnverified, isTrue);
      expect(page.inventoryDeclarationsUnverified, isTrue);
      expect(page.executionAuthorized, isFalse);
      expect(page.reservationCreated, isFalse);
      expect(page.dispatchPerformed, isFalse);
      expect(page.devices, hasLength(2));
      expect(page.devices.first.instanceID, 'runner-a');
      expect(page.devices.first.device.deviceID, 'device-a');
      expect(page.devices.first.device.availableCPUCores, 8);
      expect(page.devices.first.device.gpu.present, isFalse);
      expect(page.devices.last.device.approvalState, 'pending');
    },
    skip: fixturePath == null
        ? 'Run through scripts/test-forge-contracts.sh.'
        : false,
  );

  test(
    'rejects authority changes and unknown fields in the observation fixture',
    () {
      final root = Map<String, dynamic>.from(
        jsonDecode(File(fixturePath!).readAsStringSync()) as Map,
      );
      root['execution_authorized'] = true;
      expect(
        () => ForgeDeviceInventoryPage.fromJson(root),
        throwsFormatException,
      );

      root['execution_authorized'] = false;
      root['unexpected'] = true;
      expect(
        () => ForgeDeviceInventoryPage.fromJson(root),
        throwsFormatException,
      );
    },
    skip: fixturePath == null
        ? 'Run through scripts/test-forge-contracts.sh.'
        : false,
  );

  test('rejects C1 control characters in owner declarations', () {
    expect(
      () => ForgeDeviceOwner.fromJson({
        'issuer': 'https://id.example',
        'subject': 'user-${String.fromCharCode(0x85)}',
        'tenant_id': 'tenant-1',
      }),
      throwsFormatException,
    );
  });

  test('rejects isolated UTF-16 surrogates in every owner tuple field', () {
    for (final field in ['issuer', 'subject', 'tenant_id']) {
      for (final surrogate in [0xd800, 0xdfff]) {
        final owner = <String, dynamic>{
          'issuer': 'https://id.example',
          'subject': 'user-1',
          'tenant_id': 'tenant-1',
        };
        owner[field] = 'owner-${String.fromCharCode(surrogate)}';

        expect(
          () => ForgeDeviceOwner.fromJson(owner),
          throwsFormatException,
          reason: '$field contains ${surrogate.toRadixString(16)}',
        );
      }
    }
  });

  test('enforces the owner UTF-8 byte bound for every tuple field', () {
    for (final field in ['issuer', 'subject', 'tenant_id']) {
      final exact = <String, dynamic>{
        'issuer': 'https://id.example',
        'subject': 'user-1',
        'tenant_id': 'tenant-1',
      };
      exact[field] = 'é' * 256;
      expect(
        ForgeDeviceOwner.fromJson(exact),
        isA<ForgeDeviceOwner>(),
        reason: '$field accepts exactly 512 UTF-8 bytes',
      );

      final over = <String, dynamic>{
        'issuer': 'https://id.example',
        'subject': 'user-1',
        'tenant_id': 'tenant-1',
      };
      over[field] = 'é' * 257;
      expect(
        () => ForgeDeviceOwner.fromJson(over),
        throwsFormatException,
        reason: '$field exceeds 512 UTF-8 bytes',
      );
    }
  });

  test(
    'rejects duplicate Runner instance declarations',
    () {
      final root = Map<String, dynamic>.from(
        jsonDecode(File(fixturePath!).readAsStringSync()) as Map,
      );
      final devices = List<Map<String, dynamic>>.from(
        (root['devices'] as List).map(
          (row) => Map<String, dynamic>.from(row as Map),
        ),
      );
      devices[1]['instance_id'] = devices[0]['instance_id'];
      root['devices'] = devices;

      expect(
        () => ForgeDeviceInventoryPage.fromJson(root),
        throwsFormatException,
      );
    },
    skip: fixturePath == null
        ? 'Run through scripts/test-forge-contracts.sh.'
        : false,
  );
}
