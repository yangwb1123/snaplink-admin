import 'dart:convert';

import 'forge_client_instance_resource_view.dart';
import 'forge_device_inventory_declaration.dart';
import 'forge_device_inventory_v2_models.dart';

/// Canonical read-only join of the lossless device inventory and the
/// composed client-instance resource view.
const forgeDeviceInventoryResourceConvergenceSchema =
    'forge.device-inventory-resource-convergence/v1';
const forgeDeviceInventoryResourceConvergenceEvaluationMode =
    'owner_bound_inventory_resource_convergence_only';

class ForgeDeviceInventoryResourceConvergenceAuthority {
  final bool inventoryAuthoritative;
  final bool deviceIdentityVerified;
  final bool reservationCreated;
  final bool leaseIssued;
  final bool executionAuthorized;
  final bool dispatchPerformed;
  final bool auditPublished;

  const ForgeDeviceInventoryResourceConvergenceAuthority.offline()
    : inventoryAuthoritative = false,
      deviceIdentityVerified = false,
      reservationCreated = false,
      leaseIssued = false,
      executionAuthorized = false,
      dispatchPerformed = false,
      auditPublished = false;

  factory ForgeDeviceInventoryResourceConvergenceAuthority.fromJson(
    Object? value,
  ) {
    final json = _convergenceObject(value, 'authority');
    _convergenceExactKeys(json, {
      'inventory_authoritative',
      'device_identity_verified',
      'reservation_created',
      'lease_issued',
      'execution_authorized',
      'dispatch_performed',
      'audit_published',
    });
    if (json.values.any((value) => value != false)) {
      throw const FormatException(
        'Forge inventory/resource convergence authority must remain false.',
      );
    }
    return const ForgeDeviceInventoryResourceConvergenceAuthority.offline();
  }

  bool get isOffline =>
      !inventoryAuthoritative &&
      !deviceIdentityVerified &&
      !reservationCreated &&
      !leaseIssued &&
      !executionAuthorized &&
      !dispatchPerformed &&
      !auditPublished;

  Map<String, dynamic> toJson() => {
    'inventory_authoritative': inventoryAuthoritative,
    'device_identity_verified': deviceIdentityVerified,
    'reservation_created': reservationCreated,
    'lease_issued': leaseIssued,
    'execution_authorized': executionAuthorized,
    'dispatch_performed': dispatchPerformed,
    'audit_published': auditPublished,
  };
}

class ForgeDeviceInventoryResourceConvergence {
  final String schemaVersion;
  final String evaluationMode;
  final ForgeDeviceOwner owner;
  final ForgeDeviceInventoryPageV2 inventory;
  final ForgeClientInstanceResourceView resourceView;
  final bool converged;
  final bool readOnly;
  final ForgeDeviceInventoryResourceConvergenceAuthority authority;

  const ForgeDeviceInventoryResourceConvergence({
    required this.schemaVersion,
    required this.evaluationMode,
    required this.owner,
    required this.inventory,
    required this.resourceView,
    required this.converged,
    required this.readOnly,
    required this.authority,
  });

  factory ForgeDeviceInventoryResourceConvergence.fromJson(Object? value) {
    final json = _convergenceObject(value, 'envelope');
    _convergenceExactKeys(json, {
      'schema_version',
      'evaluation_mode',
      'inventory',
      'resource_view',
      'converged',
      'read_only',
      'authority',
    });
    if (json['schema_version'] !=
            forgeDeviceInventoryResourceConvergenceSchema ||
        json['evaluation_mode'] !=
            forgeDeviceInventoryResourceConvergenceEvaluationMode ||
        json['converged'] != true ||
        json['read_only'] != true) {
      throw const FormatException(
        'Invalid Forge inventory/resource convergence envelope.',
      );
    }
    final inventory = ForgeDeviceInventoryPageV2.fromJson(json['inventory']);
    final resourceView = ForgeClientInstanceResourceView.fromJson(
      json['resource_view'],
    );
    final owner = inventory.owner;
    if (resourceView.owner != owner ||
        !inventory.ownerDeclarationUnverified ||
        !resourceView.ownerDeclarationUnverified ||
        !resourceView.deviceAttributesUnverified ||
        inventory.executionAuthorized ||
        inventory.reservationCreated ||
        inventory.dispatchPerformed ||
        !resourceView.isDisplayOnly ||
        !_convergedDevices(inventory, resourceView)) {
      throw const FormatException(
        'Forge inventory/resource observations did not converge.',
      );
    }
    final authority = ForgeDeviceInventoryResourceConvergenceAuthority.fromJson(
      json['authority'],
    );
    if (!authority.isOffline) {
      throw const FormatException(
        'Forge inventory/resource convergence claims authority.',
      );
    }
    return ForgeDeviceInventoryResourceConvergence(
      schemaVersion: forgeDeviceInventoryResourceConvergenceSchema,
      evaluationMode: forgeDeviceInventoryResourceConvergenceEvaluationMode,
      owner: owner,
      inventory: inventory,
      resourceView: resourceView,
      converged: true,
      readOnly: true,
      authority: authority,
    );
  }

  factory ForgeDeviceInventoryResourceConvergence.fromJsonText(String source) {
    try {
      if (utf8.encode(source).length > 4 * 1024 * 1024) {
        throw const FormatException(
          'Forge inventory/resource convergence is too large.',
        );
      }
      _convergenceRejectDuplicateKeys(source);
      return ForgeDeviceInventoryResourceConvergence.fromJson(
        jsonDecode(source),
      );
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException(
        'Invalid Forge inventory/resource convergence JSON.',
      );
    }
  }

