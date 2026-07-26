import 'dart:async';

/// Lightweight response cache with request deduplication.
///
/// Features:
/// - Caches GET responses by `{method}:{path}` with configurable TTL
/// - Request deduplication: concurrent requests for the same URL
///   share a single HTTP call (subsequent callers await the first)
/// - Mutations invalidate related cache entries
class DataCache {
  final Duration ttl;
  final Map<String, _CacheEntry> _store = {};
  final Map<String, Completer<Map<String, dynamic>>> _pending = {};

  DataCache({this.ttl = const Duration(seconds: 10)});

  /// Read cached response. Returns null if missing or expired.
  Map<String, dynamic>? get(String method, String path) {
    if (method != 'GET') return null;
    final key = _key(method, path);
    final entry = _store[key];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.timestamp) > ttl) {
      _store.remove(key);
      return null;
    }
    return entry.data;
  }

  /// Store response in cache.
  void set(String method, String path, Map<String, dynamic> data) {
    if (method != 'GET') return;
    _store[_key(method, path)] = _CacheEntry(data, DateTime.now());
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
    // First caller - create completer
    _pending[key] = Completer<Map<String, dynamic>>();
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
  void reject(String method, String path, Object error,
      [StackTrace? stackTrace]) {
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
    _store.removeWhere((key, _) => key.contains(normalized));
  }

  /// Clear all cached data and pending requests.
  void clear() {
    _store.clear();
    _pending.clear();
  }

  /// Number of cached responses.
  int get size => _store.length;

  /// Number of in-flight deduplicated requests.
  int get pendingCount => _pending.length;

  String _key(String method, String path) => '$method:$path';
}

class _CacheEntry {
  final Map<String, dynamic> data;
  final DateTime timestamp;
  const _CacheEntry(this.data, this.timestamp);
}
