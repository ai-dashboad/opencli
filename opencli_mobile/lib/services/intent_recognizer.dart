import 'dart:core';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'daemon_service.dart';

/// AI 驱动的意图识别引擎
/// 使用 Ollama LLM 理解自然语言，无需硬编码模式
class IntentRecognizer {
  final DaemonService daemonService;

  IntentRecognizer(this.daemonService);

  /// 识别用户输入的意图（AI 驱动）
  Future<IntentResult> recognize(String input) async {
    final trimmed = input.trim();

    if (trimmed.isEmpty) {
      return IntentResult(
        intent: 'unknown',
        confidence: 0.0,
        taskType: null,
        taskData: {},
      );
    }

    // 可选：超高频命令的快速路径（跳过 AI 调用以提速）
    // 这些是最常用且格式固定的命令，占比约 20%
    final quickResult = _tryQuickPath(trimmed);
    if (quickResult != null) {
      return quickResult;
    }

    // 主流程：使用 AI 识别所有其他命令
    return await _recognizeWithAI(trimmed);
  }

  /// 快速路径：少数超高频命令直接返回，无需 AI
  /// 这是性能优化，可以完全去掉改为纯 AI
  IntentResult? _tryQuickPath(String input) {
    final lower = input.toLowerCase();

    // 仅保留最简单最常用的几个命令
    if (lower == '截图' || lower == '截屏') {
      return IntentResult(
        intent: 'screenshot',
        confidence: 1.0,
        taskType: 'screenshot',
        taskData: {},
      );
    }

    if (lower == '系统信息' || lower == 'system info') {
      return IntentResult(
        intent: 'system_info',
        confidence: 1.0,
        taskType: 'system_info',
        taskData: {},
      );
    }

    return null; // 其他都交给 AI
  }

  /// 使用 AI (Ollama) 识别意图
  Future<IntentResult> _recognizeWithAI(String input) async {
    try {
      // 提交到 daemon 的 AI 意图识别服务
      final response = await daemonService.submitTaskAndWait(
        'ai_query',
        {
          'query': input,
          'mode': 'intent_recognition',
        },
        timeout: Duration(seconds: 10),
      );

      // 解析 AI 返回的结果
      if (response['success'] == true) {
        final intent = response['intent'] as String? ?? 'unknown';
        final confidence = (response['confidence'] as num?)?.toDouble() ?? 0.0;
        final parameters = response['parameters'] as Map<String, dynamic>? ?? {};

        // 映射 AI 识别的 intent 到 taskType
        final taskType = _mapIntentToTaskType(intent);

        return IntentResult(
          intent: intent,
          confidence: confidence,
          taskType: taskType,
          taskData: parameters,
          isAIFallback: true,
        );
      } else {
        // AI 识别失败，返回未知
        return IntentResult(
          intent: 'unknown',
          confidence: 0.0,
          taskType: null,
          taskData: {},
          error: response['error'] as String?,
        );
      }
    } catch (e) {
      print('AI intent recognition failed: $e');

      // 降级：直接调用本地 Ollama（绕过 daemon）
      return await _fallbackRecognition(input);
    }
  }

  /// 映射 AI 返回的 intent 到实际的 taskType
  String? _mapIntentToTaskType(String intent) {
    // AI 返回的 intent 直接就是 taskType
    // 例如: "screenshot", "open_app", "web_search" 等
    final validTaskTypes = {
      'screenshot',
      'open_app',
      'close_app',
      'open_url',
      'web_search',
      'system_info',
      'open_file',
      'run_command',
      'ai_query',
      'check_process',  // 新增：检查进程
      'list_processes', // 新增：列出进程
    };

    return validTaskTypes.contains(intent) ? intent : null;
  }

