import 'dart:async';
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

  testWidgets('independent session and resource readers fail closed on drift', (
    tester,
  ) async {
    final credentialStore = await _credentialStore('drift-token');
    final owner = ForgeDeviceOwner(
      issuer: 'https://id.example',
      subject: 'drift-user',
      tenantID: 'tenant-drift',
    );
    var promptReads = 0;
    final client = MockClient((request) async {
      if (request.url.path == '/api/v1/conversations') {
        return _json({
          'conversations': [
            {
              'conversation': {
                'id': 'conversation-001',
                'scope': {'kind': 'global'},
                'title': 'Drift guarded session',
                'created_at_ms': 10,
                'updated_at_ms': 20,
              },
              'aggregate_version': 1,
            },
          ],
          'has_more': false,
        });
      }
      if (request.url.path.endsWith('/prompts')) {
        promptReads++;
        return _json({
          'conversation_id': 'conversation-001',
          'prompts': [
            {
              'id': 'prompt-001',
              'conversation_id': 'conversation-001',
              'role': 'user',
              'content': 'private prompt before resource drift',
              'created_at_ms': 30,
            },
          ],
          'has_more': false,
        });
      }
      if (request.url.path.endsWith('/runs')) {
        return _json({
          'conversation_id': 'conversation-001',
          'runs': <Object>[],
          'has_more': false,
        });
      }
      if (request.url.path == '/api/v1/conversation-changes') {
        final cursor = request.url.queryParameters['after_cursor'] ?? '0';
        return _json({
          'after_cursor': int.parse(cursor),
          'scanned_through_cursor': int.parse(cursor),
          'has_more': false,
          'changes': <Object>[],
        });
      }
      throw StateError('Unexpected owner request: ${request.url}');
    });
    addTearDown(client.close);

    final canonicalSession = ForgeClientInstanceSessionView.fromJson(
      _sessionView(owner),
    );
    final canonicalResource = ForgeClientInstanceResourceView.fromJson(
      _resourceView(owner),
    );
    var resourceReads = 0;

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsGate(
          credentialStore: credentialStore,
          httpClient: client,
          initialClientInstanceID: 'client-cli-001',
          clientInstanceSessionViewOwner: owner,
          clientInstanceSessionViewReader: (_) async => canonicalSession,
          clientInstanceResourceViewOwner: owner,
          clientInstanceResourceViewReader: (_) async {
            resourceReads++;
            if (resourceReads != 2) return canonicalResource;
            final drifted = canonicalResource.toJson();
            final instances = drifted['instances']! as List<Object?>;
            final row = Map<String, dynamic>.from(instances.first! as Map);
            row['observed_at_ms'] = 200501;
            instances[0] = row;
            return ForgeClientInstanceResourceView.fromJson(drifted);
          },
        ),
      ),
    );
    await _pump(tester);
    for (var index = 0; index < 20; index++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }

    expect(resourceReads, 1);
    for (var index = 0; index < 4; index++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -600));
      await tester.pump();
    }
    expect(
      find.byKey(const ValueKey('forge-conversation-conversation-001')),
      findsOneWidget,
    );
    expect(find.text('private prompt before resource drift'), findsOneWidget);
    expect(promptReads, 1);

    // The change-feed boundary forces both independent readers again. The
    // resource row now has a different observed_at_ms, so the selected
    // instance must become empty rather than using the session reader alone.
    await tester.pump(const Duration(seconds: 16));
    await _pump(tester);

    expect(resourceReads, greaterThanOrEqualTo(2));
    expect(
      find.text('No conversations are visible from this client instance.'),
      findsOneWidget,
    );
    expect(find.text('private prompt before resource drift'), findsNothing);
    expect(promptReads, 1);

    // The failed projection check backs off the next poll. A later refresh
    // returns the matching image, and the pair can converge again without
    // reusing the hidden Prompt projection automatically.
    await tester.pump(const Duration(seconds: 31));
    await _pump(tester);
    expect(resourceReads, greaterThanOrEqualTo(3));
    expect(
      find.byKey(const ValueKey('forge-conversation-conversation-001')),
      findsOneWidget,
    );
    expect(find.text('private prompt before resource drift'), findsNothing);
    expect(promptReads, 1);
  });

  testWidgets('independent observation refresh revokes an in-flight Run read', (
    tester,
  ) async {
    final credentialStore = await _credentialStore('run-drift-token');
    final owner = ForgeDeviceOwner(
      issuer: 'https://id.example',
      subject: 'run-drift-user',
      tenantID: 'tenant-run-drift',
    );
    final runResponse = Completer<http.Response>();
    var runReads = 0;
    var resourceReads = 0;
    final client = MockClient((request) async {
      if (request.url.path == '/api/v1/conversations') {
        return _json({
          'conversations': [
            {
              'conversation': {
                'id': 'conversation-001',
                'scope': {'kind': 'global'},
                'title': 'In-flight Run guard',
                'created_at_ms': 10,
                'updated_at_ms': 20,
              },
              'aggregate_version': 1,
            },
          ],
          'has_more': false,
        });
      }
      if (request.url.path.endsWith('/prompts')) {
        return _json({
          'conversation_id': 'conversation-001',
          'prompts': <Object>[],
          'has_more': false,
        });
      }
      if (request.url.path.endsWith('/runs')) {
        runReads++;
        return runResponse.future;
      }
      if (request.url.path.endsWith('/timeline')) {
        return _json({
          'conversation_id': 'conversation-001',
          'run_id': 'run-001',
          'after_sequence': 0,
          'scanned_through_sequence': 0,
          'has_more': false,
          'events': <Object>[],
        });
      }
      if (request.url.path == '/api/v1/conversation-changes') {
        return _json({
          'after_cursor': 0,
          'scanned_through_cursor': 0,
          'has_more': false,
          'changes': <Object>[],
        });
      }
      throw StateError('Unexpected owner request: ${request.url}');
    });
    addTearDown(client.close);

    final canonicalSession = ForgeClientInstanceSessionView.fromJson(
      _sessionView(owner),
    );
    final canonicalResource = ForgeClientInstanceResourceView.fromJson(
      _resourceView(owner),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsGate(
          credentialStore: credentialStore,
          httpClient: client,
          initialConversationID: 'conversation-001',
          initialClientInstanceID: 'client-cli-001',
          clientInstanceSessionViewOwner: owner,
          clientInstanceSessionViewReader: (_) async => canonicalSession,
          clientInstanceResourceViewOwner: owner,
          clientInstanceResourceViewReader: (_) async {
            resourceReads++;
            if (resourceReads == 1) return canonicalResource;
            final drifted = canonicalResource.toJson();
            final instances = drifted['instances']! as List<Object?>;
            final row = Map<String, dynamic>.from(instances.first! as Map);
            row['observed_at_ms'] = 200501;
            instances[0] = row;
            return ForgeClientInstanceResourceView.fromJson(drifted);
          },
        ),
      ),
    );
    for (var index = 0; index < 20 && runReads == 0; index++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    expect(runReads, 1);
    expect(resourceReads, 1);

    // The scheduled refresh changes only the resource observation while the
    // owner Run request is still in flight. The hidden response must not
    // repopulate the selected Run after this projection becomes invalid.
    await tester.pump(const Duration(seconds: 16));
    await _pump(tester);
    expect(resourceReads, greaterThanOrEqualTo(2));

    runResponse.complete(
      _json({
        'conversation_id': 'conversation-001',
        'runs': [
          {
            'run_id': 'run-001',
            'prompt_id': 'prompt-001',
            'created_at_ms': 10,
            'latest_sequence': 1,
            'status': 'nonterminal',
          },
        ],
        'has_more': false,
      }),
    );
    await _pump(tester);
    expect(find.byKey(const ValueKey('forge-run-run-001')), findsNothing);
  });

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
