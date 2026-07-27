import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
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
}
