import 'dart:convert';

import 'forge_device_inventory_placement_batch_evaluation.dart';
import 'forge_device_inventory_declaration.dart';

/// Strict response projection for the authenticated registry-backed
/// placement-preview candidate.
///
/// The HTTP response deliberately does not contain the caller fixture's
/// observation or requirements. It is a read-only comparison over the
/// owner-scoped persisted observation and never selects, reserves, schedules,
/// dispatches, or executes work.
const forgeDeviceRegistryPlacementPreviewSchema =
    'forge.device-inventory-placement-evaluation/v2';
const forgeDeviceRegistryPlacementPreviewEvaluationMode = 'offline_static_only';
const forgeDeviceRegistryPlacementPreviewSourceSchema =
    'forge.device-inventory-observation/v2';
const forgeDeviceRegistryPlacementPreviewNotice =
    'Every owner, state, timestamp, resource, GPU, reservation, residency, trust, sandbox, and concurrency value is an unverified caller declaration. This read-only comparison selects no target and grants no execution authority.';
const forgeDeviceRegistryPlacementPreviewMaxDecisions = 128;
const _forgeDeviceRegistryPlacementPreviewMaxSafeInteger = 9007199254740991;

class ForgeDeviceRegistryPlacementPreview {
  final String schemaVersion;
  final String evaluationMode;
  final String sourceSchemaVersion;
  final ForgeDeviceOwner evaluationOwner;
  final int evaluatedAtMS;
  final String notice;
  final List<ForgeDeviceRegistryPlacementDecision> decisions;
  final int eligibleCandidateCount;
  final String? selectedDeviceID;
  final String? selectedInstanceID;
  final ForgeDeviceInventoryPlacementBatchAuthority authority;

  const ForgeDeviceRegistryPlacementPreview({
    required this.schemaVersion,
    required this.evaluationMode,
    required this.sourceSchemaVersion,
    required this.evaluationOwner,
    required this.evaluatedAtMS,
    required this.notice,
    required this.decisions,
    required this.eligibleCandidateCount,
    required this.selectedDeviceID,
    required this.selectedInstanceID,
    required this.authority,
  });

  factory ForgeDeviceRegistryPlacementPreview.fromJsonText(String source) {
    if (utf8.encode(source).length > 2 * 1024 * 1024) {
      throw const FormatException(
        'Forge registry placement preview is too large.',
      );
    }
    _rejectDuplicateRegistryPlacementKeys(source);
    return ForgeDeviceRegistryPlacementPreview.fromJson(jsonDecode(source));
  }

  factory ForgeDeviceRegistryPlacementPreview.fromJson(Object? value) {
    final json = _registryPlacementObject(value);
    _registryPlacementExactKeys(json, {
      'schema_version',
      'evaluation_mode',
      'source_schema_version',
      'evaluation_owner',
      'evaluated_at_ms',
      'notice',
      'decisions',
      'eligible_candidate_count',
      'selected_device_id',
      'selected_instance_id',
      'authority',
    });
    if (json['schema_version'] != forgeDeviceRegistryPlacementPreviewSchema ||
        json['evaluation_mode'] !=
            forgeDeviceRegistryPlacementPreviewEvaluationMode ||
        json['source_schema_version'] !=
            forgeDeviceRegistryPlacementPreviewSourceSchema ||
        json['notice'] != forgeDeviceRegistryPlacementPreviewNotice) {
      throw const FormatException(
        'Invalid Forge registry placement preview envelope.',
      );
    }
    if (json['selected_device_id'] != null ||
        json['selected_instance_id'] != null) {
      throw const FormatException(
        'Forge registry placement preview selected a device.',
      );
    }
    final owner = ForgeDeviceOwner.fromJson(json['evaluation_owner']);
    final evaluatedAt = _registryPlacementSafePositiveInt(
      json['evaluated_at_ms'],
    );
    final decisions = _registryPlacementDecisions(json['decisions']);
    final eligible = _registryPlacementSafeNonNegativeInt(
      json['eligible_candidate_count'],
    );
    if (eligible !=
        decisions.where((decision) => decision.matchesRequirements).length) {
      throw const FormatException(
        'Forge registry placement eligible count drifted.',
      );
    }
    final authority = ForgeDeviceInventoryPlacementBatchAuthority.fromJson(
      json['authority'],
    );
    if (authority.anyGranted) {
      throw const FormatException(
        'Forge registry placement preview grants authority.',
      );
    }
    return ForgeDeviceRegistryPlacementPreview(
      schemaVersion: forgeDeviceRegistryPlacementPreviewSchema,
      evaluationMode: forgeDeviceRegistryPlacementPreviewEvaluationMode,
      sourceSchemaVersion: forgeDeviceRegistryPlacementPreviewSourceSchema,
      evaluationOwner: owner,
      evaluatedAtMS: evaluatedAt,
      notice: forgeDeviceRegistryPlacementPreviewNotice,
      decisions: List.unmodifiable(decisions),
      eligibleCandidateCount: eligible,
      selectedDeviceID: null,
      selectedInstanceID: null,
      authority: authority,
    );
  }

