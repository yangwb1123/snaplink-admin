import 'dart:convert';

import 'forge_device_inventory_models.dart';
import 'forge_session_placement.dart';

part 'forge_device_resource_summary_projection.dart';
part 'forge_device_resource_summary_codec.dart';

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
