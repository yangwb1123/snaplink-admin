import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_client_instance_resource_view.dart';

void main() {
  final fixturePath =
      Platform.environment['FORGE_CLIENT_INSTANCE_RESOURCE_VIEW_FIXTURE'];

  test(
    'consumes the shared Go/Rust client-instance/resource-view fixture',
    () {
      final path = fixturePath;
      if (path == null || path.isEmpty) return;
      final fixture = ForgeClientInstanceResourceView.fromJsonText(
        File(path).readAsStringSync(),
      );
      expect(fixture.schemaVersion, forgeClientInstanceResourceViewSchema);
      expect(
        fixture.evaluationMode,
        forgeClientInstanceResourceViewEvaluationMode,
      );
      expect(fixture.owner.subject, 'user-1');
      expect(fixture.instances, hasLength(5));
      expect(fixture.instances.map((instance) => instance.clientKind), [
        'app',
        'cli',
        'mobile',
        'tui',
        'web',
      ]);
      expect(fixture.devices, hasLength(2));
      expect(fixture.devices.first.deviceID, 'device-a');
      expect(fixture.devices.first.runnerInstanceID, 'runner-a');
      expect(fixture.devices.last.reservationState, 'none');
      expect(fixture.authority.isOffline, isTrue);
      expect(fixture.isDisplayOnly, isTrue);
    },
    skip: fixturePath == null || fixturePath.isEmpty
        ? 'Run with the canonical Go/Rust fixture path.'
        : false,
  );

  test('round-trips only the strict metadata contract', () {
    final fixture = ForgeClientInstanceResourceView.fromJson(_fixture());
    expect(fixture.toJson(), _fixture());
    expect(fixture.isDisplayOnly, isTrue);
  });

  test(
    'rejects unknown fields, enabled authority, trailing JSON, and owners',
    () {
      final unknown = _fixture();
      unknown['unexpected'] = true;
      expect(
        () => ForgeClientInstanceResourceView.fromJson(unknown),
        throwsA(isA<FormatException>()),
      );

      final enabled = _fixture();
      (enabled['authority'] as Map<String, dynamic>)['dispatch_performed'] =
          true;
      expect(
        () => ForgeClientInstanceResourceView.fromJson(enabled),
        throwsA(isA<FormatException>()),
      );

      expect(
        () => ForgeClientInstanceResourceView.fromJsonText(
          '${jsonEncode(_fixture())}\n{}',
        ),
        throwsA(isA<FormatException>()),
      );

      final foreignOwner = _fixture();
      final firstDevice = Map<String, dynamic>.from(
        (foreignOwner['devices'] as List).first as Map,
      );
      firstDevice['owner'] = {
        'issuer': 'https://id.example',
        'subject': 'other-user',
        'tenant_id': 'tenant-1',
      };
      foreignOwner['devices'] = [
        firstDevice,
        ...(foreignOwner['devices'] as List).skip(1),
      ];
      expect(
        () => ForgeClientInstanceResourceView.fromJson(foreignOwner),
        throwsA(isA<FormatException>()),
      );
    },
  );

  test('rejects duplicate JSON keys before Dart map decoding', () {
    final source = jsonEncode(_fixture());
    final duplicateRoot = source.replaceFirst(
      '"schema_version":"$forgeClientInstanceResourceViewSchema",',
      '"schema_version":"$forgeClientInstanceResourceViewSchema",'
          '"schema_version":"$forgeClientInstanceResourceViewSchema",',
    );
    expect(duplicateRoot, isNot(source));
    expect(
      () => ForgeClientInstanceResourceView.fromJsonText(duplicateRoot),
      throwsA(isA<FormatException>()),
    );

    final duplicateNested = source.replaceFirst(
      '"device_id":"device-a",',
      '"device_id":"device-a","device_id":"device-a",',
    );
    expect(duplicateNested, isNot(source));
    expect(
      () => ForgeClientInstanceResourceView.fromJsonText(duplicateNested),
      throwsA(isA<FormatException>()),
    );
  });

  test('rejects unsorted, duplicate, capacity, and bounded rows', () {
    final unsorted = _fixture();
    unsorted['devices'] = (unsorted['devices'] as List).reversed.toList();
    expect(
      () => ForgeClientInstanceResourceView.fromJson(unsorted),
      throwsA(isA<FormatException>()),
    );

    final duplicateDevice = _fixture();
    final devices = duplicateDevice['devices'] as List;
    duplicateDevice['devices'] = [devices.first, devices.first];
    expect(
      () => ForgeClientInstanceResourceView.fromJson(duplicateDevice),
      throwsA(isA<FormatException>()),
    );

    final duplicateRunner = _fixture();
    final second = Map<String, dynamic>.from(
      (duplicateRunner['devices'] as List).last as Map,
    );
    second['runner_instance_id'] = 'runner-a';
    duplicateRunner['devices'] = [
      (duplicateRunner['devices'] as List).first,
      second,
    ];
    expect(
      () => ForgeClientInstanceResourceView.fromJson(duplicateRunner),
      throwsA(isA<FormatException>()),
    );

    final capacity = _fixture();
    final capacityDevice = Map<String, dynamic>.from(
      (capacity['devices'] as List).first as Map,
    );
    capacityDevice['available_cpu_cores'] = 9;
    capacity['devices'] = [
      capacityDevice,
      ...(capacity['devices'] as List).skip(1),
    ];
    expect(
      () => ForgeClientInstanceResourceView.fromJson(capacity),
      throwsA(isA<FormatException>()),
    );

    final tooManyDevices = _fixture();
    tooManyDevices['devices'] = List.generate(
      forgeClientInstanceResourceViewMaxDevices + 1,
      (index) => _device('device-${index.toString().padLeft(3, '0')}'),
    );
    expect(
      () => ForgeClientInstanceResourceView.fromJson(tooManyDevices),
      throwsA(isA<FormatException>()),
    );
  });
}

