import 'dart:async';

/// Lightweight response cache with request deduplication.
///
/// Features:
/// - Caches GET responses by `{method}:{path}` with configurable TTL
/// - Request deduplication: concurrent requests for the same URL
///   share a single HTTP call (subsequent callers await the first)
/// - Mutations invalidate related cache entries
class DataCache {
  /// Time-to-live for completed cached responses.
  final Duration ttl;

  /// Maximum number of completed GET responses retained.
  ///
  /// Zero disables completed-response storage while request deduplication
  /// remains available.
  final int maxEntries;

  final Map<String, _CacheEntry> _store = {};
  final Map<String, Completer<Map<String, dynamic>>> _pending = {};

  DataCache({this.ttl = const Duration(seconds: 10), int maxEntries = 128})
    : maxEntries = _validateMaxEntries(maxEntries);

  /// Read cached response. Returns null if missing or expired.
  Map<String, dynamic>? get(String method, String path) {
    if (method != 'GET') return null;
    final key = _key(method, path);
    final entry = _store.remove(key);
    if (entry == null) return null;
    if (DateTime.now().difference(entry.timestamp) > ttl) {
      return null;
    }
    // Re-insertion marks the entry as most recently used without changing its
    // timestamp, so a read refreshes recency but not TTL.
    _store[key] = entry;
    return entry.data;
  }

  /// Store response in cache.
  void set(String method, String path, Map<String, dynamic> data) {
    if (method != 'GET' || maxEntries == 0) return;
    final key = _key(method, path);
    // Replacing an entry must not evict a different, still-useful entry.
    _store.remove(key);
    while (_store.length >= maxEntries) {
      _store.remove(_store.keys.first);
    }
    _store[key] = _CacheEntry(data, DateTime.now());
  }

  /// Attempt to register a pending request.
  ///
  /// Returns `null` if caller should make the HTTP request (first caller).
  /// Returns a `Future` that completes when the first caller finishes.
  Future<Map<String, dynamic>>? registerOrGet(String method, String path) {
    if (method != 'GET') return null;
    final key = _key(method, path);
    final existing = _pending[key];
    if (existing != null) return existing.future; // Wait for first caller
    // First caller creates the shared completion. Install an error observer so
    // a failed request with no deduplicated waiters does not surface as an
    // unhandled asynchronous exception. Later waiters still receive the same
    // error from the original future.
    final completer = Completer<Map<String, dynamic>>();
    unawaited(completer.future.then<void>((_) {}, onError: (_, _) {}));
    _pending[key] = completer;
    return null; // Caller should make HTTP request
  }

  /// Resolve a pending request, notifying all waiters.
  void resolve(String method, String path, Map<String, dynamic> data) {
    if (method != 'GET') return;
    final key = _key(method, path);
    final completer = _pending.remove(key);
    if (completer != null && !completer.isCompleted) {
      completer.complete(data);
    }
  }

  /// Reject a pending request, notifying all waiters.
  void reject(
    String method,
    String path,
    Object error, [
    StackTrace? stackTrace,
  ]) {
    if (method != 'GET') return;
    final key = _key(method, path);
    final completer = _pending.remove(key);
    if (completer != null && !completer.isCompleted) {
      completer.completeError(error, stackTrace);
    }
  }

  /// Invalidate all cache entries matching [path] prefix.
  void invalidate(String path) {
    final normalized = path.split('?')[0];
    _store.removeWhere((key, _) {
      final cachedPath = (key.startsWith('GET:') ? key.substring(4) : key)
          .split('?')[0];
      return _pathsAreRelated(cachedPath, normalized);
    });
  }

  /// Clear all cached data and pending requests.
  void clear() {
    _store.clear();
    final error = StateError('Cache cleared while request was in flight.');
    for (final completer in _pending.values) {
      if (!completer.isCompleted) completer.completeError(error);
    }
    _pending.clear();
  }

  /// Number of cached responses.
  int get size => _store.length;

  /// Number of in-flight deduplicated requests.
  int get pendingCount => _pending.length;

  String _key(String method, String path) => '$method:$path';

  static int _validateMaxEntries(int value) {
    if (value < 0) {
      throw ArgumentError.value(value, 'maxEntries', 'must be non-negative');
    }
    return value;
  }

  static bool _pathsAreRelated(String left, String right) =>
      left == right ||
      left.startsWith('$right/') ||
      right.startsWith('$left/') ||
      left.startsWith('$right:') ||
      right.startsWith('$left:');
}

class _CacheEntry {
  final Map<String, dynamic> data;
  final DateTime timestamp;
  const _CacheEntry(this.data, this.timestamp);
}
