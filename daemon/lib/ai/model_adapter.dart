/// Base interface for AI model adapters
abstract class ModelAdapter {
  String get name;
  String get provider;
  bool get isAvailable;

  /// Initialize the model connection
  Future<void> initialize();

  /// Chat completion
  Future<ChatResponse> chat(ChatRequest request);

  /// Text completion (non-chat)
  Future<String> complete(String prompt, {int? maxTokens});

  /// Generate embeddings
  Future<List<double>> embed(String text);

  /// Stream chat responses
  Stream<String> chatStream(ChatRequest request);

  /// Estimate cost for a request
  double estimateCost(int inputTokens, int outputTokens);

  /// Check if model supports feature
  bool supports(String feature);

  /// Dispose resources
  Future<void> dispose();
}

class ChatRequest {
  final String message;
  final List<ChatMessage> history;
  final Map<String, dynamic> context;
  final String? systemPrompt;
  final double? temperature;
  final int? maxTokens;
  final List<String>? stopSequences;

  ChatRequest({
    required this.message,
    this.history = const [],
    this.context = const {},
    this.systemPrompt,
    this.temperature,
    this.maxTokens,
    this.stopSequences,
  });

  int estimateInputTokens() {
    // Simple estimation: 1 token ≈ 4 characters
    int total = message.length ~/ 4;

    for (var msg in history) {
      total += msg.content.length ~/ 4;
    }

    if (systemPrompt != null) {
      total += systemPrompt!.length ~/ 4;
    }

    return total;
  }
}

class ChatMessage {
  final String role; // "user", "assistant", "system"
  final String content;
  final DateTime timestamp;

  ChatMessage({
    required this.role,
    required this.content,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'role': role,
      'content': content,
    };
  }
}

class ChatResponse {
  final String content;
  final int inputTokens;
  final int outputTokens;
  final double? cost;
  final Map<String, dynamic>? metadata;

  ChatResponse({
    required this.content,
    required this.inputTokens,
    required this.outputTokens,
    this.cost,
    this.metadata,
  });
}
