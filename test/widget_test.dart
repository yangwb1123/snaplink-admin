import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:sso_admin/main.dart';

void main() {
  testWidgets('App boots to the unified first-party login screen by default', (WidgetTester tester) async {
    await tester.pumpWidget(const SSOConsoleApp());
    // The screen briefly shows a spinner while it checks whether this load is
    // a federated-login return leg (an async gap even on a plain first load).
    await tester.pump();
    await tester.pump();

    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
    expect(find.text('Sign in with Google'), findsOneWidget);
    expect(find.text('Sign in with GitHub'), findsOneWidget);
  });
}
