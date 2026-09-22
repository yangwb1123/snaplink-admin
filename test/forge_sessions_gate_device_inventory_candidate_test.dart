import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/forge_device_inventory_models.dart';
import 'package:sso_admin/screens/forge/forge_sessions_gate.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/services/forge_credential_store.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/memory_forge_credential_backend.dart';

const _owner = ForgeDeviceOwner(
  issuer: 'https://id.example',
  subject: 'inventory-gate-v1-user',
  tenantID: 'tenant-1',
);

http.Response _json(Object value) => http.Response(
  jsonEncode(value),
  200,
  headers: const {'content-type': 'application/json'},
);

Map<String, dynamic> _inventory() => {
  'schema_version': forgeDeviceInventorySchema,
  'evaluation_mode': forgeDeviceInventoryEvaluationMode,
  'evaluated_at_ms': 200000,
  'owner_declaration': _owner.toJson(),
  'owner_declaration_unverified': true,
  'inventory_declarations_unverified': true,
  'notice': forgeDeviceInventoryNotice,
  'devices': [
    {
      'instance_id': 'runner-v1',
      'device': {
        'device_id': 'device-v1',
        'owner': _owner.toJson(),
        'approval_state': 'approved',
        'cordon_state': 'clear',
        'liveness': 'online',
        'snapshot_observed_at_ms': 150000,
        'lease_expires_at_ms': 210000,
        'os': 'linux',
        'architecture': 'amd64',
        'available_cpu_cores': 8,
        'available_memory_bytes': 16384,
        'available_storage_bytes': 8192,
        'runtimes': ['oci'],
        'gpu': {'present': false, 'memory_bytes': 0, 'runtime': ''},
        'data_residency_zones': ['us-west'],
        'trust_zone': 'standard',
        'sandbox_levels': ['container'],
        'concurrency_limit': 2,
        'active_concurrency': 0,
      },
    },
  ],
  'execution_authorized': false,
  'reservation_created': false,
  'dispatch_performed': false,
};

Future<ForgeCredentialStore> _credentialStore(String token) async {
  final store = ForgeCredentialStore(
    backend: MemoryForgeCredentialBackend(),
    forcePersistentStorage: true,
  );
  expect(await store.store(accessToken: token), isTrue);
  return store;
}

Future<void> _settle(WidgetTester tester) async {
  for (var index = 0; index < 8; index++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  setUp(BrowserNavigation.resetForTest);
  tearDown(BrowserNavigation.resetForTest);

  testWidgets('explicit Gate performs one authenticated v1 inventory read', (
    tester,
  ) async {
    final credentialStore = await _credentialStore('inventory-v1-token');
    final inventoryURLs = <Uri>[];
    final inventoryAuthorization = <String?>[];
    final client = MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations') {
        return _json({'conversations': <Object>[], 'has_more': false});
      }
      if (request.method == 'GET' && request.url.path == '/api/v1/devices') {
        inventoryURLs.add(request.url);
        inventoryAuthorization.add(request.headers['authorization']);
        return _json(_inventory());
      }
      throw StateError(
        'Unexpected Forge request: ${request.method} ${request.url}',
      );
    });
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsGate(
          credentialStore: credentialStore,
          httpClient: client,
          deviceInventoryOwner: _owner,
          enableDeviceInventoryCandidate: true,
          deviceInventoryCandidateApiOrigin: 'https://forge.example',
        ),
      ),
    );
    await _settle(tester);

    expect(inventoryURLs, [Uri.parse('https://forge.example/api/v1/devices')]);
    expect(inventoryAuthorization, ['Bearer inventory-v1-token']);
    expect(
      find.byKey(const ValueKey('forge-authenticated-device-inventory')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('forge-inventory-device-v1-runner-v1')),
      findsOneWidget,
    );
  });

  testWidgets('default Gate keeps v1 inventory candidate request-free', (
    tester,
  ) async {
    final credentialStore = await _credentialStore('inventory-v1-default');
    final candidateRequests = <http.Request>[];
    final client = MockClient((request) async {
      candidateRequests.add(request);
      if (request.url.path == '/api/v1/conversations') {
        return _json({'conversations': <Object>[], 'has_more': false});
      }
      throw StateError(
        'Default Gate contacted a candidate route: ${request.url}',
      );
    });
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsGate(
          credentialStore: credentialStore,
          httpClient: client,
          deviceInventoryOwner: _owner,
        ),
      ),
    );
    await _settle(tester);

    expect(
      candidateRequests.where(
        (request) => request.url.path == '/api/v1/devices',
      ),
      isEmpty,
    );
    expect(
      find.byKey(const ValueKey('forge-authenticated-device-inventory')),
      findsNothing,
    );
  });

  testWidgets('v1 candidate without explicit origin stays request-free', (
    tester,
  ) async {
    final credentialStore = await _credentialStore('inventory-v1-no-origin');
    final candidateRequests = <http.Request>[];
    final client = MockClient((request) async {
      candidateRequests.add(request);
      if (request.url.path == '/api/v1/conversations') {
        return _json({'conversations': <Object>[], 'has_more': false});
      }
      throw StateError('Missing-origin candidate issued: ${request.url}');
    });
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsGate(
          credentialStore: credentialStore,
          httpClient: client,
          deviceInventoryOwner: _owner,
          enableDeviceInventoryCandidate: true,
        ),
      ),
    );
    await _settle(tester);

    expect(
      candidateRequests.where(
        (request) => request.url.path == '/api/v1/devices',
      ),
      isEmpty,
    );
    expect(
      find.byKey(const ValueKey('forge-authenticated-device-inventory')),
      findsNothing,
    );
  });
}
