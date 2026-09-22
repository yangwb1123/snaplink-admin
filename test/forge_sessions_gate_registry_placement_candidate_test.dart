import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/api/forge_device_inventory_placement_batch_evaluation.dart';
import 'package:sso_admin/api/forge_device_placement.dart';
import 'package:sso_admin/api/forge_device_registry_placement_preview.dart';
import 'package:sso_admin/screens/forge/forge_sessions_gate.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/services/forge_credential_store.dart';
import 'package:sso_admin/session.dart';

import 'support/memory_forge_credential_backend.dart';

void main() {
  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  setUp(BrowserNavigation.resetForTest);
  tearDown(() {
    BrowserNavigation.resetForTest();
    Session.clear();
  });

  testWidgets('explicit Gate performs one registry placement POST', (
    tester,
  ) async {
    final store = await _credentialStore('registry-token');
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/api/v1/conversations') {
        return _json({'conversations': <Object>[], 'has_more': false});
      }
      if (request.url.path == '/api/v1/device-placement/registry-preview') {
        return _json(_preview().toJson());
      }
      throw StateError('Unexpected Forge request: ${request.url}');
    });
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsGate(
          credentialStore: store,
          httpClient: client,
          deviceInventoryOwner: _owner(),
          deviceInventoryRegistryPlacementRequirements: _requirements(),
          deviceInventoryRegistryPlacementPreviewCandidateApiOrigin:
              'https://candidate.example',
          enableDeviceInventoryRegistryPlacementPreviewCandidate: true,
        ),
      ),
    );
    await _pump(tester);

    final placementRequests = requests
        .where(
          (request) =>
              request.url.path == '/api/v1/device-placement/registry-preview',
        )
        .toList();
    expect(placementRequests, hasLength(1));
    expect(placementRequests.single.method, 'POST');
    expect(placementRequests.single.url.query, isEmpty);
    expect(
      placementRequests.single.headers['authorization'],
      'Bearer registry-token',
    );
    expect((jsonDecode(placementRequests.single.body) as Map).keys, {
      'requirements',
    });
    expect(
      find.byKey(
        const ValueKey('forge-device-registry-placement-preview-panel'),
      ),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('default Gate remains registry placement request-free', (
    tester,
  ) async {
    final store = await _credentialStore('default-token');
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/api/v1/conversations') {
        return _json({'conversations': <Object>[], 'has_more': false});
      }
      throw StateError('Default Gate contacted candidate: ${request.url}');
    });
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsGate(
          credentialStore: store,
          httpClient: client,
          deviceInventoryOwner: _owner(),
          deviceInventoryRegistryPlacementRequirements: _requirements(),
        ),
      ),
    );
    await _pump(tester);

    expect(
      requests.where(
        (request) => request.url.path.contains('registry-preview'),
      ),
      isEmpty,
    );
    expect(
      find.byKey(
        const ValueKey('forge-device-registry-placement-preview-panel'),
      ),
      findsNothing,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}

ForgeDeviceOwner _owner() => const ForgeDeviceOwner(
  issuer: 'https://id.example',
  subject: 'user-1',
  tenantID: 'tenant-1',
);

ForgeDevicePlacementRequirements _requirements() =>
    const ForgeDevicePlacementRequirements(
      os: 'linux',
      architecture: 'amd64',
      minCPUCores: 1,
      minMemoryBytes: 1,
      minStorageBytes: 1,
      runtime: 'oci',
      gpu: ForgeDevicePlacementGpuRequirement(
        required: false,
        minMemoryBytes: 0,
        runtime: '',
      ),
      dataResidencyZones: ['us-west'],
      minimumTrustZone: 'standard',
      sandboxFloor: 'process',
      concurrencySlots: 1,
    );

ForgeDeviceRegistryPlacementPreview _preview() =>
    ForgeDeviceRegistryPlacementPreview(
      schemaVersion: forgeDeviceRegistryPlacementPreviewSchema,
      evaluationMode: forgeDeviceRegistryPlacementPreviewEvaluationMode,
      sourceSchemaVersion: forgeDeviceRegistryPlacementPreviewSourceSchema,
      evaluationOwner: _owner(),
      evaluatedAtMS: 200000,
      notice: forgeDeviceRegistryPlacementPreviewNotice,
      decisions: const [],
      eligibleCandidateCount: 0,
      selectedDeviceID: null,
      selectedInstanceID: null,
      authority: const ForgeDeviceInventoryPlacementBatchAuthority(
        identityVerified: false,
        heartbeatPersisted: false,
        inventoryAuthoritative: false,
        placementSelected: false,
        reservationCreated: false,
        executionAuthorized: false,
        dispatchPerformed: false,
      ),
    );

Future<ForgeCredentialStore> _credentialStore(String token) async {
  final store = ForgeCredentialStore(
    backend: MemoryForgeCredentialBackend(),
    forcePersistentStorage: true,
  );
  expect(await store.store(accessToken: token), isTrue);
  return store;
}

Future<void> _pump(WidgetTester tester) async {
  for (var index = 0; index < 10; index++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
}

http.Response _json(Object value) => http.Response(
  jsonEncode(value),
  200,
  headers: const {'content-type': 'application/json'},
);
