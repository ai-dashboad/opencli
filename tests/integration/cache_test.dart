// Cache Integration Tests

import 'package:test/test.dart';
import 'package:opencli_daemon/cache/cache_manager.dart';

void main() {
  group('Cache Integration Tests', () {
    late CacheManager cache;

    setUp(() async {
      cache = CacheManager(
        l1MaxSize: 10,
        l2MaxSize: 50,
        semanticEnabled: false, // Disable for faster tests
      );
      await cache.initialize();
    });

    tearDown(() async {
      await cache.clear();
    });

    test('should cache and retrieve exact matches', () async {
      const query = 'What is Flutter?';
      const response = 'Flutter is a UI framework...';

      await cache.put(query, response);
      final result = await cache.get(query);

      expect(result, equals(response));
    });

    test('should promote values through cache tiers', () async {
      const query = 'Explain async/await';
      const response = 'Async/await is...';

      // Put in L3 directly
      await cache.put(query, response);

      // Get should promote to L2 and L1
      await cache.get(query);

      final stats = cache.getStats();
      expect(stats['l1_size'], greaterThan(0));
    });

    test('should calculate hit rate correctly', () async {
      await cache.put('q1', 'a1');
      await cache.put('q2', 'a2');

      await cache.get('q1'); // Hit
      await cache.get('q2'); // Hit
      await cache.get('q3'); // Miss

      expect(cache.hitRate, closeTo(0.67, 0.01));
    });

    test('should handle cache eviction', () async {
      final cache = CacheManager(l1MaxSize: 2);
      await cache.initialize();

      await cache.put('a', '1');
      await cache.put('b', '2');
      await cache.put('c', '3');

      final stats = cache.getStats();
      expect(stats['l1_size'], lessThanOrEqualTo(2));

      await cache.clear();
    });
  });
}
