import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/api/forge_device_inventory_resource_convergence.dart';
import 'package:sso_admin/api/forge_device_placement.dart';
import 'package:sso_admin/api/forge_client_instance_resource_view.dart';
import 'package:sso_admin/api/forge_client_instance_session_view.dart';
import 'package:sso_admin/api/forge_client_instance_session_resource_convergence.dart';
import 'package:sso_admin/api/forge_scheduler_selection_lease.dart';
import 'package:sso_admin/screens/forge/forge_sessions_gate.dart';
import 'package:sso_admin/screens/forge/forge_scheduler_selection_lease_panel.dart';
import 'package:sso_admin/screens/forge/forge_scheduler_selection_lease_release_panel.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/services/forge_credential_store.dart';
import 'package:sso_admin/session.dart';

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

  testWidgets('explicit Gate performs one scheduler lease POST', (
    tester,
  ) async {
    final store = await _credentialStore('lease-token');
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/api/v1/conversations') {
        return _json({'conversations': <Object>[], 'has_more': false});
      }
      if (request.url.path == '/api/v1/device-placement/scheduler-lease') {
        expect(request.method, 'POST');
        expect(request.headers['authorization'], 'Bearer lease-token');
        expect(request.headers['idempotency-key'], 'lease-key-00000001');
        expect(
          ForgeSchedulerSelectionLeaseRequest.fromJson(
            jsonDecode(request.body),
          ).toJson(),
          _request().toJson(),
        );
        return _json(_lease().toJson());
      }
      throw StateError('Unexpected Forge request: ${request.url}');
    });
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsGate(
          credentialStore: store,
          httpClient: client,
          schedulerSelectionLeaseRequest: _request(),
          schedulerSelectionLeaseCandidateApiOrigin:
              'https://candidate.example',
          schedulerSelectionLeaseIdempotencyKey: 'lease-key-00000001',
          enableSchedulerSelectionLeaseCandidate: true,
        ),
      ),
    );
    await _pump(tester);

    expect(
      requests.where(
        (request) =>
            request.url.path == '/api/v1/device-placement/scheduler-lease',
      ),
      hasLength(1),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets(
    'web app and mobile claim only after independent instance readers converge',
    (tester) async {
      for (final clientKind in const ['web', 'app', 'mobile']) {
        final store = await _credentialStore('$clientKind-lease-token');
        final events = <String>[];
        final requests = <http.Request>[];
        final owner = _owner();
        final client = MockClient((request) async {
          requests.add(request);
          if (request.method == 'GET' &&
              request.url.path == '/api/v1/conversations') {
            return _json({
              'conversations': [_conversation('conversation-1')],
              'has_more': false,
            });
          }
          if (request.method == 'GET' &&
              request.url.path ==
                  '/api/v1/conversations/conversation-1/prompts') {
            return _json({
              'conversation_id': 'conversation-1',
              'prompts': <Object>[],
              'has_more': false,
            });
          }
          if (request.method == 'GET' &&
              request.url.path == '/api/v1/conversations/conversation-1/runs') {
            return _json({
              'conversation_id': 'conversation-1',
              'runs': [_run('run-1')],
              'has_more': false,
            });
          }
          if (request.method == 'GET' &&
              request.url.path ==
                  '/api/v1/conversations/conversation-1/runs/run-1/timeline') {
            return _json({
              'conversation_id': 'conversation-1',
              'run_id': 'run-1',
              'after_sequence': 0,
              'scanned_through_sequence': 0,
              'has_more': false,
              'events': <Object>[],
            });
          }
          if (request.method == 'POST' &&
              request.url.path == '/api/v1/device-placement/scheduler-lease') {
            events.add('$clientKind:claim');
            expect(
              request.headers['authorization'],
              'Bearer $clientKind-lease-token',
            );
            expect(request.headers['idempotency-key'], 'pair-$clientKind-key');
            expect(
              ForgeSchedulerSelectionLeaseRequest.fromJson(
                jsonDecode(request.body),
              ).toJson(),
              _request().toJson(),
            );
            return _json(_lease().toJson());
          }
          throw StateError(
            'Unexpected Forge request: ${request.method} ${request.url}',
          );
        });

        await tester.pumpWidget(
          MaterialApp(
            home: ForgeSessionsGate(
              credentialStore: store,
              httpClient: client,
              initialConversationID: 'conversation-1',
              initialClientInstanceID: 'client-$clientKind-001',
              clientInstanceSessionViewOwner: owner,
              clientInstanceSessionViewReader: (_) async {
                events.add('$clientKind:session');
                return _pairSessionView(owner, clientKind);
              },
              clientInstanceResourceViewOwner: owner,
              clientInstanceResourceViewReader: (_) async {
                events.add('$clientKind:resource');
                return _pairResourceView(owner, clientKind);
              },
              schedulerSelectionLeaseRequest: _request(),
              schedulerSelectionLeaseCandidateApiOrigin:
                  'https://candidate.example',
              schedulerSelectionLeaseIdempotencyKey: 'pair-$clientKind-key',
              enableSchedulerSelectionLeaseCandidate: true,
            ),
          ),
        );
        await _pump(tester);

        final claimIndex = events.indexOf('$clientKind:claim');
        expect(claimIndex, greaterThanOrEqualTo(0));
        expect(events.sublist(0, claimIndex), contains('$clientKind:session'));
        expect(events.sublist(0, claimIndex), contains('$clientKind:resource'));
        expect(
          requests.where(
            (request) =>
                request.url.path == '/api/v1/device-placement/scheduler-lease',
          ),
          hasLength(1),
        );

        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        client.close();
        await store.clear();
      }
    },
  );

  testWidgets(
    'claim reads inventory and resource pair first and stays closed on drift',
    (tester) async {
      final fixture = ForgeDeviceInventoryResourceConvergence.fromJsonText(
        File(
          'docs/contracts/fixtures/forge-device-inventory-resource-convergence-v1.json',
        ).readAsStringSync(),
      );
      final store = await _credentialStore('inventory-lease-token');
      final events = <String>[];
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        switch ('${request.method} ${request.url.path}') {
          case 'GET /api/v1/conversations':
            return _json({
              'conversations': [_conversation('conversation-001')],
              'has_more': false,
            });
          case 'GET /api/v1/conversations/conversation-001/prompts':
            return _json({
              'conversation_id': 'conversation-001',
              'prompts': <Object>[],
              'has_more': false,
            });
          case 'GET /api/v1/conversations/conversation-001/runs':
            return _json({
              'conversation_id': 'conversation-001',
              'runs': [_run('run-1')],
              'has_more': false,
            });
          case 'GET /api/v1/conversations/conversation-001/runs/run-1/timeline':
            return _json({
              'conversation_id': 'conversation-001',
              'run_id': 'run-1',
              'after_sequence': 0,
              'scanned_through_sequence': 0,
              'has_more': false,
              'events': <Object>[],
            });
          case 'POST /api/v1/device-placement/scheduler-lease':
            events.add('claim');
            return _json(_lease().toJson());
          default:
            throw StateError(
              'Unexpected Forge request: ${request.method} ${request.url}',
            );
        }
      });
      addTearDown(client.close);
      addTearDown(store.clear);

      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsGate(
            credentialStore: store,
            httpClient: client,
            initialConversationID: 'conversation-001',
            initialClientInstanceID: 'client-web-001',
            deviceInventoryOwner: fixture.inventory.owner,
            deviceInventoryV2Reader: (_) async {
              events.add('inventory');
              return fixture.inventory;
            },
            clientInstanceResourceViewOwner: fixture.inventory.owner,
            clientInstanceResourceViewReader: (_) async {
              events.add('resource');
              return fixture.resourceView;
            },
            schedulerSelectionLeaseRequest: _request(
              conversationID: 'conversation-001',
            ),
            schedulerSelectionLeaseCandidateApiOrigin:
                'https://candidate.example',
            schedulerSelectionLeaseIdempotencyKey: 'inventory-lease-key',
            enableSchedulerSelectionLeaseCandidate: true,
          ),
        ),
      );
      await _pump(tester);

      final claimIndex = events.indexOf('claim');
      expect(claimIndex, greaterThanOrEqualTo(0));
      expect(events.sublist(0, claimIndex), contains('inventory'));
      expect(events.sublist(0, claimIndex), contains('resource'));
      expect(
        requests.where(
          (request) =>
              request.url.path == '/api/v1/device-placement/scheduler-lease',
        ),
        hasLength(1),
      );

      await tester.pumpWidget(const SizedBox());
      await tester.pump();

      final drifted = Map<String, dynamic>.from(fixture.resourceView.toJson());
      final devices = List<Map<String, dynamic>>.from(
        (drifted['devices'] as List).map(
          (value) => Map<String, dynamic>.from(value as Map),
        ),
      );
      devices.single['revision'] = 99;
      drifted['devices'] = devices;
      final driftedResource = ForgeClientInstanceResourceView.fromJson(drifted);
      final driftRequests = <http.Request>[];
      final driftClient = MockClient((request) async {
        driftRequests.add(request);
        if (request.url.path == '/api/v1/conversations') {
          return _json({
            'conversations': [_conversation('conversation-001')],
            'has_more': false,
          });
        }
        if (request.url.path == '/api/v1/device-placement/scheduler-lease') {
          throw StateError('Inventory/resource drift must block lease claim.');
        }
        throw StateError(
          'Unexpected Forge request: ${request.method} ${request.url}',
        );
      });
      addTearDown(driftClient.close);
      final driftStore = await _credentialStore('inventory-drift-token');
      addTearDown(driftStore.clear);
      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsGate(
            credentialStore: driftStore,
            httpClient: driftClient,
            initialConversationID: 'conversation-001',
            initialClientInstanceID: 'client-web-001',
            deviceInventoryOwner: fixture.inventory.owner,
            deviceInventoryV2Reader: (_) async => fixture.inventory,
            clientInstanceResourceViewOwner: fixture.inventory.owner,
            clientInstanceResourceViewReader: (_) async => driftedResource,
            schedulerSelectionLeaseRequest: _request(
              conversationID: 'conversation-001',
            ),
            schedulerSelectionLeaseCandidateApiOrigin:
                'https://candidate.example',
            schedulerSelectionLeaseIdempotencyKey: 'inventory-drift-key',
            enableSchedulerSelectionLeaseCandidate: true,
          ),
        ),
      );
      await _pump(tester);
      expect(
        driftRequests.where(
          (request) =>
              request.url.path == '/api/v1/device-placement/scheduler-lease',
        ),
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets(
    'composed inventory pair must converge with the selected session pair before claim',
    (tester) async {
      final inventory = ForgeDeviceInventoryResourceConvergence.fromJsonText(
        File(
          'docs/contracts/fixtures/forge-device-inventory-resource-convergence-v1.json',
        ).readAsStringSync(),
      );
      final sessionPair = _sessionPairForResource(inventory.resourceView);
      final store = await _credentialStore('composed-inventory-lease-token');
      final events = <String>[];
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        switch ('${request.method} ${request.url.path}') {
          case 'GET /api/v1/conversations':
            return _json({
              'conversations': [_conversation('conversation-001')],
              'has_more': false,
            });
          case 'GET /api/v1/conversations/conversation-001/prompts':
            return _json({
              'conversation_id': 'conversation-001',
              'prompts': <Object>[],
              'has_more': false,
            });
          case 'GET /api/v1/conversations/conversation-001/runs':
            return _json({
              'conversation_id': 'conversation-001',
              'runs': [_run('run-1')],
              'has_more': false,
            });
          case 'GET /api/v1/conversations/conversation-001/runs/run-1/timeline':
            return _json({
              'conversation_id': 'conversation-001',
              'run_id': 'run-1',
              'after_sequence': 0,
              'scanned_through_sequence': 0,
              'has_more': false,
              'events': <Object>[],
            });
          case 'POST /api/v1/device-placement/scheduler-lease':
            events.add('claim');
            return _json(_lease().toJson());
          default:
            throw StateError(
              'Unexpected Forge request: ${request.method} ${request.url}',
            );
        }
      });
      addTearDown(client.close);
      addTearDown(store.clear);

      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsGate(
            credentialStore: store,
            httpClient: client,
            initialConversationID: 'conversation-001',
            initialClientInstanceID: 'client-web-001',
            deviceInventoryResourceConvergenceOwner: inventory.owner,
            deviceInventoryResourceConvergenceReader: (_) async {
              events.add('inventory/resource');
              return inventory;
            },
            clientInstanceSessionResourceConvergenceOwner: inventory.owner,
            clientInstanceSessionResourceConvergenceReader: (_) async {
              events.add('session/resource');
              return sessionPair;
            },
            schedulerSelectionLeaseRequest: _request(
              conversationID: 'conversation-001',
            ),
            schedulerSelectionLeaseCandidateApiOrigin:
                'https://candidate.example',
            schedulerSelectionLeaseIdempotencyKey: 'composed-inventory-key',
            enableSchedulerSelectionLeaseCandidate: true,
          ),
        ),
      );
      await _pump(tester);

      final claimIndex = events.indexOf('claim');
      expect(claimIndex, greaterThanOrEqualTo(0));
      expect(
        events.sublist(0, claimIndex),
        containsAll(<String>['inventory/resource', 'session/resource']),
      );
      expect(
        requests.where(
          (request) =>
              request.url.path == '/api/v1/device-placement/scheduler-lease',
        ),
        hasLength(1),
      );

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets(
    'composed inventory pair drift keeps the scheduler lease request-free',
    (tester) async {
      final inventory = ForgeDeviceInventoryResourceConvergence.fromJsonText(
        File(
          'docs/contracts/fixtures/forge-device-inventory-resource-convergence-v1.json',
        ).readAsStringSync(),
      );
      final drifted = Map<String, dynamic>.from(
        inventory.resourceView.toJson(),
      );
      final devices = List<Map<String, dynamic>>.from(
        (drifted['devices'] as List).map(
          (value) => Map<String, dynamic>.from(value as Map),
        ),
      );
      devices.single['revision'] = 99;
      drifted['devices'] = devices;
      final driftedPair = _sessionPairForResource(
        ForgeClientInstanceResourceView.fromJson(drifted),
      );
      final store = await _credentialStore('composed-inventory-drift-token');
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        switch ('${request.method} ${request.url.path}') {
          case 'GET /api/v1/conversations':
            return _json({
              'conversations': [_conversation('conversation-001')],
              'has_more': false,
            });
          case 'GET /api/v1/conversations/conversation-001/prompts':
            return _json({
              'conversation_id': 'conversation-001',
              'prompts': <Object>[],
              'has_more': false,
            });
          case 'GET /api/v1/conversations/conversation-001/runs':
            return _json({
              'conversation_id': 'conversation-001',
              'runs': [_run('run-1')],
              'has_more': false,
            });
          case 'GET /api/v1/conversations/conversation-001/runs/run-1/timeline':
            return _json({
              'conversation_id': 'conversation-001',
              'run_id': 'run-1',
              'after_sequence': 0,
              'scanned_through_sequence': 0,
              'has_more': false,
              'events': <Object>[],
            });
          case 'POST /api/v1/device-placement/scheduler-lease':
            throw StateError(
              'Composed inventory/resource drift must block scheduler lease.',
            );
          default:
            throw StateError(
              'Unexpected Forge request: ${request.method} ${request.url}',
            );
        }
      });
      addTearDown(client.close);
      addTearDown(store.clear);

      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsGate(
            credentialStore: store,
            httpClient: client,
            initialConversationID: 'conversation-001',
            initialClientInstanceID: 'client-web-001',
            deviceInventoryResourceConvergenceOwner: inventory.owner,
            deviceInventoryResourceConvergenceReader: (_) async => inventory,
            clientInstanceSessionResourceConvergenceOwner: inventory.owner,
            clientInstanceSessionResourceConvergenceReader: (_) async =>
                driftedPair,
            schedulerSelectionLeaseRequest: _request(
              conversationID: 'conversation-001',
            ),
            schedulerSelectionLeaseCandidateApiOrigin:
                'https://candidate.example',
            schedulerSelectionLeaseIdempotencyKey:
                'composed-inventory-drift-key',
            enableSchedulerSelectionLeaseCandidate: true,
          ),
        ),
      );
      await _pump(tester);

      expect(
        requests.where(
          (request) =>
              request.url.path == '/api/v1/device-placement/scheduler-lease',
        ),
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets('web app and mobile hidden instance stays claim request-free', (
    tester,
  ) async {
    for (final clientKind in const ['web', 'app', 'mobile']) {
      final store = await _credentialStore('$clientKind-hidden-token');
      final requests = <http.Request>[];
      final owner = _owner();
      final client = MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET' &&
            request.url.path == '/api/v1/conversations') {
          return _json({
            'conversations': [_conversation('conversation-1')],
            'has_more': false,
          });
        }
        if (request.method == 'POST' &&
            request.url.path == '/api/v1/device-placement/scheduler-lease') {
          throw StateError(
            'Hidden $clientKind instance must not reach scheduler lease.',
          );
        }
        throw StateError(
          'Unexpected Forge request: ${request.method} ${request.url}',
        );
      });

      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsGate(
            credentialStore: store,
            httpClient: client,
            initialConversationID: 'conversation-1',
            initialClientInstanceID: 'client-$clientKind-001',
            clientInstanceSessionViewOwner: owner,
            clientInstanceSessionViewReader: (_) async => _pairSessionView(
              owner,
              clientKind,
              conversationID: 'conversation-hidden',
            ),
            clientInstanceResourceViewOwner: owner,
            clientInstanceResourceViewReader: (_) async => _pairResourceView(
              owner,
              clientKind,
              conversationID: 'conversation-hidden',
            ),
            schedulerSelectionLeaseRequest: _request(),
            schedulerSelectionLeaseCandidateApiOrigin:
                'https://candidate.example',
            schedulerSelectionLeaseIdempotencyKey: 'hidden-$clientKind-key',
            enableSchedulerSelectionLeaseCandidate: true,
          ),
        ),
      );
      await _pump(tester);

      expect(
        requests.where(
          (request) =>
              request.url.path == '/api/v1/device-placement/scheduler-lease',
        ),
        isEmpty,
      );
      expect(find.text('Target: device-a/runner-a'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      client.close();
      await store.clear();
    }
  });

  testWidgets('default Gate keeps scheduler lease request-free', (
    tester,
  ) async {
    final store = await _credentialStore('default-token');
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/api/v1/conversations') {
        return _json({'conversations': <Object>[], 'has_more': false});
      }
      throw StateError('Default Gate contacted candidate: ${request.url}');
    });
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsGate(
          credentialStore: store,
          httpClient: client,
          schedulerSelectionLeaseRequest: _request(),
        ),
      ),
    );
    await _pump(tester);

    expect(
      requests.where(
        (request) =>
            request.url.path == '/api/v1/device-placement/scheduler-lease',
      ),
      isEmpty,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('explicit Gate performs one scheduler lease renewal POST', (
    tester,
  ) async {
    final store = await _credentialStore('renew-token');
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/api/v1/conversations') {
        return _json({'conversations': <Object>[], 'has_more': false});
      }
      if (request.url.path ==
          '/api/v1/device-placement/scheduler-lease/renew') {
        expect(request.method, 'POST');
        expect(request.headers['authorization'], 'Bearer renew-token');
        expect(request.headers['idempotency-key'], 'renew-key-00000001');
        expect(
          ForgeSchedulerSelectionLeaseRenewalRequest.fromJson(
            jsonDecode(request.body),
          ).toJson(),
          _renewalRequest().toJson(),
        );
        return _json(_renewedLease().toJson());
      }
      throw StateError('Unexpected Forge request: ${request.url}');
    });
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsGate(
          credentialStore: store,
          httpClient: client,
          schedulerSelectionLeaseRenewalRequest: _renewalRequest(),
          schedulerSelectionLeaseRenewalCandidateApiOrigin:
              'https://candidate.example',
          schedulerSelectionLeaseRenewalIdempotencyKey: 'renew-key-00000001',
          enableSchedulerSelectionLeaseRenewalCandidate: true,
        ),
      ),
    );
    await _pump(tester);

    expect(
      requests.where(
        (request) =>
            request.url.path ==
            '/api/v1/device-placement/scheduler-lease/renew',
      ),
      hasLength(1),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('explicit Gate performs one scheduler lease release POST', (
    tester,
  ) async {
    final store = await _credentialStore('release-token');
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/api/v1/conversations') {
        return _json({'conversations': <Object>[], 'has_more': false});
      }
      if (request.url.path ==
          '/api/v1/device-placement/scheduler-lease/release') {
        expect(request.method, 'POST');
        expect(request.headers['authorization'], 'Bearer release-token');
        expect(request.headers['idempotency-key'], 'release-key-00000001');
        expect(
          ForgeSchedulerSelectionLeaseReleaseRequest.fromJson(
            jsonDecode(request.body),
          ).toJson(),
          _releaseRequest().toJson(),
        );
        return _json(_release().toJson());
      }
      throw StateError('Unexpected Forge request: ${request.url}');
    });
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsGate(
          credentialStore: store,
          httpClient: client,
          schedulerSelectionLeaseReleaseRequest: _releaseRequest(),
          schedulerSelectionLeaseReleaseCandidateApiOrigin:
              'https://candidate.example',
          schedulerSelectionLeaseReleaseIdempotencyKey: 'release-key-00000001',
          enableSchedulerSelectionLeaseReleaseCandidate: true,
        ),
      ),
    );
    await _pump(tester);

    expect(
      requests.where(
        (request) =>
            request.url.path ==
            '/api/v1/device-placement/scheduler-lease/release',
      ),
      hasLength(1),
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets('lease panel withholds the fencing token', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ForgeSchedulerSelectionLeasePanel(lease: _lease()),
        ),
      ),
    );

    expect(find.text('Target: device-a/runner-a'), findsOneWidget);
    expect(find.text('Epoch: 1'), findsOneWidget);
    expect(find.text('token-a'), findsNothing);
    expect(find.textContaining('fencing token is withheld'), findsOneWidget);
  });

  testWidgets('lease release panel withholds the fencing token', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ForgeSchedulerSelectionLeaseReleasePanel(release: _release()),
        ),
      ),
    );

    expect(find.text('Target: device-a/runner-a'), findsOneWidget);
    expect(find.text('Epoch: 2'), findsOneWidget);
    expect(find.text('token-b'), findsNothing);
  });
}

