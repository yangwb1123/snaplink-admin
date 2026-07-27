import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/screens/portal/organization_admin_tab.dart';
import 'package:sso_admin/screens/portal/portal_api.dart';

void main() {
  testWidgets('missing invitations route does not hide member management', (
    tester,
  ) async {
    final api = PortalApi(
      httpClient: MockClient((request) async {
        if (request.url.path.endsWith('/members')) {
          return http.Response(
            '{"members":[{"user_id":"user-1","role":"admin"}]}',
            200,
          );
        }
        if (request.url.path.endsWith('/invitations')) {
          return http.Response('{}', 404);
        }
        return http.Response('{}', 500);
      }),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OrganizationAdminPanel(
            api: api,
            tenantId: 'tenant-1',
            onClose: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Members'), findsOneWidget);
    expect(find.text('user-1'), findsOneWidget);
    expect(
      find.text(
        'Organization administration is not available to this account.',
      ),
      findsNothing,
    );
    expect(find.text('Invite member'), findsNothing);
    expect(find.text('Pending invitations'), findsNothing);
  });
}
