import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'mobile_connection_manager.dart';
import '../services/ollama_service.dart';
import '../capabilities/capabilities.dart';
import '../security/device_pairing.dart';
import '../security/permission_manager.dart';

/// Handles task execution for mobile-submitted tasks
/// Integrates with desktop automation, task queue, and capability system
class MobileTaskHandler {
  final MobileConnectionManager connectionManager;
  final Map<String, TaskExecutor> _executors = {};

  /// Capability system components (optional, can be initialized separately)
  CapabilityLoader? _capabilityLoader;
  CapabilityRegistry? _capabilityRegistry;
  CapabilityExecutor? _capabilityExecutor;
  CapabilityUpdater? _capabilityUpdater;

  /// Permission manager for checking operation permissions
  PermissionManager? _permissionManager;

  /// Whether capability system is initialized
  bool _capabilitiesInitialized = false;

  /// Whether permission system is initialized
  bool _permissionsInitialized = false;

  /// Subscription to confirmation responses
  StreamSubscription<ConfirmationResponse>? _confirmationSubscription;

  MobileTaskHandler({required this.connectionManager}) {
    _registerDefaultExecutors();
    _listenToTaskSubmissions();
  }

  /// Initialize permission system for secure remote control
  Future<void> initializePermissions({
    DevicePairingManager? pairingManager,
  }) async {
    if (_permissionsInitialized) return;

    final pairing = pairingManager ?? connectionManager.pairingManager;
    if (pairing == null) {
      print('[MobileTaskHandler] Warning: No pairing manager available, permissions disabled');
      return;
    }

    print('[MobileTaskHandler] Initializing permission system...');

    _permissionManager = PermissionManager(pairingManager: pairing);

    // Listen for confirmation responses from mobile
    _confirmationSubscription = connectionManager.confirmationResponses.listen(
      (response) {
        if (response.approved) {
          _permissionManager!.approveRequest(response.requestId);
        } else {
          _permissionManager!.denyRequest(response.requestId);
        }
      },
    );

    // Add listener for confirmation requests to send to mobile
    _permissionManager!.addConfirmationListener((request) {
      connectionManager.sendConfirmationRequest(
        deviceId: request.deviceId,
        requestId: request.id,
        operation: request.operation,
        details: request.details,
        timeoutSeconds: request.timeout.inSeconds,
      );
    });

    _permissionsInitialized = true;
    print('[MobileTaskHandler] Permission system initialized');
  }

  /// Initialize capability system for hot-updatable executors
  Future<void> initializeCapabilities({
    String? repositoryUrl,
    bool autoUpdate = true,
  }) async {
    if (_capabilitiesInitialized) return;

    print('[MobileTaskHandler] Initializing capability system...');

    // Create capability loader
    _capabilityLoader = CapabilityLoader(
      repositoryUrl: repositoryUrl ?? 'https://capabilities.opencli.io',
    );

    // Create registry
    _capabilityRegistry = CapabilityRegistry(loader: _capabilityLoader!);
    await _capabilityRegistry!.initialize();

    // Create executor and register action handlers
    _capabilityExecutor = CapabilityExecutor(registry: _capabilityRegistry!);
    _registerCapabilityHandlers();

    // Create updater
    _capabilityUpdater = CapabilityUpdater(
      registry: _capabilityRegistry!,
      loader: _capabilityLoader!,
      config: CapabilityUpdateConfig(
        autoUpdate: autoUpdate,
        checkInterval: const Duration(hours: 1),
        downloadImmediately: false,
      ),
    );
    _capabilityUpdater!.start();

    _capabilitiesInitialized = true;
    print('[MobileTaskHandler] Capability system initialized with ${_capabilityRegistry!.getAll().length} capabilities');
  }

  /// Register capability action handlers that map to existing executors
  void _registerCapabilityHandlers() {
    // Map each executor to a capability action handler
    _executors.forEach((name, executor) {
      _capabilityExecutor!.registerHandler(name, (params, context) async {
        return await executor.execute(params);
      });
    });
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
    registerExecutor('list_processes', ListAppsExecutor());

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

    // Also register with capability executor if initialized
    if (_capabilityExecutor != null) {
      _capabilityExecutor!.registerHandler(taskType, (params, context) async {
        return await executor.execute(params);
      });
    }
  }

