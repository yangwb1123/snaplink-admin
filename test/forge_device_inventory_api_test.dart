import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/forge_conversations_api.dart';
import 'package:sso_admin/api/forge_device_inventory_models.dart';

http.Response _json(Object value, {int status = 200}) => http.Response(
  jsonEncode(value),
  status,
  headers: const {'content-type': 'application/json'},
);

const _owner = ForgeDeviceOwner(
  issuer: 'https://id.example',
  subject: 'user-1',
  tenantID: 'tenant-1',
);

Map<String, dynamic> _inventory({ForgeDeviceOwner owner = _owner}) => {
  'schema_version': 'forge.device-inventory-observation/v1',
  'evaluation_mode': 'offline_static_only',
  'evaluated_at_ms': 200000,
  'owner_declaration': owner.toJson(),
  'owner_declaration_unverified': true,
  'inventory_declarations_unverified': true,
  'notice':
      'Every owner, instance, state, timestamp, resource, residency, trust, sandbox, and concurrency value is an unverified caller declaration. This read-only observation selects no target and grants no execution authority.',
  'devices': [
    {
      'instance_id': 'runner-a',
      'device': {
        'device_id': 'device-a',
        'owner': owner.toJson(),
        'approval_state': 'approved',
        'cordon_state': 'clear',
        'liveness': 'online',
        'snapshot_observed_at_ms': 150000,
        'lease_expires_at_ms': 210000,
        'os': 'linux',
        'architecture': 'amd64',
        'available_cpu_cores': 8,
        'available_memory_bytes': 16384,
        'available_storage_bytes': 8192,
        'runtimes': ['oci'],
        'gpu': {'present': false, 'memory_bytes': 0, 'runtime': ''},
        'data_residency_zones': ['us-west'],
        'trust_zone': 'standard',
        'sandbox_levels': ['container'],
        'concurrency_limit': 4,
        'active_concurrency': 1,
      },
    },
  ],
  'execution_authorized': false,
  'reservation_created': false,
  'dispatch_performed': false,
};

Map<String, dynamic> _inventoryV2({ForgeDeviceOwner owner = _owner}) {
  final deviceOwner = owner.toJson();
  return {
    'schema_version': forgeDeviceInventoryV2Schema,
    'evaluation_mode': forgeDeviceInventoryV2EvaluationMode,
    'evaluated_at_ms': 200000,
    'owner_declaration': deviceOwner,
    'owner_declaration_unverified': true,
    'inventory_declarations_unverified': true,
    'notice': forgeDeviceInventoryV2Notice,
    'devices': [
      {
        'instance_id': 'runner-v2',
        'revision': 3,
        'generation': 2,
        'heartbeat_sequence': 8,
        'device': {
          'device_id': 'device-v2',
          'owner': deviceOwner,
          'approval_state': 'approved',
          'cordon_state': 'clear',
          'reservation_state': 'reserved',
          'liveness': 'online',
          'snapshot_observed_at_ms': 150000,
          'lease_expires_at_ms': 210000,
          'os': 'linux',
          'architecture': 'amd64',
          'available_cpu_cores': 8,
          'available_memory_bytes': 16384,
          'available_storage_bytes': 8192,
          'runtimes': ['oci'],
          'gpus': [
            {
              'id': 'gpu-v2',
              'vendor': 'NVIDIA',
              'memory_bytes': 1024,
              'available_memory_bytes': 768,
            },
          ],
          'data_residency_zones': <Object>[],
          'trust_zone': 'unknown',
          'sandbox_levels': <Object>[],
          'concurrency_limit': 0,
          'active_concurrency': 0,
        },
      },
    ],
    'execution_authorized': false,
    'reservation_created': false,
    'dispatch_performed': false,
  };
}

