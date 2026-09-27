export 'forge_device_inventory_declaration.dart';
export 'forge_device_inventory_placement_batch_evaluation.dart';
export 'forge_device_inventory_persistence.dart';
export 'forge_device_inventory_placement_evaluation.dart';
export 'forge_device_inventory_placement_input.dart';
export 'forge_device_placement.dart';
export 'forge_device_inventory_snapshot.dart';
export 'forge_device_inventory_status.dart';
export 'forge_device_resource_summary.dart';
export 'forge_device_heartbeat_persistence.dart';
export 'forge_device_heartbeat.dart';
export 'forge_device_identity.dart';
export 'forge_pending_write_recovery.dart';
export 'forge_device_inventory_v2_models.dart';
export 'forge_device_inventory_resource_convergence.dart';
export 'forge_device_inventory_placement_evaluation_v2.dart';
export 'forge_device_registry_placement_preview.dart';

import 'forge_device_inventory_declaration.dart';

const _inventorySchema = 'forge.device-inventory-observation/v1';
const _inventoryMode = 'offline_static_only';
const _maxSafeForgeDeviceInteger = 9007199254740991;
const _inventoryNotice =
    'Every owner, instance, state, timestamp, resource, residency, trust, sandbox, and concurrency value is an unverified caller declaration. This read-only observation selects no target and grants no execution authority.';

/// Public contract constants for callers that construct the typed offline
/// observation in memory. `fromJson` remains the strict boundary for external
/// data.
const forgeDeviceInventorySchema = _inventorySchema;
const forgeDeviceInventoryEvaluationMode = _inventoryMode;
const forgeDeviceInventoryNotice = _inventoryNotice;

/// A bounded caller-supplied observation. It has no network or execution role.
class ForgeDeviceInventoryPage {
  final String evaluationMode;
  final int evaluatedAtMS;
  final ForgeDeviceOwner owner;
  final bool ownerDeclarationUnverified;
  final bool inventoryDeclarationsUnverified;
  final String notice;
  final List<ForgeDeviceInventoryCandidate> devices;
  final bool executionAuthorized;
  final bool reservationCreated;
  final bool dispatchPerformed;

  const ForgeDeviceInventoryPage({
    required this.evaluationMode,
    required this.evaluatedAtMS,
    required this.owner,
    required this.ownerDeclarationUnverified,
    required this.inventoryDeclarationsUnverified,
    required this.notice,
    required this.devices,
    required this.executionAuthorized,
    required this.reservationCreated,
    required this.dispatchPerformed,
  });

  factory ForgeDeviceInventoryPage.fromJson(Object? value) {
    final json = _object(value);
    _exactKeys(json, {
      'schema_version',
      'evaluation_mode',
      'evaluated_at_ms',
      'owner_declaration',
      'owner_declaration_unverified',
      'inventory_declarations_unverified',
      'notice',
      'devices',
      'execution_authorized',
      'reservation_created',
      'dispatch_performed',
    });
    if (json['schema_version'] != _inventorySchema ||
        json['evaluation_mode'] != _inventoryMode ||
        json['owner_declaration_unverified'] != true ||
        json['inventory_declarations_unverified'] != true ||
        json['notice'] != _inventoryNotice ||
        json['execution_authorized'] != false ||
        json['reservation_created'] != false ||
        json['dispatch_performed'] != false) {
      throw const FormatException('Invalid Forge device observation envelope.');
    }
    final evaluatedAt = _positiveInt(json['evaluated_at_ms']);
    final owner = ForgeDeviceOwner.fromJson(json['owner_declaration']);
    final rawDevices = json['devices'];
    if (rawDevices is! List || rawDevices.length > 128) {
      throw const FormatException('Invalid Forge device observation devices.');
    }
    final devices = rawDevices
        .map((row) => ForgeDeviceInventoryCandidate.fromJson(row, owner))
        .toList(growable: false);
    final instanceIDs = <String>{};
    for (var index = 1; index < devices.length; index++) {
      if (_compareIDs(
            devices[index - 1].device.deviceID,
            devices[index].device.deviceID,
          ) >=
          0) {
        throw const FormatException('Forge device observations are unsorted.');
      }
    }
    for (final candidate in devices) {
      if (!instanceIDs.add(candidate.instanceID)) {
        throw const FormatException(
          'Forge device observations contain duplicate instances.',
        );
      }
    }
    return ForgeDeviceInventoryPage(
      evaluationMode: _inventoryMode,
      evaluatedAtMS: evaluatedAt,
      owner: owner,
      ownerDeclarationUnverified: true,
      inventoryDeclarationsUnverified: true,
      notice: _inventoryNotice,
      devices: devices,
      executionAuthorized: false,
      reservationCreated: false,
      dispatchPerformed: false,
    );
  }

