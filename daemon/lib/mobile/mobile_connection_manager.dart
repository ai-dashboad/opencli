import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as path;

/// Manages connections from mobile clients
/// Handles authentication, task submission, and real-time updates
class MobileConnectionManager {
  final Map<String, MobileClient> _activeConnections = {};
  final Map<String, String> _deviceTokens = {}; // deviceId -> pushToken
  late HttpServer _server;
  final int port;
  final String authSecret;

  final StreamController<MobileTaskSubmission> _taskSubmissionController =
      StreamController.broadcast();

  Stream<MobileTaskSubmission> get taskSubmissions =>
      _taskSubmissionController.stream;

  /// Get list of connected device IDs
  List<String> get connectedClients => _activeConnections.keys.toList();

  MobileConnectionManager({
    this.port = 8765,
    required this.authSecret,
  });

  /// Start the WebSocket server for mobile connections
  Future<void> start() async {
    var currentPort = port;
    var maxRetries = 10;
    var retryCount = 0;

    while (retryCount < maxRetries) {
      try {
        _server = await HttpServer.bind(InternetAddress.anyIPv4, currentPort);
        print('✓ Mobile connection server listening on port $currentPort');

        // Save actual port to config file
        await _savePortToConfig(currentPort);
        break;
      } catch (e) {
        if (e.toString().contains('Address already in use')) {
          print('⚠️  Port $currentPort is in use, trying ${currentPort + 1}...');
          currentPort++;
          retryCount++;
        } else {
          rethrow;
        }
      }
    }

    if (retryCount >= maxRetries) {
      throw Exception('Failed to find available port after $maxRetries attempts');
    }

    _server.transform(WebSocketTransformer()).listen(
      _handleConnection,
      onError: (error) => print('Server error: $error'),
    );
  }

  /// Stop the server and close all connections
  Future<void> stop() async {
    // Copy values to avoid concurrent modification during iteration
    final clients = _activeConnections.values.toList();
    for (var client in clients) {
      await client.disconnect();
    }
    _activeConnections.clear();
    await _server.close();
    await _taskSubmissionController.close();
  }

  /// Handle new WebSocket connection from mobile client
  void _handleConnection(WebSocket socket) {
    final channel = IOWebSocketChannel(socket);
    String? deviceId;

    channel.stream.listen(
      (message) async {
        try {
          final data = jsonDecode(message as String) as Map<String, dynamic>;
          final type = data['type'] as String;

          switch (type) {
            case 'auth':
              deviceId = await _handleAuth(channel, data);
              break;
            case 'submit_task':
              if (deviceId != null) {
                await _handleTaskSubmission(deviceId!, data);
              } else {
                _sendError(channel, 'Not authenticated');
              }
              break;
            case 'register_push_token':
              if (deviceId != null) {
                _registerPushToken(deviceId!, data['token'] as String);
              }
              break;
            case 'heartbeat':
              _sendMessage(channel, {'type': 'heartbeat_ack'});
              break;
            default:
              _sendError(channel, 'Unknown message type: $type');
          }
        } catch (e) {
          _sendError(channel, 'Invalid message format: $e');
        }
      },
      onDone: () {
        if (deviceId != null) {
          _activeConnections.remove(deviceId);
          print('Mobile client disconnected: $deviceId');
        }
      },
      onError: (error) {
        print('Connection error: $error');
        if (deviceId != null) {
          _activeConnections.remove(deviceId);
        }
      },
    );
  }

  /// Authenticate mobile client
  Future<String?> _handleAuth(
    WebSocketChannel channel,
    Map<String, dynamic> data,
  ) async {
    final deviceId = data['device_id'] as String?;
    final token = data['token'] as String?;
    final timestamp = data['timestamp'] as int?;

    if (deviceId == null || token == null || timestamp == null) {
      _sendError(channel, 'Missing authentication fields');
      return null;
    }

    // Verify timestamp (prevent replay attacks)
    final now = DateTime.now().millisecondsSinceEpoch;
    if ((now - timestamp).abs() > 300000) { // 5 minutes
      _sendError(channel, 'Authentication expired');
      return null;
    }

    // Verify token
    final expectedToken = _generateAuthToken(deviceId, timestamp);
    if (token != expectedToken) {
      _sendError(channel, 'Invalid authentication token');
      return null;
    }

    // Create client session
    final client = MobileClient(
      deviceId: deviceId,
      channel: channel,
      connectedAt: DateTime.now(),
    );

    _activeConnections[deviceId] = client;

    _sendMessage(channel, {
      'type': 'auth_success',
      'device_id': deviceId,
      'server_time': now,
    });

    print('Mobile client authenticated: $deviceId');
    return deviceId;
  }