ForgeSchedulerSelectionLeaseRequest _request({
  String conversationID = 'conversation-1',
}) => ForgeSchedulerSelectionLeaseRequest(
  conversationID: conversationID,
  runID: 'run-1',
  attemptID: 'attempt-1',
  requirements: const ForgeDevicePlacementRequirements(
    os: 'linux',
    architecture: 'amd64',
    minCPUCores: 1,
    minMemoryBytes: 1,
    minStorageBytes: 1,
    runtime: 'oci',
    gpu: ForgeDevicePlacementGpuRequirement(
      required: false,
      minMemoryBytes: 0,
      runtime: '',
    ),
    dataResidencyZones: ['us-west'],
    minimumTrustZone: 'standard',
    sandboxFloor: 'container',
    concurrencySlots: 1,
  ),
  ttlMS: 30000,
);

ForgeDeviceOwner _owner() => const ForgeDeviceOwner(
  issuer: 'https://id.example',
  subject: 'user-a',
  tenantID: 'tenant-a',
);

Map<String, dynamic> _conversation(String id) => {
  'conversation': {
    'id': id,
    'scope': {'kind': 'global'},
    'title': 'Scheduler lease pair test',
    'created_at_ms': 1,
    'updated_at_ms': 2,
  },
  'aggregate_version': 1,
};

