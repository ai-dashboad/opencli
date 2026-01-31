import 'package:opencli_daemon/cache/l1_cache.dart';
import 'package:opencli_daemon/cache/l2_cache.dart';
import 'package:opencli_daemon/cache/l3_cache.dart';
import 'package:opencli_daemon/cache/semantic_matcher.dart';

class CacheManager {
  late final L1Cache _l1;
  late final L2Cache _l2;
  late final L3Cache _l3;
  late final SemanticMatcher _semantic;

  final bool semanticEnabled;
  final double similarityThreshold;

  int _hits = 0;
  int _misses = 0;

  CacheManager({
    int l1MaxSize = 100,
    int l2MaxSize = 1000,
    String? l3Dir,
    this.semanticEnabled = true,
    this.similarityThreshold = 0.95,
  }) {
    _l1 = L1Cache(maxSize: l1MaxSize);
    _l2 = L2Cache(maxSize: l2MaxSize);
    _l3 = L3Cache(directory: l3Dir);
    _semantic = SemanticMatcher(threshold: similarityThreshold);
  }

  Future<void> initialize() async {
    await _l3.initialize();
    if (semanticEnabled) {
      await _semantic.initialize();
    }
    print('Cache system initialized');
  }

  Future<String?> get(String query) async {
    final key = _hashKey(query);

    // Try L1 (fastest)
    final l1Result = _l1.get(key);
    if (l1Result != null) {
      _hits++;
      return l1Result;
    }

    // Try L2
    final l2Result = _l2.get(key);
    if (l2Result != null) {
      _hits++;
      _l1.put(key, l2Result); // Promote to L1
      return l2Result;
    }

    // Try L3
    final l3Result = await _l3.get(key);
    if (l3Result != null) {
      _hits++;
      _l1.put(key, l3Result); // Promote to L1
      _l2.put(key, l3Result); // Promote to L2
      return l3Result;
    }

    // Try semantic matching
    if (semanticEnabled) {
      final semanticResult = await _semantic.findSimilar(query);
      if (semanticResult != null) {
        _hits++;
        return semanticResult;
      }
    }

    _misses++;
    return null;
  }

  Future<void> put(String query, String value) async {
    final key = _hashKey(query);

    // Store in all layers
    _l1.put(key, value);
    _l2.put(key, value);
    await _l3.put(key, value);

    // Store embedding for semantic search
    if (semanticEnabled) {
      await _semantic.addEntry(query, value);
    }
  }

  double get hitRate {
    final total = _hits + _misses;
    return total > 0 ? _hits / total : 0.0;
  }

  Map<String, dynamic> getStats() {
    return {
      'l1_size': _l1.size,
      'l2_size': _l2.size,
      'hit_rate': hitRate,
      'total_hits': _hits,
      'total_misses': _misses,
    };
  }

  String _hashKey(String input) {
    // Simple hash for now - in production use SHA256
    return input.hashCode.toString();
  }

  Future<void> clear() async {
    _l1.clear();
    _l2.clear();
    await _l3.clear();
    _hits = 0;
    _misses = 0;
  }
}
