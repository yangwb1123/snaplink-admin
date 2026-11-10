@TestOn('browser')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/screens/oidc_login/hosted_login_models.dart';
import 'package:sso_admin/screens/oidc_login/login_view_widget.dart';
import 'package:web/web.dart' as web;

void main() {
  testWidgets('login never rewrites another form or new-password metadata', (
    tester,
  ) async {
    final form = web.HTMLFormElement();
    final account = web.HTMLInputElement()
      ..type = 'text'
      ..name = 'registration-account'
      ..autocomplete = 'username';
    final password = web.HTMLInputElement()
      ..type = 'password'
      ..name = 'registration-password'
      ..autocomplete = 'new-password';
    form.append(account);
    form.append(password);
    web.document.body!.append(form);
    // Registration usernames use the standard username token. Chrome reflects
    // an invalid token such as new-username as empty, even before Flutter runs.
    expect(account.autocomplete, 'username');
    expect(password.autocomplete, 'new-password');
    final controllers = List.generate(4, (_) => TextEditingController());
    try {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: LoginViewWidget(
                provider: 'password',
                providers: const [LoginProviderDescriptor.password()],
                userCtrl: controllers[0],
                passCtrl: controllers[1],
                codeTargetCtrl: controllers[2],
                providerCodeCtrl: controllers[3],
                codeSent: false,
                loading: false,
                usesFederatedProvider: false,
                usesCodeProvider: false,
                usesTotpProvider: false,
                onSubmit: () {},
                onSendCode: () {},
                onHomeRealm: () {},
                onForgotPassword: () {},
                onSignUp: () {},
                onProviderChanged: (_) {},
                onFederatedSignIn: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(account.name, 'registration-account');
      expect(account.autocomplete, 'username');
      expect(password.name, 'registration-password');
      expect(password.autocomplete, 'new-password');
    } finally {
      await tester.pumpWidget(const SizedBox.shrink());
      form.remove();
      for (final controller in controllers) {
        controller.dispose();
      }
    }
  });
}
