import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Manages AI workers and their integration with various AI services
/// Supports multiple AI providers: Claude, GPT, Gemini, etc.
class AIWorkforceManager {
  final Map<String, AIWorker> _aiWorkers = {};
  final Map<String, AIProvider> _providers = {};
  final StreamController<AITaskResult> _resultController =
      StreamController.broadcast();

  Stream<AITaskResult> get results => _resultController.stream;

  AIWorkforceManager() {
    _initializeProviders();
  }

  /// Initialize AI providers
  void _initializeProviders() {
    // Claude (Anthropic)
    _providers['claude'] = ClaudeProvider();

    // GPT (OpenAI)
    _providers['gpt'] = GPTProvider();

    // Gemini (Google)
    _providers['gemini'] = GeminiProvider();

    // Local models (Ollama, etc.)
    _providers['local'] = LocalModelProvider();
  }

  /// Create and register an AI worker
  Future<String> createAIWorker({
    required String name,
    required String provider,
    required String model,
    required List<String> capabilities,
    Map<String, dynamic>? config,
  }) async {
    final workerId = _generateWorkerId();

    final aiProvider = _providers[provider];
    if (aiProvider == null) {
      throw Exception('Unknown AI provider: $provider');
    }

    final worker = AIWorker(
      id: workerId,
      name: name,
      provider: aiProvider,
      model: model,
      capabilities: capabilities,
      config: config ?? {},
    );

    _aiWorkers[workerId] = worker;
    print('AI worker created: $workerId ($provider/$model)');

    return workerId;
  }

  /// Execute a task with an AI worker
  Future<AITaskResult> executeTask({
    required String workerId,
    required AITask task,
  }) async {
    final worker = _aiWorkers[workerId];
    if (worker == null) {
      throw Exception('AI worker not found: $workerId');
    }

    if (!worker.isAvailable) {
      throw Exception('AI worker is busy: $workerId');
    }

    worker.isAvailable = false;
    worker.currentTask = task;

    try {
      final result = await worker.provider.execute(
        model: worker.model,
        task: task,
        config: worker.config,
      );

      worker.completedTasks++;
      worker.totalTokensUsed += result.tokensUsed;

      final taskResult = AITaskResult(
        workerId: workerId,
        taskId: task.id,
        success: true,
        result: result.content,
        tokensUsed: result.tokensUsed,
        duration: result.duration,
        completedAt: DateTime.now(),
      );

      _resultController.add(taskResult);

      return taskResult;
    } catch (e) {
      worker.failedTasks++;

      final taskResult = AITaskResult(
        workerId: workerId,
        taskId: task.id,
        success: false,
        error: e.toString(),
        completedAt: DateTime.now(),
      );

      _resultController.add(taskResult);

      return taskResult;
    } finally {
      worker.isAvailable = true;
      worker.currentTask = null;
    }
  }

  /// Execute task with automatic worker selection
  Future<AITaskResult> executeTaskAuto({
    required AITask task,
    String? preferredProvider,
  }) async {
    // Find best available worker
    final availableWorkers = _aiWorkers.values
        .where((w) => w.isAvailable)
        .where((w) => _hasRequiredCapabilities(w, task))
        .toList();

    if (availableWorkers.isEmpty) {
      throw Exception('No available AI workers for task: ${task.type}');
    }

    // Prefer specified provider
    if (preferredProvider != null) {
      final preferredWorker = availableWorkers.firstWhere(
        (w) => w.provider.name == preferredProvider,
        orElse: () => availableWorkers.first,
      );
      return executeTask(workerId: preferredWorker.id, task: task);
    }

    // Select worker with best performance
    availableWorkers.sort((a, b) {
      final scoreA = _calculateWorkerScore(a);
      final scoreB = _calculateWorkerScore(b);
      return scoreB.compareTo(scoreA);
    });

    return executeTask(workerId: availableWorkers.first.id, task: task);
  }

  /// Check if worker has required capabilities
  bool _hasRequiredCapabilities(AIWorker worker, AITask task) {
    final requiredCap = _getRequiredCapability(task.type);
    return worker.capabilities.contains(requiredCap);
  }

