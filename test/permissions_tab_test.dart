import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/screens/admin/permissions_tab.dart';
import 'package:sso_admin/screens/admin/snaplink_admin_api.dart';

void main() {
  testWidgets('loads roles and assignments for the selected client', (
    tester,
  ) async {
    final paths = <String>[];
    final api = SnaplinkAdminApi(
      baseUrl: 'https://sso.example.test',
      accessToken: 'admin-token',
      httpClient: MockClient((request) async {
        paths.add(request.url.path);
        if (request.url.path.endsWith('/roles')) {
          return http.Response(
            '{"roles":[{"code":"viewer","name":"Viewer","permissions":["report:read"]}]}',
            200,
          );
        }
        return http.Response(
          '{"assignments":[{"user_id":"person-1","roles":["viewer"]}]}',
          200,
        );
      }),
    );
    final capabilities = SnaplinkAdminCapabilities(const [
      SnaplinkAdminEndpoint(
        method: 'GET',
        path: '/api/v1/admin/authz/policy-bundle',
        feature: 'permissions',
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PermissionsTab(api: api, capabilities: capabilities),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField).first, 'console-app');
    await tester.tap(find.text('Load permissions'));
    await tester.pumpAndSettle();

    expect(paths, [
      '/api/v1/admin/permissions/console-app/roles',
      '/api/v1/admin/permissions/console-app/assignments',
    ]);
    expect(find.text('Viewer'), findsOneWidget);
    expect(find.text('person-1'), findsOneWidget);
  });
}
