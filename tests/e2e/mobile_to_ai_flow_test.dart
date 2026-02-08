/// E2E Test: Mobile to AI Complete Flow
///
/// Tests the complete flow:
/// Mobile App → Daemon → AI Model → Response → Mobile App

import 'package:test/test.dart';
import 'helpers/test_helpers.dart';

void main() {
  group('Mobile to AI Complete Flow', () {
    late DaemonTestHelper daemon;
    late WebSocketClientHelper mobileClient;
    late PerformanceHelper perf;

    setUp(() async {
      daemon = DaemonTestHelper();
      mobileClient = WebSocketClientHelper(port: 9876); // Legacy mobile port
      perf = PerformanceHelper();

      // Start daemon
      await daemon.start();
      await daemon.waitUntilHealthy();
    });

    tearDown(() async {
      await mobileClient.disconnect();
      await daemon.stop();
    });

    test('mobile app can send chat message and receive AI response', () async {
      // 1. Connect mobile client
      perf.start('mobile_connect');
      await mobileClient.connect();
      perf.assertWithinTime('mobile_connect', const Duration(seconds: 2));

      expect(mobileClient.isConnected, isTrue);
      expect(mobileClient.clientId, isNotNull);

      // 2. Send authentication
      mobileClient.send({
        'type': 'auth',
        'device_id': 'test-device-001',
        'token': 'test-token',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      // Wait for auth response
      final authResponse = await mobileClient.waitForMessage(
        (msg) => msg['type'] == 'auth_response',
        timeout: const Duration(seconds: 5),
      );

      expect(authResponse['success'], isTrue);

      // 3. Send chat message
      perf.start('chat_roundtrip');

      mobileClient.send({
        'type': 'chat',
        'message': 'Hello, AI!',
        'conversation_id': 'test-conversation-001',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      // 4. Wait for AI response
      final aiResponse = await mobileClient.waitForMessage(
        (msg) => msg['type'] == 'chat_response',
        timeout: const Duration(seconds: 30), // AI might take time
      );

      perf.stop('chat_roundtrip');

      // 5. Verify response structure
      expect(aiResponse['type'], equals('chat_response'));
      expect(aiResponse['message'], isNotNull);
      expect(aiResponse['message'], isNotEmpty);
      expect(aiResponse['conversation_id'], equals('test-conversation-001'));

      // 6. Verify response metadata
      expect(aiResponse['model'], isNotNull);
      expect(aiResponse['timestamp'], isNotNull);

      print('✅ Chat flow completed successfully');
      print('   Message: ${aiResponse['message']}');
      print('   Model: ${aiResponse['model']}');
    });

    test('mobile app can stream AI responses in real-time', () async {
      await mobileClient.connect();

      // Authenticate
      mobileClient.send({
        'type': 'auth',
        'device_id': 'test-device-002',
        'token': 'test-token',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      await mobileClient.waitForMessage((msg) => msg['type'] == 'auth_response');

      // Request streaming response
      mobileClient.send({
        'type': 'chat',
        'message': 'Tell me a story',
        'stream': true,
        'conversation_id': 'test-conversation-002',
      });

      // Collect streaming chunks
      final chunks = <Map<String, dynamic>>[];
      var receivedFinal = false;

      final deadline = DateTime.now().add(const Duration(seconds: 60));
      while (DateTime.now().isBefore(deadline) && !receivedFinal) {
        await Future.delayed(const Duration(milliseconds: 100));

        for (var msg in mobileClient.receivedMessages) {
          if (msg['type'] == 'chat_chunk') {
            chunks.add(msg);
          } else if (msg['type'] == 'chat_response') {
            receivedFinal = true;
            break;
          }
        }
      }

      // Verify streaming
      expect(chunks.length, greaterThan(0),
        reason: 'Should have received streaming chunks');
      expect(receivedFinal, isTrue,
        reason: 'Should have received final response');

      // Verify each chunk has content
      for (var chunk in chunks) {
        expect(chunk['chunk'], isNotEmpty);
        expect(chunk['conversation_id'], equals('test-conversation-002'));
      }

      print('✅ Streaming flow completed');
      print('   Received ${chunks.length} chunks');
    });

    test('mobile app receives error for invalid requests', () async {
      await mobileClient.connect();

      // Send invalid message (no type)
      mobileClient.send({
        'message': 'Test',
      });

      // Expect error response
      final errorResponse = await mobileClient.waitForMessage(
        (msg) => msg['type'] == 'error',
        timeout: const Duration(seconds: 5),
      );

      AssertionHelper.assertErrorResponse(errorResponse);

      print('✅ Error handling verified');
    });

    test('mobile app maintains connection during long AI processing', () async {
      await mobileClient.connect();

      mobileClient.send({
        'type': 'auth',
        'device_id': 'test-device-003',
        'token': 'test-token',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      await mobileClient.waitForMessage((msg) => msg['type'] == 'auth_response');

      // Send complex request that takes time
      mobileClient.send({
        'type': 'chat',
        'message': 'Write a detailed technical design document for a microservices architecture',
        'conversation_id': 'test-conversation-003',
      });

      // Wait for response (AI might take 30-60 seconds)
      final response = await mobileClient.waitForMessage(
        (msg) => msg['type'] == 'chat_response',
        timeout: const Duration(seconds: 90),
      );

      expect(response['message'], isNotEmpty);
      expect(mobileClient.isConnected, isTrue,
        reason: 'Connection should remain active during processing');

      print('✅ Long processing connection maintained');
    });

    test('mobile app can switch between AI models', () async {
      await mobileClient.connect();

      mobileClient.send({
        'type': 'auth',
        'device_id': 'test-device-004',
        'token': 'test-token',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      await mobileClient.waitForMessage((msg) => msg['type'] == 'auth_response');

      // Request with Claude
      mobileClient.clearMessages();
      mobileClient.send({
        'type': 'chat',
        'message': 'Hello',
        'model': 'claude-3-sonnet-20240229',
        'conversation_id': 'test-conversation-004a',
      });

      final claudeResponse = await mobileClient.waitForMessage(
        (msg) => msg['type'] == 'chat_response',
      );

      expect(claudeResponse['model'], contains('claude'));

      // Request with GPT-4
      mobileClient.clearMessages();
      mobileClient.send({
        'type': 'chat',
        'message': 'Hello',
        'model': 'gpt-4',
        'conversation_id': 'test-conversation-004b',
      });

      final gptResponse = await mobileClient.waitForMessage(
        (msg) => msg['type'] == 'chat_response',
      );

      expect(gptResponse['model'], contains('gpt'));

      print('✅ Model switching verified');
      print('   Claude: ${claudeResponse['model']}');
      print('   GPT: ${gptResponse['model']}');
    });
  });
}
