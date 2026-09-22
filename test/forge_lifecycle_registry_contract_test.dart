import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_device_enrollment_heartbeat_lifecycle_registry.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';

import 'support/forge_lifecycle_registry_fixture.dart';

void main() {
  test('accepts the canonical owner-scoped display-only registry image', () {
    final registry = ForgeDeviceEnrollmentHeartbeatLifecycleRegistry.fromJson(
      forgeLifecycleRegistryTestEnvelope(),
    );

    expect(registry.schemaVersion, isNotEmpty);
    expect(registry.owner, forgeLifecycleRegistryTestOwner);
    expect(registry.states.map((state) => state.deviceID), [
      'device-a',
      'device-b',
    ]);
    expect(registry.states.map((state) => state.instanceID), [
      'runner-a',
      'runner-b',
    ]);
    expect(registry.states.first.revision, BigInt.one);
    expect(registry.states.last.heartbeatSequence, BigInt.from(3));
    expect(registry.isDisplayOnly, isTrue);
    expect(registry.toJson()['states'], hasLength(2));
  });

  test('rejects unknown fields and authority mutations at every boundary', () {
    final unknownEnvelope = forgeLifecycleRegistryTestEnvelope();
    unknownEnvelope['unexpected'] = true;
    expect(
      () => ForgeDeviceEnrollmentHeartbeatLifecycleRegistry.fromJson(
        unknownEnvelope,
      ),
      throwsFormatException,
    );

    final unknownState = forgeLifecycleRegistryTestEnvelope();
    final state = Map<String, dynamic>.from(
      (unknownState['states'] as List).first as Map,
    );
    state['unexpected'] = true;
    unknownState['states'] = [state, (unknownState['states'] as List)[1]];
    expect(
      () => ForgeDeviceEnrollmentHeartbeatLifecycleRegistry.fromJson(
        unknownState,
      ),
      throwsFormatException,
    );

    expect(
      () => ForgeDeviceEnrollmentHeartbeatLifecycleRegistry.fromJson(
        forgeLifecycleRegistryTestAuthorityMutation(),
      ),
      throwsFormatException,
    );

    final nestedAuthority = forgeLifecycleRegistryTestEnvelope();
    final nestedState = Map<String, dynamic>.from(
      (nestedAuthority['states'] as List).first as Map,
    );
    final nestedDevice = Map<String, dynamic>.from(
      nestedState['device'] as Map,
    );
    nestedDevice['execution_authorized'] = false;
    nestedState['device'] = nestedDevice;
    nestedAuthority['states'] = [
      nestedState,
      (nestedAuthority['states'] as List)[1],
    ];
    expect(
      () => ForgeDeviceEnrollmentHeartbeatLifecycleRegistry.fromJson(
        nestedAuthority,
      ),
      throwsFormatException,
    );
  });

  test('rejects duplicate JSON fields before Dart decoding can overwrite one', () {
    expect(
      () => ForgeDeviceEnrollmentHeartbeatLifecycleRegistry.fromJsonText(
        '{"schema_version":"forge.device-enrollment-heartbeat-lifecycle-file-set/v1",'
        '"schema_version":"forge.device-enrollment-heartbeat-lifecycle-file-set/v1",'
        '"owner":{},"states":[]}',
      ),
      throwsFormatException,
    );
  });

  test(
    'rejects foreign owners at envelope, state, device, and inventory joins',
    () {
      const foreignOwner = ForgeDeviceOwner(
        issuer: 'https://id.example',
        subject: 'foreign-user',
        tenantID: 'tenant-1',
      );

      final envelopeForeign = forgeLifecycleRegistryTestEnvelope(
        owner: foreignOwner,
      );
      expect(
        () => ForgeDeviceEnrollmentHeartbeatLifecycleRegistry.fromJson(
          envelopeForeign,
        ),
        throwsFormatException,
      );

      final stateForeign = forgeLifecycleRegistryTestEnvelope();
      final state = forgeLifecycleRegistryTestState(
        deviceID: 'device-a',
        instanceID: 'runner-a',
        revision: 1,
        heartbeatSequence: 1,
        owner: foreignOwner,
      );
      stateForeign['states'] = [state, (stateForeign['states'] as List)[1]];
      expect(
        () => ForgeDeviceEnrollmentHeartbeatLifecycleRegistry.fromJson(
          stateForeign,
        ),
        throwsFormatException,
      );

      final deviceForeign = forgeLifecycleRegistryTestEnvelope();
      final deviceState = Map<String, dynamic>.from(
        (deviceForeign['states'] as List).first as Map,
      );
      final device = Map<String, dynamic>.from(deviceState['device'] as Map);
      device['owner'] = foreignOwner.toJson();
      deviceState['device'] = device;
      deviceForeign['states'] = [
        deviceState,
        (deviceForeign['states'] as List)[1],
      ];
      expect(
        () => ForgeDeviceEnrollmentHeartbeatLifecycleRegistry.fromJson(
          deviceForeign,
        ),
        throwsFormatException,
      );

      final inventoryForeign = forgeLifecycleRegistryTestEnvelope();
      final inventoryState = Map<String, dynamic>.from(
        (inventoryForeign['states'] as List).first as Map,
      );
      final inventory = Map<String, dynamic>.from(
        inventoryState['inventory'] as Map,
      );
      final inventoryDevice = Map<String, dynamic>.from(
        inventory['device'] as Map,
      );
      inventoryDevice['owner'] = foreignOwner.toJson();
      inventory['device'] = inventoryDevice;
      inventoryState['inventory'] = inventory;
      inventoryForeign['states'] = [
        inventoryState,
        (inventoryForeign['states'] as List)[1],
      ];
      expect(
        () => ForgeDeviceEnrollmentHeartbeatLifecycleRegistry.fromJson(
          inventoryForeign,
        ),
        throwsFormatException,
      );
    },
  );

  test('rejects unsorted and duplicate device or Runner identities', () {
    final unsorted = forgeLifecycleRegistryTestEnvelope();
    unsorted['states'] = (unsorted['states'] as List).reversed.toList();
    expect(
      () => ForgeDeviceEnrollmentHeartbeatLifecycleRegistry.fromJson(unsorted),
      throwsFormatException,
    );

    final duplicateDevice = forgeLifecycleRegistryTestEnvelope(
      states: [
        forgeLifecycleRegistryTestState(
          deviceID: 'device-a',
          instanceID: 'runner-a',
          revision: 1,
          heartbeatSequence: 1,
        ),
        forgeLifecycleRegistryTestState(
          deviceID: 'device-a',
          instanceID: 'runner-b',
          revision: 2,
          heartbeatSequence: 3,
        ),
      ],
    );
    expect(
      () => ForgeDeviceEnrollmentHeartbeatLifecycleRegistry.fromJson(
        duplicateDevice,
      ),
      throwsFormatException,
    );

    final duplicateRunner = forgeLifecycleRegistryTestEnvelope(
      states: [
        forgeLifecycleRegistryTestState(
          deviceID: 'device-a',
          instanceID: 'runner-a',
          revision: 1,
          heartbeatSequence: 1,
        ),
        forgeLifecycleRegistryTestState(
          deviceID: 'device-b',
          instanceID: 'runner-a',
          revision: 2,
          heartbeatSequence: 3,
        ),
      ],
    );
    expect(
      () => ForgeDeviceEnrollmentHeartbeatLifecycleRegistry.fromJson(
        duplicateRunner,
      ),
      throwsFormatException,
    );
  });

  test(
    'rejects identity, revision, heartbeat, and capability binding drift',
    () {
      final identityDrift = forgeLifecycleRegistryTestEnvelope();
      final state = Map<String, dynamic>.from(
        (identityDrift['states'] as List).first as Map,
      );
      final heartbeat = Map<String, dynamic>.from(state['heartbeat'] as Map);
      final instance = Map<String, dynamic>.from(heartbeat['instance'] as Map);
      instance['device_id'] = 'device-foreign';
      heartbeat['instance'] = instance;
      state['heartbeat'] = heartbeat;
      identityDrift['states'] = [state, (identityDrift['states'] as List)[1]];
      expect(
        () => ForgeDeviceEnrollmentHeartbeatLifecycleRegistry.fromJson(
          identityDrift,
        ),
        throwsFormatException,
      );

      final revisionDrift = forgeLifecycleRegistryTestEnvelope();
      final revisionState = Map<String, dynamic>.from(
        (revisionDrift['states'] as List).first as Map,
      );
      final revisionInventory = Map<String, dynamic>.from(
        revisionState['inventory'] as Map,
      );
      revisionInventory['revision'] = 99;
      revisionState['inventory'] = revisionInventory;
      revisionDrift['states'] = [
        revisionState,
        (revisionDrift['states'] as List)[1],
      ];
      expect(
        () => ForgeDeviceEnrollmentHeartbeatLifecycleRegistry.fromJson(
          revisionDrift,
        ),
        throwsFormatException,
      );

      final capabilityDrift = forgeLifecycleRegistryTestEnvelope();
      final capabilityState = Map<String, dynamic>.from(
        (capabilityDrift['states'] as List).first as Map,
      );
      final capabilityHeartbeat = Map<String, dynamic>.from(
        capabilityState['heartbeat'] as Map,
      );
      final capabilityInstance = Map<String, dynamic>.from(
        capabilityHeartbeat['instance'] as Map,
      );
      final capabilities = Map<String, dynamic>.from(
        capabilityInstance['capabilities'] as Map,
      );
      capabilities['available_cpu_cores'] = 1;
      capabilityInstance['capabilities'] = capabilities;
      capabilityHeartbeat['instance'] = capabilityInstance;
      capabilityState['heartbeat'] = capabilityHeartbeat;
      capabilityDrift['states'] = [
        capabilityState,
        (capabilityDrift['states'] as List)[1],
      ];
      expect(
        () => ForgeDeviceEnrollmentHeartbeatLifecycleRegistry.fromJson(
          capabilityDrift,
        ),
        throwsFormatException,
      );
    },
  );

  test('fromJson and fromJsonText reject malformed JSON without authority', () {
    expect(
      () => ForgeDeviceEnrollmentHeartbeatLifecycleRegistry.fromJsonText(
        jsonEncode(forgeLifecycleRegistryTestAuthorityMutation()),
      ),
      throwsFormatException,
    );
    expect(
      () => ForgeDeviceEnrollmentHeartbeatLifecycleRegistry.fromJsonText(
        '{"schema_version":',
      ),
      throwsFormatException,
    );
  });
}