  Map<String, dynamic> toJson() => {
    'schema_version': schemaVersion,
    'evaluation_mode': evaluationMode,
    'source_schema_version': sourceSchemaVersion,
    'evaluation_owner': evaluationOwner.toJson(),
    'evaluated_at_ms': evaluatedAtMS,
    'notice': notice,
    'decisions': decisions.map((decision) => decision.toJson()).toList(),
    'eligible_candidate_count': eligibleCandidateCount,
    'selected_device_id': selectedDeviceID,
    'selected_instance_id': selectedInstanceID,
    'authority': {
      'identity_verified': authority.identityVerified,
      'heartbeat_persisted': authority.heartbeatPersisted,
      'inventory_authoritative': authority.inventoryAuthoritative,
      'placement_selected': authority.placementSelected,
      'reservation_created': authority.reservationCreated,
      'execution_authorized': authority.executionAuthorized,
      'dispatch_performed': authority.dispatchPerformed,
    },
  };
}

class ForgeDeviceRegistryPlacementDecision {
  final int revision;
  final int generation;
  final int heartbeatSequence;
  final String deviceID;
  final String instanceID;
  final String reservationState;
  final int gpuCount;
  final int availableGPUMemoryBytes;
  final bool matchesRequirements;
  final List<String> exclusionReasons;
  final bool ownerDeclarationUnverified;
  final bool deviceAttributesUnverified;

  const ForgeDeviceRegistryPlacementDecision({
    required this.revision,
    required this.generation,
    required this.heartbeatSequence,
    required this.deviceID,
    required this.instanceID,
    required this.reservationState,
    required this.gpuCount,
    required this.availableGPUMemoryBytes,
    required this.matchesRequirements,
    required this.exclusionReasons,
    required this.ownerDeclarationUnverified,
    required this.deviceAttributesUnverified,
  });

  factory ForgeDeviceRegistryPlacementDecision.fromJson(Object? value) {
    final json = _registryPlacementObject(value);
    _registryPlacementExactKeys(json, {
      'revision',
      'generation',
      'heartbeat_sequence',
      'device_id',
      'instance_id',
      'reservation_state',
      'gpu_count',
      'available_gpu_memory_bytes',
      'matches_requirements',
      'exclusion_reasons',
      'owner_declaration_unverified',
      'device_attributes_unverified',
    });
    final matches = json['matches_requirements'];
    if (matches is! bool) {
      throw const FormatException('Invalid Forge registry placement match.');
    }
    final ownerUnverified = json['owner_declaration_unverified'];
    final deviceUnverified = json['device_attributes_unverified'];
    if (ownerUnverified is! bool ||
        !ownerUnverified ||
        deviceUnverified is! bool ||
        !deviceUnverified) {
      throw const FormatException(
        'Forge registry placement declaration became authoritative.',
      );
    }
    final reasons = _registryPlacementReasons(json['exclusion_reasons']);
    if (matches != reasons.isEmpty) {
      throw const FormatException(
        'Forge registry placement match/reasons drifted.',
      );
    }
    final reservation = json['reservation_state'];
    if (reservation is! String ||
        !const {'none', 'reserved'}.contains(reservation)) {
      throw const FormatException(
        'Invalid Forge registry placement reservation state.',
      );
    }
    return ForgeDeviceRegistryPlacementDecision(
      revision: _registryPlacementSafePositiveInt(json['revision']),
      generation: _registryPlacementSafePositiveInt(json['generation']),
      heartbeatSequence: _registryPlacementSafePositiveInt(
        json['heartbeat_sequence'],
      ),
      deviceID: _registryPlacementIdentifier(json['device_id']),
      instanceID: _registryPlacementIdentifier(json['instance_id']),
      reservationState: reservation,
      gpuCount: _registryPlacementBoundedInt(json['gpu_count'], 32),
      availableGPUMemoryBytes: _registryPlacementSafeNonNegativeInt(
        json['available_gpu_memory_bytes'],
      ),
      matchesRequirements: matches,
      exclusionReasons: List.unmodifiable(reasons),
      ownerDeclarationUnverified: true,
      deviceAttributesUnverified: true,
    );
  }

