import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_device_resource_summary.dart';
import 'package:sso_admin/api/forge_session_placement.dart';

void main() {
  test(
    'session placement observation decodes its strict offline wire shape',
    () {
      final wire = _sessionObservationJSON();

      final observation = ForgeSessionPlacementObservation.fromJson(wire);

      expect(observation.toJson(), wire);
      expect(observation.decisions, hasLength(2));
      expect(observation.authority.executionAuthorized, isFalse);
    },
  );

  test('session placement observation fails closed on unsafe wire values', () {
    final mutations = <void Function(Map<String, dynamic>)>[
      (json) => json['unexpected'] = true,
      (json) => json['selected_device_id'] = 'device-a',
      (json) => json['evaluated_at_ms'] = 9007199254740992,
      (json) => json['conversation_id'] = 'conversation with spaces',
      (json) => (json['authority'] as Map)['dispatch_performed'] = true,
      (json) => (json['authority'] as Map)['unknown'] = false,
      (json) =>
          ((json['decisions'] as List).first as Map)['matches_requirements'] =
              false,
      (json) =>
          ((json['decisions'] as List)[1] as Map)['device_id'] = 'device-a',
      (json) =>
          ((json['decisions'] as List)[1] as Map)['instance_id'] = 'runner-a',
      (json) => (json['decisions'] as List).setAll(0, [
        (json['decisions'] as List)[1],
        (json['decisions'] as List)[0],
      ]),
    ];

    for (final mutate in mutations) {
      final wire = _copy(_sessionObservationJSON());
      mutate(wire);
      expect(
        () => ForgeSessionPlacementObservation.fromJson(wire),
        throwsFormatException,
      );
    }
  });

  test('resource summary decodes its strict offline wire shape', () {
    final wire = _resourceSummaryJSON();

    final summary = ForgeDeviceResourceSummary.fromJson(wire);

    expect(summary.toJson(), wire);
    expect(summary.deviceCount, 2);
    expect(summary.eligibleDeviceCount, 1);
    expect(summary.selectedInstanceID, isNull);
  });

  test('resource summary fails closed on authority and count drift', () {
    final mutations = <void Function(Map<String, dynamic>)>[
      (json) => json['unexpected'] = true,
      (json) => json.remove('notice'),
      (json) => json['selected_instance_id'] = 'runner-a',
      (json) => json['available_memory_bytes'] = -1,
      (json) => json['available_storage_bytes'] = 9007199254740992,
      (json) => json['runner_instance_count'] = 1,
      (json) => json['available_gpu_count'] = 3,
      (json) => json['eligible_instance_count'] = 2,
      (json) => (json['authority'] as Map)['identity_verified'] = true,
      (json) => (json['owner'] as Map)['private'] = 'value',
    ];

    for (final mutate in mutations) {
      final wire = _copy(_resourceSummaryJSON());
      mutate(wire);
      expect(
        () => ForgeDeviceResourceSummary.fromJson(wire),
        throwsFormatException,
      );
    }
  });
}

Map<String, dynamic> _sessionObservationJSON() => {
  'schema_version': forgeSessionPlacementObservationSchema,
  'evaluation_mode': forgeSessionPlacementObservationEvaluationMode,
  'owner': _ownerJSON(),
  'conversation_id': 'conversation-1',
  'run_id': 'run-1',
  'evaluated_at_ms': 10,
  'owner_declaration_unverified': true,
  'device_attributes_unverified': true,
  'decisions': [
    {
      'device_id': 'device-a',
      'instance_id': 'runner-a',
      'matches_requirements': true,
      'exclusion_reasons': <String>[],
    },
    {
      'device_id': 'device-b',
      'instance_id': 'runner-b',
      'matches_requirements': false,
      'exclusion_reasons': ['cpu_cores_insufficient'],
    },
  ],
  'selected_device_id': null,
  'selected_instance_id': null,
  'authority': _authorityJSON(),
};

Map<String, dynamic> _resourceSummaryJSON() => {
  'schema_version': forgeDeviceResourceSummarySchema,
  'evaluation_mode': forgeDeviceResourceSummaryEvaluationMode,
  'owner': _ownerJSON(),
  'conversation_id': 'conversation-1',
  'run_id': 'run-1',
  'evaluated_at_ms': 10,
  'owner_declaration_unverified': true,
  'inventory_declarations_unverified': true,
  'placement_declaration_unverified': true,
  'notice': forgeDeviceResourceSummaryNotice,
  'device_count': 2,
  'runner_instance_count': 2,
  'available_cpu_cores': 12,
  'available_memory_bytes': 4096,
  'available_storage_bytes': 8192,
  'available_gpu_count': 1,
  'available_gpu_memory_bytes': 1024,
  'eligible_device_count': 1,
  'eligible_instance_count': 1,
  'selected_device_id': null,
  'selected_instance_id': null,
  'authority': _authorityJSON(),
};

Map<String, dynamic> _ownerJSON() => {
  'issuer': 'https://id.example',
  'subject': 'user-1',
  'tenant_id': 'tenant-1',
};

Map<String, dynamic> _authorityJSON() => {
  'identity_verified': false,
  'heartbeat_persisted': false,
  'inventory_authoritative': false,
  'reservation_created': false,
  'execution_authorized': false,
  'dispatch_performed': false,
};

Map<String, dynamic> _copy(Map<String, dynamic> value) =>
    Map<String, dynamic>.from(jsonDecode(jsonEncode(value)) as Map);
