import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/sso_client.dart';
import 'package:sso_admin/app_settings.dart';
import 'package:sso_admin/screens/admin/dashboard_screen.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/services/shortcut_platform.dart' as shortcut_platform;
import 'package:sso_admin/session.dart';

/// Scratch verification of dashboard Ctrl+1-9 wiring. NOT part of suite.
void main() {
  setUp(() {
    Session.clear();
    BrowserNavigation.resetForTest();
    shortcut_platform.resetForTest();
    AppSettings.instance.adminNavMode = AdminNavMode.professional;
  });

  testWidgets('Ctrl+1-9 navigates within the current group without error', (
    tester,
  ) async {
    final client = SSOAdminClient(
      'https://sso.example.test',
      httpClient: MockClient((request) async {
        if (request.url.path == '/api/v1/admin/endpoints') {
          return http.Response(
            jsonEncode({
              'endpoints': [
                {
                  'method': 'GET',
                  'path': '/api/v1/admin/clients',
                  'feature': 'core',
                },
              ],
            }),
            200,
          );
        }
        if (request.url.path == '/api/v1/admin/commerce/plans') {
          return http.Response('{}', 404);
        }
        if (request.url.path == '/api/v1/admin/clients') {
          return http.Response(
            jsonEncode({'clients': <Object>[], 'total_size': 0}),
            200,
          );
        }
        return http.Response('{"error":"not found"}', 404);
      }),
    );
    tester.view.physicalSize = const Size(1280, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(home: DashboardScreen(client: client)));
    await tester.pumpAndSettle();

    // Ctrl+1: single visible module → no crash, still on clients.
    shortcut_platform.testEmitKey('1', true);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Clients'), findsWidgets);

    // Ctrl+9 beyond range → silent no-op.
    shortcut_platform.testEmitKey('9', true);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.pumpWidget(const SizedBox());
  });
}
