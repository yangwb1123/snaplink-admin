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
      Platform.environment['FORGE_CLIENT_INSTANCE_SESSION_VIEW_E2E_INPUT'];

  test(
    'Flutter decodes the authenticated client-instance/session view',
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
          'Invalid Forge client-instance/session-view E2E input.',
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
        final view = await api.readClientInstanceSessionViewCandidate(
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
        expect(view.instances.first.sessionIDs, ['conversation-a']);
        expect(view.instances.last.sessionIDs, [
          'conversation-a',
          'conversation-b',
        ]);
        expect(view.ownerDeclarationUnverified, isTrue);
        expect(view.isDisplayOnly, isTrue);
      } finally {
        api.close();
      }
    },
    skip: inputPath == null,
  );
}
