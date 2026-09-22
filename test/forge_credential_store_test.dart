import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/sso_client.dart';
import 'package:sso_admin/screens/forge/forge_sessions_gate.dart';
import 'package:sso_admin/services/forge_conversations_oauth.dart';
import 'package:sso_admin/services/forge_credential_store.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/session.dart';

import 'support/memory_forge_credential_backend.dart';
import 'support/memory_forge_refresh_lock.dart';

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

final class _MapForgeCredentialBackend implements ForgeCredentialBackend {
  final values = <String, String>{};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

void main() {
  setUp(() {
    BrowserNavigation.resetForTest();
    Session.clear();
  });
  tearDown(() {
    BrowserNavigation.resetForTest();
    Session.clear();
  });

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
    'isolates native records, restore, and clear by OAuth client slot',
    () async {
      final backend = _MapForgeCredentialBackend();
      final first = ForgeCredentialStore(
        clientId: 'forge-client-a',
        backend: backend,
        forcePersistentStorage: true,
      );
      final second = ForgeCredentialStore(
        clientId: 'forge-client-b',
        backend: backend,
        forcePersistentStorage: true,
      );

      expect(
        await first.store(accessToken: 'access-a', refreshToken: 'refresh-a'),
        isTrue,
      );
      expect(
        await second.store(accessToken: 'access-b', refreshToken: 'refresh-b'),
        isTrue,
      );
      expect(backend.values, hasLength(2));

      Session.clearForClient('forge-client-a');
      Session.clearForClient('forge-client-b');
      expect(await first.restore(), 'access-a');
      expect(await second.restore(), 'access-b');
      expect(Session.readRefreshTokenForClient('forge-client-a'), 'refresh-a');
      expect(Session.readRefreshTokenForClient('forge-client-b'), 'refresh-b');

      await first.clear();
      expect(backend.values, hasLength(1));
      expect(await first.restore(), isNull);
      expect(await second.restore(), 'access-b');
      expect(Session.readForClient('forge-client-a'), isNull);
      expect(Session.readForClient('forge-client-b'), 'access-b');
    },
  );

  test('fails closed for an unsupported native Forge secure store', () async {
    final store = ForgeCredentialStore(forceSecureStorageSupport: false);

    expect(
      await store.store(
        accessToken: 'forge-access',
        refreshToken: 'forge-refresh',
      ),
      isFalse,
    );
    expect(Session.readForClient(ForgeConversationsOAuth.clientId), isNull);
    expect(await store.restore(), isNull);
  });

  test('reload clears stale memory when secure-store read fails', () async {
    final backend = MemoryForgeCredentialBackend()
      ..value = _credentialRecord(accessToken: 'stored-access')
      ..failRead = true;
    final store = ForgeCredentialStore(
      backend: backend,
      forcePersistentStorage: true,
    );
    Session.storeForClient(
      ForgeConversationsOAuth.clientId,
      'stale-access',
      refreshToken: 'stale-refresh',
    );

    expect(await store.reloadForRefresh(), isNull);
    expect(Session.readForClient(ForgeConversationsOAuth.clientId), isNull);
    expect(
      Session.readRefreshTokenForClient(ForgeConversationsOAuth.clientId),
      isNull,
    );
  });

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

  test('credential writes wait behind an active refresh lock', () async {
    final backend = MemoryForgeCredentialBackend();
    final lock = MemoryForgeRefreshLock();
    final store = ForgeCredentialStore(
      backend: backend,
      forcePersistentStorage: true,
      refreshLock: lock,
    );
    final release = Completer<void>();
    final held = store.withRefreshLock<void>((_) => release.future);

    await Future<void>.delayed(Duration.zero);
    expect(lock.active, 1);

    final pendingStore = store.store(
      accessToken: 'login-access',
      refreshToken: 'login-refresh',
    );
    await Future<void>.delayed(Duration.zero);
    expect(lock.acquisitions, 1);
    expect(backend.value, isNull);
    expect(Session.readForClient(ForgeConversationsOAuth.clientId), isNull);

    release.complete();
    await held;
    expect(await pendingStore, isTrue);
    expect(lock.maxActive, 1);
    expect(
      (jsonDecode(backend.value!) as Map<String, dynamic>)['access_token'],
      'login-access',
    );
  });

  test('refresh lock serializes actions and releases after failure', () async {
    final lock = MemoryForgeRefreshLock();
    final firstRelease = Completer<void>();
    var secondStarted = false;
    final first = lock.synchronized(() async {
      await firstRelease.future;
      return 'first';
    });
    final second = lock.synchronized(() async {
      secondStarted = true;
      return 'second';
    });

    await Future<void>.delayed(Duration.zero);
    expect(lock.active, 1);
    expect(lock.maxActive, 1);
    expect(secondStarted, isFalse);

    firstRelease.complete();
    expect(await first, 'first');
    expect(await second, 'second');
    expect(lock.active, 0);
    expect(lock.maxActive, 1);
  });

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

  testWidgets(
    'Forge gate uses a same-document deep link that changes during restore',
    (tester) async {
      final backend = MemoryForgeCredentialBackend()
        ..value = _credentialRecord();
      final readBarrier = Completer<void>();
      backend.readBarrier = readBarrier.future;
      final store = ForgeCredentialStore(
        backend: backend,
        forcePersistentStorage: true,
      );
      Session.store(
        'admin-access',
        clientId: SSOAdminClient.firstPartyClientId,
      );
      String? restoredConversationID;

      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsGate(
            credentialStore: store,
            initialConversationID: 'stale-from-entry',
            testScreenBuilderWithRoute: (token, conversationID) {
              restoredConversationID = conversationID;
              return Text('ready:$token');
            },
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      BrowserNavigation.pushState('/forge/conversations/current-link');
      readBarrier.complete();
      await tester.pumpAndSettle();

      expect(restoredConversationID, 'current-link');
      expect(find.text('ready:restored-access'), findsOneWidget);
    },
  );

  testWidgets(
    'Forge gate clears an entry deep link when restore returns to Forge root',
    (tester) async {
      final backend = MemoryForgeCredentialBackend()
        ..value = _credentialRecord();
      final readBarrier = Completer<void>();
      backend.readBarrier = readBarrier.future;
      final store = ForgeCredentialStore(
        backend: backend,
        forcePersistentStorage: true,
      );
      Session.store(
        'admin-access',
        clientId: SSOAdminClient.firstPartyClientId,
      );
      String? restoredConversationID = 'stale';

      await tester.pumpWidget(
        MaterialApp(
          home: ForgeSessionsGate(
            credentialStore: store,
            initialConversationID: 'stale-from-entry',
            testScreenBuilderWithRoute: (token, conversationID) {
              restoredConversationID = conversationID;
              return Text('ready:$token');
            },
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      BrowserNavigation.replaceState('/forge');
      readBarrier.complete();
      await tester.pumpAndSettle();

      expect(restoredConversationID, isNull);
      expect(find.text('ready:restored-access'), findsOneWidget);
    },
  );
}
