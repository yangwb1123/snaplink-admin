import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sso_admin/api/forge_client_instance_resource_view.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/screens/forge/forge_client_instance_resource_view_panel.dart';
import 'package:sso_admin/screens/forge/forge_sessions_gate.dart';
import 'package:sso_admin/screens/forge/forge_sessions_screen.dart';
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

  testWidgets('renders instances and resources as metadata only', (
    tester,
  ) async {
    final fixture = ForgeClientInstanceResourceView.fromJson(_fixture());

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ForgeClientInstanceResourceViewPanel(fixture: fixture),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('forge-client-instance-resource-view-panel')),
      findsOneWidget,
    );
    expect(find.text('Client instance resource view'), findsOneWidget);
    expect(
      find.text(
        'Read-only metadata; resources are unverified and cannot run work.',
      ),
      findsOneWidget,
    );
    expect(find.text('client-cli-001'), findsOneWidget);
    expect(find.text('device-a'), findsOneWidget);
    expect(find.textContaining('Runner runner-a'), findsOneWidget);
    expect(find.textContaining('cpu=7/8'), findsNWidgets(2));
    expect(
      find.textContaining('memory=8589934592/17179869184'),
      findsNWidgets(2),
    );
    expect(find.byType(ButtonStyleButton), findsNothing);
    expect(find.byType(IconButton), findsNothing);
  });

  testWidgets(
    'renders through the shared Forge Sessions screen without devices',
    (tester) async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        expect(request.method, 'GET');
        if (request.url.path == '/api/v1/conversations') {
          return http.Response(
            '{"conversations":[],"has_more":false}',
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        if (request.url.path == '/api/v1/conversation-changes') {
          return http.Response(
            '{"after_cursor":0,"scanned_through_cursor":0,'
            '"has_more":false,"changes":[]}',
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        throw StateError('Unexpected Forge request: ${request.url}');
      });
      addTearDown(client.close);

      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsScreen(
            accessToken: 'fixture-access',
            apiOrigin: 'https://forge.example',
            httpClient: client,
            clientInstanceResourceViewPreview:
                ForgeClientInstanceResourceView.fromJson(_fixture()),
          ),
        ),
      );
      for (var count = 0; count < 8; count++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }

      expect(
        find.byKey(const ValueKey('forge-client-instance-resource-view-panel')),
        findsOneWidget,
      );
      expect(find.text('device-b'), findsOneWidget);
      expect(
        requests.where((request) => request.url.path.contains('/devices')),
        isEmpty,
      );
      expect(
        requests.where(
          (request) => request.url.path == '/api/v1/conversations',
        ),
        isNotEmpty,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets('loads the resource view only through an explicit owner reader', (
    tester,
  ) async {
    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      if (request.url.path == '/api/v1/conversations') {
        return http.Response(
          '{"conversations":[],"has_more":false}',
          200,
          headers: const {'content-type': 'application/json'},
        );
      }
      if (request.url.path == '/api/v1/conversation-changes') {
        return http.Response(
          '{"after_cursor":0,"scanned_through_cursor":0,'
          '"has_more":false,"changes":[]}',
          200,
          headers: const {'content-type': 'application/json'},
        );
      }
      throw StateError('Unexpected Forge request: ${request.url}');
    });
    addTearDown(client.close);

    final owner = ForgeDeviceOwner.fromJson(_owner());
    var readerCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: 'reader-access',
          apiOrigin: 'https://forge.example',
          httpClient: client,
          clientInstanceResourceViewOwner: owner,
          clientInstanceResourceViewReader: (requestedOwner) async {
            readerCalls++;
            expect(requestedOwner, owner);
            return ForgeClientInstanceResourceView.fromJson(_fixture());
          },
        ),
      ),
    );
    for (var count = 0; count < 8; count++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }

    expect(readerCalls, 1);
    expect(
      find.byKey(const ValueKey('forge-client-instance-resource-view-panel')),
      findsOneWidget,
    );
    expect(
      requests.where(
        (request) =>
            request.url.path == '/api/v1/client-instances/resource-view',
      ),
      isEmpty,
    );
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
  });

  testWidgets(
    'keeps the selected instance empty when its resource reader is revoked',
    (tester) async {
      final client = MockClient((request) async {
        final path = request.url.path;
        if (request.method == 'GET' && path == '/api/v1/conversations') {
          return http.Response(
            jsonEncode({
              'conversations': [
                {
                  'conversation': {
                    'id': 'conversation-001',
                    'scope': {'kind': 'global'},
                    'title': 'Shared from CLI and Web',
                    'created_at_ms': 10,
                    'updated_at_ms': 20,
                  },
                  'aggregate_version': 1,
                },
                {
                  'conversation': {
                    'id': 'conversation-002',
                    'scope': {'kind': 'global'},
                    'title': 'CLI-only session',
                    'created_at_ms': 11,
                    'updated_at_ms': 21,
                  },
                  'aggregate_version': 1,
                },
              ],
              'has_more': false,
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        if (request.method == 'GET' && path.endsWith('/prompts')) {
          return http.Response(
            jsonEncode({
              'conversation_id': path.split('/')[4],
              'prompts': <Object>[],
              'has_more': false,
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        if (request.method == 'GET' && path.endsWith('/runs')) {
          return http.Response(
            jsonEncode({
              'conversation_id': path.split('/')[4],
              'runs': <Object>[],
              'has_more': false,
            }),
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        if (request.method == 'GET' && path == '/api/v1/conversation-changes') {
          return http.Response(
            '{"after_cursor":0,"scanned_through_cursor":0,'
            '"has_more":false,"changes":[]}',
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        throw StateError('Unexpected Forge request: ${request.method} $path');
      });
      addTearDown(client.close);

      final owner = ForgeDeviceOwner.fromJson(_owner());
      Widget buildScreen({required bool readerEnabled}) => MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: 'resource-reader-revocation-access',
          apiOrigin: 'https://forge.example',
          httpClient: client,
          clientInstanceResourceViewOwner: readerEnabled ? owner : null,
          clientInstanceResourceViewReader: readerEnabled
              ? (_) async =>
                    ForgeClientInstanceResourceView.fromJson(_fixture())
              : null,
        ),
      );

      await tester.pumpWidget(buildScreen(readerEnabled: true));
      for (var count = 0; count < 8; count++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('forge-client-instance-resource-view-panel')),
        findsOneWidget,
      );
      for (var count = 0; count < 20; count++) {
        if (find
            .byKey(const ValueKey('forge-client-instance-session-filter-menu'))
            .evaluate()
            .isNotEmpty) {
          break;
        }
        await tester.drag(find.byType(ListView).first, const Offset(0, -500));
        await tester.pump();
      }
      expect(
        find.byKey(const ValueKey('forge-client-instance-session-filter-menu')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('forge-client-instance-session-filter-menu')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('client-web-001').last);
      await tester.pumpAndSettle();
      for (var count = 0; count < 20; count++) {
        if (find
            .byKey(const ValueKey('forge-conversation-conversation-001'))
            .evaluate()
            .isNotEmpty) {
          break;
        }
        await tester.drag(find.byType(ListView).first, const Offset(0, -500));
        await tester.pump();
      }

      expect(
        find.byKey(const ValueKey('forge-conversation-conversation-001')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('forge-conversation-conversation-002')),
        findsNothing,
      );

      await tester.pumpWidget(buildScreen(readerEnabled: false));
      for (var count = 0; count < 8; count++) {
        await tester.pump();
      }

      expect(
        find.byKey(const ValueKey('forge-conversation-conversation-001')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('forge-conversation-conversation-002')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('forge-client-instance-session-filter')),
        findsOneWidget,
      );
      expect(
        find.text('No conversations are visible from this client instance.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets('scheduled change sync refreshes the resource view reader', (
    tester,
  ) async {
    final client = MockClient((request) async {
      if (request.url.path == '/api/v1/conversations') {
        return http.Response(
          '{"conversations":[],"has_more":false}',
          200,
          headers: const {'content-type': 'application/json'},
        );
      }
      if (request.url.path == '/api/v1/conversation-changes') {
        final after = request.url.queryParameters['after_cursor'] ?? '0';
        return http.Response(
          '{"after_cursor":$after,"scanned_through_cursor":$after,'
          '"has_more":false,"changes":[]}',
          200,
          headers: const {'content-type': 'application/json'},
        );
      }
      throw StateError('Unexpected Forge request: ${request.url}');
    });
    addTearDown(client.close);

    final owner = ForgeDeviceOwner.fromJson(_owner());
    var readerCalls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: 'scheduled-access',
          apiOrigin: 'https://forge.example',
          httpClient: client,
          clientInstanceResourceViewOwner: owner,
          clientInstanceResourceViewReader: (requestedOwner) async {
            readerCalls++;
            expect(requestedOwner, owner);
            return ForgeClientInstanceResourceView.fromJson(_fixture());
          },
        ),
      ),
    );
    for (var count = 0; count < 8; count++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    expect(readerCalls, 1);

    await tester.pump(const Duration(seconds: 16));
    for (var count = 0; count < 8; count++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }

    expect(readerCalls, greaterThanOrEqualTo(2));
  });

  testWidgets('Gate forwards the resource view without a device request', (
    tester,
  ) async {
    final backend = MemoryForgeCredentialBackend();
    final credentialStore = ForgeCredentialStore(
      backend: backend,
      forcePersistentStorage: true,
    );
    expect(await credentialStore.store(accessToken: 'gate-access'), isTrue);

    final requests = <http.Request>[];
    final client = MockClient((request) async {
      requests.add(request);
      expect(request.method, 'GET');
      if (request.url.path == '/api/v1/conversations') {
        return http.Response(
          '{"conversations":[],"has_more":false}',
          200,
          headers: const {'content-type': 'application/json'},
        );
      }
      if (request.url.path == '/api/v1/conversation-changes') {
        return http.Response(
          '{"after_cursor":0,"scanned_through_cursor":0,'
          '"has_more":false,"changes":[]}',
          200,
          headers: const {'content-type': 'application/json'},
        );
      }
      throw StateError('Unexpected Forge request: ${request.url}');
    });
    addTearDown(client.close);

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsGate(
          credentialStore: credentialStore,
          httpClient: client,
          clientInstanceResourceViewPreview:
              ForgeClientInstanceResourceView.fromJson(_fixture()),
        ),
      ),
    );
    for (var count = 0; count < 8; count++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }

    expect(
      find.byKey(const ValueKey('forge-client-instance-resource-view-panel')),
      findsOneWidget,
    );
    expect(find.textContaining('Runner runner-b'), findsOneWidget);
    expect(
      requests.where((request) => request.url.path.contains('/devices')),
      isEmpty,
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
