import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/forge_device_inventory_placement_evaluation_v2.dart';
import 'package:sso_admin/screens/forge/forge_device_inventory_placement_evaluation_v2_panel.dart';
import 'package:sso_admin/screens/forge/forge_sessions_screen.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

http.Response _json(Object value, {int status = 200}) => http.Response(
  jsonEncode(value),
  status,
  headers: const {'content-type': 'application/json'},
);

Map<String, dynamic> _owned() => {
  'conversations': [
    {
      'conversation': {
        'id': 'conversation-1',
        'scope': {'kind': 'global'},
        'title': 'Placement preview session',
        'created_at_ms': 10,
        'updated_at_ms': 20,
      },
      'aggregate_version': 1,
    },
  ],
  'has_more': false,
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
  final fixturePath =
      Platform.environment['FORGE_INVENTORY_PLACEMENT_V2_FIXTURE'];

  setUp(() => BrowserNavigation.resetForTest());
  tearDown(() => BrowserNavigation.resetForTest());

  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets('renders v2 placement metadata without controls', (tester) async {
    final path = fixturePath;
    if (path == null) return;
    final evaluation = ForgeDeviceInventoryPlacementEvaluationV2.fromJson(
      jsonDecode(File(path).readAsStringSync()),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ForgeDeviceInventoryPlacementEvaluationV2Panel(
              evaluation: evaluation,
            ),
          ),
        ),
      ),
    );

    expect(
      find.byKey(
        const ValueKey('forge-device-inventory-placement-evaluation-v2-panel'),
      ),
      findsOneWidget,
    );
    expect(find.text('Forge device placement evaluation v2'), findsOneWidget);
    expect(find.textContaining('device-a'), findsOneWidget);
    expect(find.textContaining('runner-a'), findsOneWidget);
    expect(
      find.textContaining('revision 1 · generation 1 · heartbeat 1'),
      findsOneWidget,
    );
    expect(
      find.textContaining('2 GPUs · 17179869184 B available memory'),
      findsOneWidget,
    );
    expect(find.textContaining('device_reserved'), findsOneWidget);
    expect(find.text('Selected device'), findsOneWidget);
    expect(find.text('Selected instance'), findsOneWidget);
    expect(find.byType(TextButton), findsNothing);
    expect(find.byType(ElevatedButton), findsNothing);
    expect(find.byType(IconButton), findsNothing);
  }, skip: fixturePath == null);

  testWidgets(
    'Sessions renders an injected v2 placement preview without a device request',
    (tester) async {
      final path = fixturePath;
      if (path == null) return;
      final evaluation = ForgeDeviceInventoryPlacementEvaluationV2.fromJson(
        jsonDecode(File(path).readAsStringSync()),
      );
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
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
            deviceInventoryPlacementEvaluationV2Preview: evaluation,
          ),
        ),
      );
      await _pumpRequests(tester);

      final panel = find.byKey(
        const ValueKey('forge-device-inventory-placement-evaluation-v2-panel'),
      );
      expect(panel, findsOneWidget);
      expect(
        find.descendant(
          of: panel,
          matching: find.byKey(
            const ValueKey('forge-placement-evaluation-v2-device-a-runner-a'),
          ),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: panel, matching: find.byType(IconButton)),
        findsNothing,
      );
      expect(
        requests.where((request) => request.url.path.contains('/devices')),
        isEmpty,
      );
    },
    skip: fixturePath == null,
  );

  testWidgets(
    'Sessions imports a bounded v2 placement preview without a device request',
    (tester) async {
      final path = fixturePath;
      if (path == null) return;
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
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
            deviceInventoryPlacementEvaluationV2FileReader: () async =>
                File(path).readAsStringSync(),
          ),
        ),
      );
      await _pumpRequests(tester);

      expect(
        find.byKey(
          const ValueKey('forge-device-placement-evaluation-v2-import-card'),
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(
          const ValueKey('forge-import-device-placement-evaluation-v2'),
        ),
      );
      await tester.pumpAndSettle();

      final panel = find.byKey(
        const ValueKey('forge-device-inventory-placement-evaluation-v2-panel'),
      );
      expect(panel, findsOneWidget);
      expect(
        find.descendant(
          of: panel,
          matching: find.byKey(
            const ValueKey('forge-placement-evaluation-v2-device-a-runner-a'),
          ),
        ),
        findsOneWidget,
      );
      expect(
        requests.where((request) => request.url.path.contains('/devices')),
        isEmpty,
      );
    },
    skip: fixturePath == null,
  );
}