  /// Get required capability for task type
  String _getRequiredCapability(AITaskType type) {
    switch (type) {
      case AITaskType.codeGeneration:
        return 'code_generation';
      case AITaskType.codeAnalysis:
        return 'code_analysis';
      case AITaskType.codeReview:
        return 'code_review';
      case AITaskType.documentation:
        return 'documentation';
      case AITaskType.research:
        return 'research';
      case AITaskType.dataAnalysis:
        return 'data_analysis';
      case AITaskType.imageAnalysis:
        return 'image_analysis';
      case AITaskType.conversation:
        return 'conversation';
    }
  }

  /// Calculate worker performance score
  double _calculateWorkerScore(AIWorker worker) {
    if (worker.completedTasks == 0) return 0.5;

    final successRate = worker.completedTasks /
        (worker.completedTasks + worker.failedTasks);

    return successRate;
  }

  /// Get AI worker statistics
  Map<String, dynamic> getWorkerStats(String workerId) {
    final worker = _aiWorkers[workerId];
    if (worker == null) {
      throw Exception('AI worker not found: $workerId');
    }

    return {
      'id': worker.id,
      'name': worker.name,
      'provider': worker.provider.name,
      'model': worker.model,
      'is_available': worker.isAvailable,
      'capabilities': worker.capabilities,
      'completed_tasks': worker.completedTasks,
      'failed_tasks': worker.failedTasks,
      'total_tokens_used': worker.totalTokensUsed,
      'success_rate': worker.completedTasks /
          (worker.completedTasks + worker.failedTasks + 1),
    };
  }

  /// Get all AI workers
  List<Map<String, dynamic>> getAllWorkers() {
    return _aiWorkers.values.map((w) => getWorkerStats(w.id)).toList();
  }

  /// Generate unique worker ID
  String _generateWorkerId() {
    return 'ai_worker_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Cleanup resources
  Future<void> dispose() async {
    await _resultController.close();
  }
}

/// AI Worker model
class AIWorker {
  final String id;
  final String name;
  final AIProvider provider;
  final String model;
  final List<String> capabilities;
  final Map<String, dynamic> config;

  bool isAvailable;
  AITask? currentTask;
  int completedTasks;
  int failedTasks;
  int totalTokensUsed;

  AIWorker({
    required this.id,
    required this.name,
    required this.provider,
    required this.model,
    required this.capabilities,
    required this.config,
    this.isAvailable = true,
    this.currentTask,
    this.completedTasks = 0,
    this.failedTasks = 0,
    this.totalTokensUsed = 0,
  });
}

/// AI Task
class AITask {
  final String id;
  final AITaskType type;
  final String prompt;
  final Map<String, dynamic>? context;
  final List<String>? files;
  final Map<String, dynamic>? parameters;

  AITask({
    required this.id,
    required this.type,
    required this.prompt,
    this.context,
    this.files,
    this.parameters,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'prompt': prompt,
      if (context != null) 'context': context,
      if (files != null) 'files': files,
      if (parameters != null) 'parameters': parameters,
    };
  }
}

enum AITaskType {
  codeGeneration,
  codeAnalysis,
  codeReview,
  documentation,
  research,
  dataAnalysis,
  imageAnalysis,
  conversation,
}

/// AI Task Result
class AITaskResult {
  final String workerId;
  final String taskId;
  final bool success;
  final String? result;
  final String? error;
  final int tokensUsed;
  final Duration duration;
  final DateTime completedAt;

  AITaskResult({
    required this.workerId,
    required this.taskId,
    required this.success,
    this.result,
    this.error,
    this.tokensUsed = 0,
    this.duration = Duration.zero,
    required this.completedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'worker_id': workerId,
      'task_id': taskId,
      'success': success,
      if (result != null) 'result': result,
      if (error != null) 'error': error,
      'tokens_used': tokensUsed,
      'duration_ms': duration.inMilliseconds,
      'completed_at': completedAt.toIso8601String(),
    };
  }
}

/// AI Provider Response
class AIProviderResponse {
  final String content;
  final int tokensUsed;
  final Duration duration;

  AIProviderResponse({
    required this.content,
    required this.tokensUsed,
    required this.duration,
  });
}

/// Base AI Provider
abstract class AIProvider {
  String get name;

