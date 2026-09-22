import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:sso_admin/api/forge_conversations_models.dart';
import 'package:sso_admin/services/forge_conversation_metadata_cache.dart';

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

  @override
  Future<void> remove(String key, [SharedPreferencesOptions? options]) async {
    values.remove(key);
  }
}

String _token(String subject) {
  String encode(Object value) =>
      base64Url.encode(utf8.encode(jsonEncode(value))).replaceAll('=', '');
  return '${encode({'alg': 'none'})}.${encode({'iss': 'https://issuer.example', 'tenant_id': 'tenant-1', 'sub': subject})}.signature';
}

ForgeOwnedConversation _conversation({
  String id = 'conversation-1',
  String title = 'Cached work',
  int version = 3,
}) => ForgeOwnedConversation(
  conversation: ForgeConversation(
    id: id,
    scope: const ForgeConversationScope(kind: 'global'),
    title: title,
    createdAtMS: 10,
    updatedAtMS: 20,
  ),
  aggregateVersion: version,
);

ForgeConversationMetadataCache _cache({
  String subject = 'owner-1',
  String origin = 'https://forge.example',
}) => ForgeConversationMetadataCache(
  accessToken: _token(subject),
  apiOrigin: origin,
  clientId: 'forge-console',
  resource: 'forge-api',
);

void main() {
  late _MemoryPreferences preferences;

  setUpAll(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  setUp(() {
    preferences = _MemoryPreferences();
    ForgeConversationMetadataCache.debugPreferencesOverride = preferences;
  });

  tearDown(() {
    ForgeConversationMetadataCache.debugPreferencesOverride = null;
  });

  test('stores only bounded owner-bound conversation metadata', () async {
    final cache = _cache();
    final token = _token('owner-1');
    expect(await cache.save([_conversation()]), isTrue);
    expect(preferences.values, hasLength(1));

    final raw = preferences.values.values.single;
    expect(raw, isNot(contains(token)));
    expect(raw, isNot(contains('owner-1')));
    final decoded = jsonDecode(raw) as Map<String, dynamic>;
    expect(decoded.keys.toSet(), {
      'version',
      'binding',
      'saved_at_ms',
      'conversations',
    });
    final entry = (decoded['conversations'] as List).single;
    expect(entry, {
      'conversation': {
        'id': 'conversation-1',
        'scope': {'kind': 'global'},
        'title': 'Cached work',
        'created_at_ms': 10,
        'updated_at_ms': 20,
      },
      'aggregate_version': 3,
    });
    expect(await cache.load(), isA<ForgeConversationMetadataSnapshot>());
    expect(await _cache(subject: 'owner-2').load(), isNull);
    expect(await _cache(origin: 'https://other.example').load(), isNull);
  });

  test(
    'rejects unknown fields, invalid binding, duplicate IDs, and oversize JSON',
    () async {
      final cache = _cache();
      expect(await cache.save([_conversation()]), isTrue);
      final key = preferences.values.keys.single;
      final original =
          jsonDecode(preferences.values[key]!) as Map<String, dynamic>;

      final unknownField = Map<String, dynamic>.from(original)
        ..['unexpected'] = true;
      preferences.values[key] = jsonEncode(unknownField);
      expect(await cache.load(), isNull);

      final wrongBinding = Map<String, dynamic>.from(original)
        ..['binding'] = 'wrong';
      preferences.values[key] = jsonEncode(wrongBinding);
      expect(await cache.load(), isNull);

      final duplicate = Map<String, dynamic>.from(original)
        ..['conversations'] = [
          ...(original['conversations'] as List),
          ...(original['conversations'] as List),
        ];
      preferences.values[key] = jsonEncode(duplicate);
      expect(await cache.load(), isNull);

      expect(
        await cache.save([
          _conversation(),
          _conversation(id: 'conversation-2', title: 'Second cached work'),
        ]),
        isTrue,
      );
      final ordered =
          jsonDecode(preferences.values[key]!) as Map<String, dynamic>;
      final rows = ordered['conversations'] as List;
      preferences.values[key] = jsonEncode({
        ...ordered,
        'conversations': rows.reversed.toList(growable: false),
      });
      expect(await cache.load(), isNull);

      preferences.values[key] = jsonEncode({
        'version': 1,
        'binding': original['binding'],
        'saved_at_ms': original['saved_at_ms'],
        'conversations': [
          {
            'conversation': {
              'id': 'conversation-1',
              'scope': {'kind': 'global'},
              'title': 'x' * (256 * 1024),
              'created_at_ms': 10,
              'updated_at_ms': 20,
            },
            'aggregate_version': 3,
          },
        ],
      });
      expect(await cache.load(), isNull);
    },
  );

  test('does not enable persistence for opaque access tokens', () async {
    final cache = ForgeConversationMetadataCache(
      accessToken: 'opaque-token',
      apiOrigin: 'https://forge.example',
      clientId: 'forge-console',
      resource: 'forge-api',
    );
    expect(await cache.save([_conversation()]), isFalse);
    expect(await cache.load(), isNull);
    expect(preferences.values, isEmpty);
  });
}
