import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/forge_conversations_api.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/api/forge_device_placement.dart';

void main() {
  test('posts an authenticated offline placement declaration', () async {
    final request = _placementRequest();
    late http.Request sent;
    final api = ForgeConversationsApi(
      baseUrl: 'https://forge.example',
      accessToken: 'forge-bearer',
      httpClient: MockClient((value) async {
        sent = value;
        final decoded = jsonDecode(value.body);
        final echoed = ForgeDevicePlacementRequest.fromJson(decoded);
        final result = dryRunForgeDevicePlacement(echoed);
        return http.Response(
          jsonEncode(result.toJson()),
          200,
          headers: const {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(api.close);

    final result = await api.previewDevicePlacement(request: request);

    expect(sent.method, 'POST');
    expect(sent.url.path, '/api/v1/device-placement/preview');
    expect(sent.headers['authorization'], 'Bearer forge-bearer');
    expect(sent.headers['content-type'], 'application/json');
    expect(sent.headers.containsKey('idempotency-key'), isFalse);
    expect(result.owner, request.owner);
    expect(result.deviceResults.single.deviceID, 'device-1');
    expect(result.deviceResults.single.matchesRequirements, isTrue);
    expect(result.executionAuthorized, isFalse);
    expect(result.reservationCreated, isFalse);
    expect(result.dispatchPerformed, isFalse);
  });

  test('rejects a placement response that claims authority', () async {
    final api = ForgeConversationsApi(
      baseUrl: 'https://forge.example',
      accessToken: 'forge-bearer',
      httpClient: MockClient((_) async {
        final result = dryRunForgeDevicePlacement(_placementRequest()).toJson();
        result['execution_authorized'] = true;
        return http.Response(
          jsonEncode(result),
          200,
          headers: const {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(api.close);

    await expectLater(
      api.previewDevicePlacement(request: _placementRequest()),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects a placement response for another device set', () async {
    final api = ForgeConversationsApi(
      baseUrl: 'https://forge.example',
      accessToken: 'forge-bearer',
      httpClient: MockClient((_) async {
        final result = dryRunForgeDevicePlacement(_placementRequest()).toJson();
        (result['device_results'] as List).single['device_id'] =
            'device-foreign';
        return http.Response(
          jsonEncode(result),
          200,
          headers: const {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(api.close);

    await expectLater(
      api.previewDevicePlacement(request: _placementRequest()),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects a placement response for another owner', () async {
    final api = ForgeConversationsApi(
      baseUrl: 'https://forge.example',
      accessToken: 'forge-bearer',
      httpClient: MockClient((_) async {
        final result = dryRunForgeDevicePlacement(_placementRequest()).toJson();
        result['owner_declaration'] = const ForgeDeviceOwner(
          issuer: 'https://id.example',
          subject: 'foreign-user',
          tenantID: 'tenant-1',
        ).toJson();
        return http.Response(
          jsonEncode(result),
          200,
          headers: const {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(api.close);

    await expectLater(
      api.previewDevicePlacement(request: _placementRequest()),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects a placement response for another evaluation time', () async {
    final api = ForgeConversationsApi(
      baseUrl: 'https://forge.example',
      accessToken: 'forge-bearer',
      httpClient: MockClient((_) async {
        final result = dryRunForgeDevicePlacement(_placementRequest()).toJson();
        result['evaluated_at_ms'] = 200001;
        return http.Response(
          jsonEncode(result),
          200,
          headers: const {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(api.close);

    await expectLater(
      api.previewDevicePlacement(request: _placementRequest()),
      throwsA(isA<FormatException>()),
    );
  });

  test(
    'rejects a placement response with changed eligibility reasons',
    () async {
      final api = ForgeConversationsApi(
        baseUrl: 'https://forge.example',
        accessToken: 'forge-bearer',
        httpClient: MockClient((_) async {
          final result = dryRunForgeDevicePlacement(
            _placementRequest(),
          ).toJson();
          final device = (result['device_results'] as List).single as Map;
          device['matches_requirements'] = false;
          device['exclusion_reasons'] = ['caller_policy'];
          return http.Response(
            jsonEncode(result),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }),
      );
      addTearDown(api.close);

      await expectLater(
        api.previewDevicePlacement(request: _placementRequest()),
        throwsA(isA<FormatException>()),
      );
    },
  );
}

ForgeDevicePlacementRequest _placementRequest() {
  const owner = ForgeDeviceOwner(
    issuer: 'https://id.example',
    subject: 'user-1',
    tenantID: 'tenant-1',
  );
  return ForgeDevicePlacementRequest(
    schemaVersion: forgeDevicePlacementRequestSchema,
    evaluatedAtMS: 200000,
    owner: owner,
    maxSnapshotAgeMS: 90000,
    requirements: ForgeDevicePlacementRequirements(
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
    ),
    devices: [
      ForgeDeviceDeclaration(
        deviceID: 'device-1',
        owner: owner,
        approvalState: 'approved',
        cordonState: 'clear',
        liveness: 'online',
        snapshotObservedAtMS: 150000,
        leaseExpiresAtMS: 210000,
        os: 'linux',
        architecture: 'amd64',
        availableCPUCores: 8,
        availableMemoryBytes: 16384,
        availableStorageBytes: 8192,
        runtimes: ['oci'],
        gpu: ForgeDeviceGpu(present: false, memoryBytes: 0, runtime: ''),
        dataResidencyZones: ['us-west'],
        trustZone: 'high',
        sandboxLevels: ['container'],
        concurrencyLimit: 4,
        activeConcurrency: 1,
      ),
    ],
  );
}
