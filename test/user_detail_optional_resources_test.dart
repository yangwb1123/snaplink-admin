import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/api/sso_client.dart';
import 'package:sso_admin/screens/admin/user_detail_screen.dart';

void main() {
  testWidgets('optional user resources do not hide the primary user', (
    tester,
  ) async {
    final transport = MockClient((request) async {
      if (request.url.path == '/api/v1/admin/users/user-1') {
        return http.Response(
          '{"user":{"id":"user-1","provider":"local"}}',
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      return http.Response(
        '{"error":"not_found"}',
        404,
        headers: {'content-type': 'application/json'},
      );
    });
    final api = SnaplinkAdminApi(
      baseUrl: 'https://snaplink.test',
      accessToken: 'admin-token',
      httpClient: transport,
    );
    final client = SSOAdminClient(
      'https://snaplink.test',
      httpClient: transport,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: UserDetailScreen(api: api, client: client, userId: 'user-1'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Failed to load user'), findsNothing);
    expect(find.text('user-1'), findsWidgets);
    expect(find.text('This user resource is unavailable.'), findsOneWidget);
  });
}
