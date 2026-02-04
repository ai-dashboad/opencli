/// E2E Test Helper Utilities
///
/// Provides reusable helper classes for end-to-end testing

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:test/test.dart';

/// Helper for managing daemon lifecycle in tests
class DaemonTestHelper {
  Process? _daemonProcess;
  String? _daemonPath;
  bool _isRunning = false;

  DaemonTestHelper({String? daemonPath})
      : _daemonPath = daemonPath ?? '../daemon/bin/daemon.dart';

  /// Start the daemon
  Future<void> start({
    String mode = 'personal',
    Duration startupDelay = const Duration(seconds: 3),
  }) async {
    if (_isRunning) {
      throw StateError('Daemon already running');
    }

    print('🚀 Starting daemon...');

    _daemonProcess = await Process.start(
      'dart',
      ['run', _daemonPath!, '--mode', mode],
      runInShell: true,
    );

    // Listen to output for debugging
    _daemonProcess!.stdout
        .transform(utf8.decoder)
        .listen((data) => print('📤 Daemon: $data'));

    _daemonProcess!.stderr
        .transform(utf8.decoder)
        .listen((data) => print('❌ Daemon Error: $data'));

    // Wait for daemon to start
    await Future.delayed(startupDelay);
    _isRunning = true;
    print('✅ Daemon started');
  }

  /// Stop the daemon
  Future<void> stop() async {
    if (!_isRunning || _daemonProcess == null) {
      return;
    }

    print('🛑 Stopping daemon...');
    _daemonProcess!.kill(ProcessSignal.sigterm);
    await _daemonProcess!.exitCode.timeout(
      const Duration(seconds: 5),
      onTimeout: () {
        print('⚠️  Daemon did not stop gracefully, forcing kill');
        _daemonProcess!.kill(ProcessSignal.sigkill);
        return -1;
      },
    );

    _isRunning = false;
    _daemonProcess = null;
    print('✅ Daemon stopped');
  }

  /// Check if daemon is responding on HTTP
  Future<bool> isHealthy() async {
    try {
      final client = HttpClient();
      final request = await client.get('localhost', 9875, '/health');
      final response = await request.close();
      client.close();
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// Force kill daemon (for crash testing)
  void forceKill() {
    if (_daemonProcess != null) {
      print('💥 Force killing daemon');
      _daemonProcess!.kill(ProcessSignal.sigkill);
      _isRunning = false;
    }
  }

  /// Wait until daemon is healthy
  Future<void> waitUntilHealthy({
    Duration timeout = const Duration(seconds: 30),
    Duration pollInterval = const Duration(milliseconds: 500),
  }) async {
    final deadline = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(deadline)) {
      if (await isHealthy()) {
        print('✅ Daemon is healthy');
        return;
      }
      await Future.delayed(pollInterval);
    }

    throw TimeoutException('Daemon did not become healthy within $timeout');
  }

  bool get isRunning => _isRunning;
}

/// Helper for WebSocket client testing
class WebSocketClientHelper {
  WebSocketChannel? _channel;
  final List<Map<String, dynamic>> _receivedMessages = [];
  final String _host;
  final int _port;
  final String _path;
  String? _clientId;
  bool _isConnected = false;

  StreamSubscription? _subscription;

  WebSocketClientHelper({
    String host = 'localhost',
    int port = 9875,
    String path = '/ws',
  })  : _host = host,
        _port = port,
        _path = path;

  /// Connect to WebSocket
  Future<void> connect() async {
    if (_isConnected) {
      throw StateError('Already connected');
    }

    final url = 'ws://$_host:$_port$_path';
    print('🔌 Connecting to $url...');

    _channel = WebSocketChannel.connect(Uri.parse(url));

    _subscription = _channel!.stream.listen(
      (message) {
        final data = jsonDecode(message as String) as Map<String, dynamic>;
        _receivedMessages.add(data);

        // Extract client ID from welcome message
        if (data['type'] == 'notification' &&
            data['payload']?['event'] == 'connected') {
          _clientId = data['payload']['clientId'] as String?;
        }

        print('📨 Received: ${jsonEncode(data)}');
      },
      onError: (error) {
        print('❌ WebSocket error: $error');
      },
      onDone: () {
        print('🔌 WebSocket closed');
        _isConnected = false;
      },
    );

    _isConnected = true;

    // Wait for welcome message
    await waitForMessage(
      (msg) => msg['type'] == 'notification' &&
               msg['payload']?['event'] == 'connected',
      timeout: const Duration(seconds: 5),
    );

    print('✅ Connected, client ID: $_clientId');
  }