Map<String, dynamic> _run(String id) => {
  'run_id': id,
  'prompt_id': 'prompt-1',
  'created_at_ms': 10,
  'latest_sequence': 1,
  'status': 'nonterminal',
};

ForgeClientInstanceSessionView _pairSessionView(
  ForgeDeviceOwner owner,
  String clientKind, {
  String conversationID = 'conversation-1',
}) => ForgeClientInstanceSessionView.fromJson({
  'schema_version': forgeClientInstanceSessionViewSchema,
  'evaluation_mode': forgeClientInstanceSessionViewEvaluationMode,
  'owner_declaration': owner.toJson(),
  'owner_declaration_unverified': true,
  'instances': [
    {
      'instance_id': 'client-$clientKind-001',
      'client_kind': clientKind,
      'session_ids': [conversationID],
      'observed_at_ms': 1,
      'status': 'active',
    },
  ],
  'read_only': true,
  'authority': const ForgeClientInstanceSessionViewAuthority.offline().toJson(),
});

ForgeClientInstanceResourceView _pairResourceView(
  ForgeDeviceOwner owner,
  String clientKind, {
  String conversationID = 'conversation-1',
}) => ForgeClientInstanceResourceView.fromJson({
  'schema_version': forgeClientInstanceResourceViewSchema,
  'evaluation_mode': forgeClientInstanceResourceViewEvaluationMode,
  'owner_declaration': owner.toJson(),
  'owner_declaration_unverified': true,
  'instances': [
    {
      'instance_id': 'client-$clientKind-001',
      'client_kind': clientKind,
      'session_ids': [conversationID],
      'observed_at_ms': 1,
      'status': 'active',
    },
  ],
  'devices': <Object>[],
  'device_attributes_unverified': true,
  'read_only': true,
  'authority': const ForgeClientInstanceSessionViewAuthority.offline().toJson(),
});

