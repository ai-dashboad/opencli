import 'dart:collection';

/// L2 Cache - LRU (Least Recently Used) cache
class L2Cache {
  final int maxSize;
  final LinkedHashMap<String, String> _cache = LinkedHashMap();

  L2Cache({required this.maxSize});

  int get size => _cache.length;

  String? get(String key) {
    if (!_cache.containsKey(key)) return null;

    // Move to end (most recently used)
    final value = _cache.remove(key)!;
    _cache[key] = value;
    return value;
  }

  void put(String key, String value) {
    // Remove if exists (will re-add at end)
    if (_cache.containsKey(key)) {
      _cache.remove(key);
    } else if (_cache.length >= maxSize) {
      // Evict oldest (first entry)
      _cache.remove(_cache.keys.first);
    }

    _cache[key] = value;
  }

  void clear() {
    _cache.clear();
  }

  Map<String, dynamic> getStats() {
    return {
      'size': _cache.length,
      'max_size': maxSize,
      'usage': _cache.length / maxSize,
    };
  }
}
