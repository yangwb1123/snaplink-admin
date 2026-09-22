import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/screens/forge/forge_sessions_gate.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/services/forge_credential_store.dart';
import 'package:sso_admin/session.dart';

import 'support/forge_lifecycle_registry_fixture.dart';
import 'support/memory_forge_credential_backend.dart';

void main() {
  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  setUp(BrowserNavigation.resetForTest);
  tearDown(() {
    BrowserNavigation.resetForTest();
    Session.clear();
  });

  testWidgets(
    'explicit candidate Gate performs one authenticated owner-bound GET',
    (tester) async {
      final credentialStore = await _credentialStore('candidate-token');
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/v1/conversations') {
          return _json({'conversations': <Object>[], 'has_more': false});
        }
        if (request.url.path ==
            '/api/v1/device-enrollment-heartbeat/lifecycle-registry') {
          return _json(forgeLifecycleRegistryTestEnvelope());
        }
        throw StateError('Unexpected Forge request: ${request.url}');
      });
      addTearDown(client.close);

      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsGate(
            credentialStore: credentialStore,
            httpClient: client,
            lifecycleRegistryOwner: forgeLifecycleRegistryTestOwner,
            lifecycleRegistryCandidateApiOrigin: 'https://candidate.example',
            enableLifecycleRegistryCandidate: true,
          ),
        ),
      );
      await _pump(tester);

      final registryRequests = requests
          .where(
            (request) =>
                request.url.path ==
                '/api/v1/device-enrollment-heartbeat/lifecycle-registry',
          )
          .toList();
      expect(registryRequests, hasLength(1));
      expect(registryRequests.single.method, 'GET');
      expect(registryRequests.single.url.query, isEmpty);
      expect(registryRequests.single.body, isEmpty);
      expect(
        registryRequests.single.headers['authorization'],
        'Bearer candidate-token',
      );
      expect(
        find.byKey(const ValueKey('forge-lifecycle-registry-panel')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets('default Gate remains lifecycle-registry request-free', (
    tester,
  ) async {
    final credentialStore = await _credentialStore('default-token');
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/api/v1/conversations') {
        return _json({'conversations': <Object>[], 'has_more': false});
      }
      throw StateError(
        'Default Gate contacted an opt-in route: ${request.url}',
      );
    });
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsGate(
          credentialStore: credentialStore,
          httpClient: client,
        ),
      ),
    );
    await _pump(tester);

    expect(
      requests.where(
        (request) => request.url.path.contains('lifecycle-registry'),
      ),
      isEmpty,
    );
    expect(
      find.byKey(const ValueKey('forge-lifecycle-registry-panel')),
      findsNothing,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('candidate flag without explicit origin remains request-free', (
    tester,
  ) async {
    final credentialStore = await _credentialStore('missing-origin-token');
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
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
          lifecycleRegistryOwner: forgeLifecycleRegistryTestOwner,
          enableLifecycleRegistryCandidate: true,
        ),
      ),
    );
    await _pump(tester);

    expect(
      requests.where(
        (request) => request.url.path.contains('lifecycle-registry'),
      ),
      isEmpty,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('candidate Gate rejects a response bound to another owner', (
    tester,
  ) async {
    final credentialStore = await _credentialStore('foreign-owner-token');
    final foreignOwner = const ForgeDeviceOwner(
      issuer: 'https://id.example',
      subject: 'foreign-user',
      tenantID: 'tenant-1',
    );
    final client = MockClient((request) async {
      if (request.url.path == '/api/v1/conversations') {
        return _json({'conversations': <Object>[], 'has_more': false});
      }
      if (request.url.path ==
          '/api/v1/device-enrollment-heartbeat/lifecycle-registry') {
        return _json(forgeLifecycleRegistryTestEnvelope(owner: foreignOwner));
      }
      throw StateError('Unexpected Forge request: ${request.url}');
    });
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsGate(
          credentialStore: credentialStore,
          httpClient: client,
          lifecycleRegistryOwner: forgeLifecycleRegistryTestOwner,
          lifecycleRegistryCandidateApiOrigin: 'https://candidate.example',
          enableLifecycleRegistryCandidate: true,
        ),
      ),
    );
    await _pump(tester);

    expect(
      find.byKey(const ValueKey('forge-lifecycle-registry-panel')),
      findsNothing,
    );
    expect(find.text('Forge returned an invalid response.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });
}

Future<ForgeCredentialStore> _credentialStore(String token) async {
  final store = ForgeCredentialStore(
    backend: MemoryForgeCredentialBackend(),
    forcePersistentStorage: true,
  );
  expect(await store.store(accessToken: token), isTrue);
  return store;
}

Future<void> _pump(WidgetTester tester) async {
  for (var index = 0; index < 10; index++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
}

http.Response _json(Object value) => http.Response(
  jsonEncode(value),
  200,
  headers: const {'content-type': 'application/json'},
);