  /// Generate authentication token
  String _generateAuthToken(String deviceId, int timestamp) {
    final input = '$deviceId:$timestamp:$authSecret';
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Handle task submission from mobile client
  Future<void> _handleTaskSubmission(
    String deviceId,
    Map<String, dynamic> data,
  ) async {
    final taskType = data['task_type'] as String?;
    final taskData = data['task_data'] as Map<String, dynamic>?;
    final priority = data['priority'] as int? ?? 5;

    if (taskType == null || taskData == null) {
      final client = _activeConnections[deviceId];
      if (client != null) {
        _sendError(client.channel, 'Missing task fields');
      }
      return;
    }

    final submission = MobileTaskSubmission(
      deviceId: deviceId,
      taskType: taskType,
      taskData: taskData,
      priority: priority,
      submittedAt: DateTime.now(),
    );

    _taskSubmissionController.add(submission);

    // Broadcast task submission to all connected clients (including Web UI)
    _broadcastMessage({
      'type': 'task_submitted',
      'device_id': deviceId,
      'task_type': taskType,
      'task_data': taskData,
      'timestamp': submission.submittedAt.millisecondsSinceEpoch,
    });
  }

  /// Register push notification token for device
  void _registerPushToken(String deviceId, String pushToken) {
    _deviceTokens[deviceId] = pushToken;
    print('Registered push token for device: $deviceId');
  }

  /// Send task status update to mobile client
  Future<void> sendTaskUpdate(
    String deviceId,
    String taskId,
    String status, {
    Map<String, dynamic>? result,
    String? error,
  }) async {
    final client = _activeConnections[deviceId];

    // Broadcast task update to all connected clients (including Web UI)
    _broadcastMessage({
      'type': 'task_update',
      'device_id': deviceId,
      'task_id': taskId,
      'status': status,
      if (result != null) 'result': result,
      if (error != null) 'error': error,
    });

    if (client == null) {
      // Send push notification if original device is not connected
      final pushToken = _deviceTokens[deviceId];
      if (pushToken != null) {
        await _sendPushNotification(pushToken, taskId, status);
      }
    }
  }

  /// Send push notification (placeholder - integrate with FCM/APNs)
  Future<void> _sendPushNotification(
    String pushToken,
    String taskId,
    String status,
  ) async {
    // TODO: Integrate with Firebase Cloud Messaging for Android
    // TODO: Integrate with Apple Push Notification Service for iOS
    print('Would send push notification to $pushToken: Task $taskId is $status');
  }

  /// Send message to mobile client
  void _sendMessage(WebSocketChannel channel, Map<String, dynamic> message) {
    try {
      channel.sink.add(jsonEncode(message));
    } catch (e) {
      print('Failed to send message: $e');
    }
  }

  /// Broadcast message to all connected clients (including Web UI)
  void _broadcastMessage(Map<String, dynamic> message) {
    for (var client in _activeConnections.values) {
      _sendMessage(client.channel, message);
    }
  }

  /// Send error message to mobile client
  void _sendError(WebSocketChannel channel, String error) {
    _sendMessage(channel, {
      'type': 'error',
      'message': error,
    });
  }

  /// Get list of connected devices
  List<String> getConnectedDevices() {
    return _activeConnections.keys.toList();
  }

  /// Check if device is connected
  bool isDeviceConnected(String deviceId) {
    return _activeConnections.containsKey(deviceId);
  }

  /// Save port to config file for mobile clients
  Future<void> _savePortToConfig(int actualPort) async {
    try {
      final home = Platform.environment['HOME'] ?? '.';
      final configDir = path.join(home, '.opencli');
      final portFile = path.join(configDir, 'mobile_port.txt');

      await Directory(configDir).create(recursive: true);
      await File(portFile).writeAsString('$actualPort');

      print('✓ Saved mobile port to: $portFile');
    } catch (e) {
      print('⚠️  Failed to save port config: $e');
    }
  }
}

/// Represents a connected mobile client
class MobileClient {
  final String deviceId;
  final WebSocketChannel channel;
  final DateTime connectedAt;

  MobileClient({
    required this.deviceId,
    required this.channel,
    required this.connectedAt,
  });

  Future<void> disconnect() async {
    await channel.sink.close();
  }
}

/// Represents a task submitted from mobile
class MobileTaskSubmission {
  final String deviceId;
  final String taskType;
  final Map<String, dynamic> taskData;
  final int priority;
  final DateTime submittedAt;

  MobileTaskSubmission({
    required this.deviceId,
    required this.taskType,
    required this.taskData,
    required this.priority,
    required this.submittedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'device_id': deviceId,
      'task_type': taskType,
      'task_data': taskData,
      'priority': priority,
      'submitted_at': submittedAt.toIso8601String(),
    };
  }
}