Map<String, dynamic> _fixture() => {
  'schema_version': forgeClientInstanceResourceViewSchema,
  'evaluation_mode': forgeClientInstanceResourceViewEvaluationMode,
  'owner_declaration': _owner(),
  'owner_declaration_unverified': true,
  'instances': [
    {
      'instance_id': 'client-cli-001',
      'client_kind': 'cli',
      'session_ids': ['conversation-001', 'conversation-002'],
      'observed_at_ms': 200500,
      'status': 'active',
    },
    {
      'instance_id': 'client-web-001',
      'client_kind': 'web',
      'session_ids': ['conversation-001'],
      'observed_at_ms': 200500,
      'status': 'idle',
    },
  ],
  'devices': [_device('device-a'), _device('device-b', pending: true)],
  'device_attributes_unverified': true,
  'read_only': true,
  'authority': {
    'owner_authenticated': false,
    'session_read_authorized': false,
    'prompt_write_authorized': false,
    'device_identity_verified': false,
    'reservation_created': false,
    'execution_authorized': false,
    'dispatch_performed': false,
    'audit_published': false,
  },
};

Map<String, dynamic> _owner() => {
  'issuer': 'https://id.example',
  'subject': 'user-1',
  'tenant_id': 'tenant-1',
};

Map<String, dynamic> _device(String id, {bool pending = false}) => {
  'device_id': id,
  'runner_instance_id': id == 'device-a' ? 'runner-a' : 'runner-b',
  'owner': _owner(),
  'revision': id == 'device-a' ? 1 : 2,
  'generation': id == 'device-a' ? 1 : 2,
  'heartbeat_sequence': id == 'device-a' ? 1 : 4,
  'observed_at_ms': 200500,
  'approval_state': pending ? 'pending' : 'approved',
  'cordon_state': pending ? 'cordoned' : 'clear',
  'reservation_state': pending ? 'none' : 'reserved',
  'liveness': pending ? 'offline' : 'online',
  'os': 'linux',
  'architecture': 'amd64',
  'cpu_cores': 8,
  'available_cpu_cores': 7,
  'memory_bytes': 17179869184,
  'available_memory_bytes': 8589934592,
  'storage_bytes': 107374182400,
  'available_storage_bytes': 53687091200,
  'gpu_count': pending ? 0 : 2,
  'available_gpu_memory_bytes': pending ? 0 : 17179869184,
};
