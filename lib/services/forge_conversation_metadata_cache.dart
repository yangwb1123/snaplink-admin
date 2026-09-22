import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb, visibleForTesting;
import 'package:shared_preferences/shared_preferences.dart';

import '../api/forge_conversations_models.dart';
import 'forge_conversations_api_origin.dart';
import 'forge_cursor_write_lock.dart';
import 'local_storage.dart';

/// A bounded, owner-partitioned cache of Forge conversation list metadata.
///
/// The cache deliberately excludes prompts, runs, bearer tokens, and owner
/// claims. A JWT is used only to derive an opaque owner binding; opaque tokens
/// cannot establish a safe owner partition and therefore do not enable the
/// cache.
final class ForgeConversationMetadataCache {
  static const _keyPrefix = 'forge_conversation_metadata_v1:';
  static const _recordVersion = 1;
  static const _maximumJsonBytes = 256 * 1024;
  static const _maximumConversationCount = 128;
  static const _maximumConversationTitleBytes = 4096;
  static const _maximumSafeInteger = 9007199254740991;

  /// Test-only native preference injection. Production callers use the
  /// platform's asynchronous shared-preferences backend.
  @visibleForTesting
  static SharedPreferencesAsync? debugPreferencesOverride;

  late final String? _key;
  late final String? _binding;

  ForgeConversationMetadataCache({
    required String accessToken,
    required String apiOrigin,
    required String clientId,
    required String resource,
  }) {
    final binding = _cacheBinding(
      accessToken: accessToken,
      apiOrigin: apiOrigin,
      clientId: clientId,
      resource: resource,
    );
    _key = binding.$1;
    _binding = binding.$2;
  }