  Map<String, dynamic> toJson() => {
    'schema_version': _inventorySchema,
    'evaluation_mode': evaluationMode,
    'evaluated_at_ms': evaluatedAtMS,
    'owner_declaration': owner.toJson(),
    'owner_declaration_unverified': ownerDeclarationUnverified,
    'inventory_declarations_unverified': inventoryDeclarationsUnverified,
    'notice': notice,
    'devices': devices.map((candidate) => candidate.toJson()).toList(),
    'execution_authorized': executionAuthorized,
    'reservation_created': reservationCreated,
    'dispatch_performed': dispatchPerformed,
  };
}

class ForgeDeviceInventoryCandidate {
  final String instanceID;
  final ForgeDeviceDeclaration device;

  const ForgeDeviceInventoryCandidate({
    required this.instanceID,
    required this.device,
  });

  factory ForgeDeviceInventoryCandidate.fromJson(
    Object? value,
    ForgeDeviceOwner owner,
  ) {
    final json = _object(value);
    _exactKeys(json, {'instance_id', 'device'});
    final instanceID = _identifier(json['instance_id']);
    final device = ForgeDeviceDeclaration.fromJson(json['device']);
    if (device.owner != owner) {
      throw const FormatException('Forge device owner declaration mismatch.');
    }
    return ForgeDeviceInventoryCandidate(
      instanceID: instanceID,
      device: device,
    );
  }

  Map<String, dynamic> toJson() => {
    'instance_id': instanceID,
    'device': device.toJson(),
  };
}

Map<String, dynamic> _object(Object? value) {
  if (value is! Map) {
    throw const FormatException('Expected Forge device object.');
  }
  return Map<String, dynamic>.from(value);
}

void _exactKeys(Map<String, dynamic> json, Set<String> expected) {
  if (json.length != expected.length ||
      json.keys.any((key) => !expected.contains(key))) {
    throw const FormatException('Unexpected Forge device observation fields.');
  }
}

String _identifier(Object? value) {
  if (value is! String ||
      value.isEmpty ||
      value.length > 128 ||
      !_asciiIdentifier(value)) {
    throw const FormatException('Invalid Forge device identifier.');
  }
  return value;
}

bool _asciiIdentifier(String value) {
  bool first(int code) =>
      code >= 0x30 && code <= 0x39 ||
      code >= 0x41 && code <= 0x5a ||
      code >= 0x61 && code <= 0x7a;
  bool rest(int code) =>
      first(code) ||
      code == 0x2e ||
      code == 0x5f ||
      code == 0x3a ||
      code == 0x2d;
  final codes = value.codeUnits;
  return first(codes.first) && codes.skip(1).every(rest);
}

int _positiveInt(Object? value) {
  if (value is! int || value <= 0 || value > _maxSafeForgeDeviceInteger) {
    throw const FormatException('Expected positive Forge integer.');
  }
  return value;
}

int _compareIDs(String left, String right) {
  final length = left.length < right.length ? left.length : right.length;
  for (var index = 0; index < length; index++) {
    final compared = left.codeUnitAt(index).compareTo(right.codeUnitAt(index));
    if (compared != 0) return compared;
  }
  return left.length.compareTo(right.length);
}
