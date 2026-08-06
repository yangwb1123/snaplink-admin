import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/sso_client.dart';
import 'package:sso_admin/screens/admin/client_form_dialog.dart';

void main() {
  testWidgets('rejects unsafe redirect URI before sending a request', (
    tester,
  ) async {
    var requestSent = false;
    final client = SSOAdminClient(
      'https://sso.example.test',
      httpClient: MockClient((_) async {
        requestSent = true;
        throw StateError('validation should prevent the request');
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ClientFormDialog(client: client)),
      ),
    );

    await tester.enterText(
      find.widgetWithText(TextFormField, 'ID'),
      'portal-client',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Portal client',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Redirect URIs'),
      'https://user:password@app.example.test/callback',
    );
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(
      find.text(
        'Invalid redirect URI: '
        'https://user:password@app.example.test/callback',
      ),
      findsOneWidget,
    );
    expect(requestSent, isFalse);
  });

  testWidgets('rejects a public HTTP login page before sending a request', (
    tester,
  ) async {
    var requestSent = false;
    final client = SSOAdminClient(
      'https://sso.example.test',
      httpClient: MockClient((_) async {
        requestSent = true;
        throw StateError('validation should prevent the request');
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ClientFormDialog(client: client)),
      ),
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'ID'), 'portal');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Portal',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Login page URI (optional)'),
      'http://login.example.test/',
    );
    await tester.tap(find.text('Save'));
    await tester.pump();

    expect(
      find.text('Use an HTTPS login page URI (or localhost HTTP).'),
      findsOneWidget,
    );
    expect(requestSent, isFalse);
  });

  testWidgets('submits a secure federated login page URI', (tester) async {
    Map<String, dynamic>? sentBody;
    final client = SSOAdminClient(
      'https://sso.example.test',
      httpClient: MockClient((request) async {
        expect(request.method, 'POST');
        expect(request.url.path, '/api/v1/admin/clients');
        sentBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode({'client': sentBody}), 200);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ClientFormDialog(client: client)),
      ),
    );
    await tester.enterText(find.widgetWithText(TextFormField, 'ID'), 'portal');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Name'),
      'Portal',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Login page URI (optional)'),
      'https://login.example.test/login/',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(sentBody?['login_page_uri'], 'https://login.example.test/login/');
  });

  testWidgets('edit can clear a federated login page URI', (tester) async {
    Map<String, dynamic>? sentBody;
    final client = SSOAdminClient(
      'https://sso.example.test',
      httpClient: MockClient((request) async {
        expect(request.method, 'PUT');
        expect(request.url.path, '/api/v1/admin/clients/portal');
        sentBody = jsonDecode(request.body) as Map<String, dynamic>;
        return http.Response(jsonEncode({'client': sentBody}), 200);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ClientFormDialog(
            client: client,
            existing: const {
              'id': 'portal',
              'name': 'Portal',
              'active': true,
              'login_page_uri': 'https://login.example.test/login/',
            },
          ),
        ),
      ),
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Login page URI (optional)'),
      '',
    );
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    expect(sentBody?['login_page_uri'], '');
  });
}
