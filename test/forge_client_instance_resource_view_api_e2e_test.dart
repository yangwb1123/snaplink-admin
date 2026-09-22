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
  final inputPath =
      Platform.environment['FORGE_CLIENT_INSTANCE_RESOURCE_VIEW_E2E_INPUT'];

  test(
    'Flutter decodes the authenticated client-instance/resource view',
    () async {
      final input = Map<String, dynamic>.from(
        jsonDecode(File(inputPath!).readAsStringSync()) as Map,
      );
      final apiURL = input['api_url'];
      final accessToken = input['access_token'];
      final issuer = input['issuer'];
      final subject = input['subject'];
      final tenantID = input['tenant_id'];
      final expectedGPUCount = input['expected_gpu_count'];
      final expectedAvailableGPUMemoryBytes =
          input['expected_available_gpu_memory_bytes'];
      final expectedReservationState = input['expected_reservation_state'];
      if (apiURL is! String ||
          accessToken is! String ||
          issuer is! String ||
          subject is! String ||
          tenantID is! String ||
          expectedGPUCount is! int ||
          expectedAvailableGPUMemoryBytes is! int ||
          expectedReservationState is! String) {
        throw const FormatException(
          'Invalid Forge client-instance/resource-view E2E input.',
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
        final view = await api.readClientInstanceResourceViewCandidate(
          owner: owner,
        );
        expect(view.owner, owner);
        expect(view.instances, hasLength(5));
        expect(view.instances.map((instance) => instance.clientKind), [
          'app',
          'cli',
          'mobile',
          'tui',
          'web',
        ]);
        expect(view.devices, hasLength(2));
        expect(view.devices.first.deviceID, 'device-a');
        expect(view.devices.first.runnerInstanceID, 'runner-a');
        expect(view.devices.first.revision, 1);
        expect(view.devices.first.gpuCount, expectedGPUCount);
        expect(
          view.devices.first.availableGPUMemoryBytes,
          expectedAvailableGPUMemoryBytes,
        );
        expect(view.devices.first.reservationState, expectedReservationState);
        expect(view.devices.last.deviceID, 'device-b');
        expect(view.devices.last.runnerInstanceID, 'runner-b');
        expect(view.devices.last.liveness, 'offline');
        expect(view.ownerDeclarationUnverified, isTrue);
        expect(view.deviceAttributesUnverified, isTrue);
        expect(view.isDisplayOnly, isTrue);
      } finally {
        api.close();
      }
    },
    skip: inputPath == null,
  );
}
