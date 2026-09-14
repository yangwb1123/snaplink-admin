import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/sso_client.dart';
import 'package:sso_admin/services/forge_conversations_oauth.dart';
import 'package:sso_admin/services/forge_credential_store.dart';
import 'package:sso_admin/services/session_cleanup.dart';
import 'package:sso_admin/session.dart';

import 'support/memory_forge_credential_backend.dart';

void main() {
  setUp(() {
    Session.clear();
    Session.clearForClient('forge-console');
  });

  test('client-scoped token storage preserves the default Console session', () {
    expect(
      Session.store('admin-token', clientId: SSOAdminClient.firstPartyClientId),
      isTrue,
    );
    expect(
      Session.storeForClient(
        'forge-console',
        'forge-token',
        sessionId: 'sid',
        refreshToken: 'forge-refresh',
      ),
      isTrue,
    );

    expect(Session.read(), 'admin-token');
    expect(Session.readClientId(), SSOAdminClient.firstPartyClientId);
    expect(Session.readForClient('forge-console'), 'forge-token');
    expect(Session.readRefreshTokenForClient('forge-console'), 'forge-refresh');
    expect(Session.readSessionIdForClient('forge-console'), 'sid');
    expect(Session.readClientIdForClient('forge-console'), 'forge-console');

    Session.clearForClient('forge-console');
    expect(Session.readForClient('forge-console'), isNull);
    expect(Session.readRefreshTokenForClient('forge-console'), isNull);
    expect(Session.read(), 'admin-token');
  });

  test(
    'clearing the Console session removes scoped client credentials too',
    () {
      expect(Session.storeForClient('forge-console', 'forge-token'), isTrue);

      Session.clear();

      expect(Session.readForClient('forge-console'), isNull);
      expect(Session.readRefreshTokenForClient('forge-console'), isNull);
      expect(Session.readClientIdForClient('forge-console'), isNull);
    },
  );

  test(
    'application-wide cleanup also deletes persistent Forge credentials',
    () async {
      final backend = MemoryForgeCredentialBackend();
      final forgeStore = ForgeCredentialStore(
        backend: backend,
        forcePersistentStorage: true,
      );
      Session.store('admin-token', clientId: SSOAdminClient.firstPartyClientId);
      await forgeStore.store(
        accessToken: 'forge-token',
        refreshToken: 'forge-refresh',
      );

      await clearAllSessions(credentialStore: forgeStore);

      expect(Session.read(), isNull);
      expect(Session.readForClient(ForgeConversationsOAuth.clientId), isNull);
      expect(backend.value, isNull);
    },
  );
}
