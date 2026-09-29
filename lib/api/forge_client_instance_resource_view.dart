import 'dart:convert';

import 'forge_client_instance_session_view.dart';
import 'forge_device_inventory_declaration.dart';

part 'forge_client_instance_resource_view_validation.dart';

/// Strict, read-only composition of client-instance/session metadata and
/// caller-declared device resources. It never authenticates, schedules, or
/// executes work.
const forgeClientInstanceResourceViewSchema =
    'forge.client-instance-resource-view/v1';
const forgeClientInstanceResourceViewEvaluationMode =
    'owner_bound_instance_resource_view_only';
const forgeClientInstanceResourceViewMaxDevices = 128;
const forgeClientInstanceResourceViewMaxSafeInteger = 9007199254740991;
const _forgeClientInstanceResourceViewMaxInputBytes = 2 * 1024 * 1024;

/// Reads one bounded local client-instance/resource-view document.
///
/// The callback is intentionally source-only: callers still have to pass the
/// returned text through [ForgeClientInstanceResourceView.fromJsonText], and
/// no transport or execution authority is implied by the reader.
typedef ForgeClientInstanceResourceViewFileReader = Future<String?> Function();

class ForgeClientInstanceResourceViewDevice {
  final String deviceID;
  final String runnerInstanceID;
  final ForgeDeviceOwner owner;
  final int revision;
  final int generation;
  final int heartbeatSequence;
  final int observedAtMS;
  final String approvalState;
  final String cordonState;
  final String reservationState;
  final String liveness;
  final String os;
  final String architecture;
  final int cpuCores;
  final int availableCPUCores;
  final int memoryBytes;
  final int availableMemoryBytes;
  final int storageBytes;
  final int availableStorageBytes;
  final int gpuCount;
  final int availableGPUMemoryBytes;

  const ForgeClientInstanceResourceViewDevice({
    required this.deviceID,
    required this.runnerInstanceID,
    required this.owner,
    required this.revision,
    required this.generation,
    required this.heartbeatSequence,
    required this.observedAtMS,
    required this.approvalState,
    required this.cordonState,
    required this.reservationState,
    required this.liveness,
    required this.os,
    required this.architecture,
    required this.cpuCores,
    required this.availableCPUCores,
    required this.memoryBytes,
    required this.availableMemoryBytes,
    required this.storageBytes,
    required this.availableStorageBytes,
    required this.gpuCount,
    required this.availableGPUMemoryBytes,
  });

