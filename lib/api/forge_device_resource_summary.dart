import 'dart:convert';

import 'forge_device_inventory_models.dart';
import 'forge_session_placement.dart';

const forgeDeviceResourceSummarySchema = 'forge.device-resource-summary/v1';
const forgeDeviceResourceSummaryEvaluationMode = 'offline_static_only';
const forgeDeviceResourceSummaryMaxDeclarations = 128;
const forgeDeviceResourceSummaryMaxSafeInteger = 9007199254740991;
const forgeDeviceResourceSummaryNotice =
    'Every owner, instance, resource, placement, and eligibility value is an unverified caller declaration. This read-only summary aggregates declarations, selects no target, and grants no execution authority.';
const forgeDeviceResourceSummaryContractAPIVersion =
    'forgeos.device-resource-summary-contract/v1';
const forgeDeviceResourceSummaryInventoryFixture =
    'forge-device-inventory-observation-v1';
const forgeDeviceResourceSummaryPlacementFixture =
    'forge-session-placement-observation-v1';
const forgeDeviceResourceSummaryMaxInputBytes = 512 * 1024;

/// Bounded local reader seam for the complete multi-instance resource-summary
/// fixture. A reader is used only by the display-only Sessions preview; it
/// never opens a device or placement route.
typedef ForgeDeviceResourceSummaryFileReader = Future<String?> Function();

/// The complete offline resource-summary fixture emitted by Runtime. The
/// nested inventory and placement observations are decoded before the
/// expected aggregate is accepted, so a caller cannot import a hand-edited
/// total that disagrees with its declarations.
class ForgeDeviceResourceSummaryFixture {
  final ForgeDeviceOwner owner;
  final ForgeDeviceInventoryPage inventory;
  final ForgeSessionPlacementObservation placementObservation;
  final ForgeDeviceResourceSummary expected;

  const ForgeDeviceResourceSummaryFixture({
    required this.owner,
    required this.inventory,
    required this.placementObservation,
    required this.expected,
  });

  factory ForgeDeviceResourceSummaryFixture.fromJsonText(String source) {
    if (utf8.encode(source).length > forgeDeviceResourceSummaryMaxInputBytes) {
      throw const FormatException(
        'Forge resource summary document is too large.',
      );
    }
    _summaryFixtureRejectDuplicateKeys(source);
    return ForgeDeviceResourceSummaryFixture.fromJson(jsonDecode(source));
  }

  factory ForgeDeviceResourceSummaryFixture.fromJson(Object? value) {
    final json = _summaryObject(value);
    _summaryExactKeys(json, {
      'api_version',
      'inventory_contract_fixture',
      'placement_contract_fixture',
      'owner',
      'inventory',
      'placement_observation',
      'expected',
    });
    if (json['api_version'] != forgeDeviceResourceSummaryContractAPIVersion ||
        json['inventory_contract_fixture'] !=
            forgeDeviceResourceSummaryInventoryFixture ||
        json['placement_contract_fixture'] !=
            forgeDeviceResourceSummaryPlacementFixture) {
      throw const FormatException('Invalid Forge resource summary fixture.');
    }
    final owner = ForgeDeviceOwner.fromJson(json['owner']);
    final inventory = ForgeDeviceInventoryPage.fromJson(json['inventory']);
    if (inventory.owner != owner) {
      throw const FormatException(
        'Forge resource summary inventory owner mismatch.',
      );
    }
    final placement = ForgeSessionPlacementObservation.fromJson(
      json['placement_observation'],
    );
    if (placement.owner != owner) {
      throw const FormatException(
        'Forge resource summary placement owner mismatch.',
      );
    }
    final expectedJSON = _summaryObject(json['expected']);
    _summaryExactKeys(expectedJSON, {
      'schema_version',
      'evaluation_mode',
      'conversation_id',
      'run_id',
      'evaluated_at_ms',
      'owner_declaration_unverified',
      'inventory_declarations_unverified',
      'placement_declaration_unverified',
      'notice',
      'device_count',
      'runner_instance_count',
      'available_cpu_cores',
      'available_memory_bytes',
      'available_storage_bytes',
      'available_gpu_count',
      'available_gpu_memory_bytes',
      'eligible_device_count',
      'eligible_instance_count',
      'selected_device_id',
      'selected_instance_id',
      'authority',
    });
    final expectedWithOwner = Map<String, dynamic>.from(expectedJSON)
      ..['owner'] = owner.toJson();
    final expected = ForgeDeviceResourceSummary.fromJson(expectedWithOwner);
    if (expected.owner != owner) {
      throw const FormatException(
        'Forge resource summary expected owner mismatch.',
      );
    }
    final generated = observeForgeDeviceResourceSummary(
      ForgeDeviceResourceSummaryRequest(
        owner: owner,
        inventory: inventory.devices,
        placement: placement,
      ),
    );
    if (jsonEncode(generated.toJson()) != jsonEncode(expected.toJson())) {
      throw const FormatException(
        'Forge resource summary expected aggregate drifted from declarations.',
      );
    }
    return ForgeDeviceResourceSummaryFixture(
      owner: owner,
      inventory: inventory,
      placementObservation: placement,
      expected: expected,
    );
  }

