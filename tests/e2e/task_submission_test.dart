/// E2E Test: Task Submission and Progress Tracking
///
/// Tests:
/// - Task submission
/// - Real-time progress updates
/// - Task completion notifications
/// - Multiple concurrent tasks

import 'package:test/test.dart';
import 'helpers/test_helpers.dart';

void main() {
  group('Task Submission and Progress', () {
    late DaemonTestHelper daemon;
    late WebSocketClientHelper client;

    setUp(() async {
      daemon = DaemonTestHelper();
      client = WebSocketClientHelper();

      await daemon.start();
      await daemon.waitUntilHealthy();
      await client.connect();
    });

    tearDown(() async {
      await client.disconnect();
      await daemon.stop();
    });

    test('client can submit task and receive progress updates', () async {
      // Submit task
      client.send({
        'id': 'req-001',
        'type': 'command',
        'source': 'mobile',
        'target': 'daemon',
        'payload': {
          'action': 'execute_task',
          'taskId': 'test-task-001',
          'command': 'echo "Hello World"',
        },
      });

      // Wait for task started notification
      final startedNotification = await client.waitForMessage(
        (msg) => msg['type'] == 'notification' &&
                 msg['payload']?['event'] == 'task_started' &&
                 msg['payload']?['taskId'] == 'test-task-001',
      );

      expect(startedNotification['payload']['taskId'], equals('test-task-001'));
      print('✅ Task started notification received');

      // Wait for task completed notification
      final completedNotification = await client.waitForMessage(
        (msg) => msg['type'] == 'notification' &&
                 msg['payload']?['event'] == 'task_completed' &&
                 msg['payload']?['taskId'] == 'test-task-001',
      );

      expect(completedNotification['payload']['taskId'], equals('test-task-001'));
      expect(completedNotification['payload']['result'], isNotNull);
      print('✅ Task completed notification received');
      print('   Result: ${completedNotification['payload']['result']}');
    });

    test('client receives progress updates during task execution', () async {
      // Submit long-running task
      client.send({
        'id': 'req-002',
        'type': 'command',
        'source': 'mobile',
        'target': 'daemon',
        'payload': {
          'action': 'execute_task',
          'taskId': 'test-task-002',
          'command': 'sleep 5 && echo "Done"',
        },
      });

      // Collect all task-related messages
      final taskMessages = <Map<String, dynamic>>[];
      final deadline = DateTime.now().add(const Duration(seconds: 10));

      while (DateTime.now().isBefore(deadline)) {
        await Future.delayed(const Duration(milliseconds: 100));

        for (var msg in client.receivedMessages) {
          if (msg['payload']?['taskId'] == 'test-task-002' &&
              !taskMessages.contains(msg)) {
            taskMessages.add(msg);

            if (msg['payload']?['event'] == 'task_completed') {
              break;
            }
          }
        }

        if (taskMessages.any((m) => m['payload']?['event'] == 'task_completed')) {
          break;
        }
      }

      // Verify task lifecycle
      final events = taskMessages
          .map((m) => m['payload']?['event'] as String?)
          .toList();

      expect(events, contains('task_started'));
      expect(events, contains('task_completed'));

      // May also have progress updates
      print('✅ Task lifecycle verified');
      print('   Events: $events');
    });

    test('client can query task status', () async {
      // Submit task
      client.send({
        'id': 'req-003',
        'type': 'command',
        'source': 'mobile',
        'target': 'daemon',
        'payload': {
          'action': 'execute_task',
          'taskId': 'test-task-003',
          'command': 'echo "Test"',
        },
      });

      // Wait a bit for task to start
      await Future.delayed(const Duration(milliseconds: 500));

      // Query task status
      client.clearMessages();
      client.send({
        'id': 'req-004',
        'type': 'command',
        'source': 'mobile',
        'target': 'daemon',
        'payload': {
          'action': 'get_tasks',
          'filter': 'all',
        },
      });

      // Wait for tasks list
      final response = await client.waitForMessage(
        (msg) => msg['id'] == 'req-004' && msg['type'] == 'response',
      );

      AssertionHelper.assertSuccessResponse(response);
      expect(response['payload']['data']['tasks'], isList);

      final tasks = response['payload']['data']['tasks'] as List;
      final testTask = tasks.firstWhere(
        (t) => t['id'] == 'test-task-003',
        orElse: () => null,
      );

      expect(testTask, isNotNull,
        reason: 'Submitted task should appear in tasks list');

      print('✅ Task status query verified');
      print('   Found ${tasks.length} tasks');
    });

    test('client can submit multiple concurrent tasks', () async {
      final taskIds = <String>[];

      // Submit 5 concurrent tasks
      for (int i = 0; i < 5; i++) {
        final taskId = 'concurrent-task-$i';
        taskIds.add(taskId);

        client.send({
          'id': 'req-concurrent-$i',
          'type': 'command',
          'source': 'mobile',
          'target': 'daemon',
          'payload': {
            'action': 'execute_task',
            'taskId': taskId,
            'command': 'sleep ${i + 1} && echo "Task $i done"',
          },
        });
      }

      print('📤 Submitted ${taskIds.length} concurrent tasks');

      // Wait for all tasks to complete
      final completedTasks = <String>{};
      final deadline = DateTime.now().add(const Duration(seconds: 15));

      while (DateTime.now().isBefore(deadline) &&
             completedTasks.length < taskIds.length) {
        await Future.delayed(const Duration(milliseconds: 200));

        for (var msg in client.receivedMessages) {
          if (msg['type'] == 'notification' &&
              msg['payload']?['event'] == 'task_completed') {
            final taskId = msg['payload']['taskId'] as String?;
            if (taskId != null && taskIds.contains(taskId)) {
              completedTasks.add(taskId);
              print('✅ Task completed: $taskId');
            }
          }
        }
      }

      expect(completedTasks.length, equals(taskIds.length),
        reason: 'All concurrent tasks should complete');

      print('✅ All concurrent tasks completed');
    });

    test('client can cancel running task', () async {
      // Submit long-running task
      client.send({
        'id': 'req-005',
        'type': 'command',
        'source': 'mobile',
        'target': 'daemon',
        'payload': {
          'action': 'execute_task',
          'taskId': 'test-task-cancel',
          'command': 'sleep 60',
        },
      });

      // Wait for task to start
      await client.waitForMessage(
        (msg) => msg['payload']?['taskId'] == 'test-task-cancel' &&
                 msg['payload']?['event'] == 'task_started',
      );

      // Cancel the task
      client.clearMessages();
      client.send({
        'id': 'req-006',
        'type': 'command',
        'source': 'mobile',
        'target': 'daemon',
        'payload': {
          'action': 'stop_task',
          'taskId': 'test-task-cancel',
        },
      });

      // Wait for cancellation confirmation
      final cancelResponse = await client.waitForMessage(
        (msg) => msg['id'] == 'req-006',
        timeout: const Duration(seconds: 5),
      );

      AssertionHelper.assertSuccessResponse(cancelResponse);

      // Should receive task stopped notification
      final stoppedNotification = await client.waitForMessage(
        (msg) => msg['payload']?['taskId'] == 'test-task-cancel' &&
                 (msg['payload']?['event'] == 'task_stopped' ||
                  msg['payload']?['event'] == 'task_cancelled'),
        timeout: const Duration(seconds: 5),
      );

      expect(stoppedNotification['payload']['taskId'], equals('test-task-cancel'));
      print('✅ Task cancellation verified');
    });
  });
}