  factory ForgeClientInstanceResourceViewDevice.fromJson(Object? value) {
    final json = _resourceViewObject(value, 'device');
    _resourceViewExactKeys(json, {
      'device_id',
      'runner_instance_id',
      'owner',
      'revision',
      'generation',
      'heartbeat_sequence',
      'observed_at_ms',
      'approval_state',
      'cordon_state',
      'reservation_state',
      'liveness',
      'os',
      'architecture',
      'cpu_cores',
      'available_cpu_cores',
      'memory_bytes',
      'available_memory_bytes',
      'storage_bytes',
      'available_storage_bytes',
      'gpu_count',
      'available_gpu_memory_bytes',
    });
    final device = ForgeClientInstanceResourceViewDevice(
      deviceID: _resourceViewIdentifier(json['device_id'], 'device ID'),
      runnerInstanceID: _resourceViewIdentifier(
        json['runner_instance_id'],
        'Runner instance ID',
      ),
      owner: ForgeDeviceOwner.fromJson(json['owner']),
      revision: _resourceViewPositiveSafeInteger(json['revision'], 'revision'),
      generation: _resourceViewPositiveSafeInteger(
        json['generation'],
        'generation',
      ),
      heartbeatSequence: _resourceViewPositiveSafeInteger(
        json['heartbeat_sequence'],
        'heartbeat_sequence',
      ),
      observedAtMS: _resourceViewPositiveSafeInteger(
        json['observed_at_ms'],
        'observed_at_ms',
      ),
      approvalState: _resourceViewOneOf(json['approval_state'], {
        'approved',
        'pending',
        'revoked',
        'unknown',
      }, 'approval state'),
      cordonState: _resourceViewOneOf(json['cordon_state'], {
        'clear',
        'cordoned',
        'unknown',
      }, 'cordon state'),
      reservationState: _resourceViewOneOf(json['reservation_state'], {
        'none',
        'reserved',
        'unknown',
      }, 'reservation state'),
      liveness: _resourceViewOneOf(json['liveness'], {
        'online',
        'offline',
        'unknown',
      }, 'liveness'),
      os: _resourceViewToken(json['os'], 'OS'),
      architecture: _resourceViewToken(json['architecture'], 'architecture'),
      cpuCores: _resourceViewNonNegativeSafeInteger(
        json['cpu_cores'],
        'cpu_cores',
      ),
      availableCPUCores: _resourceViewNonNegativeSafeInteger(
        json['available_cpu_cores'],
        'available_cpu_cores',
      ),
      memoryBytes: _resourceViewNonNegativeSafeInteger(
        json['memory_bytes'],
        'memory_bytes',
      ),
      availableMemoryBytes: _resourceViewNonNegativeSafeInteger(
        json['available_memory_bytes'],
        'available_memory_bytes',
      ),
      storageBytes: _resourceViewNonNegativeSafeInteger(
        json['storage_bytes'],
        'storage_bytes',
      ),
      availableStorageBytes: _resourceViewNonNegativeSafeInteger(
        json['available_storage_bytes'],
        'available_storage_bytes',
      ),
      gpuCount: _resourceViewNonNegativeSafeInteger(
        json['gpu_count'],
        'gpu_count',
      ),
      availableGPUMemoryBytes: _resourceViewNonNegativeSafeInteger(
        json['available_gpu_memory_bytes'],
        'available_gpu_memory_bytes',
      ),
    );
    if (device.availableCPUCores > device.cpuCores ||
        device.availableMemoryBytes > device.memoryBytes ||
        device.availableStorageBytes > device.storageBytes) {
      throw const FormatException(
        'Forge client-instance/resource-view capacity is inconsistent.',
      );
    }
    return device;
  }

  Map<String, dynamic> toJson() => {
    'device_id': deviceID,
    'runner_instance_id': runnerInstanceID,
    'owner': owner.toJson(),
    'revision': revision,
    'generation': generation,
    'heartbeat_sequence': heartbeatSequence,
    'observed_at_ms': observedAtMS,
    'approval_state': approvalState,
    'cordon_state': cordonState,
    'reservation_state': reservationState,
    'liveness': liveness,
    'os': os,
    'architecture': architecture,
    'cpu_cores': cpuCores,
    'available_cpu_cores': availableCPUCores,
    'memory_bytes': memoryBytes,
    'available_memory_bytes': availableMemoryBytes,
    'storage_bytes': storageBytes,
    'available_storage_bytes': availableStorageBytes,
    'gpu_count': gpuCount,
    'available_gpu_memory_bytes': availableGPUMemoryBytes,
  };
}

class ForgeClientInstanceResourceView {
  final String schemaVersion;
  final String evaluationMode;
  final ForgeDeviceOwner owner;
  final bool ownerDeclarationUnverified;
  final List<ForgeClientInstanceSessionViewInstance> instances;
  final List<ForgeClientInstanceResourceViewDevice> devices;
  final bool deviceAttributesUnverified;
  final bool readOnly;
  final ForgeClientInstanceSessionViewAuthority authority;

  const ForgeClientInstanceResourceView({
    required this.schemaVersion,
    required this.evaluationMode,
    required this.owner,
    required this.ownerDeclarationUnverified,
    required this.instances,
    required this.devices,
    required this.deviceAttributesUnverified,
    required this.readOnly,
    required this.authority,
  });

