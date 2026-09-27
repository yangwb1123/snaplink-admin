import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/forge_client_instance_resource_view.dart';
import 'package:sso_admin/api/forge_conversations_api.dart';
import 'package:sso_admin/api/forge_device_inventory_models.dart';

const _owner = ForgeDeviceOwner(
  issuer: 'https://id.example',
  subject: 'user-1',
  tenantID: 'tenant-1',
);

http.Response _json(Object value, {int status = 200}) => http.Response(
  jsonEncode(value),
  status,
  headers: const {'content-type': 'application/json'},
);

Map<String, dynamic> _inventory({int heartbeat = 4}) => {
  'schema_version': forgeDeviceInventoryV2Schema,
  'evaluation_mode': forgeDeviceInventoryV2EvaluationMode,
  'evaluated_at_ms': 200000,
  'owner_declaration': _owner.toJson(),
  'owner_declaration_unverified': true,
  'inventory_declarations_unverified': true,
  'notice': forgeDeviceInventoryV2Notice,
  'devices': [
    {
      'instance_id': 'runner-a',
      'revision': 3,
      'generation': 2,
      'heartbeat_sequence': heartbeat,
      'device': {
        'device_id': 'device-a',
        'owner': _owner.toJson(),
        'approval_state': 'approved',
        'cordon_state': 'clear',
        'reservation_state': 'none',
        'liveness': 'online',
        'snapshot_observed_at_ms': 150000,
        'lease_expires_at_ms': 210000,
        'os': 'linux',
        'architecture': 'amd64',
        'available_cpu_cores': 8,
        'available_memory_bytes': 16384,
        'available_storage_bytes': 8192,
        'runtimes': ['oci'],
        'gpus': <Object>[],
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

Map<String, dynamic> _resourceView({int heartbeat = 4}) => {
  'schema_version': forgeClientInstanceResourceViewSchema,
  'evaluation_mode': forgeClientInstanceResourceViewEvaluationMode,
  'owner_declaration': _owner.toJson(),
  'owner_declaration_unverified': true,
  'instances': [
    {
      'instance_id': 'client-web-001',
      'client_kind': 'web',
      'session_ids': ['conversation-001'],
      'observed_at_ms': 200500,
      'status': 'active',
    },
  ],
  'devices': [
    {
      'device_id': 'device-a',
      'runner_instance_id': 'runner-a',
      'owner': _owner.toJson(),
      'revision': 3,
      'generation': 2,
      'heartbeat_sequence': heartbeat,
      'observed_at_ms': 150000,
      'approval_state': 'approved',
      'cordon_state': 'clear',
      'reservation_state': 'none',
      'liveness': 'online',
      'os': 'linux',
      'architecture': 'amd64',
      'cpu_cores': 8,
      'available_cpu_cores': 8,
      'memory_bytes': 16384,
      'available_memory_bytes': 16384,
      'storage_bytes': 8192,
      'available_storage_bytes': 8192,
      'gpu_count': 0,
      'available_gpu_memory_bytes': 0,
    },
  ],
  'device_attributes_unverified': true,
  'read_only': true,
  'authority': {
    'owner_authenticated': false,
    'session_read_authorized': false,
    'prompt_write_authorized': false,
    'device_identity_verified': false,
    'reservation_created': false,
    'execution_authorized': false,
    'dispatch_performed': false,
    'audit_published': false,
  },
};

Map<String, dynamic> _convergence({int inventoryHeartbeat = 4}) => {
  'schema_version': forgeDeviceInventoryResourceConvergenceSchema,
  'evaluation_mode': forgeDeviceInventoryResourceConvergenceEvaluationMode,
  'inventory': _inventory(heartbeat: inventoryHeartbeat),
  'resource_view': _resourceView(heartbeat: inventoryHeartbeat),
  'converged': true,
  'read_only': true,
  'authority': const ForgeDeviceInventoryResourceConvergenceAuthority.offline()
      .toJson(),
};

void main() {
  test('strictly decodes a converged inventory/resource pair', () {
    final pair = ForgeDeviceInventoryResourceConvergence.fromJson(
      _convergence(),
    );

    expect(pair.owner, _owner);
    expect(pair.inventory.devices.single.instanceID, 'runner-a');
    expect(pair.resourceView.devices.single.heartbeatSequence, 4);
    expect(pair.isDisplayOnly, isTrue);
    expect(
      ForgeDeviceInventoryResourceConvergence.fromJson(
        pair.toJson(),
      ).resourceView.instances.single.instanceID,
      'client-web-001',
    );
  });

  test('fails closed when a lifecycle counter drifts', () {
    final value = _convergence();
    (value['resource_view']
            as Map<String, dynamic>)['devices']![0]['heartbeat_sequence'] =
        5;

    expect(
      () => ForgeDeviceInventoryResourceConvergence.fromJson(value),
      throwsFormatException,
    );
  });

  test('fails closed when a shared resource field drifts', () {
    final value = _convergence();
    (value['resource_view']
            as Map<String, dynamic>)['devices']![0]['available_memory_bytes'] =
        8192;

    expect(
      () => ForgeDeviceInventoryResourceConvergence.fromJson(value),
      throwsFormatException,
    );
  });

  test('fails closed when the paired observation time drifts', () {
    final value = _convergence();
    (value['resource_view']
            as Map<String, dynamic>)['devices']![0]['observed_at_ms'] =
        150001;

    expect(
      () => ForgeDeviceInventoryResourceConvergence.fromJson(value),
      throwsFormatException,
    );
  });

  test('fails closed when the paired owner drifts', () {
    final value = _convergence();
    (value['resource_view']
        as Map<String, dynamic>)['owner_declaration'] = const ForgeDeviceOwner(
      issuer: 'https://id.example',
      subject: 'foreign-user',
      tenantID: 'tenant-1',
    ).toJson();
    (value['resource_view'] as Map<String, dynamic>)['devices']![0]['owner'] =
        const ForgeDeviceOwner(
          issuer: 'https://id.example',
          subject: 'foreign-user',
          tenantID: 'tenant-1',
        ).toJson();

    expect(
      () => ForgeDeviceInventoryResourceConvergence.fromJson(value),
      throwsFormatException,
    );
  });

  test('fails closed when convergence authority is elevated', () {
    final value = _convergence();
    (value['authority'] as Map<String, dynamic>)['lease_issued'] = true;

    expect(
      () => ForgeDeviceInventoryResourceConvergence.fromJson(value),
      throwsFormatException,
    );
  });

  test('API adapter performs exactly two authenticated GETs', () async {
    final requests = <http.Request>[];
    final api = ForgeConversationsApi(
      baseUrl: 'https://forge.example',
      accessToken: 'forge-bearer',
      httpClient: MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/v1/devices/observations/v2') {
          return _json(_inventory());
        }
        if (request.url.path == '/api/v1/client-instances/resource-view') {
          return _json(_resourceView());
        }
        throw StateError('Unexpected Forge request: ${request.url}');
      }),
    );
    addTearDown(api.close);

    final pair = await api.readConvergedInventoryResourceView(owner: _owner);

    expect(pair.isDisplayOnly, isTrue);
    expect(requests.map((request) => request.url.path), [
      '/api/v1/devices/observations/v2',
      '/api/v1/client-instances/resource-view',
    ]);
    expect(
      requests.every(
        (request) =>
            request.method == 'GET' &&
            request.body.isEmpty &&
            request.headers['authorization'] == 'Bearer forge-bearer' &&
            request.headers['cache-control'] == 'no-store',
      ),
      isTrue,
    );
  });

  test('API adapter rejects counter drift before returning a pair', () async {
    final api = ForgeConversationsApi(
      baseUrl: 'https://forge.example',
      accessToken: 'forge-bearer',
      httpClient: MockClient((request) async {
        if (request.url.path == '/api/v1/devices/observations/v2') {
          return _json(_inventory());
        }
        return _json(_resourceView(heartbeat: 5));
      }),
    );
    addTearDown(api.close);

    await expectLater(
      api.readConvergedInventoryResourceView(owner: _owner),
      throwsFormatException,
    );
  });
}
