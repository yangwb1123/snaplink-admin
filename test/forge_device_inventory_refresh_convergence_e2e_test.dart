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
      Platform.environment['FORGE_DEVICE_INVENTORY_CONVERGENCE_E2E_INPUT'];

  test(
    'all authenticated inventory readers converge after refresh',
    () async {
      final input = Map<String, dynamic>.from(
        jsonDecode(File(inputPath!).readAsStringSync()) as Map,
      );
      final apiURL = input['api_url'];
      final accessToken = input['access_token'];
      final issuer = input['issuer'];
      final subject = input['subject'];
      final tenantID = input['tenant_id'];
      final expectedRevision = input['expected_revision'];
      final expectedGeneration = input['expected_generation'];
      final expectedHeartbeat = input['expected_heartbeat'];
      if (apiURL is! String ||
          accessToken is! String ||
          issuer is! String ||
          subject is! String ||
          tenantID is! String ||
          expectedRevision is! int ||
          expectedGeneration is! int ||
          expectedHeartbeat is! int) {
        throw const FormatException(
          'Invalid Forge inventory convergence input.',
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
        final v1 = await api.readDeviceInventoryCandidate(owner: owner);
        final v2 = await api.readDeviceInventoryCandidateV2(owner: owner);
        final resource = await api.readClientInstanceResourceViewCandidate(
          owner: owner,
        );
        expect(v1.owner, owner);
        expect(v2.owner, owner);
        expect(resource.owner, owner);
        expect(v1.devices.map((row) => row.instanceID), [
          'runner-a',
          'runner-b',
        ]);
        expect(v2.devices, hasLength(2));
        expect(resource.devices, hasLength(2));
        final v2ByDevice = {
          for (final row in v2.devices) row.device.deviceID: row,
        };
        final resourceByDevice = {
          for (final row in resource.devices) row.deviceID: row,
        };
        final v2Device = v2ByDevice['device-a'];
        final resourceDevice = resourceByDevice['device-a'];
        expect(v2Device, isNotNull);
        expect(resourceDevice, isNotNull);
        expect(v2Device!.instanceID, resourceDevice!.runnerInstanceID);
        expect(v2Device.revision, expectedRevision);
        expect(v2Device.generation, expectedGeneration);
        expect(v2Device.heartbeatSequence, expectedHeartbeat);
        expect(resourceDevice.revision, expectedRevision);
        expect(resourceDevice.generation, expectedGeneration);
        expect(resourceDevice.heartbeatSequence, expectedHeartbeat);
        expect(v2Device.device.liveness, resourceDevice.liveness);
        expect(
          v2Device.device.reservationState,
          resourceDevice.reservationState,
        );
        expect(resource.instances.map((row) => row.clientKind), [
          'app',
          'cli',
          'mobile',
          'tui',
          'web',
        ]);
        expect(v1.executionAuthorized, isFalse);
        expect(v2.executionAuthorized, isFalse);
        expect(resource.isDisplayOnly, isTrue);
        expect(resource.authority.executionAuthorized, isFalse);
        expect(resource.authority.dispatchPerformed, isFalse);
      } finally {
        api.close();
      }
    },
    skip: inputPath == null,
  );
}