  /// Returns the last successful snapshot, or null when no valid snapshot is
  /// available for this exact Forge authority/client/resource/owner tuple.
  Future<ForgeConversationMetadataSnapshot?> load() async {
    final key = _key;
    final binding = _binding;
    if (key == null || binding == null) return null;

    try {
      final raw = await _read(key);
      if (raw == null || utf8.encode(raw).length > _maximumJsonBytes) {
        return null;
      }
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> ||
          decoded.length != 4 ||
          decoded['version'] != _recordVersion ||
          decoded['binding'] != binding ||
          decoded['saved_at_ms'] is! int ||
          decoded['conversations'] is! List) {
        return null;
      }

      final savedAtMS = decoded['saved_at_ms'] as int;
      final rawConversations = decoded['conversations'] as List;
      if (savedAtMS < 0 ||
          savedAtMS > _maximumSafeInteger ||
          rawConversations.length > _maximumConversationCount) {
        return null;
      }

      final conversations = <ForgeOwnedConversation>[];
      final conversationIDs = <String>{};
      String? previousID;
      for (final value in rawConversations) {
        if (value is! Map) return null;
        final conversation = ForgeOwnedConversation.fromJson(
          Map<String, dynamic>.from(value),
        );
        if (!_validCacheConversation(conversation) ||
            !conversationIDs.add(conversation.conversation.id) ||
            (previousID != null &&
                _compareCodePoints(previousID, conversation.conversation.id) >=
                    0)) {
          return null;
        }
        previousID = conversation.conversation.id;
        conversations.add(conversation);
      }
      return ForgeConversationMetadataSnapshot(
        conversations: List.unmodifiable(conversations),
        savedAtMS: savedAtMS,
      );
    } catch (_) {
      // Cache data is non-authoritative. Any malformed or unavailable record
      // is ignored and the caller remains on the network/error path.
      return null;
    }
  }

  /// Replaces the owner-bound snapshot. The encoded record contains only
  /// bounded conversation metadata and is verified after the write.
  Future<bool> save(List<ForgeOwnedConversation> conversations) async {
    final key = _key;
    final binding = _binding;
    if (key == null ||
        binding == null ||
        conversations.length > _maximumConversationCount) {
      return false;
    }

    final conversationIDs = <String>{};
    final encodedConversations = <Map<String, dynamic>>[];
    String? previousID;
    for (final conversation in conversations) {
      if (!_validCacheConversation(conversation) ||
          !conversationIDs.add(conversation.conversation.id) ||
          (previousID != null &&
              _compareCodePoints(previousID, conversation.conversation.id) >=
                  0)) {
        return false;
      }
      previousID = conversation.conversation.id;
      encodedConversations.add(_conversationToJson(conversation));
    }

    final value = jsonEncode({
      'version': _recordVersion,
      'binding': binding,
      'saved_at_ms': DateTime.now().millisecondsSinceEpoch,
      'conversations': encodedConversations,
    });
    if (utf8.encode(value).length > _maximumJsonBytes) return false;

    var verified = false;
    try {
      await withForgeCursorWriteLock(key, () async {
        await _write(key, value);
        verified = await _read(key) == value;
      });
      return verified;
    } catch (_) {
      return false;
    }
  }

  /// Removes this owner's metadata snapshot. Cache cleanup never affects the
  /// active session or credentials.
  Future<void> clear() async {
    final key = _key;
    if (key == null) return;
    try {
      await withForgeCursorWriteLock(key, () async {
        if (kIsWeb) {
          LocalStorage.removeItem(key);
        } else {
          await _preferences().remove(key);
        }
      });
    } catch (_) {
      // Best effort: a future load still validates binding and fields.
    }
  }

  static Map<String, dynamic> _conversationToJson(
    ForgeOwnedConversation owned,
  ) {
    final conversation = owned.conversation;
    final scope = conversation.scope;
    return {
      'conversation': {
        'id': conversation.id,
        'scope': {'kind': scope.kind, if (scope.id != null) 'id': scope.id},
        'title': conversation.title,
        'created_at_ms': conversation.createdAtMS,
        'updated_at_ms': conversation.updatedAtMS,
      },
      'aggregate_version': owned.aggregateVersion,
    };
  }

  static bool _validCacheConversation(ForgeOwnedConversation owned) {
    final conversation = owned.conversation;
    final scope = conversation.scope;
    final titleBytes = utf8.encode(conversation.title).length;
    return _validConversationID(conversation.id) &&
        conversation.title.trim().isNotEmpty &&
        titleBytes <= _maximumConversationTitleBytes &&
        !_containsControlRune(conversation.title) &&
        conversation.createdAtMS >= 0 &&
        conversation.createdAtMS <= _maximumSafeInteger &&
        conversation.updatedAtMS >= 0 &&
        conversation.updatedAtMS <= _maximumSafeInteger &&
        owned.aggregateVersion > 0 &&
        owned.aggregateVersion <= _maximumSafeInteger &&
        _validScope(scope);
  }

  static bool _validScope(ForgeConversationScope scope) {
    switch (scope.kind) {
      case 'global':
        return scope.id == null;
      case 'project':
      case 'group':
        return scope.id != null && _validConversationID(scope.id!);
      default:
        return false;
    }
  }

  static bool _validConversationID(String value) =>
      value.trim().isNotEmpty &&
      utf8.encode(value).length <= 128 &&
      !value.contains('/') &&
      !_containsControlRune(value);

  static int _compareCodePoints(String left, String right) {
    final leftRunes = left.runes.toList(growable: false);
    final rightRunes = right.runes.toList(growable: false);
    final sharedLength = leftRunes.length < rightRunes.length
        ? leftRunes.length
        : rightRunes.length;
    for (var index = 0; index < sharedLength; index++) {
      final comparison = leftRunes[index].compareTo(rightRunes[index]);
      if (comparison != 0) return comparison;
    }
    return leftRunes.length.compareTo(rightRunes.length);
  }

  static bool _containsControlRune(String value) =>
      value.runes.any((rune) => rune < 0x20 || (rune >= 0x7f && rune <= 0x9f));

  static (String?, String?) _cacheBinding({
    required String accessToken,
    required String apiOrigin,
    required String clientId,
    required String resource,
  }) {
    final identity = _jwtIdentity(accessToken);
    if (identity == null || clientId.isEmpty || resource.isEmpty) {
      return (null, null);
    }
    try {
      final normalizedOrigin = ForgeConversationsApiOrigin.normalizeOrigin(
        apiOrigin,
      );
      final binding = sha256
          .convert(
            utf8.encode(
              jsonEncode([
                'forge-conversation-metadata-v1',
                normalizedOrigin,
                clientId,
                resource,
                identity.issuer,
                identity.tenant,
                identity.subject,
              ]),
            ),
          )
          .toString();
      return ('$_keyPrefix$binding', binding);
    } on FormatException {
      return (null, null);
    }
  }

  static _ForgeTokenIdentity? _jwtIdentity(String token) {
    if (token.length > 64 * 1024) return null;
    final parts = token.split('.');
    if (parts.length != 3 || parts[1].isEmpty) return null;
    try {
      final payload = jsonDecode(
        utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
      );
      if (payload is! Map<String, dynamic>) return null;
      final issuer = payload['iss'];
      final tenant = payload['tenant_id'];
      final subject = payload['sub'];
      if (issuer is! String ||
          issuer.isEmpty ||
          issuer.length > 2048 ||
          tenant is! String ||
          tenant.isEmpty ||
          tenant.length > 256 ||
          subject is! String ||
          subject.isEmpty ||
          subject.length > 255 ||
          [issuer, tenant, subject].any(
            (value) => value.trim() != value || _containsControlRune(value),
          )) {
        return null;
      }
      return _ForgeTokenIdentity(issuer, tenant, subject);
    } catch (_) {
      return null;
    }
  }

  static Future<String?> _read(String key) async {
    if (kIsWeb) return LocalStorage.getItem(key);
    return _preferences().getString(key);
  }

  static Future<void> _write(String key, String value) async {
    if (kIsWeb) {
      LocalStorage.setItem(key, value);
      return;
    }
    await _preferences().setString(key, value);
  }

  static SharedPreferencesAsync _preferences() =>
      debugPreferencesOverride ?? SharedPreferencesAsync();
}

final class ForgeConversationMetadataSnapshot {
  final List<ForgeOwnedConversation> conversations;
  final int savedAtMS;

  const ForgeConversationMetadataSnapshot({
    required this.conversations,
    required this.savedAtMS,
  });
}

class _ForgeTokenIdentity {
  final String issuer;
  final String tenant;
  final String subject;

  const _ForgeTokenIdentity(this.issuer, this.tenant, this.subject);
}
