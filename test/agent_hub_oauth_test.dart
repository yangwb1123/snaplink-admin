import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/services/agent_hub_oauth.dart';

void main() {
  test('requests the Hub resource and only the declared Agent scopes', () {
    final login = Uri.parse(AgentHubOAuth.loginLocation());
    expect(login.path, '/login/');
    expect(login.queryParameters['redirect'], '/agent/');
    expect(login.queryParametersAll['resource'], contains('agent-hub'));
    expect(login.queryParameters['scope']!.split(' ').toSet(), {
      'openid',
      'profile',
      'email',
      'agent.instances:read',
      'agent.sessions:read',
      'agent.sessions:write',
      'agent.turns:cancel',
      'agent.devices:read',
      'agent.tasks:read',
      'agent.tasks:write',
      'agent.tasks:cancel',
    });
    expect(login.queryParameters.keys, isNot(contains('token')));
  });

  test('re-authentication returns to Agent Operations without token data', () {
    final login = Uri.parse(
      AgentHubOAuth.loginLocation(retryAfterAudienceFailure: true),
    );
    expect(login.queryParameters['redirect'], '/agent/?agent_hub_auth_retry=1');
    expect(
      login.queryParameters.values.join('&'),
      isNot(contains('access_token')),
    );
  });
}
