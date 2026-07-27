@TestOn('browser')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/screens/portal/passkey_enrollment_card.dart';
import 'package:sso_admin/screens/portal/portal_api.dart';
import 'package:sso_admin/screens/portal/recovery_codes_card.dart';
import 'package:sso_admin/screens/portal/security_mfa_card.dart';
import 'package:sso_admin/screens/portal/security_tab.dart';
import 'package:sso_admin/screens/portal/trusted_devices_card.dart';

void main() {
  testWidgets('security page renders each credential card once', (
    tester,
  ) async {
    final api = PortalApi(
      httpClient: MockClient((request) async => http.Response('{}', 404)),
    );

    await tester.pumpWidget(MaterialApp(home: SecurityTab(api: api)));
    await tester.pumpAndSettle();

    expect(find.byType(SecurityMfaCard), findsOneWidget);
    expect(find.byType(PasskeyEnrollmentCard), findsOneWidget);
    expect(find.byType(RecoveryCodesCard), findsOneWidget);
    await tester.scrollUntilVisible(
      find.byType(TrustedDevicesCard),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byType(TrustedDevicesCard), findsOneWidget);
  });

  testWidgets('physical device payload cannot expose trusted-grant revoke', (
    tester,
  ) async {
    final api = PortalApi(
      httpClient: MockClient((request) async {
        if (request.url.path == '/me') return http.Response('{}', 200);
        if (request.url.path == '/me/devices') {
          return http.Response(
            '{"devices":[{"id":"physical-1","fingerprint":"fp",'
            '"platform":"macOS","device_name":"Work Mac"}]}',
            200,
          );
        }
        return http.Response('{}', 404);
      }),
    );
    await api.login('token', clientId: 'portal');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: TrustedDevicesCard(api: api)),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Physical-device tracking owns'),
      findsOneWidget,
    );
    expect(find.text('Revoke'), findsNothing);
    expect(
      find.textContaining('No DELETE request will be issued'),
      findsOneWidget,
    );
  });
}
