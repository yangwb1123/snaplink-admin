import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/screens/developer/developer_api.dart';
import 'package:sso_admin/screens/developer/developer_screen.dart';
import 'package:sso_admin/screens/device/device_verify_api.dart';
import 'package:sso_admin/screens/device/device_verify_screen.dart';
import 'package:sso_admin/screens/setup/setup_validation.dart';
import 'package:sso_admin/screens/setup/setup_widgets.dart';
import 'package:sso_admin/widgets/responsive_entry_card.dart';

void main() {
  test('setup redirect URIs reject fragments and embedded user info', () {
    expect(
      () => parseSetupRedirectUris('https://app.example/callback#token'),
      throwsFormatException,
    );
    expect(
      () => parseSetupRedirectUris(
        'https://operator:secret@app.example/callback',
      ),
      throwsFormatException,
    );
    expect(
      parseSetupRedirectUris(
        'https://app.example/callback\nhttp://localhost:8080/callback',
      ),
      ['https://app.example/callback', 'http://localhost:8080/callback'],
    );
  });

  testWidgets('setup protects and labels a one-time client secret', (
    tester,
  ) async {
    var continued = false;
    await _useNarrowViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResponsiveEntryCard(
            child: SetupDonePanel(
              adminUsername: 'root',
              clientId: 'client-1',
              clientSecret: 'secret-1',
              onDone: () => continued = true,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Client ID'), findsOneWidget);
    expect(find.text('Client secret · shown once'), findsOneWidget);
    expect(find.byTooltip('Copy Client secret'), findsOneWidget);
    expect(_filledButton(tester, 'Go to admin console').onPressed, isNull);
    expect(tester.takeException(), isNull);

    await tester.ensureVisible(
      find.text('I have securely saved the client secret.'),
    );
    await tester.tap(find.text('I have securely saved the client secret.'));
    await tester.pump();
    expect(_filledButton(tester, 'Go to admin console').onPressed, isNotNull);
    await tester.tap(find.text('Go to admin console'));
    expect(continued, isTrue);
  });

  testWidgets('editing a checked device code invalidates its old preview', (
    tester,
  ) async {
    final api = DeviceVerifyApi(
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'status': 'pending',
            'client_name': 'Accounting terminal',
            'scopes': ['openid', 'payments:write'],
          }),
          200,
        ),
      ),
    );
    await _useNarrowViewport(tester);
    await tester.pumpWidget(
      MaterialApp(
        home: DeviceVerifyScreen(
          api: api,
          accessTokenProvider: () => 'user-token',
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'ABCD-1234');
    await tester.tap(find.text('Check code'));
    await tester.pumpAndSettle();
    expect(find.text('Accounting terminal'), findsOneWidget);
    expect(_filledButton(tester, 'Approve').onPressed, isNotNull);

    await tester.enterText(find.byType(TextField), 'WXYZ-5678');
    await tester.pump();
    expect(find.text('Accounting terminal'), findsNothing);
    expect(_filledButton(tester, 'Approve').onPressed, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('developer discovery failure offers an in-place retry', (
    tester,
  ) async {
    var calls = 0;
    final api = DeveloperApi(
      httpClient: MockClient((_) async {
        calls++;
        if (calls == 1) return http.Response('{}', 503);
        return http.Response(
          jsonEncode({
            'registration_endpoint': 'https://sso.example/register',
            'grant_types_supported': ['authorization_code'],
            'response_types_supported': ['code'],
            'token_endpoint_auth_methods_supported': ['none'],
            'code_challenge_methods_supported': ['S256'],
            'scopes_supported': ['openid'],
          }),
          200,
        );
      }),
      baseUri: Uri.parse('https://sso.example'),
    );
    await tester.pumpWidget(MaterialApp(home: DeveloperScreen(api: api)));
    await tester.pumpAndSettle();

    expect(find.text('Retry discovery'), findsOneWidget);
    await tester.tap(find.text('Retry discovery'));
    await tester.pumpAndSettle();

    expect(calls, 2);
    expect(find.text('Retry discovery'), findsNothing);
  });
}

Future<void> _useNarrowViewport(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 480);
  addTearDown(tester.view.reset);
}

FilledButton _filledButton(WidgetTester tester, String label) {
  return tester.widget<FilledButton>(find.widgetWithText(FilledButton, label));
}
