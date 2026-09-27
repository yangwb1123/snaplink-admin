import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/forge_client_instance_resource_view.dart';
import 'package:sso_admin/api/forge_client_instance_session_resource_convergence.dart';
import 'package:sso_admin/api/forge_client_instance_session_view.dart';
import 'package:sso_admin/api/forge_conversations_api.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';

const _owner = ForgeDeviceOwner(
  issuer: 'https://id.example',
  subject: 'user-1',
  tenantID: 'tenant-1',
);

Map<String, dynamic> _instances({int observedAtMS = 200500}) => {
  'instances': [
    {
      'instance_id': 'client-web-001',
      'client_kind': 'web',
      'session_ids': ['conversation-001'],
      'observed_at_ms': observedAtMS,
      'status': 'active',
    },
  ],
};

Map<String, dynamic> _sessionView({int observedAtMS = 200500}) => {
  'schema_version': forgeClientInstanceSessionViewSchema,
  'evaluation_mode': forgeClientInstanceSessionViewEvaluationMode,
  'owner_declaration': _owner.toJson(),
  'owner_declaration_unverified': true,
  ..._instances(observedAtMS: observedAtMS),
  'read_only': true,
  'authority': const ForgeClientInstanceSessionViewAuthority.offline().toJson(),
};

Map<String, dynamic> _resourceView({int observedAtMS = 200500}) => {
  'schema_version': forgeClientInstanceResourceViewSchema,
  'evaluation_mode': forgeClientInstanceResourceViewEvaluationMode,
  'owner_declaration': _owner.toJson(),
  'owner_declaration_unverified': true,
  ..._instances(observedAtMS: observedAtMS),
  'devices': [
    {
      'device_id': 'device-a',
      'runner_instance_id': 'runner-a',
      'owner': _owner.toJson(),
      'revision': 3,
      'generation': 2,
      'heartbeat_sequence': 4,
      'observed_at_ms': observedAtMS,
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
  'authority': const ForgeClientInstanceSessionViewAuthority.offline().toJson(),
};

Map<String, dynamic> _convergence({int observedAtMS = 200500}) => {
  'schema_version': forgeClientInstanceSessionResourceConvergenceSchema,
  'evaluation_mode':
      forgeClientInstanceSessionResourceConvergenceEvaluationMode,
  'session_view': _sessionView(observedAtMS: observedAtMS),
  'resource_view': _resourceView(observedAtMS: observedAtMS),
  'converged': true,
  'read_only': true,
  'authority':
      const ForgeClientInstanceSessionResourceConvergenceAuthority.offline()
          .toJson(),
};

http.Response _json(Object value, {int status = 200}) => http.Response(
  jsonEncode(value),
  status,
  headers: const {'content-type': 'application/json'},
);

void main() {
  test('strictly decodes a converged session/resource pair', () {
    final pair = ForgeClientInstanceSessionResourceConvergence.fromJson(
      _convergence(),
    );

    expect(pair.owner, _owner);
    expect(pair.sessionView.instances.single.instanceID, 'client-web-001');
    expect(pair.resourceView.devices.single.deviceID, 'device-a');
    expect(pair.isDisplayOnly, isTrue);
    expect(
      ForgeClientInstanceSessionResourceConvergence.fromJson(
        pair.toJson(),
      ).resourceView.instances.single.sessionIDs,
      ['conversation-001'],
    );
  });

  test('fails closed when the session/resource rows drift', () {
    final value = _convergence();
    (value['resource_view']
            as Map<String, dynamic>)['instances']![0]['observed_at_ms'] =
        200501;

    expect(
      () => ForgeClientInstanceSessionResourceConvergence.fromJson(value),
      throwsFormatException,
    );
  });

  test('fails closed when convergence authority is elevated', () {
    final value = _convergence();
    (value['authority'] as Map<String, dynamic>)['session_read_authorized'] =
        true;

    expect(
      () => ForgeClientInstanceSessionResourceConvergence.fromJson(value),
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
        if (request.url.path == '/api/v1/client-instances/session-view') {
          return _json(_sessionView());
        }
        if (request.url.path == '/api/v1/client-instances/resource-view') {
          return _json(_resourceView());
        }
        throw StateError('Unexpected Forge request: ${request.url}');
      }),
    );
    addTearDown(api.close);

    final pair = await api.readConvergedClientInstanceViews(owner: _owner);

    expect(pair.isDisplayOnly, isTrue);
    expect(requests.map((request) => request.url.path), [
      '/api/v1/client-instances/session-view',
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

  test('API adapter rejects instance drift before returning a pair', () async {
    final api = ForgeConversationsApi(
      baseUrl: 'https://forge.example',
      accessToken: 'forge-bearer',
      httpClient: MockClient((request) async {
        if (request.url.path == '/api/v1/client-instances/session-view') {
          return _json(_sessionView());
        }
        return _json(_resourceView(observedAtMS: 200501));
      }),
    );
    addTearDown(api.close);

    await expectLater(
      api.readConvergedClientInstanceViews(owner: _owner),
      throwsFormatException,
    );
  });
}