ForgeClientInstanceSessionResourceConvergence _sessionPairForResource(
  ForgeClientInstanceResourceView resource,
) => ForgeClientInstanceSessionResourceConvergence.fromJson({
  'schema_version': forgeClientInstanceSessionResourceConvergenceSchema,
  'evaluation_mode':
      forgeClientInstanceSessionResourceConvergenceEvaluationMode,
  'session_view': {
    'schema_version': forgeClientInstanceSessionViewSchema,
    'evaluation_mode': forgeClientInstanceSessionViewEvaluationMode,
    'owner_declaration': resource.owner.toJson(),
    'owner_declaration_unverified': true,
    'instances': resource.instances
        .map((instance) => instance.toJson())
        .toList(),
    'read_only': true,
    'authority': const ForgeClientInstanceSessionViewAuthority.offline()
        .toJson(),
  },
  'resource_view': resource.toJson(),
  'converged': true,
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
});

ForgeSchedulerSelectionLeaseRenewalRequest _renewalRequest() =>
    const ForgeSchedulerSelectionLeaseRenewalRequest(
      conversationID: 'conversation-1',
      runID: 'run-1',
      attemptID: 'attempt-1',
      targetID: 'runner-a',
      epoch: 1,
      fencingToken: 'token-a',
      ttlMS: 30000,
    );

