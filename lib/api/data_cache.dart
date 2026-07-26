/// Lightweight response cache for SnaplinkAdminApi.
///
/// Caches GET responses by `{method}:{path}` with a configurable TTL.
/// Mutations (POST, PUT, PATCH, DELETE) automatically invalidate
/// entries whose path prefix matches the mutation target.
///
/// Thread-safe for Flutter's single-threaded event loop.
class DataCache {
  final Duration ttl;
  final Map<String, _CacheEntry> _store = {};

  DataCache({this.ttl = const Duration(seconds: 10)});

  /// Read a cached response. Returns null if missing or expired.
  Map<String, dynamic>? get(String method, String path) {
    final key = _key(method, path);
    final entry = _store[key];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.timestamp) > ttl) {
      _store.remove(key);
      return null;
    }
    return entry.data;
  }

  /// Store a response in the cache.
  void set(String method, String path, Map<String, dynamic> data) {
    if (method != 'GET') return; // Only cache GET responses
    _store[_key(method, path)] = _CacheEntry(data, DateTime.now());
  }

  /// Invalidate all cache entries whose key matches [path].
  /// Called automatically on POST, PUT, PATCH, DELETE.
  void invalidate(String path) {
    final normalized = path.split('?')[0]; // Strip query params
    _store.removeWhere((key, _) => key.contains(normalized));
  }

  /// Clear the entire cache.
  void clear() => _store.clear();

  /// Current number of cached entries.
  int get size => _store.length;

  String _key(String method, String path) => '$method:$path';
}

class _CacheEntry {
  final Map<String, dynamic> data;
  final DateTime timestamp;
  const _CacheEntry(this.data, this.timestamp);
}
