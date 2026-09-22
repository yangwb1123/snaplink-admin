import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sso_admin/api/forge_device_credential_candidate.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/screens/forge/forge_sessions_gate.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/services/forge_credential_store.dart';
import 'package:sso_admin/session.dart';

import 'support/memory_forge_credential_backend.dart';

const _owner = ForgeDeviceOwner(
  issuer: 'https://id.example',
  subject: 'user-1',
  tenantID: 'tenant-1',
);

final _request = ForgeDeviceCredentialLifecycleRequest(
  deviceID: 'device-1',
  action: 'issue',
  approvalState: 'approved',
  credentialID: 'credential-1',
  keyID: 'key-1',
  publicKeySHA256: 'a' * 64,
  keyGeneration: 1,
  issuedAtMS: 100,
  expiresAtMS: 1100,
  nextCredentialID: '',
  nextKeyID: '',
  nextPublicKeySHA256: '',
  observedAtMS: 1000,
  expectedDeviceRevision: 7,
);

Map<String, dynamic> _candidate({ForgeDeviceOwner owner = _owner}) => {
  'schema_version': 'forge.device-credential-lifecycle/v1',
  'evaluation_mode': 'pure_device_credential_lifecycle',
  'owner': owner.toJson(),
  'device_id': 'device-1',
  'action': 'issue',
  'revision': 7,
  'next': {
    'credential_id': 'credential-1',
    'device_id': 'device-1',
    'owner': owner.toJson(),
    'approval_state': 'approved',
    'credential_state': 'active',
    'key_id': 'key-1',
    'public_key_sha256': 'a' * 64,
    'key_generation': 1,
    'issued_at_ms': 100,
    'expires_at_ms': 1100,
  },
  'preview_only': true,
  'candidate_published': true,
  'authority': {
    'owner_binding_matched': false,
    'owner_authenticated': false,
    'credential_material_made': false,
    'persisted': false,
    'inventory_authoritative': false,
    'execution_authorized': false,
  },
};

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

  testWidgets('explicit Gate posts one owner-bound credential candidate', (
    tester,
  ) async {
    final credentialStore = await _credentialStore('candidate-token');
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/api/v1/conversations') {
        return _json({'conversations': <Object>[], 'has_more': false});
      }
      if (request.url.path ==
          '/api/v1/device-enrollment-heartbeat/credential-candidate') {
        return _json(_candidate());
      }
      throw StateError('Unexpected Forge request: ${request.url}');
    });
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsGate(
          credentialStore: credentialStore,
          httpClient: client,
          deviceCredentialCandidateOwner: _owner,
          deviceCredentialCandidateRequest: _request,
          deviceCredentialCandidateApiOrigin: 'https://candidate.example',
          enableDeviceCredentialCandidate: true,
        ),
      ),
    );
    await _pump(tester);

    final candidateRequests = requests
        .where(
          (request) =>
              request.url.path ==
              '/api/v1/device-enrollment-heartbeat/credential-candidate',
        )
        .toList();
    expect(candidateRequests, hasLength(1));
    expect(candidateRequests.single.method, 'POST');
    expect(candidateRequests.single.url.query, isEmpty);
    expect(jsonDecode(candidateRequests.single.body), _request.toJson());
    expect(
      candidateRequests.single.headers['authorization'],
      'Bearer candidate-token',
    );
    expect(
      find.byKey(const ValueKey('forge-device-credential-candidate-panel')),
      findsOneWidget,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('default Gate keeps credential candidate request-free', (
    tester,
  ) async {
    final credentialStore = await _credentialStore('default-token');
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/api/v1/conversations') {
        return _json({'conversations': <Object>[], 'has_more': false});
      }
      throw StateError('Default Gate contacted a candidate route: $request');
    });
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsGate(
          credentialStore: credentialStore,
          httpClient: client,
          deviceCredentialCandidateOwner: _owner,
          deviceCredentialCandidateRequest: _request,
        ),
      ),
    );
    await _pump(tester);

    expect(
      requests.where(
        (request) => request.url.path.contains('device-enrollment-heartbeat'),
      ),
      isEmpty,
    );
    expect(
      find.byKey(const ValueKey('forge-device-credential-candidate-panel')),
      findsNothing,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('candidate flag without explicit origin stays request-free', (
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
          deviceCredentialCandidateOwner: _owner,
          deviceCredentialCandidateRequest: _request,
          enableDeviceCredentialCandidate: true,
        ),
      ),
    );
    await _pump(tester);

    expect(
      requests.where(
        (request) => request.url.path.contains('device-enrollment-heartbeat'),
      ),
      isEmpty,
    );
    expect(
      find.byKey(const ValueKey('forge-device-credential-candidate-panel')),
      findsNothing,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('Gate rejects a candidate returned for another owner', (
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
          '/api/v1/device-enrollment-heartbeat/credential-candidate') {
        return _json(_candidate(owner: foreignOwner));
      }
      throw StateError('Unexpected Forge request: ${request.url}');
    });
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsGate(
          credentialStore: credentialStore,
          httpClient: client,
          deviceCredentialCandidateOwner: _owner,
          deviceCredentialCandidateRequest: _request,
          deviceCredentialCandidateApiOrigin: 'https://candidate.example',
          enableDeviceCredentialCandidate: true,
        ),
      ),
    );
    await _pump(tester);

    expect(
      find.byKey(const ValueKey('forge-device-credential-candidate-panel')),
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
