import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/data_cache.dart';

void main() {
  group('DataCache capacity bounds', () {
    test('default capacity keeps at most 128 completed responses', () {
      final cache = DataCache(ttl: const Duration(hours: 1));
      for (var i = 0; i <= 128; i++) {
        cache.set('GET', '/api/v1/admin/items/$i', {'id': i});
      }

      expect(cache.size, 128);
      expect(cache.get('GET', '/api/v1/admin/items/0'), isNull);
      expect(cache.get('GET', '/api/v1/admin/items/1'), isNotNull);
      expect(cache.get('GET', '/api/v1/admin/items/128'), isNotNull);
    });

    test('configured capacity evicts the least recently used response', () {
      final cache = DataCache(ttl: const Duration(hours: 1), maxEntries: 2);
      cache.set('GET', '/api/v1/admin/a', {'value': 'a'});
      cache.set('GET', '/api/v1/admin/b', {'value': 'b'});
      expect(cache.get('GET', '/api/v1/admin/a'), isNotNull);

      cache.set('GET', '/api/v1/admin/c', {'value': 'c'});

      expect(cache.size, 2);
      expect(cache.get('GET', '/api/v1/admin/a'), isNotNull);
      expect(cache.get('GET', '/api/v1/admin/b'), isNull);
      expect(cache.get('GET', '/api/v1/admin/c'), isNotNull);
    });

    test('replacing an existing key does not evict another entry', () {
      final cache = DataCache(maxEntries: 2, ttl: const Duration(hours: 1));
      cache.set('GET', '/api/v1/admin/a', {'version': 1});
      cache.set('GET', '/api/v1/admin/b', {'value': 'b'});

      cache.set('GET', '/api/v1/admin/a', {'version': 2});

      expect(cache.size, 2);
      expect(cache.get('GET', '/api/v1/admin/a'), {'version': 2});
      expect(cache.get('GET', '/api/v1/admin/b'), {'value': 'b'});
    });

    test('replacing an existing key updates its recency', () {
      final cache = DataCache(maxEntries: 2, ttl: const Duration(hours: 1));
      cache.set('GET', '/api/v1/admin/a', {'version': 1});
      cache.set('GET', '/api/v1/admin/b', {'value': 'b'});

      cache.set('GET', '/api/v1/admin/a', {'version': 2});
      cache.set('GET', '/api/v1/admin/c', {'value': 'c'});

      expect(cache.size, 2);
      expect(cache.get('GET', '/api/v1/admin/a'), {'version': 2});
      expect(cache.get('GET', '/api/v1/admin/b'), isNull);
      expect(cache.get('GET', '/api/v1/admin/c'), {'value': 'c'});
    });

    test(
      'zero capacity disables completed storage but not deduplication',
      () async {
        final cache = DataCache(maxEntries: 0, ttl: const Duration(hours: 1));
        cache.set('GET', '/api/v1/admin/a', {'value': 'a'});
        expect(cache.size, 0);
        expect(cache.get('GET', '/api/v1/admin/a'), isNull);

        expect(cache.registerOrGet('GET', '/api/v1/admin/a'), isNull);
        final waiter = cache.registerOrGet('GET', '/api/v1/admin/a')!;
        expect(cache.pendingCount, 1);
        cache.resolve('GET', '/api/v1/admin/a', {'resolved': true});
        expect(await waiter, {'resolved': true});
        expect(cache.pendingCount, 0);
        expect(cache.size, 0);
        expect(cache.get('GET', '/api/v1/admin/a'), isNull);
      },
    );

    test('negative capacity is rejected at runtime', () {
      expect(() => DataCache(maxEntries: -1), throwsArgumentError);
    });
  });

  group('DataCache capacity preserves existing semantics', () {
    test('returns the same Map instance that was stored', () {
      final cache = DataCache(maxEntries: 2);
      final data = <String, dynamic>{'value': 1};
      cache.set('GET', '/api/v1/admin/a', data);

      expect(identical(cache.get('GET', '/api/v1/admin/a'), data), isTrue);
    });

    test('reads refresh recency but do not renew the TTL', () async {
      final cache = DataCache(
        maxEntries: 2,
        ttl: const Duration(milliseconds: 300),
      );
      cache.set('GET', '/api/v1/admin/a', {'value': 'a'});

      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(cache.get('GET', '/api/v1/admin/a'), isNotNull);
      await Future<void>.delayed(const Duration(milliseconds: 250));

      expect(cache.get('GET', '/api/v1/admin/a'), isNull);
    });

    test('GET-only and invalidation boundaries are unchanged', () {
      final cache = DataCache(maxEntries: 4, ttl: const Duration(hours: 1));
      cache.set('POST', '/api/v1/admin/a', {'value': 'post'});
      cache.set('GET', '/api/v1/admin/a?page=1', {'value': 'query'});
      cache.set('GET', '/api/v1/admin/a/child', {'value': 'slash'});
      cache.set('GET', '/api/v1/admin/a:approve', {'value': 'colon'});
      cache.set('GET', '/api/v1/admin/ab', {'value': 'unrelated'});
      expect(cache.size, 4);

      cache.invalidate('/api/v1/admin/a?page=2');

      expect(cache.get('GET', '/api/v1/admin/a?page=1'), isNull);
      expect(cache.get('GET', '/api/v1/admin/a/child'), isNull);
      expect(cache.get('GET', '/api/v1/admin/a:approve'), isNull);
      expect(cache.get('GET', '/api/v1/admin/ab'), isNotNull);
    });
  });

  group('DataCache capacity and pending requests', () {
    test('eviction pressure never removes pending completions', () async {
      final cache = DataCache(maxEntries: 1, ttl: const Duration(hours: 1));
      expect(cache.registerOrGet('GET', '/api/v1/admin/pending'), isNull);
      final firstWaiter = cache.registerOrGet('GET', '/api/v1/admin/pending')!;
      final secondWaiter = cache.registerOrGet('GET', '/api/v1/admin/pending')!;
      expect(identical(firstWaiter, secondWaiter), isTrue);

      cache.set('GET', '/api/v1/admin/a', {'value': 'a'});
      cache.set('GET', '/api/v1/admin/b', {'value': 'b'});
      cache.set('GET', '/api/v1/admin/c', {'value': 'c'});
      expect(cache.size, 1);
      expect(cache.pendingCount, 1);

      final data = <String, dynamic>{'done': true};
      cache.resolve('GET', '/api/v1/admin/pending', data);

      expect(identical(await firstWaiter, data), isTrue);
      expect(cache.pendingCount, 0);
    });

    test('eviction pressure does not change pending rejection', () async {
      final cache = DataCache(maxEntries: 1);
      cache.registerOrGet('GET', '/api/v1/admin/pending');
      final waiter = cache.registerOrGet('GET', '/api/v1/admin/pending')!;
      cache.set('GET', '/api/v1/admin/a', {'value': 'a'});
      cache.set('GET', '/api/v1/admin/b', {'value': 'b'});

      final error = StateError('network failure');
      cache.reject('GET', '/api/v1/admin/pending', error);
      await expectLater(waiter, throwsA(same(error)));
      expect(cache.pendingCount, 0);
    });

    test('zero capacity preserves clear cancellation', () async {
      final cache = DataCache(maxEntries: 0);
      cache.registerOrGet('GET', '/api/v1/admin/pending');
      final waiter = cache.registerOrGet('GET', '/api/v1/admin/pending')!;
      cache.set('GET', '/api/v1/admin/a', {'value': 'a'});
      expect(cache.size, 0);

      cache.clear();

      expect(cache.size, 0);
      expect(cache.pendingCount, 0);
      await expectLater(waiter, throwsStateError);
    });

    test(
      'rejection without a waiter remains observed under zero capacity',
      () async {
        final cache = DataCache(maxEntries: 0);
        cache.registerOrGet('GET', '/api/v1/admin/pending');
        cache.reject('GET', '/api/v1/admin/pending', 'timeout');
        await Future<void>.delayed(Duration.zero);
        expect(cache.pendingCount, 0);
      },
    );
  });
}
