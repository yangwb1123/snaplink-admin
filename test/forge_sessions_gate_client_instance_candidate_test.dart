import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sso_admin/api/forge_client_instance_resource_view.dart';
import 'package:sso_admin/api/forge_client_instance_session_view.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/screens/forge/forge_sessions_gate.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/services/forge_credential_store.dart';
import 'package:sso_admin/session.dart';

import 'support/memory_forge_credential_backend.dart';

void main() {
  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  setUp(() => BrowserNavigation.resetForTest());

  tearDown(() {
    BrowserNavigation.resetForTest();
    Session.clear();
  });

  testWidgets(
    'explicit Gate flags create owner-bound bearer readers for both views',
    (tester) async {
      final credentialStore = await _credentialStore('candidate-token');
      final owner = ForgeDeviceOwner(
        issuer: 'https://id.example',
        subject: 'user-1',
        tenantID: 'tenant-1',
      );
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/v1/conversations') {
          return _json({'conversations': <Object>[], 'has_more': false});
        }
        if (request.url.path == '/api/v1/client-instances/session-view') {
          return _json(_sessionView(owner));
        }
        if (request.url.path == '/api/v1/client-instances/resource-view') {
          return _json(_resourceView(owner));
        }
        throw StateError('Unexpected Forge request: ${request.url}');
      });
      addTearDown(client.close);

      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsGate(
            credentialStore: credentialStore,
            httpClient: client,
            clientInstanceSessionViewOwner: owner,
            clientInstanceSessionViewCandidateApiOrigin:
                'https://candidate.example',
            enableClientInstanceSessionViewCandidate: true,
            clientInstanceResourceViewOwner: owner,
            clientInstanceResourceViewCandidateApiOrigin:
                'https://candidate.example',
            enableClientInstanceResourceViewCandidate: true,
          ),
        ),
      );
      await _pump(tester);

      expect(
        find.byKey(const ValueKey('forge-client-instance-session-view-panel')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('forge-client-instance-resource-view-panel')),
        findsOneWidget,
      );
      final sessionRequests = requests
          .where(
            (request) =>
                request.url.path == '/api/v1/client-instances/session-view',
          )
          .toList();
      final resourceRequests = requests
          .where(
            (request) =>
                request.url.path == '/api/v1/client-instances/resource-view',
          )
          .toList();
      expect(sessionRequests, hasLength(1));
      expect(resourceRequests, hasLength(1));
      expect(
        sessionRequests.single.headers['authorization'],
        'Bearer candidate-token',
      );
      expect(
        resourceRequests.single.headers['authorization'],
        'Bearer candidate-token',
      );
    },
  );

  testWidgets(
    'caller readers take precedence and disabled defaults stay request-free',
    (tester) async {
      final credentialStore = await _credentialStore('caller-token');
      final owner = ForgeDeviceOwner(
        issuer: 'https://id.example',
        subject: 'user-1',
        tenantID: 'tenant-1',
      );
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/v1/conversations') {
          return _json({'conversations': <Object>[], 'has_more': false});
        }
        throw StateError(
          'Candidate route must remain disabled: ${request.url}',
        );
      });
      addTearDown(client.close);

      var sessionReaderCalls = 0;
      var resourceReaderCalls = 0;
      final sessionView = ForgeClientInstanceSessionView.fromJson(
        _sessionView(owner),
      );
      final resourceView = ForgeClientInstanceResourceView.fromJson(
        _resourceView(owner),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsGate(
            credentialStore: credentialStore,
            httpClient: client,
            // Flags and origins are intentionally supplied, but explicit
            // readers remain authoritative and must not be shadowed.
            enableClientInstanceSessionViewCandidate: true,
            clientInstanceSessionViewCandidateApiOrigin:
                'https://candidate.example',
            clientInstanceSessionViewOwner: owner,
            clientInstanceSessionViewReader: (requestedOwner) async {
              sessionReaderCalls++;
              expect(requestedOwner, owner);
              return sessionView;
            },
            enableClientInstanceResourceViewCandidate: true,
            clientInstanceResourceViewCandidateApiOrigin:
                'https://candidate.example',
            clientInstanceResourceViewOwner: owner,
            clientInstanceResourceViewReader: (requestedOwner) async {
              resourceReaderCalls++;
              expect(requestedOwner, owner);
              return resourceView;
            },
          ),
        ),
      );
      await _pump(tester);

      expect(sessionReaderCalls, 1);
      expect(resourceReaderCalls, 1);
      expect(
        requests.where(
          (request) => request.url.path.startsWith('/api/v1/client-instances/'),
        ),
        isEmpty,
      );
      expect(
        find.byKey(const ValueKey('forge-client-instance-session-view-panel')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('forge-client-instance-resource-view-panel')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'candidate Gate readers refresh on the scheduled change-feed boundary',
    (tester) async {
      final credentialStore = await _credentialStore(
        'scheduled-candidate-token',
      );
      final owner = ForgeDeviceOwner(
        issuer: 'https://id.example',
        subject: 'scheduled-user',
        tenantID: 'tenant-scheduled',
      );
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.url.path == '/api/v1/conversations') {
          return _json({'conversations': <Object>[], 'has_more': false});
        }
        if (request.url.path == '/api/v1/conversation-changes') {
          final after = request.url.queryParameters['after_cursor'] ?? '0';
          return _json({
            'after_cursor': int.parse(after),
            'scanned_through_cursor': int.parse(after),
            'has_more': false,
            'changes': <Object>[],
          });
        }
        if (request.url.path == '/api/v1/client-instances/session-view') {
          return _json(_sessionView(owner));
        }
        if (request.url.path == '/api/v1/client-instances/resource-view') {
          return _json(_resourceView(owner));
        }
        throw StateError('Unexpected Forge request: ${request.url}');
      });
      addTearDown(client.close);

      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsGate(
            credentialStore: credentialStore,
            httpClient: client,
            clientInstanceSessionViewOwner: owner,
            clientInstanceSessionViewCandidateApiOrigin:
                'https://candidate.example',
            enableClientInstanceSessionViewCandidate: true,
            clientInstanceResourceViewOwner: owner,
            clientInstanceResourceViewCandidateApiOrigin:
                'https://candidate.example',
            enableClientInstanceResourceViewCandidate: true,
          ),
        ),
      );
      await _pump(tester);

      expect(
        requests.where(
          (request) =>
              request.url.path == '/api/v1/client-instances/session-view',
        ),
        hasLength(1),
      );
      expect(
        requests.where(
          (request) =>
              request.url.path == '/api/v1/client-instances/resource-view',
        ),
        hasLength(1),
      );

      // ForgeSessionsScreen polls the owner change feed every 15 seconds.
      // The candidate adapters must participate in that scheduled refresh
      // while remaining opt-in and display-only.
      await tester.pump(const Duration(seconds: 16));
      await _pump(tester);

      final sessionRequests = requests
          .where(
            (request) =>
                request.url.path == '/api/v1/client-instances/session-view',
          )
          .toList();
      final resourceRequests = requests
          .where(
            (request) =>
                request.url.path == '/api/v1/client-instances/resource-view',
          )
          .toList();
      expect(sessionRequests.length, greaterThanOrEqualTo(2));
      expect(resourceRequests.length, greaterThanOrEqualTo(2));
      expect(
        sessionRequests.every(
          (request) =>
              request.headers['authorization'] ==
              'Bearer scheduled-candidate-token',
        ),
        isTrue,
      );
      expect(
        resourceRequests.every(
          (request) =>
              request.headers['authorization'] ==
              'Bearer scheduled-candidate-token',
        ),
        isTrue,
      );
      expect(
        find.byKey(const ValueKey('forge-client-instance-session-view-panel')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('forge-client-instance-resource-view-panel')),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
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

Map<String, dynamic> _owner(ForgeDeviceOwner owner) => owner.toJson();

Map<String, dynamic> _sessionView(ForgeDeviceOwner owner) => {
  'schema_version': forgeClientInstanceSessionViewSchema,
  'evaluation_mode': forgeClientInstanceSessionViewEvaluationMode,
  'owner_declaration': _owner(owner),
  'owner_declaration_unverified': true,
  'instances': [
    {
      'instance_id': 'client-cli-001',
      'client_kind': 'cli',
      'session_ids': ['conversation-001'],
      'observed_at_ms': 200500,
      'status': 'active',
    },
  ],
  'read_only': true,
  'authority': _authority(),
};

Map<String, dynamic> _resourceView(ForgeDeviceOwner owner) => {
  'schema_version': forgeClientInstanceResourceViewSchema,
  'evaluation_mode': forgeClientInstanceResourceViewEvaluationMode,
  'owner_declaration': _owner(owner),
  'owner_declaration_unverified': true,
  'instances': [
    {
      'instance_id': 'client-cli-001',
      'client_kind': 'cli',
      'session_ids': ['conversation-001'],
      'observed_at_ms': 200500,
      'status': 'active',
    },
  ],
  'devices': <Object>[],
  'device_attributes_unverified': true,
  'read_only': true,
  'authority': _authority(),
};

Map<String, bool> _authority() => {
  'owner_authenticated': false,
  'session_read_authorized': false,
  'prompt_write_authorized': false,
  'device_identity_verified': false,
  'reservation_created': false,
  'execution_authorized': false,
  'dispatch_performed': false,
  'audit_published': false,
};
