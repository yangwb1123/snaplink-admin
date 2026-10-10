import 'dart:convert';

import 'forge_device_inventory_declaration.dart';

part 'forge_device_inventory_v2_models_devices.dart';
part 'forge_device_inventory_v2_models_codec.dart';

/// Bounded local reader seam for the lossless v2 inventory preview. The
/// default Sessions surface uses the platform workspace picker; tests and
/// native shells can inject a reader without opening an inventory route.
typedef ForgeDeviceInventoryV2FileReader = Future<String?> Function();

const _forgeDeviceInventoryV2Schema = 'forge.device-inventory-observation/v2';
const _forgeDeviceInventoryV2Mode = 'offline_static_only';
const _forgeDeviceInventoryV2MaxSafeInteger = 9007199254740991;
const _forgeDeviceInventoryV2MaxDevices = 128;
const _forgeDeviceInventoryV2MaxArrayItems = 32;
const _forgeDeviceInventoryV2MaxGPUCount = 32;
const _forgeDeviceInventoryV2MaxCPUCores = 4096;
const _forgeDeviceInventoryV2MinLeaseTTLMS = 1000;
const _forgeDeviceInventoryV2MaxLeaseTTLMS = 600000;
const _forgeDeviceInventoryV2Notice =
    'Every owner, instance, state, timestamp, resource, GPU, reservation, residency, trust, sandbox, and concurrency value is an unverified caller declaration. This read-only observation selects no target and grants no execution authority.';

const forgeDeviceInventoryV2Schema = _forgeDeviceInventoryV2Schema;
const forgeDeviceInventoryV2EvaluationMode = _forgeDeviceInventoryV2Mode;
const forgeDeviceInventoryV2Notice = _forgeDeviceInventoryV2Notice;

/// Lossless, display-only inventory observation. This v2 model is kept
/// separate from the v1 UI model so adding reservation and multi-GPU data
/// cannot silently change the existing contract.
class ForgeDeviceInventoryPageV2 {
  final String evaluationMode;
  final int evaluatedAtMS;
  final ForgeDeviceOwner owner;
  final bool ownerDeclarationUnverified;
  final bool inventoryDeclarationsUnverified;
  final String notice;
  final List<ForgeDeviceInventoryCandidateV2> devices;
  final bool executionAuthorized;
  final bool reservationCreated;
  final bool dispatchPerformed;

  const ForgeDeviceInventoryPageV2({
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

  /// Whether this value still carries the bounded, display-only v2 contract.
  ///
  /// [fromJson] enforces these invariants while decoding wire data, but the
  /// public constructor is also used by native/test seams.  Local
  /// convergence guards must therefore re-check the envelope before using a
  /// manually constructed observation as a freshness boundary.
  bool get isDisplayOnly =>
      evaluationMode == _forgeDeviceInventoryV2Mode &&
      evaluatedAtMS > 0 &&
      ownerDeclarationUnverified &&
      inventoryDeclarationsUnverified &&
      notice == _forgeDeviceInventoryV2Notice &&
      !executionAuthorized &&
      !reservationCreated &&
      !dispatchPerformed;

  /// Decodes one bounded raw JSON document without allowing duplicate object
  /// keys to be silently replaced by [dart:convert].
  factory ForgeDeviceInventoryPageV2.fromJsonText(String source) {
    if (utf8.encode(source).length > 2 * 1024 * 1024) {
      throw const FormatException(
        'Forge v2 device observation document is too large.',
      );
    }
    _v2RejectDuplicateKeys(source);
    return ForgeDeviceInventoryPageV2.fromJson(jsonDecode(source));
  }

  factory ForgeDeviceInventoryPageV2.fromJson(Object? value) {
    final json = _v2Object(value);
    _v2ExactKeys(json, {
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
    if (json['schema_version'] != _forgeDeviceInventoryV2Schema ||
        json['evaluation_mode'] != _forgeDeviceInventoryV2Mode ||
        json['owner_declaration_unverified'] != true ||
        json['inventory_declarations_unverified'] != true ||
        json['notice'] != _forgeDeviceInventoryV2Notice ||
        json['execution_authorized'] != false ||
        json['reservation_created'] != false ||
        json['dispatch_performed'] != false) {
      throw const FormatException(
        'Invalid Forge v2 device observation envelope.',
      );
    }
    final evaluatedAt = _v2PositiveInt(json['evaluated_at_ms']);
    final owner = ForgeDeviceOwner.fromJson(json['owner_declaration']);
    final rawDevices = json['devices'];
    if (rawDevices is! List ||
        rawDevices.length > _forgeDeviceInventoryV2MaxDevices) {
      throw const FormatException('Invalid Forge v2 device observations.');
    }
    final devices = rawDevices
        .map((row) => ForgeDeviceInventoryCandidateV2.fromJson(row, owner))
        .toList(growable: false);
    final instances = <String>{};
    for (var index = 0; index < devices.length; index++) {
      final candidate = devices[index];
      if (!instances.add(candidate.instanceID)) {
        throw const FormatException(
          'Forge v2 observations contain duplicate instances.',
        );
      }
      if (index > 0 &&
          _v2CompareIDs(
                devices[index - 1].device.deviceID,
                candidate.device.deviceID,
              ) >=
              0) {
        throw const FormatException('Forge v2 observations are unsorted.');
      }
    }
    return ForgeDeviceInventoryPageV2(
      evaluationMode: _forgeDeviceInventoryV2Mode,
      evaluatedAtMS: evaluatedAt,
      owner: owner,
      ownerDeclarationUnverified: true,
      inventoryDeclarationsUnverified: true,
      notice: _forgeDeviceInventoryV2Notice,
      devices: devices,
      executionAuthorized: false,
      reservationCreated: false,
      dispatchPerformed: false,
    );
  }

  Map<String, dynamic> toJson() => {
    'schema_version': _forgeDeviceInventoryV2Schema,
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

class ForgeDeviceInventoryCandidateV2 {
  final String instanceID;
  final int revision;
  final int generation;
  final int heartbeatSequence;
  final ForgeDeviceV2 device;

  const ForgeDeviceInventoryCandidateV2({
    required this.instanceID,
    required this.revision,
    required this.generation,
    required this.heartbeatSequence,
    required this.device,
  });

  factory ForgeDeviceInventoryCandidateV2.fromJson(
    Object? value,
    ForgeDeviceOwner owner,
  ) {
    final json = _v2Object(value);
    _v2ExactKeys(json, {
      'instance_id',
      'revision',
      'generation',
      'heartbeat_sequence',
      'device',
    });
    final device = ForgeDeviceV2.fromJson(json['device']);
    if (device.owner != owner) {
      throw const FormatException('Forge v2 device owner mismatch.');
    }
    return ForgeDeviceInventoryCandidateV2(
      instanceID: _v2Identifier(json['instance_id']),
      revision: _v2PositiveInt(json['revision']),
      generation: _v2PositiveInt(json['generation']),
      heartbeatSequence: _v2PositiveInt(json['heartbeat_sequence']),
      device: device,
    );
  }

  Map<String, dynamic> toJson() => {
    'instance_id': instanceID,
    'revision': revision,
    'generation': generation,
    'heartbeat_sequence': heartbeatSequence,
    'device': device.toJson(),
  };
}
