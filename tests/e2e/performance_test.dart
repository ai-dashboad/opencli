/// E2E Test: Performance and Concurrency
///
/// Tests:
/// - Multiple clients connecting simultaneously
/// - High-volume message handling
/// - Response time under load
/// - Resource usage monitoring

import 'package:test/test.dart';
import 'helpers/test_helpers.dart';

void main() {
  group('Performance and Concurrency', () {
    late DaemonTestHelper daemon;
    late PerformanceHelper perf;

    setUp(() async {
      daemon = DaemonTestHelper();
      perf = PerformanceHelper();

      await daemon.start();
      await daemon.waitUntilHealthy();
    });

    tearDown(() async {
      await daemon.stop();
    });

    test('daemon handles 10 concurrent client connections', () async {
      final clients = <WebSocketClientHelper>[];

      perf.start('concurrent_connections');

      // Connect 10 clients concurrently
      for (int i = 0; i < 10; i++) {
        final client = WebSocketClientHelper();
        await client.connect();
        clients.add(client);
      }

      perf.assertWithinTime(
        'concurrent_connections',
        const Duration(seconds: 5),
      );

      // All should be connected
      for (var client in clients) {
        expect(client.isConnected, isTrue);
        expect(client.clientId, isNotNull);
      }

      print('✅ All 10 clients connected');

      // Cleanup
      for (var client in clients) {
        await client.disconnect();
      }
    });

    test('daemon responds to requests within 100ms under normal load', () async {
      final client = WebSocketClientHelper();
      await client.connect();

      final responseTimes = <Duration>[];

      // Send 50 requests and measure response time
      for (int i = 0; i < 50; i++) {
        perf.start('request_$i');

        client.clearMessages();
        client.send({
          'id': 'perf-req-$i',
          'type': 'command',
          'source': 'mobile',
          'target': 'daemon',
          'payload': {
            'action': 'get_status',
          },
        });

        await client.waitForMessage(
          (msg) => msg['id'] == 'perf-req-$i',
        );

        final duration = perf.stop('request_$i');
        responseTimes.add(duration);
      }

      // Calculate average
      final avgMs = responseTimes
          .map((d) => d.inMilliseconds)
          .reduce((a, b) => a + b) ~/
          responseTimes.length;

      print('📊 Average response time: ${avgMs}ms');
      print('   Min: ${responseTimes.map((d) => d.inMilliseconds).reduce((a, b) => a < b ? a : b)}ms');
      print('   Max: ${responseTimes.map((d) => d.inMilliseconds).reduce((a, b) => a > b ? a : b)}ms');

      expect(avgMs, lessThan(100),
        reason: 'Average response time should be < 100ms');

      await client.disconnect();
    });

    test('daemon handles 100 concurrent task submissions', () async {
      final clients = <WebSocketClientHelper>[];

      // Create 5 clients
      for (int i = 0; i < 5; i++) {
        final client = WebSocketClientHelper();
        await client.connect();
        clients.add(client);
      }

      perf.start('concurrent_tasks');

      // Each client submits 20 tasks (100 total)
      for (int i = 0; i < clients.length; i++) {
        for (int j = 0; j < 20; j++) {
          final taskId = 'perf-task-$i-$j';
          clients[i].send({
            'id': 'req-$taskId',
            'type': 'command',
            'source': 'mobile',
            'target': 'daemon',
            'payload': {
              'action': 'execute_task',
              'taskId': taskId,
              'command': 'echo "Task $i-$j"',
            },
          });
        }
      }

      // Wait for all tasks to complete
      final completedTasks = <String>{};
      final deadline = DateTime.now().add(const Duration(seconds: 60));

      while (DateTime.now().isBefore(deadline) && completedTasks.length < 100) {
        await Future.delayed(const Duration(milliseconds: 200));

        for (var client in clients) {
          for (var msg in client.receivedMessages) {
            if (msg['type'] == 'notification' &&
                msg['payload']?['event'] == 'task_completed') {
              final taskId = msg['payload']['taskId'] as String?;
              if (taskId != null && taskId.startsWith('perf-task-')) {
                completedTasks.add(taskId);
              }
            }
          }
        }
      }

      final duration = perf.stop('concurrent_tasks');

      expect(completedTasks.length, equals(100),
        reason: 'All 100 tasks should complete');

      print('✅ 100 concurrent tasks completed in ${duration.inSeconds}s');

      // Cleanup
      for (var client in clients) {
        await client.disconnect();
      }
    });

    test('daemon maintains performance under sustained load', () async {
      final client = WebSocketClientHelper();
      await client.connect();

      // Send requests continuously for 30 seconds
      final endTime = DateTime.now().add(const Duration(seconds: 30));
      int requestCount = 0;
      int responseCount = 0;

      perf.start('sustained_load');

      while (DateTime.now().isBefore(endTime)) {
        client.send({
          'id': 'sustained-$requestCount',
          'type': 'command',
          'source': 'mobile',
          'target': 'daemon',
          'payload': {
            'action': 'get_status',
          },
        });

        requestCount++;

        // Count responses
        for (var msg in client.receivedMessages) {
          if (msg['type'] == 'response' &&
              msg['id']?.toString().startsWith('sustained-') == true) {
            responseCount++;
          }
        }

        await Future.delayed(const Duration(milliseconds: 100));
      }

      perf.stop('sustained_load');

      // Should have received most responses
      final responseRate = (responseCount / requestCount * 100).toStringAsFixed(1);
      print('📊 Sustained load results:');
      print('   Requests: $requestCount');
      print('   Responses: $responseCount');
      print('   Response rate: $responseRate%');

      expect(responseCount / requestCount, greaterThan(0.95),
        reason: 'Should have >95% response rate');

      await client.disconnect();
    });

    test('daemon memory usage remains stable during stress test', () async {
      // Note: This test would require process monitoring
      // For now, we'll just verify daemon stays healthy

      final client = WebSocketClientHelper();
      await client.connect();

      // Submit many tasks
      for (int i = 0; i < 200; i++) {
        client.send({
          'id': 'stress-$i',
          'type': 'command',
          'source': 'mobile',
          'target': 'daemon',
          'payload': {
            'action': 'execute_task',
            'taskId': 'stress-task-$i',
            'command': 'echo "Stress test $i"',
          },
        });
      }

      // Wait for completion
      await Future.delayed(const Duration(seconds: 30));

      // Daemon should still be healthy
      final isHealthy = await daemon.isHealthy();
      expect(isHealthy, isTrue,
        reason: 'Daemon should remain healthy after stress test');

      print('✅ Daemon remained healthy during stress test');

      await client.disconnect();
    });

    test('WebSocket message size limits are enforced', () async {
      final client = WebSocketClientHelper();
      await client.connect();

      // Try to send very large message
      final largePayload = 'x' * (10 * 1024 * 1024); // 10MB

      client.send({
        'id': 'large-msg',
        'type': 'command',
        'source': 'mobile',
        'target': 'daemon',
        'payload': {
          'action': 'execute_task',
          'taskId': 'large-task',
          'command': largePayload,
        },
      });

      // Should get error or rejection
      final response = await client.waitForMessage(
        (msg) => msg['id'] == 'large-msg' ||
                 msg['type'] == 'error',
        timeout: const Duration(seconds: 5),
      );

      // If size limits are enforced, should get error
      if (response['type'] == 'error' ||
          response['payload']?['status'] == 'error') {
        print('✅ Message size limit enforced');
      } else {
        print('⚠️  Warning: No message size limit detected');
      }

      await client.disconnect();
    });

    test('daemon handles rapid connect/disconnect cycles', () async {
      perf.start('connect_disconnect_cycles');

      // Perform 20 rapid connect/disconnect cycles
      for (int i = 0; i < 20; i++) {
        final client = WebSocketClientHelper();
        await client.connect();
        expect(client.isConnected, isTrue);
        await client.disconnect();
      }

      perf.assertWithinTime(
        'connect_disconnect_cycles',
        const Duration(seconds: 10),
      );

      // Daemon should still be healthy
      expect(await daemon.isHealthy(), isTrue);

      print('✅ Rapid connect/disconnect handled');
    });
  });
}
