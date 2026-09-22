import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sso_admin/services/forge_run_timeline_cursor_store.dart';

String _token({
  String issuer = 'https://issuer.example',
  String tenant = 'tenant-1',
  String subject = 'user-1',
}) {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${encode({'alg': 'none'})}.${encode({'iss': issuer, 'tenant_id': tenant, 'sub': subject})}.signature';
}

ForgeRunTimelineCursorStore _store({
  String token = '',
  String apiOrigin = 'https://forge.example',
  String clientId = 'forge-console',
  String resource = 'forge-api',
  String conversationID = 'conversation-1',
  String runID = 'run-1',
}) => ForgeRunTimelineCursorStore(
  accessToken: token.isEmpty ? _token() : token,
  apiOrigin: apiOrigin,
  clientId: clientId,
  resource: resource,
  conversationID: conversationID,
  runID: runID,
);

class _MemoryPreferences extends SharedPreferencesAsync {
  final Map<String, String> values = {};

  @override
  Future<String?> getString(
    String key, [
    SharedPreferencesOptions? options,
  ]) async => values[key];

  @override
  Future<void> setString(
    String key,
    String value, [
    SharedPreferencesOptions? options,
  ]) async {
    values[key] = value;
  }
}

void main() {
  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  test(
    'partitions checkpoints by owner, coordinator, client, Conversation, and Run',
    () async {
      final original = _store();
      expect(await original.save(17), isTrue);
      expect(await _store(apiOrigin: 'https://forge.example/').load(), 17);
      expect(await _store(token: _token(subject: 'user-2')).load(), 0);
      expect(await _store(token: _token(tenant: 'tenant-2')).load(), 0);
      expect(await _store(apiOrigin: 'https://other.example').load(), 0);
      expect(await _store(clientId: 'another-client').load(), 0);
      expect(await _store(resource: 'another-resource').load(), 0);
      expect(await _store(conversationID: 'conversation-2').load(), 0);
      expect(await _store(runID: 'run-2').load(), 0);

      expect(await original.save(12), isFalse);
      expect(await original.load(), 17);
    },
  );

  test('serializes concurrent writes for one Run', () async {
    final store = _store(token: _token(subject: 'concurrent-writer'));
    final results = await Future.wait([store.save(100), store.save(50)]);

    expect(results, [true, false]);
    expect(await store.load(), 100);
  });

  test(
    'rejects opaque tokens, invalid IDs, and out-of-range cursors',
    () async {
      expect(await _store(token: 'not-a-jwt').save(1), isFalse);
      expect(await _store(conversationID: 'bad/id').save(1), isFalse);
      expect(await _store(runID: 'bad\nrun').save(1), isFalse);

      final valid = _store(token: _token(subject: 'range-boundary-user'));
      expect(await valid.save(-1), isFalse);
      expect(await valid.save(9007199254740992), isFalse);
      expect(await valid.load(), 0);
    },
  );

  test('checkpoint value never stores bearer token or owner claims', () async {
    final preferences = _MemoryPreferences();
    ForgeRunTimelineCursorStore.debugPreferencesOverride = preferences;
    addTearDown(
      () => ForgeRunTimelineCursorStore.debugPreferencesOverride = null,
    );
    final token = _token(subject: 'private-owner-claim');

    expect(await _store(token: token).save(7), isTrue);
    expect(preferences.values, hasLength(1));
    final encoded = preferences.values.values.single;
    expect(encoded, isNot(contains(token)));
    expect(encoded, isNot(contains('private-owner-claim')));
    expect(jsonDecode(encoded), {
      'version': 1,
      'binding': isA<String>(),
      'cursor': 7,
    });
  });
}
