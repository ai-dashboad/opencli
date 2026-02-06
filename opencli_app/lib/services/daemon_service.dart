import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:crypto/crypto.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io';

class DaemonService {
  WebSocketChannel? _channel;
  final String _host;
  final int _port;
  final String _authSecret;
  String? _deviceId;
  bool _isConnected = false;

  final StreamController<Map<String, dynamic>> _messageController =
      StreamController.broadcast();

  // 用于等待任务完成的 completers
  final Map<String, Completer<Map<String, dynamic>>> _pendingTasks = {};

  Stream<Map<String, dynamic>> get messages => _messageController.stream;
  bool get isConnected => _isConnected;

  DaemonService({
    String? host,
    int port = 9876,
    String authSecret = 'opencli-dev-secret',
  })  : _host = host ?? _getDefaultHost(),
        _port = port,
        _authSecret = authSecret;

  /// Get default host based on platform
  /// Android emulator uses 10.0.2.2 to access host machine
  static String _getDefaultHost() {
    if (Platform.isAndroid) {
      return '10.0.2.2';
    }
    return 'localhost';
  }

  Future<void> connect() async {
    if (_isConnected) return;

    try {
      // Get device ID
      _deviceId = await _getDeviceId();

      // Auto-discover port from daemon config
      final actualPort = await _discoverPort();

      // Connect to WebSocket
      final url = 'ws://$_host:$actualPort';
      print('Connecting to daemon at $url');
      _channel = WebSocketChannel.connect(Uri.parse(url));

      // Listen to messages
      _channel!.stream.listen(
        (message) {
          final data = jsonDecode(message as String) as Map<String, dynamic>;
          _handleMessage(data);
        },
        onDone: () {
          _isConnected = false;
          print('Disconnected from daemon');
        },
        onError: (error) {
          _isConnected = false;
          print('WebSocket error: $error');
        },
      );

      // Authenticate
      await _authenticate();

      print('Connected to daemon at $url');
    } catch (e) {
      print('Failed to connect: $e');
      rethrow;
    }
  }

  Future<void> disconnect() async {
    await _channel?.sink.close();
    _channel = null;
    _isConnected = false;
  }

  Future<void> _authenticate() async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final token = _generateAuthToken(_deviceId!, timestamp);

    _send({
      'type': 'auth',
      'device_id': _deviceId,
      'token': token,
      'timestamp': timestamp,
    });
  }

  String _generateAuthToken(String deviceId, int timestamp) {
    final input = '$deviceId:$timestamp:$_authSecret';
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<String> _getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();

    if (Platform.isAndroid) {
      final androidInfo = await deviceInfo.androidInfo;
      return androidInfo.id;
    } else if (Platform.isIOS) {
      final iosInfo = await deviceInfo.iosInfo;
      return iosInfo.identifierForVendor ?? 'ios-unknown';
    } else if (Platform.isMacOS) {
      final macInfo = await deviceInfo.macOsInfo;
      return macInfo.systemGUID ?? 'macos-unknown';
    }

    return 'unknown-device';
  }

  void _handleMessage(Map<String, dynamic> data) {
    final type = data['type'] as String;

    switch (type) {
      case 'auth_success':
        _isConnected = true;
        print('Authentication successful');
        break;
      case 'task_submitted':
        print('Task submitted: ${data['task_type']}');
        break;
      case 'task_update':
        print('Task update: ${data['status']}');
        if (data['result'] != null) {
          print('  Result: ${data['result']}');
        }
        if (data['error'] != null) {
          print('  Error: ${data['error']}');
        }

        // 完成等待中的任务
        final taskId = data['task_id'] as String?;
        final status = data['status'] as String?;
        if (taskId != null && (status == 'completed' || status == 'failed')) {
          final completer = _pendingTasks.remove(taskId);
          if (completer != null && !completer.isCompleted) {
            if (status == 'completed') {
              completer.complete(data['result'] as Map<String, dynamic>? ?? {});
            } else {
              completer.completeError(data['error'] ?? 'Task failed');
            }
          }
        }
        break;
      case 'auth_required':
        _isConnected = false;
        final requiresPairing = data['requires_pairing'] as bool? ?? false;
        print('Auth required from daemon: ${data['message']} (pairing=$requiresPairing)');
        break;
      case 'error':
        print('Error from daemon: ${data['message']}');
        break;
      case 'heartbeat_ack':
        // Heartbeat acknowledged
        break;
    }

    _messageController.add(data);
  }

  void _send(Map<String, dynamic> message) {
    if (_channel == null) {
      throw Exception('Not connected to daemon');
    }
    _channel!.sink.add(jsonEncode(message));
  }

  Future<void> submitTask(String taskType, Map<String, dynamic> taskData,
      {int priority = 5}) async {
    if (!_isConnected) {
      throw Exception('Not connected to daemon');
    }

    _send({
      'type': 'submit_task',
      'task_type': taskType,
      'task_data': taskData,
      'priority': priority,
    });
  }

  /// 提交任务并等待结果
  Future<Map<String, dynamic>> submitTaskAndWait(
    String taskType,
    Map<String, dynamic> taskData, {
    int priority = 5,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (!_isConnected) {
      throw Exception('Not connected to daemon');
    }

    // 生成任务 ID
    final taskId =
        '${_deviceId}_${DateTime.now().millisecondsSinceEpoch}_${taskType}';

    // 创建 completer 来等待结果
    final completer = Completer<Map<String, dynamic>>();
    _pendingTasks[taskId] = completer;

    // 发送任务
    _send({
      'type': 'submit_task',
      'task_id': taskId,
      'task_type': taskType,
      'task_data': taskData,
      'priority': priority,
    });

    // 等待结果或超时
    try {
      return await completer.future.timeout(
        timeout,
        onTimeout: () {
          _pendingTasks.remove(taskId);
          throw TimeoutException('Task timed out after ${timeout.inSeconds}s');
        },
      );
    } catch (e) {
      _pendingTasks.remove(taskId);
      rethrow;
    }
  }

  Future<int> _discoverPort() async {
    try {
      // Try to read port from daemon config file
      final home = Platform.environment['HOME'];
      if (home != null) {
        final portFile = File('$home/.opencli/mobile_port.txt');
        if (await portFile.exists()) {
          final portStr = await portFile.readAsString();
          final port = int.tryParse(portStr.trim());
          if (port != null) {
            print('✓ Discovered daemon port: $port');
            return port;
          }
        }
      }
    } catch (e) {
      print('⚠️  Failed to discover port: $e');
    }

    // Fallback to default port
    print('Using default port: $_port');
    return _port;
  }

  void dispose() {
    _messageController.close();
    disconnect();
  }
}
