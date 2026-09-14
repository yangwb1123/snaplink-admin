/// Least-privilege OAuth request for the independent Forge Sessions surface.
/// Provision this resource and both scopes on the Snaplink Console client.
abstract final class ForgeConversationsOAuth {
  static const clientId = String.fromEnvironment(
    'SNAPLINK_FORGE_CLIENT_ID',
    defaultValue: 'forge-console',
  );

  static const resource = String.fromEnvironment(
    'SNAPLINK_FORGE_RESOURCE',
    defaultValue: 'forge-api',
  );

  static const scopes = <String>[
    'forge:conversations:read',
    'forge:conversations:write',
  ];

  static Set<String> get resources => {resource};

  static String loginLocation({bool retryAfterAuthorizationFailure = false}) {
    final redirect = retryAfterAuthorizationFailure
        ? '/forge/?forge_auth_retry=1'
        : '/forge/';
    return Uri(
      path: '/login/',
      queryParameters: {
        'client_id': clientId,
        'redirect': redirect,
        'resource': resources,
        'scope': ['openid', 'profile', ...scopes].join(' '),
      },
    ).toString();
  }
}