  /// Listen to task submissions from mobile
  void _listenToTaskSubmissions() {
    connectionManager.taskSubmissions.listen((submission) async {
      await _executeTask(submission);
    });
  }

  /// Execute a mobile-submitted task
  Future<void> _executeTask(MobileTaskSubmission submission) async {
    final taskId = _generateTaskId(submission);
    final taskType = submission.taskType;
    final taskData = submission.taskData;
    final deviceId = submission.deviceId;

    try {
      // Check permissions if permission system is initialized
      if (_permissionsInitialized && _permissionManager != null) {
        final permResult = await _permissionManager!.checkPermission(
          deviceId: deviceId,
          operation: taskType,
          params: taskData,
        );

        if (!permResult.allowed) {
          if (permResult.requiresConfirmation) {
            // Request confirmation from user
            await connectionManager.sendTaskUpdate(
              deviceId,
              taskId,
              'pending_confirmation',
              result: {
                'message': 'Waiting for confirmation on host device',
                'operation': taskType,
              },
            );

            final confirmed = await _permissionManager!.requestConfirmation(
              deviceId: deviceId,
              operation: taskType,
              details: {
                'task_type': taskType,
                'task_data': taskData,
              },
            );

            if (!confirmed) {
              await connectionManager.sendTaskUpdate(
                deviceId,
                taskId,
                'denied',
                error: 'Operation not confirmed by user',
              );
              return;
            }
            // Confirmation received, continue with execution
          } else {
            // Permission denied without option for confirmation
            await connectionManager.sendTaskUpdate(
              deviceId,
              taskId,
              'denied',
              error: permResult.reason,
            );
            return;
          }
        }

        // If should notify, send notification
        if (permResult.shouldNotify) {
          _sendOperationNotification(deviceId, taskType, taskData);
        }
      }

      // Send task started status
      await connectionManager.sendTaskUpdate(
        deviceId,
        taskId,
        'running',
      );

      Map<String, dynamic> result;

      // Try capability system first if initialized
      if (_capabilitiesInitialized && _capabilityRegistry != null) {
        // Check if this is a capability-based task
        final capability = await _capabilityRegistry!.get(taskType);
        if (capability != null) {
          // Execute via capability system
          final capResult = await _capabilityExecutor!.execute(taskType, taskData);

          if (capResult.success) {
            result = capResult.result;
          } else {
            throw Exception(capResult.error ?? 'Capability execution failed');
          }
        } else {
          // Fall back to direct executor
          result = await _executeWithExecutor(taskType, taskData);
        }
      } else {
        // Use direct executor
        result = await _executeWithExecutor(taskType, taskData);
      }

      // Send success status
      await connectionManager.sendTaskUpdate(
        deviceId,
        taskId,
        'completed',
        result: result,
      );
    } catch (e) {
      // Send error status
      await connectionManager.sendTaskUpdate(
        deviceId,
        taskId,
        'failed',
        error: e.toString(),
      );
    }
  }

  /// Send notification for operation (for notify-level permissions)
  void _sendOperationNotification(
    String deviceId,
    String taskType,
    Map<String, dynamic> taskData,
  ) async {
    // Send system notification on macOS
    if (Platform.isMacOS) {
      final message = _formatOperationMessage(taskType, taskData);
      try {
        await Process.run('osascript', [
          '-e',
          'display notification "$message" with title "OpenCLI Remote"',
        ]);
      } catch (e) {
        print('[MobileTaskHandler] Failed to send notification: $e');
      }
    }
  }

  /// Format operation message for notification
  String _formatOperationMessage(String taskType, Map<String, dynamic> taskData) {
    switch (taskType) {
      case 'open_app':
        return 'Opening ${taskData['app_name'] ?? 'application'}';
      case 'open_url':
        return 'Opening URL: ${taskData['url'] ?? 'unknown'}';
      case 'screenshot':
        return 'Taking screenshot';
      case 'open_file':
        return 'Opening file: ${taskData['path'] ?? 'unknown'}';
      default:
        return 'Executing: $taskType';
    }
  }

