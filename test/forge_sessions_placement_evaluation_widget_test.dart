import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/forge_device_inventory_placement_evaluation.dart';
import 'package:sso_admin/screens/forge/forge_device_inventory_placement_evaluation_panel.dart';
import 'package:sso_admin/screens/forge/forge_sessions_screen.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

Map<String, dynamic> _owned() => {
  'conversations': [
    {
      'conversation': {
        'id': 'conversation-1',
        'scope': {'kind': 'global'},
        'title': 'Placement evaluation preview session',
        'created_at_ms': 10,
        'updated_at_ms': 20,
      },
      'aggregate_version': 1,
    },
  ],
  'has_more': false,
};

http.Response _json(Object value) => http.Response(
  jsonEncode(value),
  200,
  headers: const {'content-type': 'application/json'},
);

MockClient _client(List<http.Request> requests) => MockClient((request) async {
  requests.add(request);
  if (request.method == 'GET' && request.url.path == '/api/v1/conversations') {
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
    return _json({
      'conversation_id': 'conversation-1',
      'runs': <Object>[],
      'has_more': false,
    });
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
      Platform.environment['FORGE_INVENTORY_PLACEMENT_EVALUATION_FIXTURE'];

  setUp(() => BrowserNavigation.resetForTest());
  tearDown(() => BrowserNavigation.resetForTest());

  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  testWidgets(
    'renders the placement evaluation value without controls',
    (tester) async {
      final path = fixturePath;
      if (path == null) return;
      final evaluation =
          ForgeDeviceInventoryPlacementEvaluationFixture.fromJsonText(
            File(path).readAsStringSync(),
          );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: ForgeDeviceInventoryPlacementEvaluationPanel(
                evaluation: evaluation,
              ),
            ),
          ),
        ),
      );

      expect(
        find.byKey(
          const ValueKey('forge-device-inventory-placement-evaluation-panel'),
        ),
        findsOneWidget,
      );
      expect(find.text('Forge device placement evaluation'), findsOneWidget);
      expect(find.textContaining('device-a'), findsOneWidget);
      expect(find.textContaining('runner-a'), findsOneWidget);
      expect(
        find.textContaining('concurrency_capacity_insufficient'),
        findsWidgets,
      );
      expect(find.byType(TextButton), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
      expect(find.byType(IconButton), findsNothing);
    },
    skip: fixturePath == null,
  );

  testWidgets(
    'Sessions renders an injected placement evaluation without a device request',
    (tester) async {
      final path = fixturePath;
      if (path == null) return;
      final evaluation =
          ForgeDeviceInventoryPlacementEvaluationFixture.fromJsonText(
            File(path).readAsStringSync(),
          );
      final requests = <http.Request>[];
      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsScreen(
            accessToken: 'forge-token',
            apiOrigin: 'https://forge.example',
            httpClient: _client(requests),
            deviceInventoryPlacementEvaluationPreview: evaluation,
          ),
        ),
      );
      await _pumpRequests(tester);

      expect(
        find.byKey(
          const ValueKey('forge-device-inventory-placement-evaluation-panel'),
        ),
        findsOneWidget,
      );
      expect(
        requests.where((request) => request.url.path.contains('/devices')),
        isEmpty,
      );
      expect(
        requests.where((request) => request.url.path.contains('placement')),
        isEmpty,
      );
    },
    skip: fixturePath == null,
  );

  testWidgets(
    'Sessions imports a bounded placement evaluation without a device request',
    (tester) async {
      final path = fixturePath;
      if (path == null) return;
      final requests = <http.Request>[];
      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsScreen(
            accessToken: 'forge-token',
            apiOrigin: 'https://forge.example',
            httpClient: _client(requests),
            deviceInventoryPlacementEvaluationFileReader: () async =>
                File(path).readAsStringSync(),
          ),
        ),
      );
      await _pumpRequests(tester);

      expect(
        find.byKey(
          const ValueKey('forge-device-placement-evaluation-import-card'),
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('forge-import-device-placement-evaluation')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(
          const ValueKey('forge-device-inventory-placement-evaluation-panel'),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('trust_zone_unconfirmed'), findsWidgets);
      expect(
        requests.where((request) => request.url.path.contains('/devices')),
        isEmpty,
      );
    },
    skip: fixturePath == null,
  );
}
