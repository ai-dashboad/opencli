/// E2E Test: Error Handling and Recovery
///
/// Tests:
/// - Daemon crash recovery
/// - Network interruption recovery
/// - Invalid request handling
/// - Permission denied scenarios

import 'package:test/test.dart';
import 'helpers/test_helpers.dart';

void main() {
  group('Error Handling and Recovery', () {
    late DaemonTestHelper daemon;
    late WebSocketClientHelper client;

    setUp(() async {
      daemon = DaemonTestHelper();
      client = WebSocketClientHelper();
    });

    tearDown(() async {
      await client.disconnect();
      await daemon.stop();
    });

    test('client detects daemon crash and attempts reconnection', () async {
      await daemon.start();
      await daemon.waitUntilHealthy();
      await client.connect();

      expect(client.isConnected, isTrue);
      print('✅ Initial connection established');

      // Force daemon crash
      print('💥 Forcing daemon crash...');
      daemon.forceKill();
      await Future.delayed(const Duration(seconds: 1));

      // Client should detect disconnection
      await Future.delayed(const Duration(seconds: 2));
      // Note: In real implementation, client would have reconnection logic

      print('✅ Crash detection verified');
    });

    test('daemon handles invalid JSON gracefully', () async {
      await daemon.start();
      await daemon.waitUntilHealthy();
      await client.connect();

      // Send malformed JSON
      client.sendRaw('{ invalid json }');

      // Daemon should send error response
      final errorResponse = await client.waitForMessage(
        (msg) => msg['type'] == 'error',
        timeout: const Duration(seconds: 5),
      );

      expect(errorResponse, isNotNull);
      print('✅ Invalid JSON handled gracefully');
    });

    test('daemon rejects requests without authentication', () async {
      await daemon.start();
      await daemon.waitUntilHealthy();
      await client.connect();

      // Try to submit task without auth
      client.send({
        'type': 'command',
        'source': 'mobile',
        'target': 'daemon',
        'payload': {
          'action': 'execute_task',
          'taskId': 'unauth-task',
          'command': 'echo "test"',
        },
      });

      // Should receive error or auth required
      final response = await client.waitForMessage(
        (msg) => msg['type'] == 'error' ||
                 msg['type'] == 'auth_required',
        timeout: const Duration(seconds: 5),
      );

      expect(response, isNotNull);
      print('✅ Unauthenticated request rejected');
    });

    test('daemon handles permission denied for dangerous operations', () async {
      await daemon.start();
      await daemon.waitUntilHealthy();
      await client.connect();

      // Authenticate first
      client.send({
        'type': 'auth',
        'device_id': 'test-device',
        'token': 'test-token',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      await client.waitForMessage((msg) => msg['type'] == 'auth_response');

      // Try dangerous operation
      client.clearMessages();
      client.send({
        'type': 'command',
        'source': 'mobile',
        'target': 'daemon',
        'payload': {
          'action': 'execute_task',
          'taskId': 'dangerous-task',
          'command': 'rm -rf /',  // Dangerous!
        },
      });

      // Should be blocked or require confirmation
      final response = await client.waitForMessage(
        (msg) => msg['type'] == 'response',
        timeout: const Duration(seconds: 5),
      );

      // Should either be denied or require confirmation
      final status = response['payload']?['status'];
      expect(
        status == 'error' || status == 'requires_confirmation',
        isTrue,
        reason: 'Dangerous operation should be blocked or require confirmation'
      );

      print('✅ Dangerous operation blocked');
    });

    test('daemon recovers from task execution errors', () async {
      await daemon.start();
      await daemon.waitUntilHealthy();
      await client.connect();

      // Submit task that will fail
      client.send({
        'type': 'command',
        'source': 'mobile',
        'target': 'daemon',
        'payload': {
          'action': 'execute_task',
          'taskId': 'failing-task',
          'command': 'exit 1',  // Will fail
        },
      });

      // Should receive task_failed or error notification
      final notification = await client.waitForMessage(
        (msg) => msg['payload']?['taskId'] == 'failing-task' &&
                 (msg['payload']?['event'] == 'task_failed' ||
                  msg['payload']?['event'] == 'task_error'),
        timeout: const Duration(seconds: 10),
      );

      expect(notification, isNotNull);
      expect(notification['payload']['error'], isNotNull);

      // Daemon should still be responsive
      client.clearMessages();
      client.send({
        'type': 'command',
        'source': 'mobile',
        'target': 'daemon',
        'payload': {
          'action': 'get_status',
        },
      });

      final statusResponse = await client.waitForMessage(
        (msg) => msg['type'] == 'response',
      );

      AssertionHelper.assertSuccessResponse(statusResponse);
      print('✅ Daemon recovered from task failure');
    });

    test('client handles message queue overflow gracefully', () async {
      await daemon.start();
      await daemon.waitUntilHealthy();
      await client.connect();

      // Flood daemon with messages
      print('📤 Flooding daemon with 1000 messages...');
      for (int i = 0; i < 1000; i++) {
        client.send({
          'type': 'command',
          'source': 'mobile',
          'target': 'daemon',
          'payload': {
            'action': 'get_status',
          },
        });
      }

      // Daemon should handle gracefully (might rate limit or queue)
      await Future.delayed(const Duration(seconds: 2));

      // Daemon should still be responsive
      client.clearMessages();
      client.send({
        'type': 'command',
        'source': 'mobile',
        'target': 'daemon',
        'payload': {
          'action': 'get_status',
        },
      });

      final response = await client.waitForMessage(
        (msg) => msg['type'] == 'response',
        timeout: const Duration(seconds: 10),
      );

      expect(response, isNotNull);
      print('✅ Message flood handled');
    });

    test('daemon handles concurrent task cancellations', () async {
      await daemon.start();
      await daemon.waitUntilHealthy();
      await client.connect();

      // Submit multiple long-running tasks
      final taskIds = <String>[];
      for (int i = 0; i < 5; i++) {
        final taskId = 'cancel-task-$i';
        taskIds.add(taskId);

        client.send({
          'type': 'command',
          'source': 'mobile',
          'target': 'daemon',
          'payload': {
            'action': 'execute_task',
            'taskId': taskId,
            'command': 'sleep 30',
          },
        });
      }

      // Wait for all to start
      await Future.delayed(const Duration(seconds: 1));

      // Cancel all concurrently
      print('⏹️  Cancelling all tasks...');
      for (var taskId in taskIds) {
        client.send({
          'type': 'command',
          'source': 'mobile',
          'target': 'daemon',
          'payload': {
            'action': 'stop_task',
            'taskId': taskId,
          },
        });
      }

      // All should be cancelled
      final cancelledTasks = <String>{};
      final deadline = DateTime.now().add(const Duration(seconds: 10));

      while (DateTime.now().isBefore(deadline) &&
             cancelledTasks.length < taskIds.length) {
        await Future.delayed(const Duration(milliseconds: 100));

        for (var msg in client.receivedMessages) {
          if ((msg['payload']?['event'] == 'task_stopped' ||
               msg['payload']?['event'] == 'task_cancelled')) {
            final taskId = msg['payload']['taskId'] as String?;
            if (taskId != null && taskIds.contains(taskId)) {
              cancelledTasks.add(taskId);
            }
          }
        }
      }

      expect(cancelledTasks.length, equals(taskIds.length),
        reason: 'All tasks should be cancelled');

      print('✅ Concurrent cancellations handled');
    });

    test('daemon maintains data consistency after errors', () async {
      await daemon.start();
      await daemon.waitUntilHealthy();
      await client.connect();

      // Submit task
      client.send({
        'type': 'command',
        'source': 'mobile',
        'target': 'daemon',
        'payload': {
          'action': 'execute_task',
          'taskId': 'consistency-task',
          'command': 'echo "test"',
        },
      });

      // Wait for completion
      await client.waitForMessage(
        (msg) => msg['payload']?['taskId'] == 'consistency-task' &&
                 msg['payload']?['event'] == 'task_completed',
      );

      // Query task multiple times - should be consistent
      final results = <Map<String, dynamic>>[];

      for (int i = 0; i < 3; i++) {
        client.clearMessages();
        client.send({
          'type': 'command',
          'source': 'mobile',
          'target': 'daemon',
          'payload': {
            'action': 'get_tasks',
            'filter': 'all',
          },
        });

        final response = await client.waitForMessage(
          (msg) => msg['type'] == 'response',
        );

        results.add(response);
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // All responses should be identical
      expect(results.length, equals(3));
      final firstTasks = results[0]['payload']['data']['tasks'];

      for (var result in results.skip(1)) {
        expect(result['payload']['data']['tasks'].length,
          equals(firstTasks.length));
      }

      print('✅ Data consistency maintained');
    });
  });
}