  /// Execute task with direct executor
  Future<Map<String, dynamic>> _executeWithExecutor(
    String taskType,
    Map<String, dynamic> taskData,
  ) async {
    final executor = _executors[taskType];

    if (executor == null) {
      throw Exception('Unknown task type: $taskType');
    }

    return await executor.execute(taskData);
  }

  /// Generate task ID from submission
  String _generateTaskId(MobileTaskSubmission submission) {
    return '${submission.deviceId}_${submission.submittedAt.millisecondsSinceEpoch}';
  }

  /// Get available task types (from both executors and capabilities)
  Future<List<String>> getAvailableTaskTypes() async {
    final types = <String>{..._executors.keys};

    if (_capabilitiesInitialized && _capabilityRegistry != null) {
      final capabilities = _capabilityRegistry!.getAll();
      types.addAll(capabilities.map((c) => c.id));
    }

    return types.toList()..sort();
  }

  /// Check for capability updates
  Future<void> checkForUpdates() async {
    if (_capabilityUpdater != null) {
      await _capabilityUpdater!.checkForUpdates();
    }
  }

  /// Apply pending capability updates
  Future<List<String>> applyUpdates() async {
    if (_capabilityUpdater != null) {
      return await _capabilityUpdater!.applyUpdates();
    }
    return [];
  }

  /// Get handler statistics
  Map<String, dynamic> getStats() {
    return {
      'executorCount': _executors.length,
      'executors': _executors.keys.toList(),
      'capabilitiesInitialized': _capabilitiesInitialized,
      'capabilities': _capabilitiesInitialized
          ? _capabilityRegistry?.getStats()
          : null,
      'updates': _capabilitiesInitialized
          ? _capabilityUpdater?.getStatus()
          : null,
      'permissionsInitialized': _permissionsInitialized,
      'permissions': _permissionsInitialized
          ? _permissionManager?.getStats()
          : null,
    };
  }

  /// Get permission statistics
  Map<String, dynamic>? getPermissionStats() {
    return _permissionManager?.getStats();
  }