void main() {
  test(
    'reads the owner-bound inventory candidate with an authenticated GET',
    () async {
      final requests = <http.Request>[];
      final api = ForgeConversationsApi(
        baseUrl: 'https://forge.example',
        accessToken: 'forge-bearer',
        httpClient: MockClient((request) async {
          requests.add(request);
          return _json(_inventory());
        }),
      );
      addTearDown(api.close);

      final page = await api.readDeviceInventoryCandidate(owner: _owner);

      expect(page.owner, _owner);
      expect(page.devices.single.device.deviceID, 'device-a');
      expect(page.executionAuthorized, isFalse);
      expect(requests, hasLength(1));
      expect(requests.single.method, 'GET');
      expect(requests.single.url.path, '/api/v1/devices');
      expect(requests.single.url.queryParameters, isEmpty);
      expect(requests.single.body, isEmpty);
      expect(requests.single.headers['authorization'], 'Bearer forge-bearer');
      expect(requests.single.headers['cache-control'], 'no-store');
    },
  );

  test(
    'reads the owner-bound lossless v2 inventory candidate with an authenticated GET',
    () async {
      final requests = <http.Request>[];
      final api = ForgeConversationsApi(
        baseUrl: 'https://forge.example',
        accessToken: 'forge-bearer',
        httpClient: MockClient((request) async {
          requests.add(request);
          return _json(_inventoryV2());
        }),
      );
      addTearDown(api.close);

      final page = await api.readDeviceInventoryCandidateV2(owner: _owner);

      expect(page.owner, _owner);
      expect(page.devices.single.device.deviceID, 'device-v2');
      expect(page.devices.single.revision, 3);
      expect(page.devices.single.device.reservationState, 'reserved');
      expect(page.devices.single.device.gpus.single.memoryBytes, 1024);
      expect(page.executionAuthorized, isFalse);
      expect(requests, hasLength(1));
      expect(requests.single.method, 'GET');
      expect(requests.single.url.path, '/api/v1/devices/observations/v2');
      expect(requests.single.url.queryParameters, isEmpty);
      expect(requests.single.body, isEmpty);
      expect(requests.single.headers['authorization'], 'Bearer forge-bearer');
    },
  );

  test('rejects a v2 inventory candidate whose owner drifts', () async {
    final api = ForgeConversationsApi(
      baseUrl: 'https://forge.example',
      accessToken: 'forge-bearer',
      httpClient: MockClient((_) async {
        return _json(
          _inventoryV2(
            owner: const ForgeDeviceOwner(
              issuer: 'https://id.example',
              subject: 'foreign-user',
              tenantID: 'tenant-1',
            ),
          ),
        );
      }),
    );
    addTearDown(api.close);

    await expectLater(
      api.readDeviceInventoryCandidateV2(owner: _owner),
      throwsFormatException,
    );
  });

  test(
    'rejects an inventory candidate whose owner drifts from the caller',
    () async {
      final api = ForgeConversationsApi(
        baseUrl: 'https://forge.example',
        accessToken: 'forge-bearer',
        httpClient: MockClient((_) async {
          return _json(
            _inventory(
              owner: const ForgeDeviceOwner(
                issuer: 'https://id.example',
                subject: 'foreign-user',
                tenantID: 'tenant-1',
              ),
            ),
          );
        }),
      );
      addTearDown(api.close);

      await expectLater(
        api.readDeviceInventoryCandidate(owner: _owner),
        throwsFormatException,
      );
    },
  );

  test(
    'rejects an invalid owner before contacting the candidate route',
    () async {
      var requests = 0;
      final api = ForgeConversationsApi(
        baseUrl: 'https://forge.example',
        accessToken: 'forge-bearer',
        httpClient: MockClient((_) async {
          requests++;
          return _json(_inventory());
        }),
      );
      addTearDown(api.close);

      await expectLater(
        api.readDeviceInventoryCandidate(
          owner: const ForgeDeviceOwner(
            issuer: '',
            subject: 'user-1',
            tenantID: 'tenant-1',
          ),
        ),
        throwsFormatException,
      );
      expect(requests, 0);
    },
  );
}
