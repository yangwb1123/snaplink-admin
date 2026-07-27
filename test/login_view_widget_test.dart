import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/screens/oidc_login/hosted_login_models.dart';
import 'package:sso_admin/screens/oidc_login/login_view_widget.dart';

void main() {
  testWidgets('renders only federated providers returned by Snaplink', (
    tester,
  ) async {
    final userController = TextEditingController();
    final passController = TextEditingController();
    final targetController = TextEditingController();
    final codeController = TextEditingController();
    addTearDown(userController.dispose);
    addTearDown(passController.dispose);
    addTearDown(targetController.dispose);
    addTearDown(codeController.dispose);

    String? selectedConnection;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: LoginViewWidget(
              provider: 'password',
              providers: [
                const LoginProviderDescriptor.password(),
                LoginProviderDescriptor.fromWire({
                  'id': 'acme-workforce',
                  'type': 'oidc',
                  'display_name': 'Acme Workforce',
                  'button_label': 'Continue with Acme',
                  'button_color': '#123456',
                }),
              ],
              userCtrl: userController,
              passCtrl: passController,
              codeTargetCtrl: targetController,
              providerCodeCtrl: codeController,
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
              onFederatedSignIn: (id) => selectedConnection = id,
            ),
          ),
        ),
      ),
    );

    expect(find.text('Continue with Acme'), findsOneWidget);
    expect(find.textContaining('Google'), findsNothing);
    expect(find.textContaining('GitHub'), findsNothing);

    await tester.tap(find.text('Continue with Acme'));
    expect(selectedConnection, 'acme-workforce');
  });
}