  bool get isDisplayOnly =>
      expected.ownerDeclarationUnverified &&
      expected.inventoryDeclarationsUnverified &&
      expected.placementDeclarationUnverified &&
      expected.selectedDeviceID == null &&
      expected.selectedInstanceID == null &&
      _offlineAuthority(expected.authority);

  Map<String, dynamic> toJson() => {
    'api_version': forgeDeviceResourceSummaryContractAPIVersion,
    'inventory_contract_fixture': forgeDeviceResourceSummaryInventoryFixture,
    'placement_contract_fixture': forgeDeviceResourceSummaryPlacementFixture,
    'owner': owner.toJson(),
    'inventory': inventory.toJson(),
    'placement_observation': placementObservation.toJson(),
    'expected': _expectedJSON(expected),
  };

  Map<String, dynamic> _expectedJSON(ForgeDeviceResourceSummary value) {
    final json = Map<String, dynamic>.from(value.toJson())..remove('owner');
    return json;
  }
}

class ForgeDeviceResourceSummaryRequest {
  final ForgeDeviceOwner owner;
  final List<ForgeDeviceInventoryCandidate> inventory;
  final ForgeSessionPlacementObservation placement;

  const ForgeDeviceResourceSummaryRequest({
    required this.owner,
    required this.inventory,
    required this.placement,
  });
}

class ForgeDeviceResourceSummary {
  final String schemaVersion;
  final String evaluationMode;
  final ForgeDeviceOwner owner;
  final String conversationID;
  final String runID;
  final int evaluatedAtMS;
  final bool ownerDeclarationUnverified;
  final bool inventoryDeclarationsUnverified;
  final bool placementDeclarationUnverified;
  final String notice;
  final int deviceCount;
  final int runnerInstanceCount;
  final int availableCPUCores;
  final int availableMemoryBytes;
  final int availableStorageBytes;
  final int availableGPUCount;
  final int availableGPUMemoryBytes;
  final int eligibleDeviceCount;
  final int eligibleInstanceCount;
  final String? selectedDeviceID;
  final String? selectedInstanceID;
  final ForgeSessionPlacementAuthority authority;

  const ForgeDeviceResourceSummary({
    required this.schemaVersion,
    required this.evaluationMode,
    required this.owner,
    required this.conversationID,
    required this.runID,
    required this.evaluatedAtMS,
    required this.ownerDeclarationUnverified,
    required this.inventoryDeclarationsUnverified,
    required this.placementDeclarationUnverified,
    required this.notice,
    required this.deviceCount,
    required this.runnerInstanceCount,
    required this.availableCPUCores,
    required this.availableMemoryBytes,
    required this.availableStorageBytes,
    required this.availableGPUCount,
    required this.availableGPUMemoryBytes,
    required this.eligibleDeviceCount,
    required this.eligibleInstanceCount,
    required this.selectedDeviceID,
    required this.selectedInstanceID,
    required this.authority,
  });

