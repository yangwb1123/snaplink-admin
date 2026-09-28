import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_conversations_api.dart';
import 'package:sso_admin/api/forge_device_inventory_models.dart';
import 'package:sso_admin/screens/forge/forge_sessions_screen.dart';

class _LiveHttpTestWidgetsBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

void main() {
  _LiveHttpTestWidgetsBinding();
  final inputPath =
      Platform.environment['FORGE_ACCEPTED_DEVICE_INVENTORY_E2E_INPUT'];

  testWidgets(
    'Console reads accepted v1 inventory and lossless v2 resources',
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
          'Invalid accepted Forge device inventory E2E input.',
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
        timeout: const Duration(seconds: 5),
      );
      try {
        // The same accepted HTTP route is fed into the shared Sessions surface
        // used by Web, desktop App, and Mobile. This proves the user-facing
        // resource panel consumes the authenticated production projection.
        ForgeDeviceInventoryPage? fetchedV1;
        ForgeDeviceInventoryPageV2? fetchedV2;
        await tester.pumpWidget(
          MaterialApp(
            home: ForgeSessionsScreen(
              accessToken: accessToken,
              apiOrigin: apiURL,
              deviceInventoryOwner: owner,
              deviceInventoryReader: (requestedOwner) => api
                  .readDeviceInventoryCandidate(owner: requestedOwner)
                  .then((page) {
                    fetchedV1 = page;
                    return page;
                  }),
              deviceInventoryV2Reader: (requestedOwner) async {
                final page = await api.readDeviceInventoryCandidateV2(
                  owner: requestedOwner,
                );
                fetchedV2 = page;
                return page;
              },
            ),
          ),
        );
        await _pumpUntil(
          tester,
          () => find
              .byKey(const ValueKey('forge-authenticated-device-inventory'))
              .evaluate()
              .isNotEmpty,
          waitFor: 'accepted v1 inventory panel',
        );
        final v1 = fetchedV1;
        expect(v1, isNotNull);
        expect(v1!.owner, owner);
        expect(v1.devices, hasLength(2));
        expect(v1.devices.map((candidate) => candidate.device.deviceID), [
          'device-a',
          'device-b',
        ]);
        expect(v1.devices.map((candidate) => candidate.instanceID), [
          'runner-a',
          'runner-b',
        ]);
        expect(v1.evaluatedAtMS, greaterThan(0));
        expect(v1.ownerDeclarationUnverified, isTrue);
        expect(v1.inventoryDeclarationsUnverified, isTrue);
        expect(v1.executionAuthorized, isFalse);
        expect(v1.reservationCreated, isFalse);
        expect(v1.dispatchPerformed, isFalse);
        expect(
          find.byKey(const ValueKey('forge-authenticated-device-inventory')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('forge-inventory-device-a-runner-a')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('forge-inventory-device-b-runner-b')),
          findsOneWidget,
        );
        expect(find.text('Execution authorized: false'), findsOneWidget);
        expect(find.text('Reservation created: false'), findsOneWidget);
        expect(find.text('Dispatch performed: false'), findsOneWidget);

        await _pumpUntil(
          tester,
          () => fetchedV2 != null,
          waitFor: 'accepted v2 inventory response',
        );
        final v2 = fetchedV2;
        expect(v2, isNotNull);
        expect(v2!.owner, owner);
        expect(v2.devices, hasLength(2));
        expect(v2.evaluatedAtMS, greaterThan(0));
        expect(v2.devices.first.instanceID, 'runner-a');
        expect(v2.devices.first.revision, 1);
        expect(v2.devices.first.generation, 1);
        expect(v2.devices.first.heartbeatSequence, 1);
        expect(v2.devices.first.device.gpus, isEmpty);
        expect(v2.devices.last.instanceID, 'runner-b');
        expect(v2.devices.last.revision, 1);
        expect(v2.devices.last.generation, 1);
        expect(v2.devices.last.heartbeatSequence, 1);
        expect(v2.devices.last.device.gpus, isEmpty);
        expect(v2.ownerDeclarationUnverified, isTrue);
        expect(v2.inventoryDeclarationsUnverified, isTrue);
        expect(v2.executionAuthorized, isFalse);
        expect(v2.reservationCreated, isFalse);
        expect(v2.dispatchPerformed, isFalse);
      } finally {
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
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
    reason: 'Timed out waiting for $waitFor from the accepted inventory API.',
  );
}