  factory ForgeClientInstanceResourceView.fromJson(Object? value) {
    final json = _resourceViewObject(value, 'fixture');
    _resourceViewExactKeys(json, {
      'schema_version',
      'evaluation_mode',
      'owner_declaration',
      'owner_declaration_unverified',
      'instances',
      'devices',
      'device_attributes_unverified',
      'read_only',
      'authority',
    });
    if (json['schema_version'] != forgeClientInstanceResourceViewSchema ||
        json['evaluation_mode'] !=
            forgeClientInstanceResourceViewEvaluationMode ||
        json['owner_declaration_unverified'] != true ||
        json['device_attributes_unverified'] != true ||
        json['read_only'] != true) {
      throw const FormatException(
        'Invalid Forge client-instance/resource-view envelope.',
      );
    }
    final owner = ForgeDeviceOwner.fromJson(json['owner_declaration']);
    final rawInstances = json['instances'];
    final rawDevices = json['devices'];
    if (rawInstances is! List ||
        rawDevices is! List ||
        rawInstances.length > forgeClientInstanceSessionViewMaxInstances ||
        rawDevices.length > forgeClientInstanceResourceViewMaxDevices) {
      throw const FormatException(
        'Invalid Forge client-instance/resource-view rows.',
      );
    }
    final instances = rawInstances
        .map(ForgeClientInstanceSessionViewInstance.fromJson)
        .toList(growable: false);
    for (var index = 1; index < instances.length; index++) {
      if (instances[index - 1].instanceID.compareTo(
            instances[index].instanceID,
          ) >=
          0) {
        throw const FormatException(
          'Forge client-instance/resource-view instances must be sorted and unique.',
        );
      }
    }
    final devices = rawDevices
        .map(ForgeClientInstanceResourceViewDevice.fromJson)
        .toList(growable: false);
    final deviceIDs = <String>{};
    final runnerIDs = <String>{};
    for (var index = 0; index < devices.length; index++) {
      final device = devices[index];
      if (!_sameOwner(device.owner, owner) ||
          !deviceIDs.add(device.deviceID) ||
          !runnerIDs.add(device.runnerInstanceID) ||
          (index > 0 &&
              (devices[index - 1].deviceID.compareTo(device.deviceID) > 0 ||
                  (devices[index - 1].deviceID == device.deviceID &&
                      devices[index - 1].runnerInstanceID.compareTo(
                            device.runnerInstanceID,
                          ) >=
                          0)))) {
        throw const FormatException(
          'Forge client-instance/resource-view devices must be owner-bound, sorted, and unique.',
        );
      }
    }
    final authority = ForgeClientInstanceSessionViewAuthority.fromJson(
      json['authority'],
    );
    if (!authority.isOffline) {
      throw const FormatException(
        'Forge client-instance/resource-view fixture claims authority.',
      );
    }
    return ForgeClientInstanceResourceView(
      schemaVersion: forgeClientInstanceResourceViewSchema,
      evaluationMode: forgeClientInstanceResourceViewEvaluationMode,
      owner: owner,
      ownerDeclarationUnverified: true,
      instances: List.unmodifiable(instances),
      devices: List.unmodifiable(devices),
      deviceAttributesUnverified: true,
      readOnly: true,
      authority: authority,
    );
  }

  factory ForgeClientInstanceResourceView.fromJsonText(String source) {
    try {
      if (utf8.encode(source).length >
          _forgeClientInstanceResourceViewMaxInputBytes) {
        throw const FormatException(
          'Forge client-instance/resource-view fixture is too large.',
        );
      }
      _resourceViewRejectDuplicateKeys(source);
      return ForgeClientInstanceResourceView.fromJson(jsonDecode(source));
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException(
        'Invalid Forge client-instance/resource-view JSON.',
      );
    }
  }

  bool get isDisplayOnly =>
      schemaVersion == forgeClientInstanceResourceViewSchema &&
      evaluationMode == forgeClientInstanceResourceViewEvaluationMode &&
      ownerDeclarationUnverified &&
      deviceAttributesUnverified &&
      readOnly &&
      authority.isOffline;

  Map<String, dynamic> toJson() => {
    'schema_version': schemaVersion,
    'evaluation_mode': evaluationMode,
    'owner_declaration': owner.toJson(),
    'owner_declaration_unverified': ownerDeclarationUnverified,
    'instances': instances.map((instance) => instance.toJson()).toList(),
    'devices': devices.map((device) => device.toJson()).toList(),
    'device_attributes_unverified': deviceAttributesUnverified,
    'read_only': readOnly,
    'authority': authority.toJson(),
  };
}
