import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:web_socket_channel/io.dart';

void main() async {
  print('📤 Submitting test task to daemon...\n');

  // Connect to daemon
  final ws = IOWebSocketChannel.connect('ws://localhost:9876');
  print('✓ Connected to daemon');

  // Generate auth token
  final deviceId = 'test_device_${DateTime.now().millisecondsSinceEpoch}';
  final timestamp = DateTime.now().millisecondsSinceEpoch;
  final authSecret = 'opencli-dev-secret';
  final input = '$deviceId:$timestamp:$authSecret';
  final bytes = utf8.encode(input);
  final digest = sha256.convert(bytes);
  final token = digest.toString();

  // Authenticate
  ws.sink.add(jsonEncode({
    'type': 'auth',
    'device_id': deviceId,
    'token': token,
    'timestamp': timestamp,
  }));

  print('📤 Sent authentication...');

  // Wait for auth success
  await Future.delayed(Duration(milliseconds: 500));

  // Submit a test task
  print('📤 Submitting screenshot task...\n');
  ws.sink.add(jsonEncode({
    'type': 'submit_task',
    'task_type': 'screenshot',
    'task_data': {
      'path': '/tmp/test_screenshot.png',
      'test': true,
    },
    'priority': 5,
  }));

  // Listen for response
  var receivedUpdate = false;
  ws.stream.listen(
    (message) {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      print('📨 Received: ${data['type']}');

      if (data['type'] == 'task_update') {
        receivedUpdate = true;
        print('✅ Task completed! Check Web UI for broadcast message.\n');
        ws.sink.close();
        exit(0);
      }
    },
  );

  // Timeout after 15 seconds
  await Future.delayed(Duration(seconds: 15));

  if (!receivedUpdate) {
    print('⏱️  Timeout - no response received');
  }

  ws.sink.close();
  exit(0);
}
