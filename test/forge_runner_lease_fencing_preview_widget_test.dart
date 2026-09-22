import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/screens/forge/forge_sessions_screen.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  final fixturePath = Platform.environment['FORGE_LEASE_FENCING_FIXTURE'];

  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });
  setUp(BrowserNavigation.resetForTest);
  tearDown(BrowserNavigation.resetForTest);

  testWidgets(
    'imports a file-backed Runner lease fixture into a read-only client card',
    (tester) async {
      final path = fixturePath;
      if (path == null || path.isEmpty) return;
      final source = File(path).readAsStringSync();
      final client = MockClient((request) async {
        expect(request.method, 'GET');
        expect(request.url.path, '/api/v1/conversations');
        return http.Response(
          '{"conversations":[],"has_more":false}',
          200,
          headers: const {'content-type': 'application/json'},
        );
      });
      addTearDown(client.close);

      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsScreen(
            accessToken: 'fixture-access',
            apiOrigin: 'https://forge.example',
            httpClient: client,
            runnerLeaseFencingFileReader: () async => source,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('forge-runner-lease-fencing-import-card')),
        findsOneWidget,
      );
      await tester.tap(
        find.byKey(const ValueKey('forge-import-runner-lease-fencing')),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('forge-runner-lease-fencing-preview-card')),
        findsOneWidget,
      );
      expect(find.text('offline'), findsWidgets);
      expect(find.text('active_at_issue'), findsOneWidget);
      expect(find.text('fencing-token'), findsNothing);
      expect(
        find.text(
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        ),
        findsNothing,
      );
      expect(find.text('false'), findsWidgets);
    },
  );
}