  factory ForgeDeviceResourceSummary.fromJson(Object? value) {
    final json = _summaryObject(value);
    _summaryExactKeys(json, {
      'schema_version',
      'evaluation_mode',
      'owner',
      'conversation_id',
      'run_id',
      'evaluated_at_ms',
      'owner_declaration_unverified',
      'inventory_declarations_unverified',
      'placement_declaration_unverified',
      'notice',
      'device_count',
      'runner_instance_count',
      'available_cpu_cores',
      'available_memory_bytes',
      'available_storage_bytes',
      'available_gpu_count',
      'available_gpu_memory_bytes',
      'eligible_device_count',
      'eligible_instance_count',
      'selected_device_id',
      'selected_instance_id',
      'authority',
    });
    if (json['schema_version'] != forgeDeviceResourceSummarySchema ||
        json['evaluation_mode'] != forgeDeviceResourceSummaryEvaluationMode ||
        json['notice'] != forgeDeviceResourceSummaryNotice ||
        json['owner_declaration_unverified'] != true ||
        json['inventory_declarations_unverified'] != true ||
        json['placement_declaration_unverified'] != true ||
        json['selected_device_id'] != null ||
        json['selected_instance_id'] != null) {
      throw const FormatException('Invalid Forge resource summary envelope.');
    }
    final deviceCount = _summaryBoundedCount(json['device_count']);
    final runnerInstanceCount = _summaryBoundedCount(
      json['runner_instance_count'],
    );
    final availableGPUCount = _summaryBoundedCount(json['available_gpu_count']);
    final eligibleDeviceCount = _summaryBoundedCount(
      json['eligible_device_count'],
    );
    final eligibleInstanceCount = _summaryBoundedCount(
      json['eligible_instance_count'],
    );
    if (runnerInstanceCount != deviceCount ||
        availableGPUCount > deviceCount ||
        eligibleDeviceCount > deviceCount ||
        eligibleInstanceCount > runnerInstanceCount ||
        eligibleDeviceCount != eligibleInstanceCount) {
      throw const FormatException(
        'Inconsistent Forge resource summary counts.',
      );
    }
    return ForgeDeviceResourceSummary(
      schemaVersion: forgeDeviceResourceSummarySchema,
      evaluationMode: forgeDeviceResourceSummaryEvaluationMode,
      owner: ForgeDeviceOwner.fromJson(json['owner']),
      conversationID: _summaryIdentifier(json['conversation_id']),
      runID: _summaryIdentifier(json['run_id']),
      evaluatedAtMS: _summaryPositiveSafeInteger(json['evaluated_at_ms']),
      ownerDeclarationUnverified: true,
      inventoryDeclarationsUnverified: true,
      placementDeclarationUnverified: true,
      notice: forgeDeviceResourceSummaryNotice,
      deviceCount: deviceCount,
      runnerInstanceCount: runnerInstanceCount,
      availableCPUCores: _summarySafeInteger(json['available_cpu_cores']),
      availableMemoryBytes: _summarySafeInteger(json['available_memory_bytes']),
      availableStorageBytes: _summarySafeInteger(
        json['available_storage_bytes'],
      ),
      availableGPUCount: availableGPUCount,
      availableGPUMemoryBytes: _summarySafeInteger(
        json['available_gpu_memory_bytes'],
      ),
      eligibleDeviceCount: eligibleDeviceCount,
      eligibleInstanceCount: eligibleInstanceCount,
      selectedDeviceID: null,
      selectedInstanceID: null,
      authority: ForgeSessionPlacementAuthority.fromJson(json['authority']),
    );
  }

  Map<String, dynamic> toJson() => {
    'schema_version': schemaVersion,
    'evaluation_mode': evaluationMode,
    'owner': {
      'issuer': owner.issuer,
      'subject': owner.subject,
      'tenant_id': owner.tenantID,
    },
    'conversation_id': conversationID,
    'run_id': runID,
    'evaluated_at_ms': evaluatedAtMS,
    'owner_declaration_unverified': ownerDeclarationUnverified,
    'inventory_declarations_unverified': inventoryDeclarationsUnverified,
    'placement_declaration_unverified': placementDeclarationUnverified,
    'notice': notice,
    'device_count': deviceCount,
    'runner_instance_count': runnerInstanceCount,
    'available_cpu_cores': availableCPUCores,
    'available_memory_bytes': availableMemoryBytes,
    'available_storage_bytes': availableStorageBytes,
    'available_gpu_count': availableGPUCount,
    'available_gpu_memory_bytes': availableGPUMemoryBytes,
    'eligible_device_count': eligibleDeviceCount,
    'eligible_instance_count': eligibleInstanceCount,
    'selected_device_id': selectedDeviceID,
    'selected_instance_id': selectedInstanceID,
    'authority': authority.toJson(),
  };
}

class ForgeDeviceResourceSummaryError implements Exception {
  final String code;

  const ForgeDeviceResourceSummaryError(this.code);
}