  Map<String, dynamic> toJson() => {
    'revision': revision,
    'generation': generation,
    'heartbeat_sequence': heartbeatSequence,
    'device_id': deviceID,
    'instance_id': instanceID,
    'reservation_state': reservationState,
    'gpu_count': gpuCount,
    'available_gpu_memory_bytes': availableGPUMemoryBytes,
    'matches_requirements': matchesRequirements,
    'exclusion_reasons': exclusionReasons,
    'owner_declaration_unverified': ownerDeclarationUnverified,
    'device_attributes_unverified': deviceAttributesUnverified,
  };
}

List<ForgeDeviceRegistryPlacementDecision> _registryPlacementDecisions(
  Object? value,
) {
  if (value is! List ||
      value.length > forgeDeviceRegistryPlacementPreviewMaxDecisions) {
    throw const FormatException('Invalid Forge registry placement decisions.');
  }
  final decisions = value
      .map(ForgeDeviceRegistryPlacementDecision.fromJson)
      .toList(growable: false);
  final pairs = <String>{};
  for (var index = 0; index < decisions.length; index++) {
    final decision = decisions[index];
    if (!pairs.add('${decision.deviceID}\u0000${decision.instanceID}')) {
      throw const FormatException(
        'Forge registry placement decisions repeat a candidate.',
      );
    }
    if (index > 0) {
      final previous = decisions[index - 1];
      final deviceOrder = _registryPlacementCompare(
        previous.deviceID,
        decision.deviceID,
      );
      if (deviceOrder > 0 ||
          (deviceOrder == 0 &&
              _registryPlacementCompare(
                    previous.instanceID,
                    decision.instanceID,
                  ) >=
                  0)) {
        throw const FormatException(
          'Forge registry placement decisions are unsorted.',
        );
      }
    }
  }
  return decisions;
}

Map<String, dynamic> _registryPlacementObject(Object? value) {
  if (value is! Map) {
    throw const FormatException('Invalid Forge registry placement object.');
  }
  return Map<String, dynamic>.from(value);
}

void _registryPlacementExactKeys(
  Map<String, dynamic> value,
  Set<String> expected,
) {
  if (value.length != expected.length ||
      value.keys.any((key) => !expected.contains(key))) {
    throw const FormatException('Unexpected Forge registry placement fields.');
  }
}

int _registryPlacementSafePositiveInt(Object? value) {
  final parsed = _registryPlacementSafeNonNegativeInt(value);
  if (parsed <= 0) {
    throw const FormatException('Invalid Forge registry placement integer.');
  }
  return parsed;
}

int _registryPlacementSafeNonNegativeInt(Object? value) {
  if (value is! int ||
      value < 0 ||
      value > _forgeDeviceRegistryPlacementPreviewMaxSafeInteger) {
    throw const FormatException('Invalid Forge registry placement integer.');
  }
  return value;
}

int _registryPlacementBoundedInt(Object? value, int maximum) {
  final parsed = _registryPlacementSafeNonNegativeInt(value);
  if (parsed > maximum) {
    throw const FormatException('Invalid Forge registry placement count.');
  }
  return parsed;
}

String _registryPlacementIdentifier(Object? value) {
  if (value is! String ||
      value.isEmpty ||
      value.length > 128 ||
      !_registryPlacementASCIIIdentifier(value)) {
    throw const FormatException('Invalid Forge registry placement identifier.');
  }
  return value;
}

