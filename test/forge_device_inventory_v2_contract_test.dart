import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_device_inventory_v2_models.dart';

void main() {
  final fixturePath = Platform.environment['FORGE_INVENTORY_V2_FIXTURE'];

  test(
    'consumes the lossless v2 inventory observation fixture',
    () {
      final root = Map<String, dynamic>.from(
        jsonDecode(File(fixturePath!).readAsStringSync()) as Map,
      );
      final page = ForgeDeviceInventoryPageV2.fromJson(root);
      expect(page.evaluationMode, forgeDeviceInventoryV2EvaluationMode);
      expect(page.evaluatedAtMS, 200000);
      expect(page.devices, hasLength(2));
      expect(page.devices.first.revision, 1);
      expect(page.devices.first.generation, 1);
      expect(page.devices.first.heartbeatSequence, 1);
      expect(page.devices.first.device.reservationState, 'reserved');
      expect(page.devices.first.device.gpus, hasLength(2));
      expect(page.devices.first.device.gpus.first.id, 'gpu-a');
      expect(page.devices.first.device.gpus.last.id, 'gpu-b');
      expect(page.devices.last.revision, 2);
      expect(page.devices.last.generation, 2);
      expect(page.devices.last.heartbeatSequence, 4);
      expect(page.devices.last.device.reservationState, 'none');
      expect(page.devices.last.device.gpus, isEmpty);
      expect(page.executionAuthorized, isFalse);
      expect(page.reservationCreated, isFalse);
      expect(page.dispatchPerformed, isFalse);
      expect(page.toJson(), root);
    },
    skip: fixturePath == null
        ? 'Run through scripts/test-forge-contracts.sh.'
        : false,
  );

  test(
    'raw v2 inventory decoding rejects duplicate keys before map conversion',
    () {
      final source = File(fixturePath!).readAsStringSync();
      final duplicateRoot = source.replaceFirst(
        '  "schema_version": "forge.device-inventory-observation/v2",',
        '  "schema_version": "forge.device-inventory-observation/v2",\n'
            '  "schema_version": "forge.device-inventory-observation/v2",',
      );
      expect(duplicateRoot, isNot(source));
      expect(
        () => ForgeDeviceInventoryPageV2.fromJsonText(duplicateRoot),
        throwsFormatException,
      );

      final duplicateNested = source.replaceFirst(
        '          "issuer": "issuer",\n'
            '          "subject": "user",',
        '          "issuer": "issuer",\n'
            '          "issuer": "issuer",\n'
            '          "subject": "user",',
      );
      expect(duplicateNested, isNot(source));
      expect(
        () => ForgeDeviceInventoryPageV2.fromJsonText(duplicateNested),
        throwsFormatException,
      );

      expect(
        ForgeDeviceInventoryPageV2.fromJsonText(source).toJson(),
        jsonDecode(source),
      );
    },
    skip: fixturePath == null
        ? 'Run through scripts/test-forge-contracts.sh.'
        : false,
  );

  test(
    'rejects authority, reservation, and GPU ordering mutations',
    () {
      final root = Map<String, dynamic>.from(
        jsonDecode(File(fixturePath!).readAsStringSync()) as Map,
      );
      final authority = Map<String, dynamic>.from(root)
        ..['execution_authorized'] = true;
      expect(
        () => ForgeDeviceInventoryPageV2.fromJson(authority),
        throwsFormatException,
      );

      final reservation = Map<String, dynamic>.from(root);
      final rows = (reservation['devices'] as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      final first = Map<String, dynamic>.from(rows.first['device'] as Map)
        ..['reservation_state'] = 'unknown';
      rows[0] = {...rows.first, 'device': first};
      reservation['devices'] = rows;
      expect(
        () => ForgeDeviceInventoryPageV2.fromJson(reservation),
        throwsFormatException,
      );

      final gpuOrder = Map<String, dynamic>.from(root);
      final gpuRows = (gpuOrder['devices'] as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      final originalGPUList =
          Map<String, dynamic>.from(gpuRows.first['device'] as Map)['gpus']
              as List;
      final gpuDevice = Map<String, dynamic>.from(
        gpuRows.first['device'] as Map,
      )..['gpus'] = originalGPUList.reversed.toList();
      gpuRows[0] = {...gpuRows.first, 'device': gpuDevice};
      gpuOrder['devices'] = gpuRows;
      expect(
        () => ForgeDeviceInventoryPageV2.fromJson(gpuOrder),
        throwsFormatException,
      );

      final zeroMemory = Map<String, dynamic>.from(root);
      final zeroRows = (zeroMemory['devices'] as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      final zeroDevice = Map<String, dynamic>.from(
        zeroRows.first['device'] as Map,
      );
      final zeroGPU = Map<String, dynamic>.from(
        (zeroDevice['gpus'] as List).first as Map,
      )..['memory_bytes'] = 0;
      zeroDevice['gpus'] = [zeroGPU, ...(zeroDevice['gpus'] as List).skip(1)];
      zeroRows[0] = {...zeroRows.first, 'device': zeroDevice};
      zeroMemory['devices'] = zeroRows;
      expect(
        () => ForgeDeviceInventoryPageV2.fromJson(zeroMemory),
        throwsFormatException,
      );

      final cpuLimit = Map<String, dynamic>.from(root);
      final cpuRows = (cpuLimit['devices'] as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      final cpuDevice = Map<String, dynamic>.from(
        cpuRows.first['device'] as Map,
      )..['available_cpu_cores'] = 4097;
      cpuRows[0] = {...cpuRows.first, 'device': cpuDevice};
      cpuLimit['devices'] = cpuRows;
      expect(
        () => ForgeDeviceInventoryPageV2.fromJson(cpuLimit),
        throwsFormatException,
      );

      final leaseOrder = Map<String, dynamic>.from(root);
      final leaseRows = (leaseOrder['devices'] as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      final leaseDevice = Map<String, dynamic>.from(
        leaseRows.first['device'] as Map,
      )..['lease_expires_at_ms'] = 99999;
      leaseRows[0] = {...leaseRows.first, 'device': leaseDevice};
      leaseOrder['devices'] = leaseRows;
      expect(
        () => ForgeDeviceInventoryPageV2.fromJson(leaseOrder),
        throwsFormatException,
      );

      final belowMinimumLease = Map<String, dynamic>.from(root);
      final belowMinimumRows = (belowMinimumLease['devices'] as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      final belowMinimumDevice = Map<String, dynamic>.from(
        belowMinimumRows.first['device'] as Map,
      );
      final belowMinimumObservedAt =
          belowMinimumDevice['snapshot_observed_at_ms'] as int;
      belowMinimumDevice['lease_expires_at_ms'] = belowMinimumObservedAt + 999;
      belowMinimumRows[0] = {
        ...belowMinimumRows.first,
        'device': belowMinimumDevice,
      };
      belowMinimumLease['devices'] = belowMinimumRows;
      expect(
        () => ForgeDeviceInventoryPageV2.fromJson(belowMinimumLease),
        throwsFormatException,
      );

      final aboveMaximumLease = Map<String, dynamic>.from(root);
      final aboveMaximumRows = (aboveMaximumLease['devices'] as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      final aboveMaximumDevice = Map<String, dynamic>.from(
        aboveMaximumRows.first['device'] as Map,
      );
      final aboveMaximumObservedAt =
          aboveMaximumDevice['snapshot_observed_at_ms'] as int;
      aboveMaximumDevice['lease_expires_at_ms'] =
          aboveMaximumObservedAt + 600001;
      aboveMaximumRows[0] = {
        ...aboveMaximumRows.first,
        'device': aboveMaximumDevice,
      };
      aboveMaximumLease['devices'] = aboveMaximumRows;
      expect(
        () => ForgeDeviceInventoryPageV2.fromJson(aboveMaximumLease),
        throwsFormatException,
      );

      final minimumLease = Map<String, dynamic>.from(root);
      final minimumRows = (minimumLease['devices'] as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      final minimumDevice = Map<String, dynamic>.from(
        minimumRows.first['device'] as Map,
      );
      minimumDevice['lease_expires_at_ms'] =
          (minimumDevice['snapshot_observed_at_ms'] as int) + 1000;
      minimumRows[0] = {...minimumRows.first, 'device': minimumDevice};
      minimumLease['devices'] = minimumRows;
      expect(
        () => ForgeDeviceInventoryPageV2.fromJson(minimumLease),
        returnsNormally,
      );

      final maximumLease = Map<String, dynamic>.from(root);
      final maximumRows = (maximumLease['devices'] as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      final maximumDevice = Map<String, dynamic>.from(
        maximumRows.first['device'] as Map,
      );
      maximumDevice['lease_expires_at_ms'] =
          (maximumDevice['snapshot_observed_at_ms'] as int) + 600000;
      maximumRows[0] = {...maximumRows.first, 'device': maximumDevice};
      maximumLease['devices'] = maximumRows;
      expect(
        () => ForgeDeviceInventoryPageV2.fromJson(maximumLease),
        returnsNormally,
      );

      final runtimePunctuation = Map<String, dynamic>.from(root);
      final runtimeRows = (runtimePunctuation['devices'] as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      final runtimeDevice = Map<String, dynamic>.from(
        runtimeRows.first['device'] as Map,
      )..['runtimes'] = ['oci/container'];
      runtimeRows[0] = {...runtimeRows.first, 'device': runtimeDevice};
      runtimePunctuation['devices'] = runtimeRows;
      expect(
        () => ForgeDeviceInventoryPageV2.fromJson(runtimePunctuation),
        throwsFormatException,
      );

      final overlongRuntime = Map<String, dynamic>.from(root);
      final overlongRows = (overlongRuntime['devices'] as List)
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      final overlongDevice = Map<String, dynamic>.from(
        overlongRows.first['device'] as Map,
      )..['runtimes'] = [List.filled(65, 'r').join()];
      overlongRows[0] = {...overlongRows.first, 'device': overlongDevice};
      overlongRuntime['devices'] = overlongRows;
      expect(
        () => ForgeDeviceInventoryPageV2.fromJson(overlongRuntime),
        throwsFormatException,
      );
    },
    skip: fixturePath == null
        ? 'Run through scripts/test-forge-contracts.sh.'
        : false,
  );
}