ForgeSchedulerSelectionLeaseReleaseRequest _releaseRequest() =>
    const ForgeSchedulerSelectionLeaseReleaseRequest(
      conversationID: 'conversation-1',
      runID: 'run-1',
      attemptID: 'attempt-1',
      targetID: 'runner-a',
      epoch: 2,
      fencingToken: 'token-b',
    );

ForgeSchedulerSelectionLease _lease() => const ForgeSchedulerSelectionLease(
  schemaVersion: ForgeSchedulerSelectionLease.schema,
  mode: ForgeSchedulerSelectionLease.evaluationMode,
  owner: ForgeDeviceOwner(
    issuer: 'https://id.example',
    subject: 'user-a',
    tenantID: 'tenant-a',
  ),
  conversationID: 'conversation-1',
  runID: 'run-1',
  attemptID: 'attempt-1',
  deviceID: 'device-a',
  instanceID: 'runner-a',
  inventoryRevision: 1,
  generation: 1,
  heartbeatSequence: 1,
  grant: ForgeExecutionLeaseGrant(
    version: 1,
    attemptID: 'attempt-1',
    targetID: 'runner-a',
    epoch: 1,
    fencingToken: 'token-a',
    issuedAtMS: 1800000000000,
    expiresAtMS: 1800000030000,
  ),
  replayed: false,
  authority: ForgeSchedulerSelectionLeaseAuthority(
    placementSelected: true,
    reservationCreated: true,
    leaseIssued: true,
    executionAuthorized: false,
    dispatchPerformed: false,
    auditPublished: false,
  ),
);

