import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:web_socket_channel/io.dart';

void main() async {
  print('🌐 Testing Web UI Broadcast...\n');

  // Connect to daemon
  final ws = IOWebSocketChannel.connect('ws://localhost:9876');
  print('✓ Connected to daemon');

  // Generate auth token
  final deviceId = 'web_dashboard_test';
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

  print('📤 Sent authentication...\n');

  // Listen for messages
  ws.stream.listen(
    (message) {
      final data = jsonDecode(message as String) as Map<String, dynamic>;
      final type = data['type'];

      switch (type) {
        case 'auth_success':
          print('✅ Authentication successful!');
          print('📡 Listening for broadcasted messages...\n');
          break;

        case 'task_submitted':
          print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          print('📤 Task Submitted (BROADCAST)');
          print('   Device: ${data['device_id']}');
          print('   Type: ${data['task_type']}');
          if (data['task_data'] != null) {
            print('   Data: ${jsonEncode(data['task_data'])}');
          }
          print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
          break;

        case 'task_update':
          print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
          print('🔄 Task Update (BROADCAST)');
          print('   Device: ${data['device_id']}');
          print('   Status: ${data['status']}');
          if (data['result'] != null) {
            print('   Result: ${jsonEncode(data['result'])}');
          }
          if (data['error'] != null) {
            print('   Error: ${data['error']}');
          }
          print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');
          break;

        case 'error':
          print('❌ Error: ${data['message']}');
          break;

        default:
          print('📨 Unknown message type: $type');
      }
    },
    onError: (error) {
      print('❌ Connection error: $error');
      exit(1);
    },
    onDone: () {
      print('\n👋 Connection closed');
      exit(0);
    },
  );

  // Keep alive
  print('Press Ctrl+C to stop\n');
}
