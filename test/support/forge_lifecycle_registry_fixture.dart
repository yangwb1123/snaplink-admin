import 'package:sso_admin/api/forge_device_inventory_declaration.dart';

const forgeLifecycleRegistryTestOwner = ForgeDeviceOwner(
  issuer: 'https://id.example',
  subject: 'user-1',
  tenantID: 'tenant-1',
);

Map<String, dynamic> forgeLifecycleRegistryTestEnvelope({
  ForgeDeviceOwner owner = forgeLifecycleRegistryTestOwner,
  List<Map<String, dynamic>>? states,
}) => {
  'schema_version': 'forge.device-enrollment-heartbeat-lifecycle-file-set/v1',
  'owner': owner.toJson(),
  'states':
      states ??
      <Map<String, dynamic>>[
        forgeLifecycleRegistryTestState(
          deviceID: 'device-a',
          instanceID: 'runner-a',
          revision: 1,
          heartbeatSequence: 1,
        ),
        forgeLifecycleRegistryTestState(
          deviceID: 'device-b',
          instanceID: 'runner-b',
          revision: 2,
          heartbeatSequence: 3,
        ),
      ],
};

Map<String, dynamic> forgeLifecycleRegistryTestState({
  required String deviceID,
  required String instanceID,
  required int revision,
  required int heartbeatSequence,
  ForgeDeviceOwner owner = forgeLifecycleRegistryTestOwner,
}) {
  final capabilities = <String, dynamic>{
    'os': 'linux',
    'architecture': 'amd64',
    'cpu_cores': 8,
    'available_cpu_cores': 7,
    'memory_bytes': 16384,
    'available_memory_bytes': 8192,
    'storage_bytes': 32768,
    'available_storage_bytes': 16384,
    'gpus': <Object>[],
    'runtimes': ['oci'],
  };
  final heartbeatInstance = <String, dynamic>{
    'device_id': deviceID,
    'instance_id': instanceID,
    'generation': 1,
    'heartbeat_sequence': heartbeatSequence,
    'server_observed_at_ms': 100000 + revision,
    'capability_lease_expires_at_ms': 160000 + revision,
    'capabilities': capabilities,
  };
  return {
    'revision': revision,
    'owner': owner.toJson(),
    'device': {
      'device_id': deviceID,
      'owner': owner.toJson(),
      'key_id': 'key-$deviceID',
      'public_key_sha256':
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
      'approval_state': 'approved',
      'credential_state': 'active',
    },
    'heartbeat': {'revision': revision, 'instance': heartbeatInstance},
    'inventory': {
      'revision': revision,
      'device': {
        'device_id': deviceID,
        'owner': owner.toJson(),
        'approval_state': 'approved',
        'cordon_state': 'clear',
        'reservation_state': 'none',
      },
      'runner': {...heartbeatInstance, 'liveness': 'online'},
    },
  };
}

Map<String, dynamic> forgeLifecycleRegistryTestAuthorityMutation() => {
  ...forgeLifecycleRegistryTestEnvelope(),
  'execution_authorized': true,
};
