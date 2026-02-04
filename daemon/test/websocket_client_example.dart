import 'dart:io';
import 'package:web_socket_channel/io.dart';
import 'package:opencli_shared/protocol/message.dart';

/// Example WebSocket client demonstrating the unified OpenCLI protocol
///
/// This shows how mobile clients (iOS/Android) can connect to the daemon
/// and send commands using the standardized message format.
void main() async {
  print('🔌 Connecting to OpenCLI Daemon WebSocket...');

  try {
    // Connect to the daemon's WebSocket endpoint
    final channel = IOWebSocketChannel.connect(
      Uri.parse('ws://localhost:9875/ws'),
    );

    print('✓ Connected to ws://localhost:9875/ws');

    // Listen for messages from daemon
    channel.stream.listen(
      (message) {
        print('📨 Received: $message');

        try {
          final msg = OpenCLIMessage.fromJsonString(message);
          print('   Type: ${msg.type.name}');
          print('   Payload: ${msg.payload}');

          // Handle welcome message
          if (msg.type == MessageType.notification &&
              msg.payload['event'] == 'connected') {
            print('\n✓ Successfully connected!');
            print('   Client ID: ${msg.payload['clientId']}');
            print('   Version: ${msg.payload['version']}');

            // Send a test command
            _sendTestCommands(channel);
          }
        } catch (e) {
          print('⚠️  Error parsing message: $e');
        }
      },
      onDone: () {
        print('🔌 Connection closed');
        exit(0);
      },
      onError: (error) {
        print('❌ Connection error: $error');
        exit(1);
      },
    );

    // Keep the program running
    await Future.delayed(Duration(seconds: 30));
    await channel.sink.close();

  } catch (e) {
    print('❌ Failed to connect: $e');
    print('\nMake sure the daemon is running:');
    print('  cd daemon && dart run bin/daemon.dart --mode personal');
    exit(1);
  }
}

/// Send test commands to demonstrate the protocol
void _sendTestCommands(IOWebSocketChannel channel) async {
  print('\n📤 Sending test commands...\n');

  await Future.delayed(Duration(seconds: 1));

  // 1. Get AI models
  print('1️⃣  Requesting AI models list...');
  final modelsCmd = CommandMessageBuilder.getModels(source: ClientType.mobile);
  channel.sink.add(modelsCmd.toJsonString());

  await Future.delayed(Duration(seconds: 2));

  // 2. Get tasks
  print('2️⃣  Requesting tasks list...');
  final tasksCmd = CommandMessageBuilder.getTasks(
    source: ClientType.mobile,
    filter: 'running',
  );
  channel.sink.add(tasksCmd.toJsonString());

  await Future.delayed(Duration(seconds: 2));

  // 3. Get daemon status
  print('3️⃣  Requesting daemon status...');
  final statusCmd = CommandMessageBuilder.getStatus(source: ClientType.mobile);
  channel.sink.add(statusCmd.toJsonString());

  await Future.delayed(Duration(seconds: 2));

  // 4. Execute a task
  print('4️⃣  Executing a test task...');
  final executeCmd = CommandMessageBuilder.executeTask(
    source: ClientType.mobile,
    taskId: 'demo-task-001',
    params: {
      'action': 'echo',
      'message': 'Hello from mobile client!',
    },
  );
  channel.sink.add(executeCmd.toJsonString());

  print('\n✓ All test commands sent!\n');
}