  /// 降级方案：直接调用本地 Ollama（绕过 daemon）
  /// 用于 daemon WebSocket 连接失败但 Ollama 仍在运行的情况
  Future<IntentResult> _fallbackRecognition(String input) async {
    try {
      // 直接通过 HTTP 调用本地 Ollama
      final result = await _callOllamaDirectly(input);
      if (result != null) {
        return result;
      }
    } catch (e) {
      print('Direct Ollama call failed: $e');
    }

    // 如果所有 AI 服务都不可用，返回友好的错误
    return IntentResult(
      intent: 'unknown',
      confidence: 0.0,
      taskType: null,
      taskData: {},
      error: 'AI 服务暂时不可用。请确保 Ollama 正在运行，或稍后重试。',
    );
  }

  /// 直接调用本地 Ollama API
  Future<IntentResult?> _callOllamaDirectly(String input) async {
    try {
      // 构建 Ollama 提示词
      final prompt = '''你是一个智能助手，负责识别用户的指令意图。

用户输入：$input

请分析用户的意图，并返回 JSON 格式的结果：
{
  "intent": "意图名称",
  "confidence": 0.0-1.0,
  "parameters": {参数}
}

可用的意图类型及示例：
- screenshot: 截屏、截图、截取屏幕
- open_app: 打开应用（参数：app_name）
  示例：打开 Chrome -> {"intent": "open_app", "parameters": {"app_name": "chrome"}}
- close_app: 关闭应用（参数：app_name）
- open_url: 打开网址（参数：url）
  示例：打开 google.com -> {"intent": "open_url", "parameters": {"url": "https://google.com"}}
- web_search: 网络搜索（参数：query）
  示例：搜索 Flutter -> {"intent": "web_search", "parameters": {"query": "Flutter"}}
- system_info: 获取系统信息
- check_process: 检查进程是否运行（参数：process_name）
  示例：检查 claude code 是否运行 -> {"intent": "check_process", "parameters": {"process_name": "claude code"}}
- run_command: 运行 shell 命令（参数：command）
  示例：列出文件 -> {"intent": "run_command", "parameters": {"command": "ls -la"}}
- ai_query: AI 问答（参数：query）
  示例：什么是 AI -> {"intent": "ai_query", "parameters": {"query": "什么是 AI"}}

重要规则：
1. 对于检查进程/程序是否运行的请求，使用 check_process
2. 对于需要执行 shell 命令的请求，使用 run_command
3. 所有用户命令都必须映射到某个 intent，不要返回 unknown
4. confidence 应该 >= 0.7 表示有信心识别

只返回 JSON，不要其他内容。''';

      final response = await http.Client().post(
        Uri.parse('http://localhost:11434/api/generate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': 'qwen2.5:latest',
          'prompt': prompt,
          'stream': false,
          'format': 'json',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final responseText = data['response'] as String;
        final result = jsonDecode(responseText);

        final intent = result['intent'] as String? ?? 'unknown';
        final confidence = (result['confidence'] as num?)?.toDouble() ?? 0.0;
        final parameters = result['parameters'] as Map<String, dynamic>? ?? {};

        return IntentResult(
          intent: intent,
          confidence: confidence,
          taskType: _mapIntentToTaskType(intent),
          taskData: parameters,
          isAIFallback: true,
        );
      }
    } catch (e) {
      print('Failed to call Ollama directly: $e');
    }

    return null;
  }
}

/// 意图识别结果
class IntentResult {
  final String intent; // 意图名称
  final double confidence; // 置信度 0-1
  final String? taskType; // 对应的任务类型
  final Map<String, dynamic> taskData; // 任务数据
  final bool needsConfirmation; // 是否需要用户确认
  final bool isAIFallback; // 是否使用 AI 识别
  final String? error; // 错误信息

  IntentResult({
    required this.intent,
    required this.confidence,
    this.taskType,
    required this.taskData,
    this.needsConfirmation = false,
    this.isAIFallback = false,
    this.error,
  });

  bool get isRecognized => confidence > 0.3 || isAIFallback;
  bool get hasError => error != null;
}