  /// Dispose resources
  void dispose() {
    _capabilityUpdater?.stop();
    _confirmationSubscription?.cancel();
    _permissionManager?.dispose();
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
  static const _dangerousPatterns = [
    r'rm\s+-rf\s+/', // rm -rf /
    r'rm\s+-rf\s+~', // rm -rf ~
    r'rm\s+-rf\s+\*', // rm -rf *
    r':\(\)\s*\{\s*:\|:\s*&\s*\}', // fork bomb
    r'dd\s+if=/dev/', // dd overwrite
    r'mkfs\.', // format filesystem
    r'>(\/dev\/sda|\/dev\/disk)', // overwrite disk
    r'chmod\s+-R\s+777\s+/', // chmod 777 /
    r'wget.*\|\s*sh', // pipe remote script to shell
    r'curl.*\|\s*sh', // pipe remote script to shell
  ];

  static const _defaultTimeout = Duration(seconds: 120);

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> taskData) async {
    final command = taskData['command'] as String;
    // Handle args as either List or String (JSON may stringify it)
    List<String> args;
    final rawArgs = taskData['args'];
    if (rawArgs is List) {
      args = rawArgs.cast<String>();
    } else if (rawArgs is String) {
      args = rawArgs.isNotEmpty ? [rawArgs] : [];
    } else {
      args = [];
    }
    final workingDir = taskData['working_directory'] as String?;

    // Build the full command string for safety check
    final fullCommand = '$command ${args.join(' ')}';

    // Safety check
    for (final pattern in _dangerousPatterns) {
      if (RegExp(pattern).hasMatch(fullCommand)) {
        return {
          'success': false,
          'command': fullCommand,
          'error': 'Command blocked for safety: matches dangerous pattern',
          'blocked': true,
        };
      }
    }

    // Resolve ~ in working directory
    String? resolvedDir;
    if (workingDir != null) {
      resolvedDir = workingDir.replaceFirst('~', Platform.environment['HOME'] ?? '/tmp');
      if (!await Directory(resolvedDir).exists()) {
        resolvedDir = null; // Fall back to default
      }
    }

    try {
      final result = await Process.run(
        command,
        args,
        workingDirectory: resolvedDir,
      ).timeout(_defaultTimeout);

      return {
        'success': result.exitCode == 0,
        'command': fullCommand,
        'exit_code': result.exitCode,
        'stdout': result.stdout,
        'stderr': result.stderr,
      };
    } on TimeoutException {
      return {
        'success': false,
        'command': fullCommand,
        'error': 'Command timed out after 120 seconds',
        'timed_out': true,
      };
    } catch (e) {
      return {
        'success': false,
        'command': fullCommand,
        'error': 'Command failed: $e',
      };
    }
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

/// File operation executor with rich metadata
class FileOperationExecutor extends TaskExecutor {
  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> taskData) async {
    final operation = taskData['operation'] as String? ?? 'list';

    switch (operation) {
      case 'list':
        return await _listFiles(taskData);
      case 'search':
        return await _searchFiles(taskData);
      case 'create':
        return await _createFile(taskData);
      case 'move':
        return await _moveFile(taskData);
      case 'delete':
        return await _deleteFile(taskData);
      case 'organize':
        return await _organizeFiles(taskData);
      default:
        return {
          'success': false,
          'error': 'Unknown operation: $operation',
        };
    }
  }

  /// List files with rich metadata
  Future<Map<String, dynamic>> _listFiles(Map<String, dynamic> taskData) async {
    final directory = taskData['directory'] as String? ?? Platform.environment['HOME'] ?? '/';
    final expandedDir = directory.replaceFirst('~', Platform.environment['HOME'] ?? '~');

    final dir = Directory(expandedDir);

    if (!await dir.exists()) {
      return {
        'success': false,
        'error': 'Directory not found: $directory',
      };
    }

    final files = <Map<String, dynamic>>[];

    await for (var entity in dir.list()) {
      final stat = await entity.stat();
      final isDirectory = entity is Directory;
      final name = entity.path.split('/').last;
      final extension = isDirectory ? '' : name.contains('.') ? name.split('.').last.toLowerCase() : '';

      files.add({
        'name': name,
        'path': entity.path,
        'is_directory': isDirectory,
        'type': isDirectory ? 'directory' : _getFileType(extension),
        'icon': isDirectory ? '📁' : _getFileIcon(extension),
        'size': stat.size,
        'size_formatted': _formatFileSize(stat.size),
        'modified': stat.modified.toIso8601String(),
        'modified_relative': _formatRelativeTime(stat.modified),
      });
    }

    // Sort: directories first, then by name
    files.sort((a, b) {
      if (a['is_directory'] != b['is_directory']) {
        return a['is_directory'] ? -1 : 1;
      }
      return (a['name'] as String).compareTo(b['name'] as String);
    });

    return {
      'success': true,
      'operation': 'list',
      'directory': directory,
      'files': files,
      'count': files.length,
    };
  }

  /// Search files by pattern
  Future<Map<String, dynamic>> _searchFiles(Map<String, dynamic> taskData) async {
    final directory = taskData['directory'] as String? ?? Platform.environment['HOME'] ?? '/';
    final pattern = taskData['pattern'] as String;
    final expandedDir = directory.replaceFirst('~', Platform.environment['HOME'] ?? '~');

    final dir = Directory(expandedDir);
    final results = <Map<String, dynamic>>[];

    await for (var entity in dir.list(recursive: true)) {
      final name = entity.path.split('/').last;
      if (name.toLowerCase().contains(pattern.toLowerCase())) {
        final stat = await entity.stat();
        final isDirectory = entity is Directory;
        final extension = isDirectory ? '' : name.contains('.') ? name.split('.').last.toLowerCase() : '';

        results.add({
          'name': name,
          'path': entity.path,
          'is_directory': isDirectory,
          'type': isDirectory ? 'directory' : _getFileType(extension),
          'icon': isDirectory ? '📁' : _getFileIcon(extension),
          'size': stat.size,
          'size_formatted': _formatFileSize(stat.size),
          'modified': stat.modified.toIso8601String(),
          'modified_relative': _formatRelativeTime(stat.modified),
        });
      }
    }

    return {
      'success': true,
      'operation': 'search',
      'pattern': pattern,
      'directory': directory,
      'files': results,
      'count': results.length,
    };
  }

  /// Create a new file
  Future<Map<String, dynamic>> _createFile(Map<String, dynamic> taskData) async {
    final filePath = taskData['path'] as String;
    final content = taskData['content'] as String? ?? '';
    final expandedPath = filePath.replaceFirst('~', Platform.environment['HOME'] ?? '~');

    final file = File(expandedPath);
    await file.create(recursive: true);
    await file.writeAsString(content);

    return {
      'success': true,
      'operation': 'create',
      'path': filePath,
      'size': content.length,
    };
  }

  /// Move a file
  Future<Map<String, dynamic>> _moveFile(Map<String, dynamic> taskData) async {
    final from = (taskData['from'] as String).replaceFirst('~', Platform.environment['HOME'] ?? '~');
    final to = (taskData['to'] as String).replaceFirst('~', Platform.environment['HOME'] ?? '~');

    final file = File(from);
    if (!await file.exists()) {
      return {
        'success': false,
        'error': 'Source file not found: $from',
      };
    }

    await file.rename(to);

    return {
      'success': true,
      'operation': 'move',
      'from': taskData['from'],
      'to': taskData['to'],
    };
  }

  /// Delete a file
  Future<Map<String, dynamic>> _deleteFile(Map<String, dynamic> taskData) async {
    final filePath = (taskData['path'] as String).replaceFirst('~', Platform.environment['HOME'] ?? '~');
    final file = File(filePath);

    if (!await file.exists()) {
      return {
        'success': false,
        'error': 'File not found: ${taskData['path']}',
      };
    }

    await file.delete();

    return {
      'success': true,
      'operation': 'delete',
      'path': taskData['path'],
    };
  }

  /// Organize files by type
  Future<Map<String, dynamic>> _organizeFiles(Map<String, dynamic> taskData) async {
    final directory = (taskData['directory'] as String? ?? Platform.environment['HOME'] ?? '/').replaceFirst('~', Platform.environment['HOME'] ?? '~');

    final dir = Directory(directory);
    final moved = <String, String>{};

    await for (var entity in dir.list()) {
      if (entity is File) {
        final name = entity.path.split('/').last;
        final extension = name.contains('.') ? name.split('.').last.toLowerCase() : '';
        final category = _getFileType(extension);
        final targetDir = '$directory/$category';

        await Directory(targetDir).create(recursive: true);
        final newPath = '$targetDir/$name';
        await entity.rename(newPath);

        moved[entity.path] = newPath;
      }
    }

    return {
      'success': true,
      'operation': 'organize',
      'directory': taskData['directory'],
      'files_organized': moved.length,
      'moves': moved,
    };
  }

  /// Get file type category
  String _getFileType(String extension) {
    const typeMap = {
      'txt': 'document',
      'doc': 'document',
      'docx': 'document',
      'pdf': 'document',
      'md': 'document',
      'rtf': 'document',
      'jpg': 'image',
      'jpeg': 'image',
      'png': 'image',
      'gif': 'image',
      'bmp': 'image',
      'svg': 'image',
      'webp': 'image',
      'mp4': 'video',
      'avi': 'video',
      'mov': 'video',
      'mkv': 'video',
      'webm': 'video',
      'mp3': 'audio',
      'wav': 'audio',
      'flac': 'audio',
      'aac': 'audio',
      'm4a': 'audio',
      'js': 'code',
      'ts': 'code',
      'dart': 'code',
      'py': 'code',
      'java': 'code',
      'cpp': 'code',
      'c': 'code',
      'go': 'code',
      'rs': 'code',
      'swift': 'code',
      'zip': 'archive',
      'rar': 'archive',
      'tar': 'archive',
      'gz': 'archive',
      '7z': 'archive',
    };
    return typeMap[extension] ?? 'other';
  }

  /// Get emoji icon for file type
  String _getFileIcon(String extension) {
    const iconMap = {
      'txt': '📄',
      'doc': '📝',
      'docx': '📝',
      'pdf': '📕',
      'md': '📝',
      'jpg': '🖼️',
      'jpeg': '🖼️',
      'png': '🖼️',
      'gif': '🖼️',
      'svg': '🖼️',
      'mp4': '🎬',
      'avi': '🎬',
      'mov': '🎬',
      'mp3': '🎵',
      'wav': '🎵',
      'js': '💻',
      'ts': '💻',
      'dart': '💻',
      'py': '💻',
      'java': '💻',
      'zip': '📦',
      'rar': '📦',
      'tar': '📦',
    };
    return iconMap[extension] ?? '📄';
  }

  /// Format file size to human readable
  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  /// Format relative time
  String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) return 'just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
    if (difference.inHours < 24) return '${difference.inHours} hours ago';
    if (difference.inDays < 30) return '${difference.inDays} days ago';
    if (difference.inDays < 365) return '${(difference.inDays / 30).floor()} months ago';
    return '${(difference.inDays / 365).floor()} years ago';
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

