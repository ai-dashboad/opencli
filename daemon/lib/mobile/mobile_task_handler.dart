import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'mobile_connection_manager.dart';
import '../services/ollama_service.dart';
import '../executors/file_executor.dart';

/// Handles task execution for mobile-submitted tasks
/// Integrates with desktop automation and task queue
class MobileTaskHandler {
  final MobileConnectionManager connectionManager;
  final Map<String, TaskExecutor> _executors = {};

  MobileTaskHandler({required this.connectionManager}) {
    _registerDefaultExecutors();
    _listenToTaskSubmissions();
  }

  /// Register default task executors
  void _registerDefaultExecutors() {
    // File operations
    registerExecutor('open_file', OpenFileExecutor());
    registerExecutor('create_file', CreateFileExecutor());
    registerExecutor('read_file', ReadFileExecutor());
    registerExecutor('delete_file', DeleteFileExecutor());

    // Application control
    registerExecutor('open_app', OpenAppExecutor());
    registerExecutor('close_app', CloseAppExecutor());
    registerExecutor('list_apps', ListAppsExecutor());

    // System operations
    registerExecutor('screenshot', ScreenshotExecutor());
    registerExecutor('system_info', SystemInfoExecutor());
    registerExecutor('run_command', RunCommandExecutor());
    registerExecutor('check_process', CheckProcessExecutor());
    registerExecutor('list_processes', ListAppsExecutor());  // 重用现有的列表进程执行器

    // File operations
    registerExecutor('file_operation', FileOperationExecutor());

    // Web operations
    registerExecutor('open_url', OpenUrlExecutor());
    registerExecutor('web_search', WebSearchExecutor());

    // AI operations
    registerExecutor('ai_query', AIQueryExecutor());
    registerExecutor('ai_analyze_image', AIAnalyzeImageExecutor());
  }

  /// Register a custom task executor
  void registerExecutor(String taskType, TaskExecutor executor) {
    _executors[taskType] = executor;
    print('Registered executor for task type: $taskType');
  }

  /// Listen to task submissions from mobile
  void _listenToTaskSubmissions() {
    connectionManager.taskSubmissions.listen((submission) async {
      await _executeTask(submission);
    });
  }

  /// Execute a mobile-submitted task
  Future<void> _executeTask(MobileTaskSubmission submission) async {
    final executor = _executors[submission.taskType];

    if (executor == null) {
      await connectionManager.sendTaskUpdate(
        submission.deviceId,
        _generateTaskId(submission),
        'failed',
        error: 'Unknown task type: ${submission.taskType}',
      );
      return;
    }

    final taskId = _generateTaskId(submission);

    try {
      // Send task started status
      await connectionManager.sendTaskUpdate(
        submission.deviceId,
        taskId,
        'running',
      );

      // Execute the task
      final result = await executor.execute(submission.taskData);

      // Send success status
      await connectionManager.sendTaskUpdate(
        submission.deviceId,
        taskId,
        'completed',
        result: result,
      );
    } catch (e) {
      // Send error status
      await connectionManager.sendTaskUpdate(
        submission.deviceId,
        taskId,
        'failed',
        error: e.toString(),
      );
    }
  }

  /// Generate task ID from submission
  String _generateTaskId(MobileTaskSubmission submission) {
    return '${submission.deviceId}_${submission.submittedAt.millisecondsSinceEpoch}';
  }
}

/// Base class for task executors
abstract class TaskExecutor {
  Future<Map<String, dynamic>> execute(Map<String, dynamic> taskData);
}

/// File operations executors
class OpenFileExecutor extends TaskExecutor {
  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> taskData) async {
    final path = taskData['path'] as String;

    if (Platform.isMacOS) {
      await Process.run('open', [path]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [path]);
    } else if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', path]);
    }

    return {'success': true, 'path': path};
  }
}

class CreateFileExecutor extends TaskExecutor {
  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> taskData) async {
    final path = taskData['path'] as String;
    final content = taskData['content'] as String? ?? '';

    final file = File(path);
    await file.writeAsString(content);

    return {'success': true, 'path': path, 'size': content.length};
  }
}

class ReadFileExecutor extends TaskExecutor {
  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> taskData) async {
    final path = taskData['path'] as String;
    final file = File(path);

    if (!await file.exists()) {
      throw Exception('File not found: $path');
    }

    final content = await file.readAsString();
    return {'success': true, 'path': path, 'content': content};
  }
}

