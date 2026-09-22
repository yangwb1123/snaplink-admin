import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_conversations_api.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/screens/forge/forge_sessions_screen.dart';

class _LiveHttpTestWidgetsBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

void main() {
  _LiveHttpTestWidgetsBinding();
  final inputPath =
      Platform.environment['FORGE_DEVICE_INVENTORY_V2_SESSIONS_E2E_INPUT'];

  testWidgets(
    'shared Web/App/Mobile Sessions renders the authenticated v2 inventory candidate',
    (tester) async {
      final input = Map<String, dynamic>.from(
        jsonDecode(File(inputPath!).readAsStringSync()) as Map,
      );
      final apiURL = input['api_url'];
      final accessToken = input['access_token'];
      final issuer = input['issuer'];
      final subject = input['subject'];
      final tenantID = input['tenant_id'];
      if (apiURL is! String ||
          accessToken is! String ||
          issuer is! String ||
          subject is! String ||
          tenantID is! String) {
        throw const FormatException(
          'Invalid Forge v2 Sessions inventory E2E input.',
        );
      }

      final owner = ForgeDeviceOwner(
        issuer: issuer,
        subject: subject,
        tenantID: tenantID,
      );
      final api = ForgeConversationsApi(
        baseUrl: apiURL,
        accessToken: accessToken,
      );
      try {
        await tester.pumpWidget(
          MaterialApp(
            home: ForgeSessionsScreen(
              accessToken: accessToken,
              apiOrigin: apiURL,
              deviceInventoryOwner: owner,
              deviceInventoryV2Reader: (requestedOwner) =>
                  api.readDeviceInventoryCandidateV2(owner: requestedOwner),
            ),
          ),
        );
        await _pumpUntil(
          tester,
          () => find
              .byKey(const ValueKey('forge-authenticated-device-inventory-v2'))
              .evaluate()
              .isNotEmpty,
          waitFor: 'authenticated v2 inventory Sessions panel',
        );

        expect(
          find.byKey(const ValueKey('forge-authenticated-device-inventory-v2')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('forge-inventory-v2-device-a-runner-a')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('forge-inventory-v2-device-b-runner-b')),
          findsOneWidget,
        );
        expect(find.textContaining('revision 1'), findsOneWidget);
        expect(find.textContaining('heartbeat 4'), findsOneWidget);
        expect(find.text('Execution authorized: false'), findsOneWidget);
        expect(find.text('Reservation created: false'), findsOneWidget);
        expect(find.text('Dispatch performed: false'), findsOneWidget);
      } finally {
        api.close();
      }
    },
    skip: inputPath == null,
  );
}

Future<void> _pumpUntil(
  WidgetTester tester,
  bool Function() condition, {
  required String waitFor,
}) async {
  for (var count = 0; count < 250; count++) {
    if (condition()) return;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  expect(
    condition(),
    isTrue,
    reason: 'Timed out waiting for $waitFor from the live inventory API.',
  );
}
