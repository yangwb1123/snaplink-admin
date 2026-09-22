import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../session.dart';
import 'forge_conversations_oauth.dart';
import 'forge_native_credential_platform.dart';
import 'forge_refresh_lock.dart';

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
    mOptions: MacOsOptions(
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

/// Operations that may run while a [ForgeCredentialStore] refresh lock is
/// already held.
///
/// The scope is only valid for the duration of the callback passed to
/// [ForgeCredentialStore.withRefreshLock]. It exposes the credential-store
/// operations needed by the refresh exchange without trying to acquire the
/// same non-reentrant desktop file lock a second time.
final class ForgeCredentialStoreLockScope {
  ForgeCredentialStoreLockScope._(this._store);

  final ForgeCredentialStore _store;
  bool _active = true;

  void _close() => _active = false;

  void _ensureActive() {
    if (!_active) {
      throw StateError('Forge credential lock scope is no longer active.');
    }
  }

  Future<bool> store({
    required String accessToken,
    String? sessionId,
    String? refreshToken,
  }) {
    _ensureActive();
    return _store._storeUnlocked(
      accessToken: accessToken,
      sessionId: sessionId,
      refreshToken: refreshToken,
    );
  }

  Future<String?> reloadForRefresh() {
    _ensureActive();
    return _store._reloadForRefreshUnlocked();
  }

  Future<void> clear() {
    _ensureActive();
    return _store._clearUnlocked();
  }
}

/// Persists only the Forge OAuth client slot on Android, iOS, and desktop.
///
/// Web continues to use the existing tab-scoped `sessionStorage`; unsupported
/// native platforms fail closed rather than retaining a Forge bearer in
/// process memory. Native secure storage stores one versioned record so a
/// rotated access/refresh-token pair cannot be split across partial writes.
final class ForgeCredentialStore {
  static const _recordVersion = 1;
  // Keep the original key for the first-party Forge client so existing native
  // installs can restore their credentials after this client-slot hardening.
  static const _defaultStorageKey = 'forge.oauth.credentials.v1';

  final String clientId;
  final ForgeCredentialBackend _backend;
  final bool? _forcePersistentStorage;
  final bool? _forceSecureStorageSupport;
  final ForgeRefreshLock _refreshLock;

  ForgeCredentialStore({
    this.clientId = ForgeConversationsOAuth.clientId,
    ForgeCredentialBackend? backend,
    ForgeRefreshLock? refreshLock,
    @visibleForTesting bool? forcePersistentStorage,
    @visibleForTesting bool? forceSecureStorageSupport,
  }) : _backend = backend ?? const _SecureStorageForgeCredentialBackend(),
       _refreshLock =
           refreshLock ??
           (backend == null &&
                   forcePersistentStorage != false &&
                   (forceSecureStorageSupport ?? supportsSecureForgeCredentials)
               ? createForgeRefreshLock(clientId)
               : const NoopForgeRefreshLock()),
       _forcePersistentStorage = forcePersistentStorage,
       _forceSecureStorageSupport = forceSecureStorageSupport;

  bool get _secureStorageAvailable =>
      _forceSecureStorageSupport ?? supportsSecureForgeCredentials;

  bool get _unsupportedNativeForgeStorage =>
      _forcePersistentStorage == null &&
      !kIsWeb &&
      clientId == ForgeConversationsOAuth.clientId &&
      !_secureStorageAvailable;

  bool get _usesPersistentStorage =>
      _forcePersistentStorage ??
      (!kIsWeb &&
          clientId == ForgeConversationsOAuth.clientId &&
          _secureStorageAvailable);

  /// Derives a bounded secure-store key for each OAuth client slot.
  ///
  /// Client IDs are server-controlled input, but using them directly as a
  /// platform key would make key length/character limits platform-dependent.
  /// A digest also prevents one client from overwriting or clearing another
  /// client's native credential record. The legacy first-party key remains
  /// stable for migration compatibility.
  String get _storageKey => clientId == ForgeConversationsOAuth.clientId
      ? _defaultStorageKey
      : 'forge.oauth.credentials.v1.client-${sha256.convert(utf8.encode(clientId))}';

  Future<bool> store({
    required String accessToken,
    String? sessionId,
    String? refreshToken,
  }) => withRefreshLock(
    (lockedStore) => lockedStore.store(
      accessToken: accessToken,
      sessionId: sessionId,
      refreshToken: refreshToken,
    ),
  );

  Future<bool> _storeUnlocked({
    required String accessToken,
    String? sessionId,
    String? refreshToken,
  }) async {
    if (accessToken.isEmpty) {
      await _clearUnlocked();
      return false;
    }

    // A native Forge bearer must never be left only in process memory when
    // the platform secure store is unavailable. Tests may explicitly opt in
    // to volatile storage with forcePersistentStorage: false.
    if (_unsupportedNativeForgeStorage) {
      Session.clearForClient(clientId);
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
  Future<String?> restore() => _refreshLock.synchronized(_restoreUnlocked);

  Future<String?> _restoreUnlocked() async {
    if (_unsupportedNativeForgeStorage) {
      Session.clearForClient(clientId);
      return null;
    }
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

  /// Reloads the native record under the per-client refresh lock.
  ///
  /// A second desktop process can have rotated the refresh token since this
  /// process last populated [Session]. Reading the secure record again inside
  /// the inter-process lock lets that process reuse the newer access token
  /// instead of spending the old single-use refresh token. A missing record
  /// clears the in-memory slot so a stale bearer cannot be replayed after a
  /// concurrent sign-out or secure-store failure.
  Future<String?> reloadForRefresh() =>
      withRefreshLock((lockedStore) => lockedStore.reloadForRefresh());

  Future<String?> _reloadForRefreshUnlocked() async {
    if (_unsupportedNativeForgeStorage) {
      Session.clearForClient(clientId);
      return null;
    }
    final inMemory = Session.readForClient(clientId);
    if (!_usesPersistentStorage) return inMemory;

    String? raw;
    try {
      raw = await _backend.read(_storageKey);
    } catch (_) {
      // A failed secure-store read must not leave a stale bearer available to
      // the next API request.
      Session.clearForClient(clientId);
      return null;
    }
    if (raw == null) {
      Session.clearForClient(clientId);
      return null;
    }

    final record = _decodeRecord(raw);
    if (record == null) {
      Session.clearForClient(clientId);
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
      Session.clearForClient(clientId);
      await _deletePersistentRecordBestEffort();
      return null;
    }
    return record.accessToken;
  }

  /// Runs [action] while desktop processes coordinate refresh-token use.
  /// Web, mobile, unsupported platforms, and injected test backends use the
  /// no-op lock implementation. Use the callback's scope for credential
  /// reads/writes so the non-reentrant desktop lock is not acquired again.
  Future<T> withRefreshLock<T>(
    Future<T> Function(ForgeCredentialStoreLockScope lockedStore) action,
  ) => _refreshLock.synchronized(() async {
    final lockedStore = ForgeCredentialStoreLockScope._(this);
    try {
      return await action(lockedStore);
    } finally {
      lockedStore._close();
    }
  });

  /// Clears the in-memory Forge slot first, then confirms native deletion.
  /// A storage error is propagated so sign-out cannot navigate back into a
  /// session that would be restored from a leftover credential record.
  Future<void> clear() => withRefreshLock((lockedStore) => lockedStore.clear());

  Future<void> _clearUnlocked() async {
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