class DeleteFileExecutor extends TaskExecutor {
  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> taskData) async {
    final path = taskData['path'] as String;
    final file = File(path);

    if (await file.exists()) {
      await file.delete();
    }

    return {'success': true, 'path': path};
  }
}

/// Application control executors
class OpenAppExecutor extends TaskExecutor {
  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> taskData) async {
    final appName = taskData['app_name'] as String;

    if (Platform.isMacOS) {
      await Process.run('open', ['-a', appName]);
    } else if (Platform.isLinux) {
      await Process.run(appName, []);
    } else if (Platform.isWindows) {
      await Process.run('start', [appName]);
    }

    return {'success': true, 'app': appName};
  }
}

class CloseAppExecutor extends TaskExecutor {
  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> taskData) async {
    final appName = taskData['app_name'] as String;

    if (Platform.isMacOS) {
      await Process.run('osascript', [
        '-e',
        'quit app "$appName"',
      ]);
    } else if (Platform.isLinux) {
      await Process.run('killall', [appName]);
    } else if (Platform.isWindows) {
      await Process.run('taskkill', ['/IM', '$appName.exe', '/F']);
    }

    return {'success': true, 'app': appName};
  }
}

class ListAppsExecutor extends TaskExecutor {
  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> taskData) async {
    final result = await Process.run('ps', ['aux']);
    final processes = (result.stdout as String)
        .split('\n')
        .skip(1)
        .where((line) => line.isNotEmpty)
        .take(20)
        .toList();

    return {'success': true, 'processes': processes};
  }
}

/// System operations executors
class ScreenshotExecutor extends TaskExecutor {
  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> taskData) async {
    final outputPath = taskData['output_path'] as String? ??
        '/tmp/screenshot_${DateTime.now().millisecondsSinceEpoch}.png';

    if (Platform.isMacOS) {
      await Process.run('screencapture', [outputPath]);
    } else if (Platform.isLinux) {
      await Process.run('import', ['-window', 'root', outputPath]);
    } else if (Platform.isWindows) {
      // Windows screenshot using PowerShell
      await Process.run('powershell', [
        '-Command',
        'Add-Type -AssemblyName System.Windows.Forms; [System.Windows.Forms.SendKeys]::SendWait("{PRTSC}"); Start-Sleep -Milliseconds 100'
      ]);
    }

    // Read the screenshot file and encode as base64
    final file = File(outputPath);
    if (await file.exists()) {
      final bytes = await file.readAsBytes();
      final base64Image = base64Encode(bytes);
      final fileSize = bytes.length;

      return {
        'success': true,
        'path': outputPath,
        'image_base64': base64Image,
        'size_bytes': fileSize,
      };
    }

    return {'success': true, 'path': outputPath};
  }
}

class SystemInfoExecutor extends TaskExecutor {
  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> taskData) async {
    return {
      'success': true,
      'platform': Platform.operatingSystem,
      'version': Platform.operatingSystemVersion,
      'hostname': Platform.localHostname,
      'processors': Platform.numberOfProcessors,
    };
  }
}

class RunCommandExecutor extends TaskExecutor {
  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> taskData) async {
    final command = taskData['command'] as String;
    final args = (taskData['args'] as List<dynamic>?)?.cast<String>() ?? [];

    final result = await Process.run(command, args);

    return {
      'success': result.exitCode == 0,
      'exit_code': result.exitCode,
      'stdout': result.stdout,
      'stderr': result.stderr,
    };
  }
}

class CheckProcessExecutor extends TaskExecutor {
  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> taskData) async {
    final processName = taskData['process_name'] as String;
    ProcessResult result;

    if (Platform.isMacOS || Platform.isLinux) {
      result = await Process.run('pgrep', ['-i', '-f', processName]);
    } else if (Platform.isWindows) {
      result = await Process.run('tasklist', ['/FI', 'IMAGENAME eq $processName*', '/NH']);
    } else {
      throw UnsupportedError('Platform not supported');
    }

    final isRunning = result.exitCode == 0;
    final output = result.stdout.toString().trim();

    return {
      'success': true,
      'process_name': processName,
      'is_running': isRunning,
      'details': isRunning ? output : 'Process not found',
    };
  }
}

/// Web operations executors
class OpenUrlExecutor extends TaskExecutor {
  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> taskData) async {
    final url = taskData['url'] as String;

    if (Platform.isMacOS) {
      await Process.run('open', [url]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [url]);
    } else if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', url]);
    }

    return {'success': true, 'url': url};
  }
}

