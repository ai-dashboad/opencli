/// Mobile connection manager for personal mode
///
/// Manages WebSocket connections from mobile devices with automatic
/// pairing, reconnection, and connection health monitoring.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Mobile connection manager
class MobileConnectionManager {
  final int port;
  final PairingManagerRef pairingManager;
  final AutoDiscoveryServiceRef discoveryService;

  HttpServer? _server;
  final Map<String, MobileConnection> _connections = {};
  final _connectionController = StreamController<ConnectionEvent>.broadcast();

  bool _isRunning = false;

  MobileConnectionManager({
    required this.port,
    required this.pairingManager,
    required this.discoveryService,
  });

  /// Stream of connection events
  Stream<ConnectionEvent> get connectionEvents => _connectionController.stream;

  /// Start the mobile connection server
  Future<void> start() async {
    if (_isRunning) return;

    try {
      // Start HTTP server for WebSocket upgrades
      _server = await HttpServer.bind(InternetAddress.anyIPv4, port);

      print('[MobileConnMgr] Server started on port $port');

      // Handle incoming connections
      _server!.listen(_handleConnection);

      // Start auto-discovery service
      await discoveryService.start();

      _isRunning = true;

      print('[MobileConnMgr] Mobile connection manager started');
    } catch (e) {
      print('[MobileConnMgr] Failed to start: $e');
      rethrow;
    }
  }

  /// Stop the mobile connection server
  Future<void> stop() async {
    if (!_isRunning) return;

    // Close all connections
    for (var conn in _connections.values) {
      await conn.close();
    }
    _connections.clear();

    // Stop discovery service
    await discoveryService.stop();

    // Close server
    await _server?.close();
    _server = null;

    _isRunning = false;

    print('[MobileConnMgr] Mobile connection manager stopped');
  }

  /// Handle incoming HTTP connection
  Future<void> _handleConnection(HttpRequest request) async {
    if (request.uri.path == '/ws') {
      await _handleWebSocketUpgrade(request);
    } else if (request.uri.path == '/health') {
      _handleHealthCheck(request);
    } else if (request.uri.path == '/pair') {
      await _handlePairRequest(request);
    } else {
      request.response
        ..statusCode = HttpStatus.notFound
        ..write('Not found')
        ..close();
    }
  }

  /// Handle WebSocket upgrade
  Future<void> _handleWebSocketUpgrade(HttpRequest request) async {
    try {
      final socket = await WebSocketTransformer.upgrade(request);

      print('[MobileConnMgr] WebSocket connection from ${request.connectionInfo?.remoteAddress}');

      // Create mobile connection
      final connection = MobileConnection(
        socket: socket,
        address: request.connectionInfo!.remoteAddress.address,
        connectedAt: DateTime.now(),
      );

      // Listen for messages
      socket.listen(
        (message) => _handleMessage(connection, message),
        onDone: () => _handleDisconnect(connection),
        onError: (error) => _handleError(connection, error),
      );

      // Send welcome message
      _sendWelcome(connection);

    } catch (e) {
      print('[MobileConnMgr] WebSocket upgrade failed: $e');
    }
  }

  /// Handle health check
  void _handleHealthCheck(HttpRequest request) {
    final health = {
      'status': 'ok',
      'connections': _connections.length,
      'uptime': _isRunning ? 'running' : 'stopped',
    };

    request.response
      ..headers.contentType = ContentType.json
      ..write(jsonEncode(health))
      ..close();
  }

