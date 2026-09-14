import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:shared_preferences/shared_preferences.dart';

import 'forge_conversations_api_origin.dart';
import 'forge_cursor_write_lock.dart';
import 'local_storage.dart';

/// Persists only the owner-local replay cursor. The bearer token is inspected
/// to partition this non-authoritative cache, then discarded; it is never
/// written to either storage backend.
class ForgeChangeCursorStore {
  static const _keyPrefix = 'forge_conversation_changes_v1:';
  static const _maximumJsonBytes = 512;
  static const _maximumSafeInteger = 9007199254740991;
  static SharedPreferencesAsync? debugPreferencesOverride;

  late final String? _key;
  late final String? _binding;

  ForgeChangeCursorStore({
    required String accessToken,
    required String apiOrigin,
    required String clientId,
    required String resource,
  }) {
    final binding = _checkpointBinding(
      accessToken: accessToken,
      apiOrigin: apiOrigin,
      clientId: clientId,
      resource: resource,
    );
    _key = binding.$1;
    _binding = binding.$2;
  }

  Future<int> load() async {
    final key = _key;
    final binding = _binding;
    if (key == null || binding == null) return 0;
    try {
      final raw = await _read(key);
      if (raw == null || raw.length > _maximumJsonBytes) return 0;
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic> ||
          decoded.length != 3 ||
          decoded['version'] != 1 ||
          decoded['binding'] != binding ||
          decoded['cursor'] is! int) {
        return 0;
      }
      final cursor = decoded['cursor'] as int;
      return cursor >= 0 && cursor <= _maximumSafeInteger ? cursor : 0;
    } catch (_) {
      return 0;
    }
  }

  Future<bool> save(int cursor) async {
    final key = _key;
    final binding = _binding;
    if (key == null ||
        binding == null ||
        cursor < 0 ||
        cursor > _maximumSafeInteger) {
      return false;
    }
    final value = jsonEncode({
      'version': 1,
      'binding': binding,
      'cursor': cursor,
    });
    var wrote = false;
    try {
      Future<void> writeIfCurrent() async {
        if (cursor < await load()) return;
        wrote = true;
        if (kIsWeb) {
          LocalStorage.setItem(key, value);
        } else {
          await _preferences().setString(key, value);
        }
      }

      await withForgeCursorWriteLock(key, writeIfCurrent);
      return wrote && await _read(key) == value;
    } catch (_) {
      return false;
    }
  }

  static (String?, String?) _checkpointBinding({
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
                'forge-conversation-change-checkpoint-v1',
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
            (value) =>
                value.trim() != value ||
                value.contains(RegExp(r'[\x00-\x1f\x7f]')),
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
    return await _preferences().getString(key);
  }

  static SharedPreferencesAsync _preferences() =>
      debugPreferencesOverride ?? SharedPreferencesAsync();
}

class _ForgeTokenIdentity {
  final String issuer;
  final String tenant;
  final String subject;

  const _ForgeTokenIdentity(this.issuer, this.tenant, this.subject);
}
