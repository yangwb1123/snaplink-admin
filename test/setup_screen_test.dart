import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/setup_api.dart';
import 'package:sso_admin/screens/setup/setup_screen.dart';
import 'package:sso_admin/services/browser_navigation.dart';

void main() {
  setUp(() {
    BrowserNavigation.resetForTest();
  });

  group('SetupScreen', () {
    testWidgets('walks through admin creation and finish', (tester) async {
      var posted = <String>[];
      final api = _setupApi((request) async {
        if (request.url.path == '/api/v1/setup/status') {
          return http.Response('{"setup_required":true}', 200);
        }
        if (request.url.path == '/api/v1/setup') {
          posted.add(request.body);
          return http.Response(
            jsonEncode({
              'ok': true,
              'created': {
                'admin': 'root',
                'application': {
                  'client_id': 'first-app',
                  'client_secret': 'ONE-TIME-SECRET',
                },
              },
            }),
            200,
          );
        }
        return http.Response('{}', 404);
      });

      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: SetupScreen(api: api)));
      await tester.pumpAndSettle();

      // Step 1: admin form with validation.
      await tester.enterText(
        find.widgetWithText(TextField, 'Admin username'),
        'root',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Password'),
        'short',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Confirm password'),
        'short',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(
        find.text('Password must be at least 8 characters.'),
        findsOneWidget,
      );

      await tester.enterText(
        find.widgetWithText(TextField, 'Password'),
        'long-enough-password',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Confirm password'),
        'long-enough-password',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      // Step 2: optional application.
      await tester.enterText(
        find.widgetWithText(TextField, 'Application name'),
        'First App',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Redirect URIs'),
        'https://app.example/callback',
      );
      await tester.tap(find.text('Create and finish'));
      await tester.pumpAndSettle();

      expect(posted.single, contains('"admin"'));
      expect(posted.single, contains('"username":"root"'));
      expect(posted.single, contains('"application"'));
      expect(posted.single, contains('"redirect_uris"'));
      // The one-time secret is displayed on the done screen.
      expect(find.text('ONE-TIME-SECRET'), findsOneWidget);
    });

    testWidgets('skips the application step', (tester) async {
      var posted = <String>[];
      final api = _setupApi((request) async {
        if (request.url.path == '/api/v1/setup/status') {
          return http.Response('{"setup_required":true}', 200);
        }
        if (request.url.path == '/api/v1/setup') {
          posted.add(request.body);
          return http.Response(
            jsonEncode({
              'ok': true,
              'created': {'admin': 'root'},
            }),
            200,
          );
        }
        return http.Response('{}', 404);
      });

      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: SetupScreen(api: api)));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Admin username'),
        'root',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Password'),
        'long-enough-password',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Confirm password'),
        'long-enough-password',
      );
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Skip and finish'));
      await tester.pumpAndSettle();

      expect(posted.single, contains('"admin"'));
      expect(posted.single, isNot(contains('"application"')));
    });

    testWidgets('shows already-initialized state', (tester) async {
      final api = _setupApi((request) async {
        if (request.url.path == '/api/v1/setup/status') {
          return http.Response('{"setup_required":false}', 200);
        }
        return http.Response('{}', 404);
      });
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: SetupScreen(api: api)));
      await tester.pumpAndSettle();

      expect(find.textContaining('already'), findsWidgets);
    });

    testWidgets('fails closed when the setup route is not mounted', (
      tester,
    ) async {
      final api = _setupApi((request) async => http.Response('{}', 404));
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(home: SetupScreen(api: api)));
      await tester.pumpAndSettle();

      expect(find.text('Retry'), findsOneWidget);
    });
  });
}

SetupApi _setupApi(Future<http.Response> Function(http.Request) handler) =>
    SetupApi(client: MockClient(handler));
