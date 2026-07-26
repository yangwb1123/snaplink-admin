import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/data_cache.dart';

void main() {
  group('DataCache', () {
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

    test('expires after TTL', () async {
      final cache = DataCache(ttl: const Duration(milliseconds: 50));
      cache.set('GET', '/api/v1/admin/clients', {'clients': []});
      
      // Should be available immediately
      expect(cache.get('GET', '/api/v1/admin/clients'), isNotNull);
      
      // Wait for expiry
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
      cache.set('GET', '/api/v1/admin/users', {});
      expect(cache.size, 2);
    });

    test('strips query params for invalidation', () {
      final cache = DataCache();
      cache.set('GET', '/api/v1/admin/clients?page=1', {});
      
      cache.invalidate('/api/v1/admin/clients?page=2');
      
      expect(cache.get('GET', '/api/v1/admin/clients?page=1'), isNull);
    });
  });
}
