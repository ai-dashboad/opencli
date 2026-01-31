import 'dart:math';

/// Semantic similarity matcher using embeddings
class SemanticMatcher {
  final double threshold;
  final Map<String, EmbeddingVector> _embeddings = {};
  final Map<String, String> _values = {};

  SemanticMatcher({required this.threshold});

  Future<void> initialize() async {
    // TODO: Load ONNX embedding model
    print('Semantic matcher initialized (threshold: $threshold)');
  }

  Future<void> addEntry(String query, String value) async {
    final embedding = await _computeEmbedding(query);
    final key = query.hashCode.toString();

    _embeddings[key] = embedding;
    _values[key] = value;
  }

  Future<String?> findSimilar(String query) async {
    if (_embeddings.isEmpty) return null;

    final queryEmbedding = await _computeEmbedding(query);

    double maxSimilarity = 0.0;
    String? bestMatch;

    for (final entry in _embeddings.entries) {
      final similarity = _cosineSimilarity(queryEmbedding, entry.value);

      if (similarity > maxSimilarity && similarity >= threshold) {
        maxSimilarity = similarity;
        bestMatch = entry.key;
      }
    }

    return bestMatch != null ? _values[bestMatch] : null;
  }

  Future<EmbeddingVector> _computeEmbedding(String text) async {
    // TODO: Use ONNX model for real embeddings
    // For now, use simple hash-based pseudo-embedding
    final hash = text.hashCode;
    final random = Random(hash);

    final values = List.generate(
      384,
      (_) => random.nextDouble() * 2 - 1, // [-1, 1]
    );

    return EmbeddingVector(values);
  }

  double _cosineSimilarity(EmbeddingVector a, EmbeddingVector b) {
    double dotProduct = 0.0;

    for (int i = 0; i < a.values.length; i++) {
      dotProduct += a.values[i] * b.values[i];
    }

    return dotProduct / (a.norm * b.norm);
  }
}

class EmbeddingVector {
  final List<double> values;
  late final double norm;

  EmbeddingVector(this.values) {
    norm = _computeNorm();
  }

  double _computeNorm() {
    double sum = 0.0;
    for (final v in values) {
      sum += v * v;
    }
    return sqrt(sum);
  }
}
