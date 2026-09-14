import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../session.dart';
import 'forge_conversations_oauth.dart';
import 'forge_native_credential_platform.dart';

abstract interface class ForgeCredentialBackend {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

final class _SecureStorageForgeCredentialBackend
    implements ForgeCredentialBackend {
  const _SecureStorageForgeCredentialBackend();

  static const _storage = FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.unlocked_this_device,
    ),
  );

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// Persists only the Forge OAuth client slot on Android and iOS.
///
/// Web continues to use the existing tab-scoped `sessionStorage`; other
/// platforms retain process-only storage until their credential lifecycle is
/// explicitly supported. The native vault stores one versioned record so a
/// rotated access/refresh-token pair cannot be split across partial writes.
final class ForgeCredentialStore {
  static const _recordVersion = 1;
  static const _storageKey = 'forge.oauth.credentials.v1';

  final String clientId;
  final ForgeCredentialBackend _backend;
  final bool? _forcePersistentStorage;

  ForgeCredentialStore({
    this.clientId = ForgeConversationsOAuth.clientId,
    ForgeCredentialBackend? backend,
    @visibleForTesting bool? forcePersistentStorage,
  }) : _backend = backend ?? const _SecureStorageForgeCredentialBackend(),
       _forcePersistentStorage = forcePersistentStorage;

  bool get _usesPersistentStorage =>
      _forcePersistentStorage ??
      (!kIsWeb &&
          clientId == ForgeConversationsOAuth.clientId &&
          supportsSecureForgeCredentials);

  Future<bool> store({
    required String accessToken,
    String? sessionId,
    String? refreshToken,
  }) async {
    if (accessToken.isEmpty) {
      await clear();
      return false;
    }

    if (!_usesPersistentStorage) {
      return Session.storeForClient(
        clientId,
        accessToken,
        sessionId: sessionId,
        refreshToken: refreshToken,
      );
    }

    final record = jsonEncode({
      'version': _recordVersion,
      'client_id': clientId,
      'access_token': accessToken,
      'session_id': sessionId,
      'refresh_token': refreshToken,
    });
    try {
      await _backend.write(_storageKey, record);
      if (await _backend.read(_storageKey) != record) {
        throw StateError('Forge credentials did not persist.');
      }
      final cached = Session.storeForClient(
        clientId,
        accessToken,
        sessionId: sessionId,
        refreshToken: refreshToken,
      );
      if (!cached) throw StateError('Forge credentials could not be cached.');
      return true;
    } catch (_) {
      Session.clearForClient(clientId);
      await _deletePersistentRecordBestEffort();
      return false;
    }
  }

  /// Restores a cold-start native session into the in-memory client slot.
  /// Invalid or mismatched records are deleted and never used as credentials.
  Future<String?> restore() async {
    final inMemory = Session.readForClient(clientId);
    if (inMemory != null && inMemory.isNotEmpty) return inMemory;
    if (!_usesPersistentStorage) return inMemory;

    String? raw;
    try {
      raw = await _backend.read(_storageKey);
    } catch (_) {
      return null;
    }
    if (raw == null) return null;

    final record = _decodeRecord(raw);
    if (record == null) {
      await _deletePersistentRecordBestEffort();
      return null;
    }
    final cached = Session.storeForClient(
      clientId,
      record.accessToken,
      sessionId: record.sessionId,
      refreshToken: record.refreshToken,
    );
    if (!cached) {
      await _deletePersistentRecordBestEffort();
      return null;
    }
    return record.accessToken;
  }

  /// Clears the in-memory Forge slot first, then confirms native deletion.
  /// A storage error is propagated so sign-out cannot navigate back into a
  /// session that would be restored from a leftover credential record.
  Future<void> clear() async {
    Session.clearForClient(clientId);
    if (!_usesPersistentStorage) return;
    await _backend.delete(_storageKey);
    if (await _backend.read(_storageKey) != null) {
      throw StateError('Forge credentials remain in secure storage.');
    }
  }

  ForgeCredentialRecord? _decodeRecord(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final record = Map<String, dynamic>.from(decoded);
      final accessToken = record['access_token'];
      final refreshToken = record['refresh_token'];
      final sessionId = record['session_id'];
      if (record['version'] != _recordVersion ||
          record['client_id'] != clientId ||
          accessToken is! String ||
          !_isCredential(accessToken) ||
          (refreshToken != null &&
              (refreshToken is! String || !_isCredential(refreshToken))) ||
          (sessionId != null && sessionId is! String)) {
        return null;
      }
      return ForgeCredentialRecord(
        accessToken: accessToken,
        sessionId: sessionId is String && sessionId.isNotEmpty
            ? sessionId
            : null,
        refreshToken: refreshToken is String && refreshToken.isNotEmpty
            ? refreshToken
            : null,
      );
    } on FormatException {
      return null;
    } on TypeError {
      return null;
    }
  }

  bool _isCredential(String value) =>
      value.isNotEmpty &&
      value == value.trim() &&
      !value.contains(RegExp(r'[\r\n]'));

  Future<void> _deletePersistentRecordBestEffort() async {
    if (!_usesPersistentStorage) return;
    try {
      await _backend.delete(_storageKey);
    } catch (_) {
      // The active route still fails closed; a future restore validates again.
    }
  }
}

final class ForgeCredentialRecord {
  final String accessToken;
  final String? sessionId;
  final String? refreshToken;

  const ForgeCredentialRecord({
    required this.accessToken,
    required this.sessionId,
    required this.refreshToken,
  });
}