  /// Get or create Ollama service instance
  static Future<OllamaService?> _getOllama() async {
    if (_ollama == null) {
      _ollama = OllamaService();
      // Check if available
      if (!await _ollama!.isAvailable()) {
        print('⚠️  Ollama is not running, using fallback');
        print('   Tip: Install Ollama for smarter intent recognition');
        print('   brew install ollama && ollama run qwen2.5');
        return null;
      }
      print('✓ Ollama connected');
    }
    return _ollama;
  }

  @override
  Future<Map<String, dynamic>> execute(Map<String, dynamic> taskData) async {
    final query = taskData['query'] as String;
    final mode = taskData['mode'] as String? ?? 'general'; // general | intent_recognition

    if (mode == 'intent_recognition') {
      // Intent recognition mode
      return await _recognizeIntent(query);
    } else {
      // General AI query mode
      final ollama = await _getOllama();
      if (ollama != null) {
        final response = await ollama.query(query);
        return {'success': true, 'query': query, 'response': response};
      } else {
        final response = '💡 Ollama is not running.\n\nInstallation:\nbrew install ollama\nollama run qwen2.5';
        return {'success': false, 'query': query, 'response': response};
      }
    }
  }

  /// Use AI to recognize user intent
  Future<Map<String, dynamic>> _recognizeIntent(String query) async {
    // Try Ollama first
    final ollama = await _getOllama();
    if (ollama != null) {
      try {
        final result = await ollama.recognizeIntent(query);
        if (result['success'] == true) {
          return result;
        }
      } catch (e) {
        print('Ollama recognition failed, using fallback: $e');
      }
    }

    // Fallback: use heuristic rules
    final lowerQuery = query.toLowerCase();

    // Heuristic rules + smart matching
    if (_containsAny(lowerQuery, ['chrome', 'safari', 'firefox', 'edge', 'vscode', 'xcode', 'wechat', 'browser'])) {
      final appName = _extractAppName(query);
      return {
        'success': true,
        'intent': 'open_app',
        'confidence': 0.8,
        'parameters': {'app_name': appName},
      };
    }

    if (_containsAny(lowerQuery, ['screenshot', 'capture', 'screen'])) {
      return {
        'success': true,
        'intent': 'screenshot',
        'confidence': 0.9,
        'parameters': {},
      };
    }

    // Unable to recognize
    return {
      'success': false,
      'intent': 'unknown',
      'confidence': 0.0,
      'error': 'Unable to recognize intent, please use a more specific command',
    };
  }

  bool _containsAny(String text, List<String> keywords) {
    return keywords.any((keyword) => text.contains(keyword));
  }

  String _extractAppName(String query) {
    // Extract application name
    final commonApps = {
      'chrome': 'Google Chrome',
      'safari': 'Safari',
      'firefox': 'Firefox',
      'edge': 'Microsoft Edge',
      'vscode': 'Visual Studio Code',
      'code': 'Visual Studio Code',
      'xcode': 'Xcode',
      'wechat': 'WeChat',
      'slack': 'Slack',
      'spotify': 'Spotify',
      'browser': 'Safari', // Default browser
    };

    for (final entry in commonApps.entries) {
      if (query.toLowerCase().contains(entry.key)) {
        return entry.value;
      }
    }

    // Extract first word as app name
    final match = RegExp(r'(?:open|launch|start)\s+(\S+)').firstMatch(query.toLowerCase());
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
