import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_client_instance_resource_view.dart';
import 'package:sso_admin/api/forge_device_inventory_v2_models.dart';
import 'package:sso_admin/api/forge_device_inventory_resource_convergence.dart';

void main() {
  test('shared inventory/resource fixture is display-only and converged', () {
    final path =
        Platform
            .environment['FORGE_DEVICE_INVENTORY_RESOURCE_CONVERGENCE_FIXTURE'] ??
        'docs/contracts/fixtures/forge-device-inventory-resource-convergence-v1.json';
    final convergence = ForgeDeviceInventoryResourceConvergence.fromJsonText(
      File(path).readAsStringSync(),
    );

    expect(convergence.isDisplayOnly, isTrue);
    expect(convergence.inventory.devices, hasLength(1));
    expect(convergence.resourceView.devices, hasLength(1));
    expect(
      convergence.inventory.devices.single.instanceID,
      convergence.resourceView.devices.single.runnerInstanceID,
    );
    expect(
      convergence.inventory.devices.single.heartbeatSequence,
      convergence.resourceView.devices.single.heartbeatSequence,
    );
    expect(
      forgeDeviceInventoryAndResourceObservationsConverged(
        convergence.inventory,
        convergence.resourceView,
      ),
      isTrue,
    );
  });

  test('separate inventory/resource observations fail closed on drift', () {
    final convergence = ForgeDeviceInventoryResourceConvergence.fromJsonText(
      File(
        'docs/contracts/fixtures/forge-device-inventory-resource-convergence-v1.json',
      ).readAsStringSync(),
    );
    final drifted = convergence.resourceView.toJson();
    final devices = List<Map<String, dynamic>>.from(
      (drifted['devices'] as List).map(
        (value) => Map<String, dynamic>.from(value as Map),
      ),
    );
    devices.single['observed_at_ms'] =
        (devices.single['observed_at_ms'] as int) + 1;
    drifted['devices'] = devices;

    expect(
      forgeDeviceInventoryAndResourceObservationsConverged(
        convergence.inventory,
        ForgeClientInstanceResourceView.fromJson(drifted),
      ),
      isFalse,
    );
  });

  test('manually constructed inventory with a changed envelope fails closed', () {
    final convergence = ForgeDeviceInventoryResourceConvergence.fromJsonText(
      File(
        'docs/contracts/fixtures/forge-device-inventory-resource-convergence-v1.json',
      ).readAsStringSync(),
    );
    final inventory = convergence.inventory;
    final tampered = ForgeDeviceInventoryPageV2(
      evaluationMode: 'not-display-only',
      evaluatedAtMS: inventory.evaluatedAtMS,
      owner: inventory.owner,
      ownerDeclarationUnverified: inventory.ownerDeclarationUnverified,
      inventoryDeclarationsUnverified:
          inventory.inventoryDeclarationsUnverified,
      notice: inventory.notice,
      devices: inventory.devices,
      executionAuthorized: inventory.executionAuthorized,
      reservationCreated: inventory.reservationCreated,
      dispatchPerformed: inventory.dispatchPerformed,
    );

    expect(
      forgeDeviceInventoryAndResourceObservationsConverged(
        tampered,
        convergence.resourceView,
      ),
      isFalse,
    );
    final tamperedConvergence = ForgeDeviceInventoryResourceConvergence(
      schemaVersion: convergence.schemaVersion,
      evaluationMode: convergence.evaluationMode,
      owner: convergence.owner,
      inventory: tampered,
      resourceView: convergence.resourceView,
      converged: true,
      readOnly: true,
      authority: convergence.authority,
    );
    expect(tamperedConvergence.isDisplayOnly, isFalse);
  });
}
