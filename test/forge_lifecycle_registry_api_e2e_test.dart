import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_conversations_api.dart';
import 'package:sso_admin/api/forge_device_enrollment_heartbeat_lifecycle_registry.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';

class _LiveHttpTestWidgetsBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

void main() {
  _LiveHttpTestWidgetsBinding();
  final inputPath = Platform.environment['FORGE_LIFECYCLE_REGISTRY_E2E_INPUT'];

  test(
    'Flutter decodes the accepted owner-scoped lifecycle registry read',
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
          'Invalid Forge lifecycle registry E2E input.',
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
        final registry = await api.readLifecycleRegistryCandidate(
          owner: owner,
          candidateOrigin: apiURL,
        );
        expect(
          registry.schemaVersion,
          forgeDeviceEnrollmentHeartbeatLifecycleRegistrySchema,
        );
        expect(registry.owner, owner);
        expect(registry.states, hasLength(2));
        expect(registry.states.map((state) => state.deviceID), [
          'device-a',
          'device-b',
        ]);
        expect(registry.states.map((state) => state.instanceID), [
          'runner-a',
          'runner-b',
        ]);
        expect(registry.states.first.liveness, 'online');
        expect(registry.states.last.liveness, 'offline');
        expect(registry.isDisplayOnly, isTrue);
      } finally {
        api.close();
      }
    },
    skip: inputPath == null,
  );
}