bool _registryPlacementASCIIIdentifier(String value) {
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

List<String> _registryPlacementReasons(Object? value) {
  if (value is! List || value.length > 64) {
    throw const FormatException('Invalid Forge registry placement reasons.');
  }
  final reasons = <String>[];
  for (final item in value) {
    if (item is! String || item.isEmpty || item.length > 128) {
      throw const FormatException('Invalid Forge registry placement reason.');
    }
    if (item.runes.any(
      (rune) => rune < 0x20 || (rune >= 0x7f && rune <= 0x9f),
    )) {
      throw const FormatException('Invalid Forge registry placement reason.');
    }
    reasons.add(item);
  }
  for (var index = 1; index < reasons.length; index++) {
    if (_registryPlacementCompare(reasons[index - 1], reasons[index]) >= 0) {
      throw const FormatException(
        'Forge registry placement reasons are unsorted.',
      );
    }
  }
  return reasons;
}

int _registryPlacementCompare(String left, String right) {
  final length = left.length < right.length ? left.length : right.length;
  for (var index = 0; index < length; index++) {
    final compared = left.codeUnitAt(index).compareTo(right.codeUnitAt(index));
    if (compared != 0) return compared;
  }
  return left.length.compareTo(right.length);
}

/// Detect repeated JSON object members before Dart's decoder overwrites one.
void _rejectDuplicateRegistryPlacementKeys(String source) {
  _RegistryPlacementDuplicateScanner(source).scan();
}

class _RegistryPlacementDuplicateScanner {
  final String source;
  var index = 0;

  _RegistryPlacementDuplicateScanner(this.source);

  void scan() {
    _space();
    _value();
    _space();
    if (index != source.length) {
      throw const FormatException('Invalid JSON.');
    }
  }

  void _value() {
    if (index >= source.length) throw const FormatException('Invalid JSON.');
    switch (source[index]) {
      case '{':
        _object();
      case '[':
        _array();
      case '"':
        _string();
      case 't':
        _literal('true');
      case 'f':
        _literal('false');
      case 'n':
        _literal('null');
      default:
        _number();
    }
  }

  void _object() {
    index++;
    _space();
    final keys = <String>{};
    if (_consume('}')) return;
    while (true) {
      if (index >= source.length || source[index] != '"') {
        throw const FormatException('Invalid JSON.');
      }
      final key = _string();
      if (!keys.add(key)) throw const FormatException('Duplicate JSON key.');
      _space();
      _expect(':');
      _space();
      _value();
      _space();
      if (_consume('}')) return;
      _expect(',');
      _space();
    }
  }

  void _array() {
    index++;
    _space();
    if (_consume(']')) return;
    while (true) {
      _value();
      _space();
      if (_consume(']')) return;
      _expect(',');
      _space();
    }
  }

  String _string() {
    final start = index;
    _expect('"');
    while (index < source.length) {
      final character = source[index++];
      if (character == '"') {
        final decoded = jsonDecode(source.substring(start, index));
        if (decoded is! String) throw const FormatException('Invalid JSON.');
        return decoded;
      }
      if (character == '\\') {
        if (index >= source.length) {
          throw const FormatException('Invalid JSON.');
        }
        final escaped = source[index++];
        if (escaped == 'u') {
          if (index + 4 > source.length) {
            throw const FormatException('Invalid JSON.');
          }
          for (var digit = 0; digit < 4; digit++) {
            if (!_hex(source[index++])) {
              throw const FormatException('Invalid JSON.');
            }
          }
        } else if (!'"\\/bfnrt'.contains(escaped)) {
          throw const FormatException('Invalid JSON.');
        }
      } else if (character.codeUnitAt(0) < 0x20) {
        throw const FormatException('Invalid JSON.');
      }
    }
    throw const FormatException('Invalid JSON.');
  }

  void _literal(String literal) {
    if (!source.startsWith(literal, index)) {
      throw const FormatException('Invalid JSON.');
    }
    index += literal.length;
  }

  void _number() {
    final start = index;
    if (_consume('-') && index >= source.length) {
      throw const FormatException('Invalid JSON.');
    }
    if (_consume('0')) {
      if (index < source.length && _digit(source[index])) {
        throw const FormatException('Invalid JSON.');
      }
    } else {
      if (index >= source.length || !_nonZeroDigit(source[index])) {
        throw const FormatException('Invalid JSON.');
      }
      while (index < source.length && _digit(source[index])) {
        index++;
      }
    }
    if (_consume('.')) {
      if (index >= source.length || !_digit(source[index])) {
        throw const FormatException('Invalid JSON.');
      }
      while (index < source.length && _digit(source[index])) {
        index++;
      }
    }
    if (index < source.length && 'eE'.contains(source[index])) {
      index++;
      if (index < source.length && '+-'.contains(source[index])) {
        index++;
      }
      if (index >= source.length || !_digit(source[index])) {
        throw const FormatException('Invalid JSON.');
      }
      while (index < source.length && _digit(source[index])) {
        index++;
      }
    }
    if (start == index) throw const FormatException('Invalid JSON.');
  }

  void _space() {
    while (index < source.length && ' \t\r\n'.contains(source[index])) {
      index++;
    }
  }

  bool _consume(String value) {
    if (index < source.length && source[index] == value) {
      index++;
      return true;
    }
    return false;
  }

  void _expect(String value) {
    if (!_consume(value)) throw const FormatException('Invalid JSON.');
  }

  static bool _digit(String value) =>
      value.codeUnitAt(0) >= 0x30 && value.codeUnitAt(0) <= 0x39;
  static bool _nonZeroDigit(String value) =>
      value.codeUnitAt(0) >= 0x31 && value.codeUnitAt(0) <= 0x39;
  static bool _hex(String value) => '0123456789abcdefABCDEF'.contains(value);
}
