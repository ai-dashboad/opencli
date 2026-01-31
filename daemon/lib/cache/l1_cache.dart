/// L1 Cache - In-memory hash map (fastest access)
class L1Cache {
  final int maxSize;
  final Map<String, CacheEntry> _cache = {};

  L1Cache({required this.maxSize});

  int get size => _cache.length;

  String? get(String key) {
    final entry = _cache[key];
    if (entry == null) return null;

    entry.markAccessed();
    return entry.value;
  }

  void put(String key, String value) {
    // Evict oldest if at capacity
    if (_cache.length >= maxSize && !_cache.containsKey(key)) {
      _evictOldest();
    }

    _cache[key] = CacheEntry(
      key: key,
      value: value,
      createdAt: DateTime.now(),
      accessedAt: DateTime.now(),
    );
  }

  void _evictOldest() {
    if (_cache.isEmpty) return;

    // Find least recently accessed entry
    CacheEntry? oldest;
    String? oldestKey;

    for (final entry in _cache.entries) {
      if (oldest == null || entry.value.accessedAt.isBefore(oldest.accessedAt)) {
        oldest = entry.value;
        oldestKey = entry.key;
      }
    }

    if (oldestKey != null) {
      _cache.remove(oldestKey);
    }
  }

  void clear() {
    _cache.clear();
  }
}

class CacheEntry {
  final String key;
  final String value;
  final DateTime createdAt;
  DateTime accessedAt;
  int hitCount = 0;

  CacheEntry({
    required this.key,
    required this.value,
    required this.createdAt,
    required this.accessedAt,
  });

  void markAccessed() {
    accessedAt = DateTime.now();
    hitCount++;
  }

  int get sizeBytes => key.length + value.length + 32;
}
