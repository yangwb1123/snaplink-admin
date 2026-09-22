import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_device_inventory_models.dart';
import 'package:sso_admin/api/forge_session_placement.dart';
import 'package:sso_admin/screens/forge/forge_device_inventory_panel.dart';

void main() {
  final inventoryPath =
      Platform.environment['FORGE_INVENTORY_CONTRACT_FIXTURE'];
  final snapshotPath =
      Platform.environment['FORGE_INVENTORY_SNAPSHOT_CANONICAL_FIXTURE'];

  testWidgets(
    'renders read-only inventory, status, snapshot, and dry-run values',
    (tester) async {
      final page = ForgeDeviceInventoryPage.fromJson(
        jsonDecode(File(inventoryPath!).readAsStringSync()),
      );
      final snapshotFixture =
          jsonDecode(File(snapshotPath!).readAsStringSync()) as Map;
      final firstCase = (snapshotFixture['cases'] as List).first as Map;
      final snapshot = ForgeDeviceInventorySnapshot.fromJson(
        (firstCase['input'] as Map).cast<String, dynamic>(),
      );
      final requirements = const ForgeDevicePlacementRequirements(
        os: 'linux',
        architecture: 'amd64',
        minCPUCores: 4,
        minMemoryBytes: 8192,
        minStorageBytes: 4096,
        runtime: 'oci',
        gpu: ForgeDevicePlacementGpuRequirement(
          required: false,
          minMemoryBytes: 0,
          runtime: '',
        ),
        dataResidencyZones: ['us-west'],
        minimumTrustZone: 'standard',
        sandboxFloor: 'container',
        concurrencySlots: 1,
      );
      final placement = dryRunForgeDevicePlacement(
        ForgeDevicePlacementRequest(
          schemaVersion: forgeDevicePlacementRequestSchema,
          evaluatedAtMS: page.evaluatedAtMS,
          owner: page.owner,
          maxSnapshotAgeMS: 90000,
          requirements: requirements,
          devices: page.devices.map((candidate) => candidate.device).toList(),
        ),
      );
      final status = projectForgeDeviceInventoryStatus(
        const ForgeDeviceInventoryStatusObservation(
          approvalState: 'approved',
          cordonState: 'clear',
          liveness: 'online',
          reservationState: 'none',
          snapshotObservedAtMS: 150000,
          leaseExpiresAtMS: 210000,
          evaluatedAtMS: 200000,
        ),
      );
      final pendingStatus = projectForgeDeviceInventoryStatus(
        const ForgeDeviceInventoryStatusObservation(
          approvalState: 'pending',
          cordonState: 'clear',
          liveness: 'online',
          reservationState: 'none',
          snapshotObservedAtMS: 150000,
          leaseExpiresAtMS: 210000,
          evaluatedAtMS: 200000,
        ),
      );

      const resourceSummary = ForgeDeviceResourceSummary(
        schemaVersion: forgeDeviceResourceSummarySchema,
        evaluationMode: forgeDeviceResourceSummaryEvaluationMode,
        owner: ForgeDeviceOwner(
          issuer: 'https://id.example',
          subject: 'user-1',
          tenantID: 'tenant-1',
        ),
        conversationID: 'conversation-001',
        runID: 'run-001',
        evaluatedAtMS: 200000,
        ownerDeclarationUnverified: true,
        inventoryDeclarationsUnverified: true,
        placementDeclarationUnverified: true,
        notice: forgeDeviceResourceSummaryNotice,
        deviceCount: 2,
        runnerInstanceCount: 2,
        availableCPUCores: 16,
        availableMemoryBytes: 32768,
        availableStorageBytes: 16384,
        availableGPUCount: 1,
        availableGPUMemoryBytes: 4096,
        eligibleDeviceCount: 1,
        eligibleInstanceCount: 1,
        selectedDeviceID: null,
        selectedInstanceID: null,
        authority: ForgeSessionPlacementAuthority.offline(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: SingleChildScrollView(
            child: ForgeDeviceInventoryPanel(
              page: page,
              snapshot: snapshot,
              placement: placement,
              resourceSummary: resourceSummary,
              statusByDeviceInstance: {
                ForgeDeviceInventoryPanel.statusKey('device-a', 'runner-a'):
                    status,
                ForgeDeviceInventoryPanel.statusKey('device-b', 'runner-b'):
                    pendingStatus,
              },
            ),
          ),
        ),
      );

      expect(
        find.byKey(const ValueKey('forge-device-inventory-panel')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('forge-inventory-device-a-runner-a')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('forge-inventory-device-b-runner-b')),
        findsOneWidget,
      );
      expect(
        find.text('All values below are unverified caller declarations.'),
        findsOneWidget,
      );
      expect(find.text('Execution authorized: false'), findsOneWidget);
      expect(find.text('Reservation created: false'), findsOneWidget);
      expect(find.text('Dispatch performed: false'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('forge-device-resource-summary')),
        findsOneWidget,
      );
      expect(find.text('Devices: 2 · Runner instances: 2'), findsOneWidget);
      expect(
        find.text('Declared totals: CPU 16 · memory 32768 B · storage 16384 B'),
        findsOneWidget,
      );
      expect(find.text('Declared GPUs: 1 · GPU memory 4096 B'), findsOneWidget);
      expect(
        find.text('Eligible declared devices: 1 · instances: 1'),
        findsOneWidget,
      );
      expect(find.text('Snapshot: snapshot-1 · rows: 3'), findsOneWidget);
      expect(find.text('Device: device-a'), findsOneWidget);
      expect(find.text('Instance: runner-a'), findsOneWidget);
      expect(
        find.text('Resources: CPU 8 · memory 16384 B · storage 8192 B'),
        findsNWidgets(2),
      );
      expect(find.text('Status: online · fresh: true'), findsOneWidget);
      expect(find.text('Status: pending · fresh: true'), findsOneWidget);
      expect(
        find.textContaining('Exclusion reasons: approval_pending'),
        findsOneWidget,
      );
    },
    skip: inventoryPath == null || snapshotPath == null,
  );
}
