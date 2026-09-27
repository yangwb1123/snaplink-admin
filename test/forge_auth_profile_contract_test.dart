import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/services/forge_auth_profile.dart';
import 'package:sso_admin/services/forge_conversations_oauth.dart';
import 'package:sso_admin/services/forge_device_observation_oauth.dart';

void main() {
  final fixturePath = Platform.environment['FORGE_SNAPLINK_PROFILE_FIXTURE'];

  test(
    'keeps Flutter Forge OAuth profile aligned with the shared Snaplink fixture',
    () {
      final root =
          jsonDecode(File(fixturePath!).readAsStringSync())
              as Map<String, dynamic>;
      expect(root.keys.toSet(), {
        'schema_version',
        'evaluation_mode',
        'issuer',
        'audience',
        'resource',
        'conversation_scopes',
        'device_observation_scopes',
        'clients',
        'optional_clients',
        'authority',
      });
      expect(root['schema_version'], 'forge.snaplink-profile/v1');
      expect(root['evaluation_mode'], 'configuration_parity_only');
      expect(root['issuer'], 'https://id.example');
      expect(root['audience'], ForgeAuthProfile.audience);
      expect(root['resource'], ForgeAuthProfile.resource);
      expect(root['conversation_scopes'], ForgeAuthProfile.conversationScopes);
      expect(root['device_observation_scopes'], ['forge:devices:read']);

      final clients = Map<String, dynamic>.from(root['clients'] as Map);
      final cli = Map<String, dynamic>.from(clients['cli'] as Map);
      expect(cli['client_id'], ForgeAuthProfile.cliClientId);
      expect(cli['public'], isTrue);
      expect(cli['grant_types'], [
        ForgeAuthProfile.deviceCodeGrantType,
        ForgeAuthProfile.refreshTokenGrantType,
      ]);
      expect(cli['scopes'], ForgeAuthProfile.conversationScopes);

      final console = Map<String, dynamic>.from(clients['console'] as Map);
      expect(console['client_id'], ForgeAuthProfile.consoleClientId);
      expect(console['public'], isTrue);
      expect(console['grant_types'], [
        ForgeAuthProfile.authorizationCodeGrantType,
        ForgeAuthProfile.refreshTokenGrantType,
      ]);
      expect(console['scopes'], ForgeAuthProfile.conversationScopes);
      expect(
        ForgeConversationsOAuth.clientId,
        ForgeAuthProfile.consoleClientId,
      );
      expect(ForgeConversationsOAuth.resource, ForgeAuthProfile.resource);
      expect(
        ForgeConversationsOAuth.scopes,
        ForgeAuthProfile.conversationScopes,
      );

      final optionalClients = Map<String, dynamic>.from(
        root['optional_clients'] as Map,
      );
      final observer = Map<String, dynamic>.from(
        optionalClients['device_observer'] as Map,
      );
      expect(observer['client_id'], ForgeDeviceObservationOAuth.clientId);
      expect(observer['enabled'], isFalse);
      expect(observer['public'], isTrue);
      expect(observer['grant_types'], [
        ForgeAuthProfile.authorizationCodeGrantType,
        ForgeAuthProfile.refreshTokenGrantType,
      ]);
      expect(observer['scopes'], ForgeDeviceObservationOAuth.scopes);
      expect(
        ForgeConversationsOAuth.loginLocation(),
        isNot(contains('forge:devices:read')),
      );

      final authority = Map<String, dynamic>.from(root['authority'] as Map);
      expect(authority.values, everyElement(isFalse));
    },
    skip: fixturePath == null
        ? 'Run through scripts/test-forge-contracts.sh.'
        : false,
  );
}
