@TestOn('browser')
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/sso_client.dart';
import 'package:sso_admin/screens/forge/forge_sessions_gate.dart';
import 'package:sso_admin/services/forge_conversations_oauth.dart';
import 'package:sso_admin/services/forge_credential_store.dart';
import 'package:sso_admin/session.dart';
import 'package:web/web.dart' as web;

void main() {
  tearDown(Session.clear);

  testWidgets('Forge Web restores only its tab-scoped client credential', (
    tester,
  ) async {
    expect(
      Session.store('admin-token', clientId: SSOAdminClient.firstPartyClientId),
      isTrue,
    );
    expect(
      Session.storeForClient(
        ForgeConversationsOAuth.clientId,
        'forge-token',
        refreshToken: 'forge-refresh',
      ),
      isTrue,
    );

    const forgeTokenKey = 'sso_access_token:forge-console';
    expect(web.window.sessionStorage.getItem(forgeTokenKey), 'forge-token');
    expect(web.window.localStorage.getItem(forgeTokenKey), isNull);

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsGate(
          credentialStore: ForgeCredentialStore(forcePersistentStorage: false),
          testScreenBuilder: (token) => Text('Forge token: $token'),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Forge token: forge-token'), findsOneWidget);
    expect(Session.read(), 'admin-token');
    expect(
      Session.readRefreshTokenForClient(ForgeConversationsOAuth.clientId),
      'forge-refresh',
    );
  });
}
