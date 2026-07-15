import 'package:flutter_test/flutter_test.dart';

import 'package:sso_admin/main.dart';

void main() {
  testWidgets('App boots to the admin login screen by default', (WidgetTester tester) async {
    await tester.pumpWidget(const SSOConsoleApp());
    await tester.pump();

    expect(find.text('SSO Admin'), findsOneWidget);
    expect(find.text('登录'), findsOneWidget);
  });
}
