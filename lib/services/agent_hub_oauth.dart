import 'admin_oauth_resources.dart';

/// Audience and narrow OAuth scopes requested only by Agent Operations.
///
/// These values must be provisioned on the Snaplink first-party OAuth client
/// and independently allowed by the Agent Hub deployment. A successful
/// Snaplink login alone does not grant Agent Hub access.
abstract final class AgentHubOAuth {
  static const audience = String.fromEnvironment(
    'SNAPLINK_AGENT_HUB_RESOURCE',
    defaultValue: 'agent-hub',
  );

  static const scopes = <String>[
    'agent.instances:read',
    'agent.sessions:read',
    'agent.sessions:write',
    'agent.turns:cancel',
    'agent.devices:read',
    'agent.tasks:read',
    'agent.tasks:write',
    'agent.tasks:cancel',
  ];

  /// Keep the ordinary Console resources in the token because this app keeps
  /// one tab-scoped bearer across product routes.
  static Set<String> get resources => {...AdminOAuthResources.values, audience};

  static String loginLocation({bool retryAfterAudienceFailure = false}) {
    final redirect = retryAfterAudienceFailure
        ? '/agent/?agent_hub_auth_retry=1'
        : '/agent/';
    return Uri(
      path: '/login/',
      queryParameters: {
        'redirect': redirect,
        'resource': resources,
        'scope': ['openid', 'profile', 'email', ...scopes].join(' '),
      },
    ).toString();
  }
}
