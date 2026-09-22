import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_conversations_api.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';

class _LiveHttpTestWidgetsBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

void main() {
  _LiveHttpTestWidgetsBinding();
  final inputPath = Platform.environment['FORGE_DEVICE_INVENTORY_V2_E2E_INPUT'];

  test(
    'Flutter decodes the exact owner-bound v2 envelope over authenticated HTTP',
    () async {
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
          'Invalid Forge v2 device inventory E2E input.',
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
        final page = await api.readDeviceInventoryCandidateV2(owner: owner);
        expect(page.owner, owner);
        expect(page.evaluatedAtMS, 200000);
        expect(page.devices, hasLength(2));

        final first = page.devices.first;
        expect(first.instanceID, 'runner-a');
        expect(first.revision, 1);
        expect(first.generation, 1);
        expect(first.heartbeatSequence, 1);
        expect(first.device.reservationState, 'reserved');
        expect(first.device.gpus, hasLength(2));
        expect(first.device.gpus[0].id, 'gpu-a');
        expect(first.device.gpus[0].memoryBytes, 16 * 1024 * 1024 * 1024);
        expect(
          first.device.gpus[0].availableMemoryBytes,
          12 * 1024 * 1024 * 1024,
        );
        expect(first.device.gpus[1].id, 'gpu-b');
        expect(
          first.device.gpus[1].availableMemoryBytes,
          4 * 1024 * 1024 * 1024,
        );

        final second = page.devices.last;
        expect(second.instanceID, 'runner-b');
        expect(second.revision, 2);
        expect(second.generation, 2);
        expect(second.heartbeatSequence, 4);
        expect(second.device.reservationState, 'none');
        expect(second.device.gpus, isEmpty);
        expect(page.ownerDeclarationUnverified, isTrue);
        expect(page.inventoryDeclarationsUnverified, isTrue);
        expect(page.executionAuthorized, isFalse);
        expect(page.reservationCreated, isFalse);
        expect(page.dispatchPerformed, isFalse);
      } finally {
        api.close();
      }
    },
    skip: inputPath == null,
  );
}
