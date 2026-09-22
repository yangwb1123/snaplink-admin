import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/forge_conversations_api.dart';
import 'package:sso_admin/api/forge_device_inventory_models.dart';
import 'package:sso_admin/screens/forge/forge_sessions_screen.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

http.Response _json(Object value, {int status = 200}) => http.Response(
  jsonEncode(value),
  status,
  headers: const {'content-type': 'application/json'},
);

const _owner = ForgeDeviceOwner(
  issuer: 'https://id.example',
  subject: 'inventory-user',
  tenantID: 'tenant-1',
);

Map<String, dynamic> _owned() => {
  'conversations': [
    {
      'conversation': {
        'id': 'conversation-1',
        'scope': {'kind': 'global'},
        'title': 'Inventory session',
        'created_at_ms': 10,
        'updated_at_ms': 20,
      },
      'aggregate_version': 1,
    },
  ],
  'has_more': false,
};

Map<String, dynamic> _inventoryDevice({
  required ForgeDeviceOwner owner,
  required String deviceID,
  required String instanceID,
  required String architecture,
  required int cpu,
}) => {
  'instance_id': instanceID,
  'device': {
    'device_id': deviceID,
    'owner': owner.toJson(),
    'approval_state': 'approved',
    'cordon_state': 'clear',
    'liveness': 'online',
    'snapshot_observed_at_ms': 150000,
    'lease_expires_at_ms': 210000,
    'os': 'linux',
    'architecture': architecture,
    'available_cpu_cores': cpu,
    'available_memory_bytes': cpu * 2048,
    'available_storage_bytes': cpu * 1024,
    'runtimes': ['oci'],
    'gpu': {'present': false, 'memory_bytes': 0, 'runtime': ''},
    'data_residency_zones': ['us-west'],
    'trust_zone': 'standard',
    'sandbox_levels': ['container'],
    'concurrency_limit': cpu,
    'active_concurrency': 0,
  },
};

Map<String, dynamic> _inventory(ForgeDeviceOwner owner) => {
  'schema_version': forgeDeviceInventorySchema,
  'evaluation_mode': forgeDeviceInventoryEvaluationMode,
  'evaluated_at_ms': 200000,
  'owner_declaration': owner.toJson(),
  'owner_declaration_unverified': true,
  'inventory_declarations_unverified': true,
  'notice': forgeDeviceInventoryNotice,
  'devices': [
    _inventoryDevice(
      owner: owner,
      deviceID: 'device-a',
      instanceID: 'runner-a',
      architecture: 'amd64',
      cpu: 8,
    ),
    _inventoryDevice(
      owner: owner,
      deviceID: 'device-b',
      instanceID: 'runner-b',
      architecture: 'arm64',
      cpu: 4,
    ),
  ],
  'execution_authorized': false,
  'reservation_created': false,
  'dispatch_performed': false,
};

Map<String, dynamic> _inventoryV2(ForgeDeviceOwner owner) => {
  'schema_version': forgeDeviceInventoryV2Schema,
  'evaluation_mode': forgeDeviceInventoryV2EvaluationMode,
  'evaluated_at_ms': 200000,
  'owner_declaration': owner.toJson(),
  'owner_declaration_unverified': true,
  'inventory_declarations_unverified': true,
  'notice': forgeDeviceInventoryV2Notice,
  'devices': [
    {
      'instance_id': 'runner-v2',
      'revision': 3,
      'generation': 2,
      'heartbeat_sequence': 8,
      'device': {
        'device_id': 'device-v2',
        'owner': owner.toJson(),
        'approval_state': 'approved',
        'cordon_state': 'clear',
        'reservation_state': 'reserved',
        'liveness': 'online',
        'snapshot_observed_at_ms': 150000,
        'lease_expires_at_ms': 210000,
        'os': 'linux',
        'architecture': 'amd64',
        'available_cpu_cores': 8,
        'available_memory_bytes': 16384,
        'available_storage_bytes': 8192,
        'runtimes': ['oci'],
        'gpus': [
          {
            'id': 'gpu-v2',
            'vendor': 'NVIDIA',
            'memory_bytes': 1024,
            'available_memory_bytes': 768,
          },
        ],
        'data_residency_zones': <Object>[],
        'trust_zone': 'unknown',
        'sandbox_levels': <Object>[],
        'concurrency_limit': 0,
        'active_concurrency': 0,
      },
    },
  ],
  'execution_authorized': false,
  'reservation_created': false,
  'dispatch_performed': false,
};