  /// Disconnect from WebSocket
  Future<void> disconnect() async {
    await _subscription?.cancel();
    await _channel?.sink.close();
    _channel = null;
    _subscription = null;
    _isConnected = false;
    print('✅ Disconnected');
  }

  /// Send a message
  void send(Map<String, dynamic> message) {
    if (!_isConnected) {
      throw StateError('Not connected');
    }

    final json = jsonEncode(message);
    _channel!.sink.add(json);
    print('📤 Sent: $json');
  }

  /// Send raw data (for testing invalid JSON)
  void sendRaw(String data) {
    if (!_isConnected) {
      throw StateError('Not connected');
    }

    _channel!.sink.add(data);
    print('📤 Sent raw: $data');
  }

  /// Wait for a message matching predicate
  Future<Map<String, dynamic>> waitForMessage(
    bool Function(Map<String, dynamic>) predicate, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final deadline = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(deadline)) {
      // Check existing messages
      for (var msg in _receivedMessages) {
        if (predicate(msg)) {
          return msg;
        }
      }

      // Wait a bit before checking again
      await Future.delayed(const Duration(milliseconds: 100));
    }

    throw TimeoutException(
      'Message not received within $timeout. '
      'Received: ${_receivedMessages.length} messages'
    );
  }

  /// Get all received messages
  List<Map<String, dynamic>> get receivedMessages =>
      List.unmodifiable(_receivedMessages);

  /// Clear received messages
  void clearMessages() => _receivedMessages.clear();

  /// Check if connected
  bool get isConnected => _isConnected;

  /// Get client ID
  String? get clientId => _clientId;
}

/// Helper for making assertions
class AssertionHelper {
  /// Assert message has expected structure
  static void assertMessageStructure(
    Map<String, dynamic> message, {
    String? expectedType,
    Map<String, dynamic>? expectedPayload,
  }) {
    expect(message, isA<Map<String, dynamic>>());

    if (expectedType != null) {
      expect(message['type'], equals(expectedType));
    }

    if (expectedPayload != null) {
      expect(message['payload'], isA<Map<String, dynamic>>());
      expectedPayload.forEach((key, value) {
        expect(message['payload'][key], equals(value));
      });
    }
  }

  /// Assert task progress notifications
  static void assertTaskProgress(
    List<Map<String, dynamic>> messages,
    String taskId,
  ) {
    final taskMessages = messages.where(
      (msg) => msg['payload']?['taskId'] == taskId
    ).toList();

    expect(taskMessages, isNotEmpty,
      reason: 'Should have received task messages');

    // Should have at least started and completed
    final events = taskMessages
        .map((m) => m['payload']?['event'] as String?)
        .toList();

    expect(events, contains('task_started'));
    expect(events, contains('task_completed'));
  }

  /// Assert response is successful
  static void assertSuccessResponse(Map<String, dynamic> message) {
    expect(message['type'], equals('response'));
    expect(message['payload']['status'], equals('success'));
  }

  /// Assert error response
  static void assertErrorResponse(
    Map<String, dynamic> message, {
    String? expectedError,
  }) {
    expect(message['type'], equals('response'));
    expect(message['payload']['status'], equals('error'));

    if (expectedError != null) {
      expect(message['payload']['error'], contains(expectedError));
    }
  }
}

/// Helper for performance measurements
class PerformanceHelper {
  final Map<String, Stopwatch> _stopwatches = {};

  /// Start timing an operation
  void start(String operation) {
    _stopwatches[operation] = Stopwatch()..start();
  }

  /// Stop timing and return duration
  Duration stop(String operation) {
    final stopwatch = _stopwatches[operation];
    if (stopwatch == null) {
      throw StateError('Timer for $operation not started');
    }

    stopwatch.stop();
    final duration = stopwatch.elapsed;
    print('⏱️  $operation took ${duration.inMilliseconds}ms');
    return duration;
  }

  /// Assert operation completed within time limit
  void assertWithinTime(
    String operation,
    Duration maxDuration,
  ) {
    final duration = stop(operation);
    expect(
      duration,
      lessThan(maxDuration),
      reason: '$operation took ${duration.inMilliseconds}ms, '
              'expected < ${maxDuration.inMilliseconds}ms',
    );
  }

  /// Get all measurements
  Map<String, Duration> get measurements =>
      Map.fromEntries(
        _stopwatches.entries.map(
          (e) => MapEntry(e.key, e.value.elapsed)
        )
      );
}