  bool get isDisplayOnly =>
      schemaVersion == forgeDeviceInventoryResourceConvergenceSchema &&
      evaluationMode == forgeDeviceInventoryResourceConvergenceEvaluationMode &&
      converged &&
      readOnly &&
      authority.isOffline &&
      forgeDeviceInventoryAndResourceObservationsConverged(
        inventory,
        resourceView,
      );

  Map<String, dynamic> toJson() => {
    'schema_version': schemaVersion,
    'evaluation_mode': evaluationMode,
    'inventory': inventory.toJson(),
    'resource_view': resourceView.toJson(),
    'converged': converged,
    'read_only': readOnly,
    'authority': authority.toJson(),
  };
}

bool _convergedDevices(
  ForgeDeviceInventoryPageV2 inventory,
  ForgeClientInstanceResourceView resourceView,
) {
  if (inventory.devices.length != resourceView.devices.length) return false;
  final resources = {
    for (final device in resourceView.devices) device.deviceID: device,
  };
  for (final candidate in inventory.devices) {
    final resource = resources[candidate.device.deviceID];
    if (resource == null || !_convergedDevice(candidate, resource)) {
      return false;
    }
  }
  return true;
}

/// Compares two already-decoded, owner-bound observations without creating a
/// synthetic convergence envelope.  This is a local freshness guard for
/// callers that opened the inventory-v2 and client-instance/resource readers
/// separately; it grants no inventory, placement, lease, or execution
/// authority.
bool forgeDeviceInventoryAndResourceObservationsConverged(
  ForgeDeviceInventoryPageV2 inventory,
  ForgeClientInstanceResourceView resourceView,
) {
  // The public constructors are intentionally usable by native/test seams,
  // so flags alone are not a sufficient freshness proof. Round-trip both
  // values through their strict wire decoders before joining them; this
  // catches malformed manually constructed rows as well as envelope drift.
  late final ForgeDeviceInventoryPageV2 validatedInventory;
  late final ForgeClientInstanceResourceView validatedResourceView;
  try {
    validatedInventory = ForgeDeviceInventoryPageV2.fromJson(
      inventory.toJson(),
    );
    validatedResourceView = ForgeClientInstanceResourceView.fromJson(
      resourceView.toJson(),
    );
  } on FormatException {
    return false;
  }
  return validatedInventory.isDisplayOnly &&
      validatedResourceView.isDisplayOnly &&
      validatedResourceView.owner == validatedInventory.owner &&
      _convergedDevices(validatedInventory, validatedResourceView);
}

bool _convergedDevice(
  ForgeDeviceInventoryCandidateV2 candidate,
  ForgeClientInstanceResourceViewDevice resource,
) {
  final device = candidate.device;
  final availableGpuMemory = device.gpus.fold<int>(
    0,
    (total, gpu) => total + gpu.availableMemoryBytes,
  );
  return candidate.instanceID == resource.runnerInstanceID &&
      candidate.revision == resource.revision &&
      candidate.generation == resource.generation &&
      candidate.heartbeatSequence == resource.heartbeatSequence &&
      device.owner == resource.owner &&
      device.approvalState == resource.approvalState &&
      device.cordonState == resource.cordonState &&
      device.reservationState == resource.reservationState &&
      device.liveness == resource.liveness &&
      device.snapshotObservedAtMS == resource.observedAtMS &&
      device.os == resource.os &&
      device.architecture == resource.architecture &&
      device.availableCPUCores == resource.availableCPUCores &&
      device.availableMemoryBytes == resource.availableMemoryBytes &&
      device.availableStorageBytes == resource.availableStorageBytes &&
      device.gpus.length == resource.gpuCount &&
      availableGpuMemory == resource.availableGPUMemoryBytes;
}

Map<String, dynamic> _convergenceObject(Object? value, String label) {
  if (value is! Map) {
    throw FormatException(
      'Forge inventory/resource convergence $label must be an object.',
    );
  }
  return value.map<String, dynamic>(
    (key, value) => MapEntry(key.toString(), value),
  );
}

void _convergenceExactKeys(Map<String, dynamic> json, Set<String> expected) {
  if (json.length != expected.length ||
      json.keys.any((key) => !expected.contains(key))) {
    throw const FormatException(
      'Unexpected Forge inventory/resource convergence fields.',
    );
  }
}

void _convergenceRejectDuplicateKeys(String source) {
  final objects = <Set<String>>[];
  var inString = false;
  var escaped = false;
  var stringStart = 0;
  for (var index = 0; index < source.length; index++) {
    final char = source[index];
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (char == '\\') {
        escaped = true;
      } else if (char == '"') {
        inString = false;
        var next = index + 1;
        while (next < source.length && source[next].trim().isEmpty) {
          next++;
        }
        if (next < source.length && source[next] == ':') {
          final key = jsonDecode(source.substring(stringStart, index + 1));
          if (key is! String || objects.isEmpty || !objects.last.add(key)) {
            throw const FormatException(
              'Duplicate Forge inventory/resource convergence JSON key.',
            );
          }
        }
      }
      continue;
    }
    if (char == '"') {
      inString = true;
      stringStart = index;
    } else if (char == '{') {
      objects.add(<String>{});
    } else if (char == '}') {
      if (objects.isEmpty) {
        throw const FormatException(
          'Invalid Forge inventory/resource convergence JSON.',
        );
      }
      objects.removeLast();
    }
  }
  if (inString || objects.isNotEmpty) {
    throw const FormatException(
      'Invalid Forge inventory/resource convergence JSON.',
    );
  }
}
