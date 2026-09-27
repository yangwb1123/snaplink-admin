import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/api/forge_device_inventory_v2_models.dart';
import 'package:sso_admin/api/forge_client_instance_resource_view.dart';
import 'package:sso_admin/screens/forge/forge_sessions_gate.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/services/forge_credential_store.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'support/memory_forge_credential_backend.dart';

http.Response _json(Object value) => http.Response(
  jsonEncode(value),
  200,
  headers: const {'content-type': 'application/json'},
);

const _owner = ForgeDeviceOwner(
  issuer: 'https://id.example',
  subject: 'inventory-gate-user',
  tenantID: 'tenant-1',
);

Map<String, dynamic> _inventory() => {
  'schema_version': forgeDeviceInventoryV2Schema,
  'evaluation_mode': forgeDeviceInventoryV2EvaluationMode,
  'evaluated_at_ms': 200000,
  'owner_declaration': _owner.toJson(),
  'owner_declaration_unverified': true,
  'inventory_declarations_unverified': true,
  'notice': forgeDeviceInventoryV2Notice,
  'devices': <Object>[],
  'execution_authorized': false,
  'reservation_created': false,
  'dispatch_performed': false,
};

http.Client _client({
  List<Uri>? inventoryURLs,
  List<String?>? inventoryAuthorization,
  List<Uri>? resourceURLs,
  List<String?>? resourceAuthorization,
}) => MockClient((request) async {
  final path = request.url.path;
  if (request.method == 'GET' && path == '/api/v1/conversations') {
    return _json({
      'conversations': [
        {
          'conversation': {
            'id': 'conversation-1',
            'scope': {'kind': 'global'},
            'title': 'Inventory gate session',
            'created_at_ms': 10,
            'updated_at_ms': 20,
          },
          'aggregate_version': 1,
        },
      ],
      'has_more': false,
    });
  }
  if (request.method == 'GET' &&
      path == '/api/v1/conversations/conversation-1/prompts') {
    return _json({
      'conversation_id': 'conversation-1',
      'prompts': <Object>[],
      'has_more': false,
    });
  }
  if (request.method == 'GET' &&
      path == '/api/v1/conversations/conversation-1/runs') {
    return _json({
      'conversation_id': 'conversation-1',
      'runs': <Object>[],
      'has_more': false,
    });
  }
  if (request.method == 'GET' && path == '/api/v1/devices/observations/v2') {
    inventoryURLs?.add(request.url);
    inventoryAuthorization?.add(request.headers['authorization']);
    return _json(_inventory());
  }
  if (request.method == 'GET' &&
      path == '/api/v1/client-instances/resource-view') {
    resourceURLs?.add(request.url);
    resourceAuthorization?.add(request.headers['authorization']);
    return _json(_resourceView());
  }
  throw StateError('Unexpected Forge request: ${request.method} $path');
});

Map<String, dynamic> _resourceView() => {
  'schema_version': forgeClientInstanceResourceViewSchema,
  'evaluation_mode': forgeClientInstanceResourceViewEvaluationMode,
  'owner_declaration': _owner.toJson(),
  'owner_declaration_unverified': true,
  'instances': <Object>[],
  'devices': <Object>[],
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

  setUp(() => BrowserNavigation.resetForTest());
  tearDown(() => BrowserNavigation.resetForTest());

  testWidgets('Gate candidate performs one authenticated v2 inventory read', (
    tester,
  ) async {
    final backend = MemoryForgeCredentialBackend();
    final credentialStore = ForgeCredentialStore(
      backend: backend,
      forcePersistentStorage: true,
    );
    expect(
      await credentialStore.store(accessToken: 'inventory-gate-token'),
      isTrue,
    );
    final inventoryURLs = <Uri>[];
    final inventoryAuthorization = <String?>[];

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsGate(
          credentialStore: credentialStore,
          httpClient: _client(
            inventoryURLs: inventoryURLs,
            inventoryAuthorization: inventoryAuthorization,
          ),
          deviceInventoryOwner: _owner,
          enableDeviceInventoryV2Candidate: true,
          deviceInventoryV2CandidateApiOrigin: 'https://forge.example',
        ),
      ),
    );
    await _settle(tester);

    expect(
      find.byKey(const ValueKey('forge-authenticated-device-inventory-v2')),
      findsOneWidget,
    );
    expect(inventoryURLs, [
      Uri.parse('https://forge.example/api/v1/devices/observations/v2'),
    ]);
    expect(inventoryAuthorization, ['Bearer inventory-gate-token']);
  });

  testWidgets('Gate leaves v2 inventory candidate request-free by default', (
    tester,
  ) async {
    final backend = MemoryForgeCredentialBackend();
    final credentialStore = ForgeCredentialStore(
      backend: backend,
      forcePersistentStorage: true,
    );
    expect(
      await credentialStore.store(accessToken: 'inventory-default-token'),
      isTrue,
    );
    final inventoryURLs = <Uri>[];
    final resourceURLs = <Uri>[];

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsGate(
          credentialStore: credentialStore,
          httpClient: _client(
            inventoryURLs: inventoryURLs,
            resourceURLs: resourceURLs,
          ),
          deviceInventoryOwner: _owner,
          deviceInventoryResourceConvergenceOwner: _owner,
        ),
      ),
    );
    await _settle(tester);

    expect(inventoryURLs, isEmpty);
    expect(resourceURLs, isEmpty);
    expect(
      find.byKey(const ValueKey('forge-authenticated-device-inventory-v2')),
      findsNothing,
    );
  });

  testWidgets('Gate paired candidate performs two owner-bound GETs', (
    tester,
  ) async {
    final credentialStore = ForgeCredentialStore(
      backend: MemoryForgeCredentialBackend(),
      forcePersistentStorage: true,
    );
    expect(
      await credentialStore.store(accessToken: 'convergence-gate-token'),
      isTrue,
    );
    final inventoryURLs = <Uri>[];
    final resourceURLs = <Uri>[];
    final inventoryAuthorization = <String?>[];
    final resourceAuthorization = <String?>[];

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsGate(
          credentialStore: credentialStore,
          httpClient: _client(
            inventoryURLs: inventoryURLs,
            inventoryAuthorization: inventoryAuthorization,
            resourceURLs: resourceURLs,
            resourceAuthorization: resourceAuthorization,
          ),
          deviceInventoryResourceConvergenceOwner: _owner,
          enableDeviceInventoryResourceConvergenceCandidate: true,
          deviceInventoryResourceConvergenceCandidateApiOrigin:
              'https://forge.example',
        ),
      ),
    );
    await _settle(tester);
    await tester.pump(const Duration(milliseconds: 20));
    expect(inventoryURLs, [
      Uri.parse('https://forge.example/api/v1/devices/observations/v2'),
    ]);
    expect(resourceURLs, [
      Uri.parse('https://forge.example/api/v1/client-instances/resource-view'),
    ]);
    expect(inventoryAuthorization, ['Bearer convergence-gate-token']);
    expect(resourceAuthorization, ['Bearer convergence-gate-token']);
  });
}