ForgeSchedulerSelectionLease _renewedLease() => ForgeSchedulerSelectionLease(
  schemaVersion: ForgeSchedulerSelectionLease.schema,
  mode: ForgeSchedulerSelectionLease.evaluationMode,
  owner: const ForgeDeviceOwner(
    issuer: 'https://id.example',
    subject: 'user-a',
    tenantID: 'tenant-a',
  ),
  conversationID: 'conversation-1',
  runID: 'run-1',
  attemptID: 'attempt-1',
  deviceID: 'device-a',
  instanceID: 'runner-a',
  inventoryRevision: 1,
  generation: 1,
  heartbeatSequence: 1,
  grant: const ForgeExecutionLeaseGrant(
    version: 1,
    attemptID: 'attempt-1',
    targetID: 'runner-a',
    epoch: 2,
    fencingToken: 'token-b',
    issuedAtMS: 1800000010000,
    expiresAtMS: 1800000040000,
  ),
  replayed: false,
  authority: const ForgeSchedulerSelectionLeaseAuthority(
    placementSelected: true,
    reservationCreated: true,
    leaseIssued: true,
    executionAuthorized: false,
    dispatchPerformed: false,
    auditPublished: false,
  ),
);

ForgeSchedulerSelectionLeaseRelease _release() =>
    const ForgeSchedulerSelectionLeaseRelease(
      schemaVersion: ForgeSchedulerSelectionLeaseRelease.schema,
      mode: ForgeSchedulerSelectionLeaseRelease.evaluationMode,
      owner: ForgeDeviceOwner(
        issuer: 'https://id.example',
        subject: 'user-a',
        tenantID: 'tenant-a',
      ),
      conversationID: 'conversation-1',
      runID: 'run-1',
      attemptID: 'attempt-1',
      deviceID: 'device-a',
      instanceID: 'runner-a',
      epoch: 2,
      releasedAtMS: 1800000020000,
      replayed: false,
      authority: ForgeSchedulerSelectionLeaseReleaseAuthority(
        placementSelected: false,
        reservationCreated: false,
        leaseIssued: false,
        executionAuthorized: false,
        dispatchPerformed: false,
        auditPublished: false,
      ),
    );

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
