import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sso_admin/screens/forge/forge_sessions_screen.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/session.dart';

void main() {
  final fixturePath =
      Platform.environment['FORGE_CLIENT_INSTANCE_RESOURCE_VIEW_FIXTURE'];

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
    'imports a client-instance resource view locally without device requests',
    (tester) async {
      final path = fixturePath;
      if (path == null || path.isEmpty) return;
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.method == 'GET' &&
            request.url.path == '/api/v1/conversations') {
          return http.Response(
            '{"conversations":[],"has_more":false}',
            200,
            headers: const {'content-type': 'application/json'},
          );
        }
        if (request.method == 'GET' &&
            request.url.path == '/api/v1/conversation-changes') {
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
            clientInstanceResourceViewFileReader: () async =>
                File(path).readAsStringSync(),
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
        find.byKey(
          const ValueKey('forge-client-instance-resource-view-import-card'),
        ),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(
          const ValueKey('forge-import-client-instance-resource-view'),
        ),
      );
      await tester.pump();
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
      expect(find.text('device-a'), findsOneWidget);
      expect(find.text('client-cli-001'), findsOneWidget);
      expect(
        requests.where((request) => request.url.path.contains('/devices')),
        isEmpty,
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
    },
    skip: fixturePath == null || fixturePath.isEmpty,
  );
}