class WebSearchExecutor extends TaskExecutor {
  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> taskData) async {
    final query = taskData['query'] as String;
    final searchUrl = 'https://www.google.com/search?q=${Uri.encodeComponent(query)}';

    if (Platform.isMacOS) {
      await Process.run('open', [searchUrl]);
    } else if (Platform.isLinux) {
      await Process.run('xdg-open', [searchUrl]);
    } else if (Platform.isWindows) {
      await Process.run('cmd', ['/c', 'start', searchUrl]);
    }

    return {'success': true, 'query': query, 'url': searchUrl};
  }
}

/// AI operations executors
class AIQueryExecutor extends TaskExecutor {
  static OllamaService? _ollama;

  /// 获取或创建 Ollama 服务实例
  static Future<OllamaService?> _getOllama() async {
    if (_ollama == null) {
      _ollama = OllamaService();
      // 检查是否可用
      if (!await _ollama!.isAvailable()) {
        print('⚠️  Ollama 未运行，将使用降级方案');
        print('   提示: 安装 Ollama 以获得更智能的意图识别');
        print('   brew install ollama && ollama run qwen2.5');
        return null;
      }
      print('✓ Ollama 已连接');
    }
    return _ollama;
  }

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> taskData) async {
    final query = taskData['query'] as String;
    final mode = taskData['mode'] as String? ?? 'general'; // general | intent_recognition

    if (mode == 'intent_recognition') {
      // 意图识别模式
      return await _recognizeIntent(query);
    } else {
      // 通用 AI 查询模式
      final ollama = await _getOllama();
      if (ollama != null) {
        final response = await ollama.query(query);
        return {'success': true, 'query': query, 'response': response};
      } else {
        final response = '💡 Ollama 未运行。\n\n安装方法：\nbrew install ollama\nollama run qwen2.5';
        return {'success': false, 'query': query, 'response': response};
      }
    }
  }

  /// 使用 AI 识别用户意图
  Future<Map<String, dynamic>> _recognizeIntent(String query) async {
    // 优先尝试使用 Ollama
    final ollama = await _getOllama();
    if (ollama != null) {
      try {
        final result = await ollama.recognizeIntent(query);
        if (result['success'] == true) {
          return result;
        }
      } catch (e) {
        print('Ollama 识别失败，使用降级方案: $e');
      }
    }

    // 降级方案：使用启发式规则
    final lowerQuery = query.toLowerCase();

    // 使用启发式规则 + 智能匹配
    if (_containsAny(lowerQuery, ['chrome', 'safari', 'firefox', 'edge', 'vscode', 'xcode', 'wechat', '微信', '浏览器'])) {
      final appName = _extractAppName(query);
      return {
        'success': true,
        'intent': 'open_app',
        'confidence': 0.8,
        'parameters': {'app_name': appName},
      };
    }

    if (_containsAny(lowerQuery, ['截', 'screenshot', 'capture'])) {
      return {
        'success': true,
        'intent': 'screenshot',
        'confidence': 0.9,
        'parameters': {},
      };
    }

    // 无法识别
    return {
      'success': false,
      'intent': 'unknown',
      'confidence': 0.0,
      'error': '无法识别意图，请使用更明确的指令',
    };
  }

  bool _containsAny(String text, List<String> keywords) {
    return keywords.any((keyword) => text.contains(keyword));
  }

  String _extractAppName(String query) {
    // 提取应用名称
    final commonApps = {
      'chrome': 'Google Chrome',
      'safari': 'Safari',
      'firefox': 'Firefox',
      'edge': 'Microsoft Edge',
      'vscode': 'Visual Studio Code',
      'code': 'Visual Studio Code',
      'xcode': 'Xcode',
      'wechat': 'WeChat',
      '微信': 'WeChat',
      '浏览器': 'Safari', // 默认浏览器
    };

    for (final entry in commonApps.entries) {
      if (query.toLowerCase().contains(entry.key)) {
        return entry.value;
      }
    }

    // 提取第一个单词作为应用名
    final match = RegExp(r'(?:打开|open|启动|launch)\s+(\S+)').firstMatch(query);
    return match?.group(1) ?? query;
  }
}

class AIAnalyzeImageExecutor extends TaskExecutor {
  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> taskData) async {
    final imagePath = taskData['image_path'] as String;

    // TODO: Integrate with AI vision service
    final analysis = 'Image analysis of $imagePath (placeholder)';

    return {'success': true, 'image_path': imagePath, 'analysis': analysis};
  }
}
