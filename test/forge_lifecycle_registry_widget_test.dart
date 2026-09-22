import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/forge_device_enrollment_heartbeat_lifecycle_registry.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/screens/forge/forge_lifecycle_registry_panel.dart';
import 'package:sso_admin/screens/forge/forge_sessions_screen.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/session.dart';

import 'support/forge_lifecycle_registry_fixture.dart';

void main() {
  setUp(BrowserNavigation.resetForTest);
  tearDown(() {
    BrowserNavigation.resetForTest();
    Session.clear();
  });

  testWidgets('renders lifecycle rows as display-only metadata', (
    tester,
  ) async {
    final registry = ForgeDeviceEnrollmentHeartbeatLifecycleRegistry.fromJson(
      forgeLifecycleRegistryTestEnvelope(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ForgeLifecycleRegistryPanel(registry: registry),
          ),
        ),
      ),
    );

    expect(
      find.byKey(const ValueKey('forge-lifecycle-registry-panel')),
      findsOneWidget,
    );
    expect(find.text('Lifecycle registry candidate'), findsOneWidget);
    expect(
      find.text(
        'Read-only authenticated restart snapshot; no enrollment or execution authority.',
      ),
      findsOneWidget,
    );
    expect(find.text('device-a'), findsOneWidget);
    expect(find.text('device-b'), findsOneWidget);
    expect(find.textContaining('Runner runner-a'), findsOneWidget);
    expect(find.textContaining('liveness=online'), findsNWidgets(2));
    expect(find.byType(ButtonStyleButton), findsNothing);
    expect(find.byType(IconButton), findsNothing);
  });

  testWidgets(
    'loads one explicit owner-bound registry reader into the screen',
    (tester) async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        expect(request.method, 'GET');
        if (request.url.path == '/api/v1/conversations') {
          return _json({'conversations': <Object>[], 'has_more': false});
        }
        throw StateError('Unexpected request: ${request.url}');
      });
      addTearDown(client.close);

      var readerCalls = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsScreen(
            accessToken: 'lifecycle-screen-token',
            apiOrigin: 'https://forge.example',
            httpClient: client,
            lifecycleRegistryOwner: forgeLifecycleRegistryTestOwner,
            lifecycleRegistryReader: (owner) async {
              readerCalls++;
              expect(owner, forgeLifecycleRegistryTestOwner);
              return ForgeDeviceEnrollmentHeartbeatLifecycleRegistry.fromJson(
                forgeLifecycleRegistryTestEnvelope(),
              );
            },
          ),
        ),
      );
      await _pump(tester);

      expect(readerCalls, 1);
      expect(
        find.byKey(const ValueKey('forge-lifecycle-registry-panel')),
        findsOneWidget,
      );
      expect(
        requests.where(
          (request) => request.url.path.contains('lifecycle-registry'),
        ),
        isEmpty,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );

  testWidgets('hides a reader result whose owner binding changes', (
    tester,
  ) async {
    final client = MockClient((request) async {
      if (request.url.path == '/api/v1/conversations') {
        return _json({'conversations': <Object>[], 'has_more': false});
      }
      throw StateError('Unexpected request: ${request.url}');
    });
    addTearDown(client.close);

    final foreignOwner = const ForgeDeviceOwner(
      issuer: 'https://id.example',
      subject: 'foreign-user',
      tenantID: 'tenant-1',
    );
    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsScreen(
          accessToken: 'lifecycle-screen-token',
          apiOrigin: 'https://forge.example',
          httpClient: client,
          lifecycleRegistryOwner: forgeLifecycleRegistryTestOwner,
          lifecycleRegistryReader: (_) async =>
              ForgeDeviceEnrollmentHeartbeatLifecycleRegistry.fromJson(
                forgeLifecycleRegistryTestEnvelope(owner: foreignOwner),
              ),
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