  Future<AIProviderResponse> execute({
    required String model,
    required AITask task,
    required Map<String, dynamic> config,
  });
}

/// Claude Provider (Anthropic)
class ClaudeProvider implements AIProvider {
  @override
  String get name => 'claude';

  @override
  Future<AIProviderResponse> execute({
    required String model,
    required AITask task,
    required Map<String, dynamic> config,
  }) async {
    final apiKey = config['api_key'] as String?;
    if (apiKey == null) {
      throw Exception('Claude API key not configured');
    }

    final startTime = DateTime.now();

    try {
      final response = await http.post(
        Uri.parse('https://api.anthropic.com/v1/messages'),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': model,
          'max_tokens': config['max_tokens'] ?? 4096,
          'messages': [
            {
              'role': 'user',
              'content': task.prompt,
            }
          ],
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Claude API error: ${response.body}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final content = data['content'][0]['text'] as String;
      final tokensUsed = (data['usage']['input_tokens'] as int) +
          (data['usage']['output_tokens'] as int);

      return AIProviderResponse(
        content: content,
        tokensUsed: tokensUsed,
        duration: DateTime.now().difference(startTime),
      );
    } catch (e) {
      throw Exception('Claude execution failed: $e');
    }
  }
}

/// GPT Provider (OpenAI)
class GPTProvider implements AIProvider {
  @override
  String get name => 'gpt';

  @override
  Future<AIProviderResponse> execute({
    required String model,
    required AITask task,
    required Map<String, dynamic> config,
  }) async {
    final apiKey = config['api_key'] as String?;
    if (apiKey == null) {
      throw Exception('OpenAI API key not configured');
    }

    final startTime = DateTime.now();

    try {
      final response = await http.post(
        Uri.parse('https://api.openai.com/v1/chat/completions'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': model,
          'messages': [
            {
              'role': 'user',
              'content': task.prompt,
            }
          ],
          'max_tokens': config['max_tokens'] ?? 4096,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('OpenAI API error: ${response.body}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final content = data['choices'][0]['message']['content'] as String;
      final tokensUsed = data['usage']['total_tokens'] as int;

      return AIProviderResponse(
        content: content,
        tokensUsed: tokensUsed,
        duration: DateTime.now().difference(startTime),
      );
    } catch (e) {
      throw Exception('GPT execution failed: $e');
    }
  }
}

/// Gemini Provider (Google)
class GeminiProvider implements AIProvider {
  @override
  String get name => 'gemini';

  @override
  Future<AIProviderResponse> execute({
    required String model,
    required AITask task,
    required Map<String, dynamic> config,
  }) async {
    final apiKey = config['api_key'] as String?;
    if (apiKey == null) {
      throw Exception('Gemini API key not configured');
    }

    final startTime = DateTime.now();

    try {
      final response = await http.post(
        Uri.parse(
            'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': task.prompt}
              ]
            }
          ],
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Gemini API error: ${response.body}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final content = data['candidates'][0]['content']['parts'][0]['text'] as String;

      return AIProviderResponse(
        content: content,
        tokensUsed: 0, // Gemini doesn't provide token count in response
        duration: DateTime.now().difference(startTime),
      );
    } catch (e) {
      throw Exception('Gemini execution failed: $e');
    }
  }
}

/// Local Model Provider (Ollama, etc.)
class LocalModelProvider implements AIProvider {
  @override
  String get name => 'local';

  @override
  Future<AIProviderResponse> execute({
    required String model,
    required AITask task,
    required Map<String, dynamic> config,
  }) async {
    final endpoint = config['endpoint'] as String? ?? 'http://localhost:11434';
    final startTime = DateTime.now();

    try {
      final response = await http.post(
        Uri.parse('$endpoint/api/generate'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': model,
          'prompt': task.prompt,
          'stream': false,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Local model error: ${response.body}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final content = data['response'] as String;

      return AIProviderResponse(
        content: content,
        tokensUsed: 0,
        duration: DateTime.now().difference(startTime),
      );
    } catch (e) {
      throw Exception('Local model execution failed: $e');
    }
  }
}
