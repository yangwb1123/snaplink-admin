import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/screens/developer/dcr_credentials.dart';
import 'package:sso_admin/screens/developer/dcr_delete_dialog.dart';
import 'package:sso_admin/screens/developer/dcr_form_controller.dart';
import 'package:sso_admin/screens/developer/dcr_metadata_form.dart';
import 'package:sso_admin/screens/developer/developer_api.dart';
import 'package:sso_admin/screens/developer/manage_panel.dart';

void main() {
  testWidgets('one-time credentials require confirmation before erase', (
    tester,
  ) async {
    var managed = false;
    var wiped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: OneTimeRegistrationCredentials(
              result: const {
                'client_id': 'client-1',
                'client_secret': 'secret-1',
                'registration_access_token': 'rat-1',
                'registration_client_uri':
                    'https://sso.example/register/client-1',
              },
              onManage: () => managed = true,
              onWipe: () => wiped = true,
            ),
          ),
        ),
      ),
    );

    expect(find.byTooltip('Copy Client ID'), findsOneWidget);
    expect(find.byTooltip('Copy Client Secret'), findsOneWidget);
    expect(find.byTooltip('Copy Registration Access Token'), findsOneWidget);
    expect(_button(tester, 'Done and Erase').onPressed, isNull);
    expect(_filledButton(tester, 'Manage App').onPressed, isNull);

    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();

    expect(_button(tester, 'Done and Erase').onPressed, isNotNull);
    await tester.ensureVisible(find.text('Manage App'));
    await tester.tap(find.text('Manage App'));
    expect(managed, isTrue);
    expect(wiped, isFalse);
  });

  testWidgets('rotated RAT cannot be dismissed before save confirmation', (
    tester,
  ) async {
    var confirmed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () => showDialog<void>(
                context: context,
                barrierDismissible: false,
                builder: (_) => RotatedRegistrationTokenDialog(
                  token: 'new-rat',
                  onConfirmed: () => confirmed = true,
                ),
              ),
              child: const Text('Rotate'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Rotate'));
    await tester.pumpAndSettle();
    expect(
      find.text(
        'The previous registration access token is already invalid. Save this replacement before closing the dialog.',
      ),
      findsOneWidget,
    );
    expect(
      _filledButton(tester, 'Continue and Erase Display').onPressed,
      isNull,
    );

    await tester.tap(find.text('I have securely saved the new token.'));
    await tester.pump();
    await tester.tap(find.text('Continue and Erase Display'));
    await tester.pumpAndSettle();

    expect(confirmed, isTrue);
    expect(find.text('new-rat'), findsNothing);
  });

  testWidgets('DCR deletion requires the exact client ID', (tester) async {
    bool? confirmed;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => FilledButton(
              onPressed: () async {
                confirmed = await confirmDcrDeletion(
                  context,
                  clientId: 'client-123',
                );
              },
              child: const Text('Open delete'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open delete'));
    await tester.pumpAndSettle();
    expect(_filledButton(tester, 'Delete App').onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'client-12');
    await tester.pump();
    expect(_filledButton(tester, 'Delete App').onPressed, isNull);

    await tester.enterText(find.byType(TextField), 'client-123');
    await tester.pump();
    expect(_filledButton(tester, 'Delete App').onPressed, isNotNull);
    await tester.tap(find.text('Delete App'));
    await tester.pumpAndSettle();
    expect(confirmed, isTrue);
  });

  testWidgets('public client form forces and locks PKCE', (tester) async {
    final controller = DcrFormController()
      ..tokenEndpointAuthMethod = 'none'
      ..requirePkce = false;
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: DcrMetadataForm(controller: controller, onChanged: () {}),
          ),
        ),
      ),
    );

    final pkce = tester.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'Require PKCE'),
    );
    expect(pkce.value, isTrue);
    expect(pkce.onChanged, isNull);
    expect(find.textContaining('PKCE S256 required'), findsOneWidget);
    expect(find.text('Contacts (one per line)'), findsOneWidget);
    expect(find.text('Expert JSON'), findsOneWidget);
  });

  testWidgets('incomplete GET disables RFC 7592 save', (tester) async {
    final api = DeveloperApi(
      baseUri: Uri.parse('https://sso.example'),
      httpClient: MockClient(
        (_) async => http.Response(
          '{"client_id":"client-1","client_name":"Acme",'
          '"redirect_uris":["https://app.example/cb"],'
          '"scope":"openid","token_endpoint_auth_method":'
          '"client_secret_basic","token_strategy":"jwt"}',
          200,
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ManagePanel(api: api)),
      ),
    );

    await tester.enterText(find.byType(TextField).at(0), 'client-1');
    await tester.enterText(find.byType(TextField).at(1), 'rat-1');
    await tester.tap(find.text('Load App'));
    await tester.pumpAndSettle();

    expect(
      find.text('Saving disabled: incomplete RFC 7592 representation'),
      findsOneWidget,
    );
    expect(_filledButton(tester, 'Save Changes').onPressed, isNull);
  });

  testWidgets('HTTP 500 remains retryable rather than invalid credentials', (
    tester,
  ) async {
    final api = DeveloperApi(
      baseUri: Uri.parse('https://sso.example'),
      httpClient: MockClient(
        (_) async => http.Response(
          '{"error":"server_error","error_description":"try later"}',
          500,
        ),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: ManagePanel(api: api)),
      ),
    );

    await tester.enterText(find.byType(TextField).at(0), 'client-1');
    await tester.enterText(find.byType(TextField).at(1), 'rat-1');
    await tester.tap(find.text('Load App'));
    await tester.pumpAndSettle();

    expect(find.textContaining('not classified as invalid'), findsOneWidget);
    expect(
      find.text('Invalid client ID or registration access token.'),
      findsNothing,
    );
    expect(find.text('Retry Load'), findsOneWidget);
  });
}

OutlinedButton _button(WidgetTester tester, String label) {
  return tester.widget<OutlinedButton>(
    find.widgetWithText(OutlinedButton, label),
  );
}

FilledButton _filledButton(WidgetTester tester, String label) {
  return tester.widget<FilledButton>(find.widgetWithText(FilledButton, label));
}