/// Aggregates caller-supplied inventory and an already observed placement
/// declaration. This pure projection has no clock, network, persistence,
/// target selection, reservation, authorization, or execution effect.
ForgeDeviceResourceSummary observeForgeDeviceResourceSummary(
  ForgeDeviceResourceSummaryRequest request,
) {
  if (request.inventory.length > forgeDeviceResourceSummaryMaxDeclarations ||
      !_validOwner(request.owner) ||
      !_validPlacement(request.placement, request.owner)) {
    throw const ForgeDeviceResourceSummaryError('invalid_binding');
  }

  final byDevice = <String, ForgeDeviceInventoryCandidate>{};
  final instances = <String>{};
  for (final candidate in request.inventory) {
    if (!_identifier(candidate.device.deviceID) ||
        !_identifier(candidate.instanceID) ||
        !_validOwner(candidate.device.owner) ||
        candidate.device.owner != request.owner ||
        byDevice.containsKey(candidate.device.deviceID) ||
        !instances.add(candidate.instanceID)) {
      throw const ForgeDeviceResourceSummaryError('invalid_inventory');
    }
    byDevice[candidate.device.deviceID] = candidate;
  }
  if (request.placement.decisions.length != request.inventory.length) {
    throw const ForgeDeviceResourceSummaryError('invalid_binding');
  }

  final decisions = [...request.placement.decisions]
    ..sort((left, right) {
      final device = _compareIDs(left.deviceID, right.deviceID);
      return device == 0
          ? _compareIDs(left.instanceID, right.instanceID)
          : device;
    });
  final devices = <String>{};
  final decisionInstances = <String>{};
  var eligibleDevices = 0;
  var eligibleInstances = 0;
  for (final decision in decisions) {
    if (!_identifier(decision.deviceID) ||
        !_identifier(decision.instanceID) ||
        !devices.add(decision.deviceID) ||
        !decisionInstances.add(decision.instanceID)) {
      throw const ForgeDeviceResourceSummaryError('invalid_placement');
    }
    final candidate = byDevice[decision.deviceID];
    if (candidate == null || candidate.instanceID != decision.instanceID) {
      throw const ForgeDeviceResourceSummaryError('invalid_binding');
    }
    if (decision.matchesRequirements) {
      eligibleDevices++;
      eligibleInstances++;
    }
  }

  var availableCPUCores = 0;
  var availableMemoryBytes = 0;
  var availableStorageBytes = 0;
  var availableGPUCount = 0;
  var availableGPUMemoryBytes = 0;
  for (final candidate in request.inventory) {
    final device = candidate.device;
    availableCPUCores = _add(availableCPUCores, device.availableCPUCores);
    availableMemoryBytes = _add(
      availableMemoryBytes,
      device.availableMemoryBytes,
    );
    availableStorageBytes = _add(
      availableStorageBytes,
      device.availableStorageBytes,
    );
    if (device.gpu.present) {
      availableGPUCount++;
      availableGPUMemoryBytes = _add(
        availableGPUMemoryBytes,
        device.gpu.memoryBytes,
      );
    }
  }
  final count = request.inventory.length;
  return ForgeDeviceResourceSummary(
    schemaVersion: forgeDeviceResourceSummarySchema,
    evaluationMode: forgeDeviceResourceSummaryEvaluationMode,
    owner: request.owner,
    conversationID: request.placement.conversationID,
    runID: request.placement.runID,
    evaluatedAtMS: request.placement.evaluatedAtMS,
    ownerDeclarationUnverified: true,
    inventoryDeclarationsUnverified: true,
    placementDeclarationUnverified: true,
    notice: forgeDeviceResourceSummaryNotice,
    deviceCount: count,
    runnerInstanceCount: count,
    availableCPUCores: availableCPUCores,
    availableMemoryBytes: availableMemoryBytes,
    availableStorageBytes: availableStorageBytes,
    availableGPUCount: availableGPUCount,
    availableGPUMemoryBytes: availableGPUMemoryBytes,
    eligibleDeviceCount: eligibleDevices,
    eligibleInstanceCount: eligibleInstances,
    selectedDeviceID: null,
    selectedInstanceID: null,
    authority: const ForgeSessionPlacementAuthority.offline(),
  );
}

bool _validOwner(ForgeDeviceOwner owner) =>
    _validOwnerPart(owner.issuer) &&
    _validOwnerPart(owner.subject) &&
    _validOwnerPart(owner.tenantID);

bool _validOwnerPart(String value) {
  if (value.isEmpty ||
      value.trim() != value ||
      utf8.encode(value).length > 512) {
    return false;
  }
  return value.codeUnits.every(
    (unit) => unit > 0x1f && !(unit >= 0x7f && unit <= 0x9f),
  );
}

