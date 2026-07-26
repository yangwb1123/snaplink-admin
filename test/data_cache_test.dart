import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/data_cache.dart';

void main() {
  group('DataCache basic operations', () {
    test('stores and retrieves data', () {
      final cache = DataCache(ttl: const Duration(seconds: 30));
      cache.set('GET', '/api/v1/admin/clients', {'key': 'value'});
      final result = cache.get('GET', '/api/v1/admin/clients');
      expect(result, isNotNull);
      expect(result!['key'], 'value');
    });

    test('returns null for uncached data', () {
      final cache = DataCache();
      final result = cache.get('GET', '/api/v1/admin/unknown');
      expect(result, isNull);
    });

    test('only caches GET requests', () {
      final cache = DataCache();
      cache.set('POST', '/api/v1/admin/clients', {'created': true});
      final result = cache.get('POST', '/api/v1/admin/clients');
      expect(result, isNull);
    });

    test('expires after TTL', () async {
      final cache = DataCache(ttl: const Duration(milliseconds: 50));
      cache.set('GET', '/api/v1/admin/clients', {'clients': []});
      expect(cache.get('GET', '/api/v1/admin/clients'), isNotNull);
      await Future.delayed(const Duration(milliseconds: 100));
      expect(cache.get('GET', '/api/v1/admin/clients'), isNull);
    });

    test('clear removes all entries', () {
      final cache = DataCache();
      cache.set('GET', '/api/v1/admin/clients', {'a': 1});
      cache.set('GET', '/api/v1/admin/users', {'b': 2});
      expect(cache.size, 2);
      cache.clear();
      expect(cache.size, 0);
    });

    test('size tracking', () {
      final cache = DataCache();
      expect(cache.size, 0);
      cache.set('GET', '/api/v1/admin/clients', {});
      expect(cache.size, 1);
    });
  });

  group('DataCache invalidation', () {
    test('invalidates matching entries', () {
      final cache = DataCache();
      cache.set('GET', '/api/v1/admin/clients', {'clients': []});
      cache.set('GET', '/api/v1/admin/clients/client-abc', {'id': 'abc'});
      cache.invalidate('/api/v1/admin/clients');
      expect(cache.get('GET', '/api/v1/admin/clients'), isNull);
      expect(cache.get('GET', '/api/v1/admin/clients/client-abc'), isNull);
    });

    test('does not invalidate unrelated entries', () {
      final cache = DataCache();
      cache.set('GET', '/api/v1/admin/clients', {'clients': []});
      cache.set('GET', '/api/v1/admin/users', {'users': []});
      cache.invalidate('/api/v1/admin/clients');
      expect(cache.get('GET', '/api/v1/admin/clients'), isNull);
      expect(cache.get('GET', '/api/v1/admin/users'), isNotNull);
    });

    test('strips query params for invalidation', () {
      final cache = DataCache();
      cache.set('GET', '/api/v1/admin/clients?page=1', {});
      cache.invalidate('/api/v1/admin/clients?page=2');
      expect(cache.get('GET', '/api/v1/admin/clients?page=1'), isNull);
    });
  });

  group('DataCache deduplication', () {
    test('registerOrGet returns null for first caller', () {
      final cache = DataCache();
      final result = cache.registerOrGet('GET', '/api/v1/admin/clients');
      expect(result, isNull);
      expect(cache.pendingCount, 1);
    });

    test('registerOrGet returns Future for subsequent callers', () {
      final cache = DataCache();
      cache.registerOrGet('GET', '/api/v1/admin/clients');
      final result = cache.registerOrGet('GET', '/api/v1/admin/clients');
      expect(result, isA<Future>());
      expect(cache.pendingCount, 1); // Still only 1 pending
    });

    test('resolve completes all waiters', () async {
      final cache = DataCache();
      cache.registerOrGet('GET', '/api/v1/admin/clients');
      final waiter = cache.registerOrGet('GET', '/api/v1/admin/clients')!;
      cache.resolve('GET', '/api/v1/admin/clients', {'done': true});
      final result = await waiter;
      expect(result['done'], true);
      expect(cache.pendingCount, 0);
    });

    test('reject propagates error to all waiters', () async {
      final cache = DataCache();
      cache.registerOrGet('GET', '/api/v1/admin/clients');
      final waiter = cache.registerOrGet('GET', '/api/v1/admin/clients')!;
      cache.reject('GET', '/api/v1/admin/clients', 'timeout');
      try {
        await waiter;
        fail('Should have thrown');
      } catch (e) {
        expect(e, 'timeout');
      }
      expect(cache.pendingCount, 0);
    });

    test('registerOrGet does not deduplicate POST requests', () {
      final cache = DataCache();
      expect(cache.registerOrGet('POST', '/api/v1/admin/clients'), isNull);
      expect(
        cache.registerOrGet('POST', '/api/v1/admin/clients'),
        isNull, // Second caller also returns null (no dedup for POST)
      );
      expect(cache.pendingCount, 0); // POST never creates pending entries
    });

    test('clear aborts all pending requests', () {
      final cache = DataCache();
      cache.registerOrGet('GET', '/api/v1/admin/clients');
      cache.registerOrGet('GET', '/api/v1/admin/users');
      expect(cache.pendingCount, 2);
      cache.clear();
      expect(cache.pendingCount, 0);
    });
  });
}
