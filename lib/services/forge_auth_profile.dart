/// Shared Snaplink profile values for the Forge Conversation client.
///
/// The issuer origin remains deployment-configured. These values are the
/// stable audience/resource and least-privilege scopes that must match the
/// CLI/TUI profile and the Snaplink client seed.
abstract final class ForgeAuthProfile {
  static const audience = 'forge-api';
  static const resource = audience;
  static const cliClientId = 'forge-cli';
  static const consoleClientId = 'forge-console';
  static const deviceCodeGrantType =
      'urn:ietf:params:oauth:grant-type:device_code';
  static const authorizationCodeGrantType = 'authorization_code';
  static const refreshTokenGrantType = 'refresh_token';
  static const conversationScopes = <String>[
    'forge:conversations:read',
    'forge:conversations:write',
  ];
}
