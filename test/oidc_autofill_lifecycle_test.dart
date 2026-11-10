import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/oidc_login_api.dart';
import 'package:sso_admin/screens/oidc_login/oidc_login_screen.dart';

Finder _field(String hint) => find.byWidgetPredicate(
  (widget) =>
      widget is TextField && (widget.autofillHints?.contains(hint) ?? false),
);

List<bool> _finishes(WidgetTester tester) => tester.testTextInput.log
    .where((call) => call.method == 'TextInput.finishAutofillContext')
    .map((call) => call.arguments as bool)
    .toList();

Future<void> _mount(WidgetTester tester, {String challenge = 'consent'}) async {
  tester.view.physicalSize = const Size(1000, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final api = OidcLoginApi(
    baseUri: Uri.parse('https://autofill.example.invalid'),
    httpClient: MockClient((request) async {
      if (request.url.path == '/branding') return http.Response('{}', 404);
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      final data = body['credential'] != null && challenge == 'success'
          ? <String, dynamic>{'code': 'fixture-code'}
          : body['credential'] != null && challenge == 'failure'
          ? <String, dynamic>{'error': 'invalid_credentials'}
          : body['credential'] == null
          ? <String, dynamic>{
              'providers': [
                {'id': 'password', 'type': 'builtin'},
              ],
            }
          : challenge == 'mfa'
          ? <String, dynamic>{
              'error': 'mfa_required',
              'mfa_challenge_id': 'fixture-mfa',
              'mfa_methods': ['totp'],
            }
          : <String, dynamic>{
              'error': 'consent_required',
              'login_transaction_id': 'fixture-transaction',
              'consent_challenge_id': 'fixture-consent',
              'client_name': 'Autofill fixture',
              'scopes': ['openid'],
              'resources': ['fixture-api'],
            };
      return http.Response(jsonEncode(data), 200);
    }),
  );
  addTearDown(api.close);
  await tester.pumpWidget(
    MaterialApp(
      home: OidcLoginScreen(
        api: api,
        defaultClientId: 'autofill-fixture',
        routeUri: Uri.parse('https://autofill.example.invalid/login/'),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _password(WidgetTester tester, {bool remember = true}) async {
  await tester.enterText(_field(AutofillHints.username), 'fixture-user');
  await tester.enterText(_field(AutofillHints.password), 'fixture-password');
  if (remember) {
    await tester.tap(find.text('Remember password'));
    await tester.pump();
  }
}

void main() {
  testWidgets('account view changes do not close the active input context', (
    tester,
  ) async {
    await _mount(tester);
    await _password(tester);
    tester.testTextInput.log.clear();
    await tester.tap(find.text('Forgot password?'));
    await tester.pumpAndSettle();
    expect(
      _finishes(tester),
      isEmpty,
      reason: 'An outgoing form must not close a new view\'s text connection.',
    );
    await tester.tap(find.widgetWithText(TextButton, 'Back'));
    await tester.pumpAndSettle();
    expect(_finishes(tester), isEmpty);
    await tester.enterText(_field(AutofillHints.username), 'return-user');
    await tester.enterText(_field(AutofillHints.password), 'return-password');
    expect(
      tester.widget<TextField>(_field(AutofillHints.username)).controller!.text,
      'return-user',
    );
    expect(
      tester.widget<TextField>(_field(AutofillHints.password)).controller!.text,
      'return-password',
    );
  });

  for (final challenge in ['consent', 'mfa']) {
    testWidgets(
      '$challenge preserves pending password autofill until success',
      (tester) async {
        await _mount(tester, challenge: challenge);
        await _password(tester);
        final controller = tester
            .widget<TextField>(_field(AutofillHints.password))
            .controller!;
        tester.testTextInput.log.clear();
        await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
        await tester.pumpAndSettle();
        expect(_field(AutofillHints.password), findsNothing);
        expect(
          _finishes(tester),
          isEmpty,
          reason: 'A challenge is not terminal authentication success.',
        );
        expect(
          controller.text.isNotEmpty,
          isTrue,
          reason: 'Do not erase the browser form before its terminal commit.',
        );
      },
    );
  }

  testWidgets('unchecked password does not retain a save candidate', (
    tester,
  ) async {
    await _mount(tester);
    await _password(tester, remember: false);
    final controller = tester
        .widget<TextField>(_field(AutofillHints.password))
        .controller!;
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(controller.text, isEmpty);
  });

  for (final remember in [false, true]) {
    testWidgets('terminal success commits only with opt-in ($remember)', (
      tester,
    ) async {
      await _mount(tester, challenge: 'success');
      await _password(tester, remember: remember);
      final controller = tester
          .widget<TextField>(_field(AutofillHints.password))
          .controller!;
      tester.testTextInput.log.clear();
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();
      expect(_finishes(tester), [remember]);
      expect(controller.text, isEmpty);
    });
  }

  testWidgets('rejected credentials never ask the password manager to save', (
    tester,
  ) async {
    await _mount(tester, challenge: 'failure');
    await _password(tester);
    tester.testTextInput.log.clear();
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(_finishes(tester), isEmpty);
  });

  testWidgets('abandoning the screen cancels, never saves, autofill', (
    tester,
  ) async {
    await _mount(tester);
    await _password(tester);
    tester.testTextInput.log.clear();
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(_finishes(tester), [false]);
  });
}
