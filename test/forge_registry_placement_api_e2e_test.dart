import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/forge_conversations_api.dart';
import 'package:sso_admin/api/forge_device_inventory_declaration.dart';
import 'package:sso_admin/api/forge_device_placement.dart';

class _LiveHttpTestWidgetsBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

void main() {
  _LiveHttpTestWidgetsBinding();
  final inputPath = Platform.environment['FORGE_REGISTRY_PLACEMENT_E2E_INPUT'];

  test(
    'Flutter reads the accepted owner-scoped registry placement preflight',
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
          'Invalid Forge registry placement E2E input.',
        );
      }

      final owner = ForgeDeviceOwner(
        issuer: issuer,
        subject: subject,
        tenantID: tenantID,
      );
      final requirements = ForgeDevicePlacementRequirements.fromJson(
        input['requirements'],
      );
      final api = ForgeConversationsApi(
        baseUrl: apiURL,
        accessToken: accessToken,
      );
      try {
        final preview = await api.previewDevicePlacementFromRegistry(
          owner: owner,
          requirements: requirements,
          candidateOrigin: apiURL,
        );
        expect(preview.evaluationOwner, owner);
        expect(preview.decisions, hasLength(2));
        expect(preview.decisions.map((decision) => decision.deviceID), [
          'device-a',
          'device-b',
        ]);
        expect(preview.decisions.map((decision) => decision.instanceID), [
          'runner-a',
          'runner-b',
        ]);
        expect(preview.evaluatedAtMS, greaterThan(0));
        expect(preview.selectedDeviceID, isNull);
        expect(preview.selectedInstanceID, isNull);
        expect(preview.authority.anyGranted, isFalse);
        for (final decision in preview.decisions) {
          expect(decision.ownerDeclarationUnverified, isTrue);
          expect(decision.deviceAttributesUnverified, isTrue);
        }
      } finally {
        api.close();
      }
    },
    skip: inputPath == null,
  );
}
