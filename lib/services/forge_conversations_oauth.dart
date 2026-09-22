import 'forge_auth_profile.dart';

/// Least-privilege OAuth request for the independent Forge Sessions surface.
/// Provision this resource and both scopes on the Snaplink Console client.
abstract final class ForgeConversationsOAuth {
  static const clientId = String.fromEnvironment(
    'SNAPLINK_FORGE_CLIENT_ID',
    defaultValue: ForgeAuthProfile.consoleClientId,
  );

  static const resource = String.fromEnvironment(
    'SNAPLINK_FORGE_RESOURCE',
    defaultValue: ForgeAuthProfile.resource,
  );

  static const scopes = ForgeAuthProfile.conversationScopes;

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