  /// Handle pairing request
  Future<void> _handlePairRequest(HttpRequest request) async {
    try {
      final body = await utf8.decoder.bind(request).join();
      final data = jsonDecode(body) as Map<String, dynamic>;

      final code = data['code'] as String;
      final deviceId = data['device_id'] as String;
      final deviceName = data['device_name'] as String;
      final ipAddress = request.connectionInfo!.remoteAddress.address;

      // Verify pairing code
      final pairedDevice = await pairingManager.verifyPairingCode(
        code,
        deviceId,
        deviceName,
        ipAddress,
        metadata: data['metadata'] as Map<String, dynamic>?,
      );

      // Send success response
      request.response
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({
          'success': true,
          'access_token': pairedDevice.accessToken,
          'device': pairedDevice.toJson(),
        }))
        ..close();

      print('[MobileConnMgr] Device paired: $deviceName');

    } catch (e) {
      request.response
        ..statusCode = HttpStatus.badRequest
        ..headers.contentType = ContentType.json
        ..write(jsonEncode({
          'success': false,
          'error': e.toString(),
        }))
        ..close();
    }
  }

  /// Send welcome message to connection
  void _sendWelcome(MobileConnection connection) {
    final welcome = {
      'type': 'welcome',
      'server_version': '1.0.0',
      'server_name': 'OpenCLI Personal',
      'timestamp': DateTime.now().toIso8601String(),
    };

    connection.send(welcome);
  }

  /// Handle incoming message
  void _handleMessage(MobileConnection connection, dynamic message) {
    try {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      final type = data['type'] as String;

      switch (type) {
        case 'auth':
          _handleAuth(connection, data);
          break;
        case 'ping':
          _handlePing(connection, data);
          break;
        case 'task':
          _handleTask(connection, data);
          break;
        case 'status':
          _handleStatusRequest(connection, data);
          break;
        default:
          print('[MobileConnMgr] Unknown message type: $type');
      }
    } catch (e) {
      print('[MobileConnMgr] Failed to handle message: $e');
      connection.sendError('Invalid message format');
    }
  }

  /// Handle authentication
  void _handleAuth(MobileConnection connection, Map<String, dynamic> data) {
    final deviceId = data['device_id'] as String;
    final accessToken = data['access_token'] as String;

    // Verify access token
    if (pairingManager.verifyAccessToken(deviceId, accessToken)) {
      connection.deviceId = deviceId;
      connection.isAuthenticated = true;

      _connections[deviceId] = connection;

      connection.send({
        'type': 'auth_success',
        'device_id': deviceId,
      });

      _connectionController.add(ConnectionEvent(
        type: ConnectionEventType.connected,
        deviceId: deviceId,
      ));

      print('[MobileConnMgr] Device authenticated: $deviceId');
    } else {
      connection.sendError('Authentication failed');
      connection.close();
    }
  }

  /// Handle ping
  void _handlePing(MobileConnection connection, Map<String, dynamic> data) {
    connection.send({
      'type': 'pong',
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Handle task submission
  void _handleTask(MobileConnection connection, Map<String, dynamic> data) {
    if (!connection.isAuthenticated) {
      connection.sendError('Not authenticated');
      return;
    }

    _connectionController.add(ConnectionEvent(
      type: ConnectionEventType.taskReceived,
      deviceId: connection.deviceId!,
      data: data,
    ));

    // Send acknowledgment
    connection.send({
      'type': 'task_received',
      'task_id': data['task_id'],
    });
  }

  /// Handle status request
  void _handleStatusRequest(MobileConnection connection, Map<String, dynamic> data) {
    final status = {
      'type': 'status_response',
      'connections': _connections.length,
      'uptime': 'running',
      'tasks_pending': 0, // Placeholder
    };

    connection.send(status);
  }

  /// Handle disconnection
  void _handleDisconnect(MobileConnection connection) {
    if (connection.deviceId != null) {
      _connections.remove(connection.deviceId);

      _connectionController.add(ConnectionEvent(
        type: ConnectionEventType.disconnected,
        deviceId: connection.deviceId!,
      ));

      print('[MobileConnMgr] Device disconnected: ${connection.deviceId}');
    }
  }

  /// Handle error
  void _handleError(MobileConnection connection, dynamic error) {
    print('[MobileConnMgr] Connection error: $error');
    _handleDisconnect(connection);
  }

  /// Send message to specific device
  bool sendToDevice(String deviceId, Map<String, dynamic> message) {
    final connection = _connections[deviceId];
    if (connection != null) {
      connection.send(message);
      return true;
    }
    return false;
  }

  /// Broadcast message to all connected devices
  void broadcast(Map<String, dynamic> message) {
    for (var connection in _connections.values) {
      connection.send(message);
    }
  }

  /// Get all active connections
  List<MobileConnection> getActiveConnections() {
    return _connections.values.toList();
  }

  /// Check if device is connected
  bool isDeviceConnected(String deviceId) {
    return _connections.containsKey(deviceId);
  }

  bool get isRunning => _isRunning;
}

/// Mobile connection
class MobileConnection {
  final WebSocket socket;
  final String address;
  final DateTime connectedAt;

  String? deviceId;
  bool isAuthenticated = false;
  DateTime lastActivity = DateTime.now();

  MobileConnection({
    required this.socket,
    required this.address,
    required this.connectedAt,
  });

  /// Send message to mobile device
  void send(Map<String, dynamic> message) {
    try {
      socket.add(jsonEncode(message));
      lastActivity = DateTime.now();
    } catch (e) {
      print('[MobileConnection] Failed to send message: $e');
    }
  }

  /// Send error message
  void sendError(String errorMessage) {
    send({
      'type': 'error',
      'error': errorMessage,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  /// Close connection
  Future<void> close() async {
    await socket.close();
  }

  /// Check if connection is active
  bool get isActive {
    final inactiveThreshold = Duration(minutes: 5);
    return DateTime.now().difference(lastActivity) < inactiveThreshold;
  }
}

/// Connection event
class ConnectionEvent {
  final ConnectionEventType type;
  final String deviceId;
  final Map<String, dynamic>? data;

  ConnectionEvent({
    required this.type,
    required this.deviceId,
    this.data,
  });
}

/// Connection event type
enum ConnectionEventType {
  connected,
  disconnected,
  taskReceived,
  error,
}

// Placeholder types (these would reference the actual implementations)
abstract class PairingManagerRef {
  Future<dynamic> verifyPairingCode(
    String code,
    String deviceId,
    String deviceName,
    String ipAddress, {
    Map<String, dynamic>? metadata,
  });
  bool verifyAccessToken(String deviceId, String accessToken);
}

abstract class AutoDiscoveryServiceRef {
  Future<void> start();
  Future<void> stop();
}
