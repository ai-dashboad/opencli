import 'package:opencli_daemon/ai/model_adapter.dart';
import 'package:opencli_daemon/ai/claude_adapter.dart';

class ModelRouter {
  final Map<String, ModelAdapter> _adapters = {};
  final List<String> _priority;
  final Map<String, dynamic> _rules;

  ModelRouter({
    required List<String> priority,
    Map<String, dynamic>? rules,
  })  : _priority = priority,
        _rules = rules ?? {};

  Future<void> registerAdapter(String name, ModelAdapter adapter) async {
    _adapters[name] = adapter;
    await adapter.initialize();
    print('Registered model adapter: $name');
  }

  Future<ChatResponse> chat(ChatRequest request) async {
    final selectedModel = selectModel(request);

    print('Routing to model: $selectedModel');

    final adapter = _adapters[selectedModel];
    if (adapter == null) {
      throw Exception('Model not available: $selectedModel');
    }

    return await adapter.chat(request);
  }

  Stream<String> chatStream(ChatRequest request) {
    final selectedModel = selectModel(request);
    final adapter = _adapters[selectedModel];

    if (adapter == null) {
      throw Exception('Model not available: $selectedModel');
    }

    return adapter.chatStream(request);
  }

  String selectModel(ChatRequest request) {
    // Apply routing rules
    final taskType = _classifyTask(request);
    final complexity = _estimateComplexity(request);
    final contextSize = request.estimateInputTokens();

    // Check rules
    for (final rule in _rules['rules'] ?? []) {
      if (_matchesRule(rule, taskType, complexity, contextSize, request)) {
        return rule['model'];
      }
    }

    // Fall back to priority list
    for (final modelName in _priority) {
      if (_adapters[modelName]?.isAvailable ?? false) {
        return modelName;
      }
    }

    throw Exception('No available models');
  }

  String _classifyTask(ChatRequest request) {
    final message = request.message.toLowerCase();

    if (message.contains('explain') || message.contains('what is')) {
      return 'explanation';
    } else if (message.contains('debug') || message.contains('fix')) {
      return 'debugging';
    } else if (message.contains('refactor') || message.contains('improve')) {
      return 'refactoring';
    } else if (message.contains('complete') || message.contains('continue')) {
      return 'code_completion';
    } else if (message.contains('architecture') || message.contains('design')) {
      return 'architecture';
    }

    return 'general';
  }

  String _estimateComplexity(ChatRequest request) {
    final messageLength = request.message.length;
    final contextSize = request.estimateInputTokens();

    if (messageLength < 100 && contextSize < 1000) {
      return 'low';
    } else if (messageLength < 500 && contextSize < 10000) {
      return 'medium';
    } else {
      return 'high';
    }
  }

  bool _matchesRule(
    Map<String, dynamic> rule,
    String taskType,
    String complexity,
    int contextSize,
    ChatRequest request,
  ) {
    // Check task type
    if (rule.containsKey('task_type')) {
      final ruleTypes = rule['task_type'];
      if (ruleTypes is String && ruleTypes != taskType) {
        return false;
      } else if (ruleTypes is List && !ruleTypes.contains(taskType)) {
        return false;
      }
    }

    // Check complexity
    if (rule.containsKey('complexity') && rule['complexity'] != complexity) {
      return false;
    }

    // Check context size
    if (rule.containsKey('context_size')) {
      final constraint = rule['context_size'] as String;
      if (constraint.startsWith('>')) {
        final threshold = int.parse(constraint.substring(1));
        if (contextSize <= threshold) return false;
      } else if (constraint.startsWith('<')) {
        final threshold = int.parse(constraint.substring(1));
        if (contextSize >= threshold) return false;
      }
    }

    // Check for images
    if (rule.containsKey('has_image')) {
      // TODO: Check for image attachments
    }

    return true;
  }

  List<String> listModels() {
    return _adapters.keys.toList();
  }

  Map<String, dynamic> getModelInfo(String modelName) {
    final adapter = _adapters[modelName];
    if (adapter == null) {
      throw Exception('Model not found: $modelName');
    }

    return {
      'name': adapter.name,
      'provider': adapter.provider,
      'available': adapter.isAvailable,
      'supports': {
        'chat': adapter.supports('chat'),
        'streaming': adapter.supports('streaming'),
        'embeddings': adapter.supports('embeddings'),
        'vision': adapter.supports('vision'),
      },
    };
  }

  Future<void> dispose() async {
    for (final adapter in _adapters.values) {
      await adapter.dispose();
    }
    _adapters.clear();
  }
}
