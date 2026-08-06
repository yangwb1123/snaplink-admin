import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/screens/developer/developer_api.dart';
import 'package:sso_admin/screens/developer/developer_screen.dart';

void main() {
  testWidgets('shows serving-region provenance advertised by discovery', (
    tester,
  ) async {
    final api = DeveloperApi(
      baseUri: Uri.parse('https://sso.example'),
      httpClient: MockClient(
        (_) async => http.Response(
          jsonEncode({
            'registration_endpoint': 'https://sso.example/register',
            'serving_region': 'eu-west-1',
          }),
          200,
        ),
      ),
    );

    await tester.pumpWidget(MaterialApp(home: DeveloperScreen(api: api)));
    await tester.pumpAndSettle();

    expect(find.text('Serving region: eu-west-1'), findsOneWidget);
    expect(
      find.text(
        'Advertised by OpenID Discovery as deployment provenance, not the user location.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('does not invent a region when discovery omits it', (
    tester,
  ) async {
    final api = DeveloperApi(
      baseUri: Uri.parse('https://sso.example'),
      httpClient: MockClient(
        (_) async => http.Response(
          '{"registration_endpoint":"https://sso.example/register"}',
          200,
        ),
      ),
    );

    await tester.pumpWidget(MaterialApp(home: DeveloperScreen(api: api)));
    await tester.pumpAndSettle();

    expect(find.textContaining('Serving region:'), findsNothing);
  });
}