Map<String, dynamic> _emptyRuns(http.Request request) => {
  'conversation_id': request.url.pathSegments[3],
  'runs': <Object>[],
  'has_more': false,
};

Future<void> _pumpRequests(WidgetTester tester) async {
  for (var count = 0; count < 8; count++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 10)),
    );
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  setUp(() => BrowserNavigation.resetForTest());
  tearDown(() => BrowserNavigation.resetForTest());

  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('renders the explicitly injected owner inventory once', (
    tester,
  ) async {
    var readerCalls = 0;
    final client = MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations') {
        return _json(_owned());
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations/conversation-1/prompts') {
        return _json({
          'conversation_id': 'conversation-1',
          'prompts': <Object>[],
          'has_more': false,
        });
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations/conversation-1/runs') {
        return _json(_emptyRuns(request));
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversation-changes') {
        return _json({
          'after_cursor': 0,
          'scanned_through_cursor': 0,
          'has_more': false,
          'changes': <Object>[],
        });
      }
      throw StateError(
        'Unexpected Forge request: ${request.method} ${request.url}',
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: 'forge-token',
          apiOrigin: 'https://forge.example',
          httpClient: client,
          deviceInventoryOwner: _owner,
          deviceInventoryReader: (owner) async {
            readerCalls++;
            expect(owner, _owner);
            return ForgeDeviceInventoryPage.fromJson(_inventory(owner));
          },
        ),
      ),
    );
    await _pumpRequests(tester);

    expect(readerCalls, 1);
    expect(
      find.byKey(const ValueKey('forge-authenticated-device-inventory')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('forge-inventory-device-a-runner-a')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('forge-inventory-device-b-runner-b')),
      findsOneWidget,
    );
    expect(find.text('Execution authorized: false'), findsOneWidget);
    expect(find.text('Reservation created: false'), findsOneWidget);
    expect(find.text('Dispatch performed: false'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.refresh).last);
    await _pumpRequests(tester);
    expect(readerCalls, 2);
  });

  testWidgets(
    'keeps the last inventory snapshot during a transient refresh failure',
    (tester) async {
      var readerCalls = 0;
      final refresh = Completer<ForgeDeviceInventoryPage>();
      final client = MockClient((request) async {
        if (request.method == 'GET' &&
            request.url.path == '/api/v1/conversations') {
          return _json(_owned());
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
          return _json(_emptyRuns(request));
        }
        if (request.method == 'GET' &&
            request.url.path == '/api/v1/conversation-changes') {
          return _json({
            'after_cursor': 0,
            'scanned_through_cursor': 0,
            'has_more': false,
            'changes': <Object>[],
          });
        }
        throw StateError(
          'Unexpected Forge request: ${request.method} ${request.url}',
        );
      });

      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsScreen(
            accessToken: 'forge-token',
            apiOrigin: 'https://forge.example',
            httpClient: client,
            deviceInventoryOwner: _owner,
            deviceInventoryReader: (owner) {
              readerCalls++;
              if (readerCalls == 1) {
                return Future<ForgeDeviceInventoryPage>.value(
                  ForgeDeviceInventoryPage.fromJson(_inventory(owner)),
                );
              }
              return refresh.future;
            },
          ),
        ),
      );
      await _pumpRequests(tester);
      expect(readerCalls, 1);
      expect(
        find.byKey(
          const ValueKey('forge-authenticated-device-inventory-panel'),
        ),
        findsOneWidget,
      );

      await tester.tap(find.byIcon(Icons.refresh).last);
      for (var count = 0; count < 12 && readerCalls < 2; count++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      expect(readerCalls, 2);
      expect(
        find.byKey(
          const ValueKey('forge-authenticated-device-inventory-panel'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('forge-device-inventory-stale')),
        findsOneWidget,
      );

      refresh.completeError(
        const ForgeConversationsApiException(
          statusCode: 503,
          code: 'service_unavailable',
          message: 'inventory unavailable',
        ),
      );
      await _pumpRequests(tester);
      expect(
        find.byKey(
          const ValueKey('forge-authenticated-device-inventory-panel'),
        ),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('forge-device-inventory-stale')),
        findsOneWidget,
      );
      expect(find.text('inventory unavailable'), findsOneWidget);
    },
  );

  testWidgets('renders and refreshes the actual owner-bound v2 page', (
    tester,
  ) async {
    var readerCalls = 0;
    final client = MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations') {
        return _json(_owned());
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations/conversation-1/prompts') {
        return _json({
          'conversation_id': 'conversation-1',
          'prompts': <Object>[],
          'has_more': false,
        });
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations/conversation-1/runs') {
        return _json(_emptyRuns(request));
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversation-changes') {
        return _json({
          'after_cursor': 0,
          'scanned_through_cursor': 0,
          'has_more': false,
          'changes': <Object>[],
        });
      }
      throw StateError(
        'Unexpected Forge request: ${request.method} ${request.url}',
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: 'forge-token',
          apiOrigin: 'https://forge.example',
          httpClient: client,
          deviceInventoryOwner: _owner,
          deviceInventoryV2Reader: (owner) async {
            readerCalls++;
            expect(owner, _owner);
            return ForgeDeviceInventoryPageV2.fromJson(_inventoryV2(owner));
          },
        ),
      ),
    );
    await _pumpRequests(tester);

    expect(readerCalls, 1);
    expect(
      find.byKey(const ValueKey('forge-authenticated-device-inventory-v2')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('forge-device-inventory-v2-panel')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('forge-inventory-v2-device-v2-runner-v2')),
      findsOneWidget,
    );
    expect(find.text('Reservation created: false'), findsOneWidget);
    expect(
      find.text('GPU gpu-v2: NVIDIA · memory 1024 B · available 768 B'),
      findsOneWidget,
    );

    await tester.tap(find.byIcon(Icons.refresh).last);
    await _pumpRequests(tester);
    expect(readerCalls, 2);
  });

  testWidgets('scheduled change sync refreshes the selected v2 inventory', (
    tester,
  ) async {
    var readerCalls = 0;
    final client = MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations') {
        return _json(_owned());
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations/conversation-1/prompts') {
        return _json({
          'conversation_id': 'conversation-1',
          'prompts': <Object>[],
          'has_more': false,
        });
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations/conversation-1/runs') {
        return _json(_emptyRuns(request));
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversation-changes') {
        final after = int.parse(
          request.url.queryParameters['after_cursor'] ?? '0',
        );
        return _json({
          'after_cursor': after,
          'scanned_through_cursor': after,
          'has_more': false,
          'changes': <Object>[],
        });
      }
      throw StateError(
        'Unexpected Forge request: ${request.method} ${request.url}',
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: 'forge-token',
          apiOrigin: 'https://forge.example',
          httpClient: client,
          deviceInventoryOwner: _owner,
          deviceInventoryV2Reader: (owner) async {
            readerCalls++;
            return ForgeDeviceInventoryPageV2.fromJson(_inventoryV2(owner));
          },
        ),
      ),
    );
    await _pumpRequests(tester);
    expect(readerCalls, 1);

    // Scheduled polling bypasses _refreshAndSync, so this verifies the
    // explicit v2 reader is refreshed by the timer path itself.
    await tester.pump(const Duration(seconds: 16));
    await _pumpRequests(tester);

    expect(readerCalls, greaterThanOrEqualTo(2));
  });

  testWidgets('scheduled change sync refreshes the selected v1 inventory', (
    tester,
  ) async {
    var readerCalls = 0;
    final client = MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations') {
        return _json(_owned());
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations/conversation-1/prompts') {
        return _json({
          'conversation_id': 'conversation-1',
          'prompts': <Object>[],
          'has_more': false,
        });
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations/conversation-1/runs') {
        return _json(_emptyRuns(request));
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversation-changes') {
        final after = int.parse(
          request.url.queryParameters['after_cursor'] ?? '0',
        );
        return _json({
          'after_cursor': after,
          'scanned_through_cursor': after,
          'has_more': false,
          'changes': <Object>[],
        });
      }
      throw StateError(
        'Unexpected Forge request: ${request.method} ${request.url}',
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: 'forge-token',
          apiOrigin: 'https://forge.example',
          httpClient: client,
          deviceInventoryOwner: _owner,
          deviceInventoryReader: (owner) async {
            readerCalls++;
            return ForgeDeviceInventoryPage.fromJson(_inventory(owner));
          },
        ),
      ),
    );
    await _pumpRequests(tester);
    expect(readerCalls, 1);

    // Scheduled polling bypasses _refreshAndSync, so this verifies the
    // explicit v1 reader is refreshed by the timer path itself.
    await tester.pump(const Duration(seconds: 16));
    await _pumpRequests(tester);

    expect(readerCalls, greaterThanOrEqualTo(2));
  });

  testWidgets('retains the v2 snapshot during a transient refresh failure', (
    tester,
  ) async {
    var readerCalls = 0;
    final refresh = Completer<ForgeDeviceInventoryPageV2>();
    final client = MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations') {
        return _json(_owned());
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations/conversation-1/prompts') {
        return _json({
          'conversation_id': 'conversation-1',
          'prompts': <Object>[],
          'has_more': false,
        });
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations/conversation-1/runs') {
        return _json(_emptyRuns(request));
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversation-changes') {
        return _json({
          'after_cursor': 0,
          'scanned_through_cursor': 0,
          'has_more': false,
          'changes': <Object>[],
        });
      }
      throw StateError(
        'Unexpected Forge request: ${request.method} ${request.url}',
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: 'forge-token',
          apiOrigin: 'https://forge.example',
          httpClient: client,
          deviceInventoryOwner: _owner,
          deviceInventoryV2Reader: (owner) {
            readerCalls++;
            if (readerCalls == 1) {
              return Future<ForgeDeviceInventoryPageV2>.value(
                ForgeDeviceInventoryPageV2.fromJson(_inventoryV2(owner)),
              );
            }
            return refresh.future;
          },
        ),
      ),
    );
    await _pumpRequests(tester);
    expect(readerCalls, 1);

    await tester.tap(find.byIcon(Icons.refresh).last);
    for (var count = 0; count < 12 && readerCalls < 2; count++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    expect(readerCalls, 2);
    expect(
      find.byKey(const ValueKey('forge-authenticated-device-inventory-v2')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('forge-device-inventory-v2-stale')),
      findsOneWidget,
    );

    refresh.completeError(
      const ForgeConversationsApiException(
        statusCode: 503,
        code: 'service_unavailable',
        message: 'v2 inventory unavailable',
      ),
    );
    await _pumpRequests(tester);
    expect(
      find.byKey(const ValueKey('forge-authenticated-device-inventory-v2')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('forge-device-inventory-v2-stale')),
      findsOneWidget,
    );
    expect(find.text('v2 inventory unavailable'), findsOneWidget);
  });

  testWidgets('clears v2 inventory and sessions after a candidate 401', (
    tester,
  ) async {
    final client = MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations') {
        return _json(_owned());
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations/conversation-1/prompts') {
        return _json({
          'conversation_id': 'conversation-1',
          'prompts': <Object>[],
          'has_more': false,
        });
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations/conversation-1/runs') {
        return _json(_emptyRuns(request));
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversation-changes') {
        return _json({
          'after_cursor': 0,
          'scanned_through_cursor': 0,
          'has_more': false,
          'changes': <Object>[],
        });
      }
      throw StateError(
        'Unexpected Forge request: ${request.method} ${request.url}',
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: 'forge-token',
          apiOrigin: 'https://forge.example',
          httpClient: client,
          deviceInventoryOwner: _owner,
          deviceInventoryV2Reader: (_) async =>
              Future<ForgeDeviceInventoryPageV2>.error(
                const ForgeConversationsApiException(
                  statusCode: 401,
                  code: 'invalid_token',
                  message: 'invalid token',
                ),
              ),
        ),
      ),
    );
    await _pumpRequests(tester);

    expect(
      find.byKey(const ValueKey('forge-authenticated-device-inventory-v2')),
      findsNothing,
    );
    expect(find.text('No Forge conversations yet.'), findsOneWidget);
  });

  testWidgets('leaves the v2 reader unset by default', (tester) async {
    final client = MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations') {
        return _json(_owned());
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations/conversation-1/prompts') {
        return _json({
          'conversation_id': 'conversation-1',
          'prompts': <Object>[],
          'has_more': false,
        });
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations/conversation-1/runs') {
        return _json(_emptyRuns(request));
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversation-changes') {
        return _json({
          'after_cursor': 0,
          'scanned_through_cursor': 0,
          'has_more': false,
          'changes': <Object>[],
        });
      }
      throw StateError(
        'Unexpected Forge request: ${request.method} ${request.url}',
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: 'forge-token',
          apiOrigin: 'https://forge.example',
          httpClient: client,
          deviceInventoryOwner: _owner,
        ),
      ),
    );
    await _pumpRequests(tester);

    expect(
      find.byKey(const ValueKey('forge-authenticated-device-inventory-v2')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey('forge-device-inventory-v2-panel')),
      findsNothing,
    );
  });

  testWidgets('imports a bounded v2 inventory file locally', (tester) async {
    var unexpectedDeviceRequests = 0;
    final client = MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations') {
        return _json(_owned());
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations/conversation-1/prompts') {
        return _json({
          'conversation_id': 'conversation-1',
          'prompts': <Object>[],
          'has_more': false,
        });
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations/conversation-1/runs') {
        return _json(_emptyRuns(request));
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversation-changes') {
        return _json({
          'after_cursor': 0,
          'scanned_through_cursor': 0,
          'has_more': false,
          'changes': <Object>[],
        });
      }
      if (request.url.path == '/api/v1/devices' ||
          request.url.path == '/api/v1/devices/observations/v2') {
        unexpectedDeviceRequests++;
      }
      throw StateError(
        'Unexpected Forge request: ${request.method} ${request.url}',
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: 'forge-token',
          apiOrigin: 'https://forge.example',
          httpClient: client,
          deviceInventoryV2FileReader: () async =>
              jsonEncode(_inventoryV2(_owner)),
        ),
      ),
    );
    await _pumpRequests(tester);

    expect(
      find.byKey(const ValueKey('forge-device-inventory-v2-import-card')),
      findsOneWidget,
    );
    await tester.tap(
      find.byKey(const ValueKey('forge-import-device-inventory-v2')),
    );
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('forge-device-inventory-v2-panel')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('forge-inventory-v2-device-v2-runner-v2')),
      findsOneWidget,
    );
    expect(unexpectedDeviceRequests, 0);
  });

  testWidgets('rejects an injected inventory owner mismatch', (tester) async {
    final foreign = const ForgeDeviceOwner(
      issuer: 'https://id.example',
      subject: 'foreign-user',
      tenantID: 'tenant-1',
    );
    final client = MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations') {
        return _json(_owned());
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations/conversation-1/prompts') {
        return _json({
          'conversation_id': 'conversation-1',
          'prompts': <Object>[],
          'has_more': false,
        });
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations/conversation-1/runs') {
        return _json(_emptyRuns(request));
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversation-changes') {
        return _json({
          'after_cursor': 0,
          'scanned_through_cursor': 0,
          'has_more': false,
          'changes': <Object>[],
        });
      }
      throw StateError(
        'Unexpected Forge request: ${request.method} ${request.url}',
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: 'forge-token',
          apiOrigin: 'https://forge.example',
          httpClient: client,
          deviceInventoryOwner: _owner,
          deviceInventoryReader: (_) async =>
              ForgeDeviceInventoryPage.fromJson(_inventory(foreign)),
        ),
      ),
    );
    await _pumpRequests(tester);

    expect(
      find.byKey(const ValueKey('forge-authenticated-device-inventory')),
      findsNothing,
    );
    expect(find.text('Forge returned an invalid response.'), findsOneWidget);
  });

  testWidgets('clears inventory and sessions after a candidate 401', (
    tester,
  ) async {
    final client = MockClient((request) async {
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations') {
        return _json(_owned());
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations/conversation-1/prompts') {
        return _json({
          'conversation_id': 'conversation-1',
          'prompts': <Object>[],
          'has_more': false,
        });
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversations/conversation-1/runs') {
        return _json(_emptyRuns(request));
      }
      if (request.method == 'GET' &&
          request.url.path == '/api/v1/conversation-changes') {
        return _json({
          'after_cursor': 0,
          'scanned_through_cursor': 0,
          'has_more': false,
          'changes': <Object>[],
        });
      }
      throw StateError(
        'Unexpected Forge request: ${request.method} ${request.url}',
      );
    });

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: 'forge-token',
          apiOrigin: 'https://forge.example',
          httpClient: client,
          deviceInventoryOwner: _owner,
          deviceInventoryReader: (_) async =>
              Future<ForgeDeviceInventoryPage>.error(
                ForgeConversationsApiException(
                  statusCode: 401,
                  code: 'invalid_token',
                  message: 'invalid token',
                ),
              ),
        ),
      ),
    );
    await _pumpRequests(tester);

    expect(
      find.byKey(const ValueKey('forge-authenticated-device-inventory')),
      findsNothing,
    );
    expect(find.text('No Forge conversations yet.'), findsOneWidget);
  });
}
