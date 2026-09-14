import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/sso_client.dart';
import 'package:sso_admin/screens/forge/forge_sessions_gate.dart';
import 'package:sso_admin/services/forge_conversations_oauth.dart';
import 'package:sso_admin/services/forge_credential_store.dart';
import 'package:sso_admin/session.dart';

import 'support/memory_forge_credential_backend.dart';

String _credentialRecord({
  String clientId = ForgeConversationsOAuth.clientId,
  String accessToken = 'restored-access',
  String? refreshToken = 'restored-refresh',
}) => jsonEncode({
  'version': 1,
  'client_id': clientId,
  'access_token': accessToken,
  'session_id': 'forge-session',
  'refresh_token': refreshToken,
});

void main() {
  setUp(() => Session.clear());
  tearDown(() => Session.clear());

  test(
    'stores before mirroring and restores a cold-start Forge session',
    () async {
      final backend = MemoryForgeCredentialBackend();
      final writeBarrier = Completer<void>();
      backend.writeBarrier = writeBarrier.future;
      final store = ForgeCredentialStore(
        backend: backend,
        forcePersistentStorage: true,
      );
      Session.store(
        'admin-access',
        clientId: SSOAdminClient.firstPartyClientId,
      );

      final pendingStore = store.store(
        accessToken: 'forge-access',
        sessionId: 'forge-session',
        refreshToken: 'forge-refresh',
      );
      await Future<void>.delayed(Duration.zero);
      expect(Session.readForClient(ForgeConversationsOAuth.clientId), isNull);

      writeBarrier.complete();
      expect(await pendingStore, isTrue);
      expect(
        Session.readForClient(ForgeConversationsOAuth.clientId),
        'forge-access',
      );
      expect(Session.read(), 'admin-access');
      expect(jsonDecode(backend.value!)['refresh_token'], 'forge-refresh');

      Session.clearForClient(ForgeConversationsOAuth.clientId);
      expect(await store.restore(), 'forge-access');
      expect(
        Session.readRefreshTokenForClient(ForgeConversationsOAuth.clientId),
        'forge-refresh',
      );
      expect(Session.read(), 'admin-access');
    },
  );

  test(
    'rejects and deletes records bound to a different OAuth client',
    () async {
      final backend = MemoryForgeCredentialBackend()
        ..value = _credentialRecord(clientId: 'another-oauth-client');
      final store = ForgeCredentialStore(
        backend: backend,
        forcePersistentStorage: true,
      );

      expect(await store.restore(), isNull);
      expect(backend.value, isNull);
      expect(Session.readForClient(ForgeConversationsOAuth.clientId), isNull);
    },
  );

  test(
    'native sign-out clears Forge storage but preserves Admin session',
    () async {
      final backend = MemoryForgeCredentialBackend();
      final store = ForgeCredentialStore(
        backend: backend,
        forcePersistentStorage: true,
      );
      Session.store(
        'admin-access',
        clientId: SSOAdminClient.firstPartyClientId,
      );
      expect(
        await store.store(
          accessToken: 'forge-access',
          refreshToken: 'forge-refresh',
        ),
        isTrue,
      );

      await store.clear();

      expect(backend.value, isNull);
      expect(Session.readForClient(ForgeConversationsOAuth.clientId), isNull);
      expect(Session.read(), 'admin-access');
    },
  );

  testWidgets('Forge gate waits for and hydrates a cold-start secure record', (
    tester,
  ) async {
    final backend = MemoryForgeCredentialBackend()..value = _credentialRecord();
    final readBarrier = Completer<void>();
    backend.readBarrier = readBarrier.future;
    final store = ForgeCredentialStore(
      backend: backend,
      forcePersistentStorage: true,
    );
    Session.store('admin-access', clientId: SSOAdminClient.firstPartyClientId);

    await tester.pumpWidget(
      MaterialApp(
        home: ForgeSessionsGate(
          credentialStore: store,
          testScreenBuilder: (token) => Text('ready:$token'),
        ),
      ),
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('ready:restored-access'), findsNothing);

    readBarrier.complete();
    await tester.pumpAndSettle();

    expect(find.text('ready:restored-access'), findsOneWidget);
    expect(
      Session.readForClient(ForgeConversationsOAuth.clientId),
      'restored-access',
    );
    expect(Session.read(), 'admin-access');
  });
}