bool _validPlacement(
  ForgeSessionPlacementObservation placement,
  ForgeDeviceOwner owner,
) {
  return placement.schemaVersion == forgeSessionPlacementObservationSchema &&
      placement.evaluationMode == forgeDeviceResourceSummaryEvaluationMode &&
      placement.owner == owner &&
      _identifier(placement.conversationID) &&
      _identifier(placement.runID) &&
      placement.evaluatedAtMS > 0 &&
      placement.evaluatedAtMS <= forgeDeviceResourceSummaryMaxSafeInteger &&
      placement.ownerDeclarationUnverified &&
      placement.deviceAttributesUnverified &&
      placement.selectedDeviceID == null &&
      placement.selectedInstanceID == null &&
      _offlineAuthority(placement.authority);
}

bool _offlineAuthority(ForgeSessionPlacementAuthority authority) =>
    !authority.identityVerified &&
    !authority.heartbeatPersisted &&
    !authority.inventoryAuthoritative &&
    !authority.reservationCreated &&
    !authority.executionAuthorized &&
    !authority.dispatchPerformed;

bool _identifier(String value) {
  if (value.isEmpty || value.length > 128) return false;
  final codes = value.codeUnits;
  bool first(int code) =>
      code >= 0x30 && code <= 0x39 ||
      code >= 0x41 && code <= 0x5a ||
      code >= 0x61 && code <= 0x7a;
  if (!first(codes.first)) return false;
  return codes
      .skip(1)
      .every(
        (code) =>
            first(code) ||
            const [0x2e, 0x5f, 0x3a, 0x2b, 0x2f, 0x2d].contains(code),
      );
}

int _add(int left, int right) {
  if (right < 0 || left > forgeDeviceResourceSummaryMaxSafeInteger - right) {
    throw const ForgeDeviceResourceSummaryError('resource_overflow');
  }
  return left + right;
}

int _compareIDs(String left, String right) {
  final length = left.length < right.length ? left.length : right.length;
  for (var index = 0; index < length; index++) {
    final compared = left.codeUnitAt(index).compareTo(right.codeUnitAt(index));
    if (compared != 0) return compared;
  }
  return left.length.compareTo(right.length);
}

Map<String, dynamic> _summaryObject(Object? value) {
  if (value is! Map || value.keys.any((key) => key is! String)) {
    throw const FormatException('Expected Forge resource summary object.');
  }
  return Map<String, dynamic>.from(value);
}

void _summaryExactKeys(Map<String, dynamic> json, Set<String> expected) {
  if (json.length != expected.length ||
      json.keys.any((key) => !expected.contains(key))) {
    throw const FormatException('Unexpected Forge resource summary fields.');
  }
}

String _summaryIdentifier(Object? value) {
  if (value is! String || !_identifier(value)) {
    throw const FormatException('Invalid Forge resource summary identifier.');
  }
  return value;
}

int _summarySafeInteger(Object? value) {
  if (value is! int ||
      value < 0 ||
      value > forgeDeviceResourceSummaryMaxSafeInteger) {
    throw const FormatException('Invalid Forge resource summary integer.');
  }
  return value;
}

int _summaryPositiveSafeInteger(Object? value) {
  final parsed = _summarySafeInteger(value);
  if (parsed == 0) {
    throw const FormatException('Invalid Forge resource summary timestamp.');
  }
  return parsed;
}

int _summaryBoundedCount(Object? value) {
  final parsed = _summarySafeInteger(value);
  if (parsed > forgeDeviceResourceSummaryMaxDeclarations) {
    throw const FormatException('Invalid Forge resource summary count.');
  }
  return parsed;
}

void _summaryFixtureRejectDuplicateKeys(String source) {
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
        while (next < source.length && _summaryWhitespace(source[next])) {
          next++;
        }
        if (next < source.length && source[next] == ':') {
          if (objects.isEmpty) {
            throw const FormatException('Invalid Forge resource summary key.');
          }
          final decoded = jsonDecode(source.substring(stringStart, index + 1));
          if (decoded is! String || !objects.last.add(decoded)) {
            throw const FormatException(
              'Duplicate Forge resource summary key.',
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
        throw const FormatException('Invalid Forge resource summary object.');
      }
      objects.removeLast();
    }
  }
  if (inString || objects.isNotEmpty) {
    throw const FormatException('Invalid Forge resource summary JSON.');
  }
}

bool _summaryWhitespace(String value) =>
    value == ' ' || value == '\t' || value == '\r' || value == '\n';
