import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/forge_conversations_api.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/api/forge_device_placement.dart';
import 'package:sso_admin/api/forge_device_inventory_placement_batch_evaluation.dart';
import 'package:sso_admin/api/forge_device_registry_placement_preview.dart';

void main() {
  test('posts one authenticated owner-bound registry preview', () async {
    final owner = _owner();
    final requirements = _requirements();
    final requests = <http.Request>[];
    final api = ForgeConversationsApi(
      baseUrl: 'https://candidate.example',
      accessToken: 'registry-token',
      httpClient: MockClient((request) async {
        requests.add(request);
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/device-placement/registry-preview');
        expect(request.url.query, isEmpty);
        expect(request.headers['authorization'], 'Bearer registry-token');
        expect(request.headers['content-type'], 'application/json');
        expect(request.headers.containsKey('idempotency-key'), isFalse);
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        expect(body.keys, {'requirements'});
        expect(
          jsonEncode(
            ForgeDevicePlacementRequirements.fromJson(
              body['requirements'],
            ).toJson(),
          ),
          jsonEncode(requirements.toJson()),
        );
        return _json(_preview(owner).toJson());
      }),
    );
    addTearDown(api.close);

    final result = await api.previewDevicePlacementFromRegistry(
      owner: owner,
      requirements: requirements,
      candidateOrigin: 'https://candidate.example/',
    );

    expect(requests, hasLength(1));
    expect(result.evaluationOwner, owner);
    expect(result.decisions.single.deviceID, 'device-1');
    expect(result.eligibleCandidateCount, 1);
    expect(result.selectedDeviceID, isNull);
    expect(result.authority.anyGranted, isFalse);
  });

  test('rejects origin drift before issuing a request', () async {
    var count = 0;
    final api = ForgeConversationsApi(
      baseUrl: 'https://candidate.example',
      accessToken: 'registry-token',
      httpClient: MockClient((_) async {
        count++;
        return _json(_preview(_owner()).toJson());
      }),
    );
    addTearDown(api.close);

    await expectLater(
      api.previewDevicePlacementFromRegistry(
        owner: _owner(),
        requirements: _requirements(),
        candidateOrigin: 'https://other.example',
      ),
      throwsFormatException,
    );
    expect(count, 0);
  });

  test('rejects selected and authority-bearing responses', () async {
    final api = ForgeConversationsApi(
      baseUrl: 'https://candidate.example',
      accessToken: 'registry-token',
      httpClient: MockClient((_) async {
        final root = _preview(_owner()).toJson();
        root['selected_device_id'] = 'device-1';
        return _json(root);
      }),
    );
    addTearDown(api.close);
    await expectLater(
      api.previewDevicePlacementFromRegistry(
        owner: _owner(),
        requirements: _requirements(),
        candidateOrigin: 'https://candidate.example',
      ),
      throwsFormatException,
    );

    final authorityApi = ForgeConversationsApi(
      baseUrl: 'https://candidate.example',
      accessToken: 'registry-token',
      httpClient: MockClient((_) async {
        final root = _preview(_owner()).toJson();
        (root['authority'] as Map<String, dynamic>)['placement_selected'] =
            true;
        return _json(root);
      }),
    );
    addTearDown(authorityApi.close);
    await expectLater(
      authorityApi.previewDevicePlacementFromRegistry(
        owner: _owner(),
        requirements: _requirements(),
        candidateOrigin: 'https://candidate.example',
      ),
      throwsFormatException,
    );
  });

  test(
    'rejects a foreign owner without replaying after the response',
    () async {
      var count = 0;
      final api = ForgeConversationsApi(
        baseUrl: 'https://candidate.example',
        accessToken: 'registry-token',
        httpClient: MockClient((_) async {
          count++;
          return _json(
            _preview(
              const ForgeDeviceOwner(
                issuer: 'https://id.example',
                subject: 'foreign',
                tenantID: 'tenant-1',
              ),
            ).toJson(),
          );
        }),
      );
      addTearDown(api.close);

      await expectLater(
        api.previewDevicePlacementFromRegistry(
          owner: _owner(),
          requirements: _requirements(),
          candidateOrigin: 'https://candidate.example',
        ),
        throwsFormatException,
      );
      expect(count, 1);
    },
  );

  test('strictly rejects duplicate response fields', () async {
    final api = ForgeConversationsApi(
      baseUrl: 'https://candidate.example',
      accessToken: 'registry-token',
      httpClient: MockClient((_) async {
        final encoded = jsonEncode(_preview(_owner()).toJson());
        final duplicate = encoded.replaceFirst(
          '"schema_version":"$forgeDeviceRegistryPlacementPreviewSchema",',
          '"schema_version":"$forgeDeviceRegistryPlacementPreviewSchema",'
              '"schema_version":"$forgeDeviceRegistryPlacementPreviewSchema",',
        );
        return http.Response(
          duplicate,
          200,
          headers: const {'content-type': 'application/json'},
        );
      }),
    );
    addTearDown(api.close);

    await expectLater(
      api.previewDevicePlacementFromRegistry(
        owner: _owner(),
        requirements: _requirements(),
        candidateOrigin: 'https://candidate.example',
      ),
      throwsA(isA<ForgeConversationsApiException>()),
    );
  });

  test('compact decoder rejects unknown and declaration-authority drift', () {
    final unknown = _preview(_owner()).toJson()..['unexpected'] = true;
    expect(
      () => ForgeDeviceRegistryPlacementPreview.fromJson(unknown),
      throwsFormatException,
    );

    final authority = _preview(_owner()).toJson();
    final decisions = authority['decisions'] as List;
    (decisions.single as Map<String, dynamic>)['owner_declaration_unverified'] =
        false;
    expect(
      () => ForgeDeviceRegistryPlacementPreview.fromJson(authority),
      throwsFormatException,
    );
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

ForgeDeviceRegistryPlacementPreview _preview(ForgeDeviceOwner owner) =>
    ForgeDeviceRegistryPlacementPreview(
      schemaVersion: forgeDeviceRegistryPlacementPreviewSchema,
      evaluationMode: forgeDeviceRegistryPlacementPreviewEvaluationMode,
      sourceSchemaVersion: forgeDeviceRegistryPlacementPreviewSourceSchema,
      evaluationOwner: owner,
      evaluatedAtMS: 200000,
      notice: forgeDeviceRegistryPlacementPreviewNotice,
      decisions: [
        const ForgeDeviceRegistryPlacementDecision(
          revision: 1,
          generation: 1,
          heartbeatSequence: 1,
          deviceID: 'device-1',
          instanceID: 'runner-1',
          reservationState: 'none',
          gpuCount: 0,
          availableGPUMemoryBytes: 0,
          matchesRequirements: true,
          exclusionReasons: [],
          ownerDeclarationUnverified: true,
          deviceAttributesUnverified: true,
        ),
      ],
      eligibleCandidateCount: 1,
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

http.Response _json(Object value) => http.Response(
  jsonEncode(value),
  200,
  headers: const {'content-type': 'application/json'},
);
