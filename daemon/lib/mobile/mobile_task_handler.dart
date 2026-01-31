import 'dart:async';
import 'dart:io';
import 'mobile_connection_manager.dart';

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

/// AI operations executors (placeholders for AI integration)
class AIQueryExecutor extends TaskExecutor {
  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> taskData) async {
    final query = taskData['query'] as String;

    // TODO: Integrate with AI service (Claude, GPT, etc.)
    final response = 'AI response to: $query (placeholder)';

    return {'success': true, 'query': query, 'response': response};
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
