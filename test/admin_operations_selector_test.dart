import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/screens/admin/admin_operations_tab.dart';

void main() {
  testWidgets('operations selector excludes the audit sibling lookalike', (
    tester,
  ) async {
    const lookalike = SnaplinkAdminEndpoint(
      method: 'GET',
      path: '/api/v1/auditx/events',
      feature: 'lookalike',
    );
    const auditEvent = SnaplinkAdminEndpoint(
      method: 'GET',
      path: '/api/v1/audit/events',
      feature: 'audit',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AdminOperationsTab(
            api: SnaplinkAdminApi(
              baseUrl: 'https://sso.example',
              accessToken: 'token',
            ),
            endpoints: const [lookalike, auditEvent],
          ),
        ),
      ),
    );
    await tester.pump();

    final picker = tester.widget<DropdownButton<SnaplinkAdminEndpoint>>(
      find.byType(DropdownButton<SnaplinkAdminEndpoint>),
    );
    final paths = picker.items!
        .map((item) => item.value?.path)
        .whereType<String>()
        .toList(growable: false);

    expect(paths, contains('/api/v1/audit/events'));
    expect(paths, isNot(contains('/api/v1/auditx/events')));
  });
}
