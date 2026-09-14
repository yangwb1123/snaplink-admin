import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/screens/oidc_login/oauth_params.dart';
import 'package:sso_admin/services/forge_conversations_oauth.dart';

void main() {
  test(
    'uses the dedicated Forge client and least-privilege resource/scopes',
    () {
      final login = Uri.parse(ForgeConversationsOAuth.loginLocation());
      expect(login.path, '/login/');
      expect(login.queryParameters['redirect'], '/forge/');
      expect(
        login.queryParameters['client_id'],
        ForgeConversationsOAuth.clientId,
      );
      expect(login.queryParametersAll['resource'], ['forge-api']);
      expect(
        login.queryParametersAll['resource']!.toSet(),
        ForgeConversationsOAuth.resources,
      );
      expect(login.queryParameters['scope']!.split(' ').toSet(), {
        'openid',
        'profile',
        'forge:conversations:read',
        'forge:conversations:write',
      });
      expect(login.queryParameters.keys, isNot(contains('token')));

      final loginPayload = OAuthParams.fromUri(
        login,
      ).toLoginPayload('password');
      expect(loginPayload['client_id'], ForgeConversationsOAuth.clientId);
      expect(loginPayload['resource'], ['forge-api']);
      expect(loginPayload['scope'], contains('forge:conversations:read'));
      expect(loginPayload['scope'], contains('forge:conversations:write'));
    },
  );

  test('authorization retry returns to Forge without bearer data', () {
    final login = Uri.parse(
      ForgeConversationsOAuth.loginLocation(
        retryAfterAuthorizationFailure: true,
      ),
    );
    expect(login.queryParameters['redirect'], '/forge/?forge_auth_retry=1');
    expect(
      login.queryParameters.values.join('&'),
      isNot(contains('access_token')),
    );
  });
}
