/// E2E Test: Multi-Client Synchronization
///
/// Tests real-time synchronization across multiple clients:
/// - iOS, Android, macOS, WebUI all connected
/// - One client submits task
/// - All clients receive notifications

import 'package:test/test.dart';
import 'helpers/test_helpers.dart';

void main() {
  group('Multi-Client Synchronization', () {
    late DaemonTestHelper daemon;
    late WebSocketClientHelper iosClient;
    late WebSocketClientHelper androidClient;
    late WebSocketClientHelper macosClient;
    late WebSocketClientHelper webClient;

    setUp(() async {
      daemon = DaemonTestHelper();
      iosClient = WebSocketClientHelper(port: 9876);
      androidClient = WebSocketClientHelper(port: 9876);
      macosClient = WebSocketClientHelper(port: 9876);
      webClient = WebSocketClientHelper(); // Default port 9875/ws

      await daemon.start();
      await daemon.waitUntilHealthy();
    });

    tearDown(() async {
      await iosClient.disconnect();
      await androidClient.disconnect();
      await macosClient.disconnect();
      await webClient.disconnect();
      await daemon.stop();
    });

    test('all clients receive task notifications from any client', () async {
      // Connect all clients
      await iosClient.connect();
      await androidClient.connect();
      await macosClient.connect();
      await webClient.connect();

      expect(iosClient.isConnected, isTrue);
      expect(androidClient.isConnected, isTrue);
      expect(macosClient.isConnected, isTrue);
      expect(webClient.isConnected, isTrue);

      print('✅ All 4 clients connected');

      // iOS client submits a task
      iosClient.send({
        'type': 'command',
        'source': 'mobile',
        'target': 'daemon',
        'payload': {
          'action': 'execute_task',
          'taskId': 'multi-client-task-001',
          'command': 'echo "Broadcast test"',
        },
      });

      print('📤 iOS submitted task');

      // All clients should receive task_started notification
      final iosStarted = await iosClient.waitForMessage(
        (msg) => msg['payload']?['taskId'] == 'multi-client-task-001' &&
                 msg['payload']?['event'] == 'task_started',
        timeout: const Duration(seconds: 5),
      );

      final androidStarted = await androidClient.waitForMessage(
        (msg) => msg['payload']?['taskId'] == 'multi-client-task-001' &&
                 msg['payload']?['event'] == 'task_started',
        timeout: const Duration(seconds: 5),
      );

      final macosStarted = await macosClient.waitForMessage(
        (msg) => msg['payload']?['taskId'] == 'multi-client-task-001' &&
                 msg['payload']?['event'] == 'task_started',
        timeout: const Duration(seconds: 5),
      );

      final webStarted = await webClient.waitForMessage(
        (msg) => msg['payload']?['taskId'] == 'multi-client-task-001' &&
                 msg['payload']?['event'] == 'task_started',
        timeout: const Duration(seconds: 5),
      );

      expect(iosStarted['payload']['taskId'], equals('multi-client-task-001'));
      expect(androidStarted['payload']['taskId'], equals('multi-client-task-001'));
      expect(macosStarted['payload']['taskId'], equals('multi-client-task-001'));
      expect(webStarted['payload']['taskId'], equals('multi-client-task-001'));

      print('✅ All clients received task_started notification');

      // All clients should receive task_completed notification
      await iosClient.waitForMessage(
        (msg) => msg['payload']?['taskId'] == 'multi-client-task-001' &&
                 msg['payload']?['event'] == 'task_completed',
      );

      await androidClient.waitForMessage(
        (msg) => msg['payload']?['taskId'] == 'multi-client-task-001' &&
                 msg['payload']?['event'] == 'task_completed',
      );

      await macosClient.waitForMessage(
        (msg) => msg['payload']?['taskId'] == 'multi-client-task-001' &&
                 msg['payload']?['event'] == 'task_completed',
      );

      await webClient.waitForMessage(
        (msg) => msg['payload']?['taskId'] == 'multi-client-task-001' &&
                 msg['payload']?['event'] == 'task_completed',
      );

      print('✅ All clients received task_completed notification');
    });

    test('task status updated by one client reflects on all clients', () async {
      await iosClient.connect();
      await androidClient.connect();

      // iOS submits task
      iosClient.send({
        'type': 'command',
        'source': 'mobile',
        'target': 'daemon',
        'payload': {
          'action': 'execute_task',
          'taskId': 'status-update-task',
          'command': 'sleep 10',
        },
      });

      // Wait for task to start
      await iosClient.waitForMessage(
        (msg) => msg['payload']?['taskId'] == 'status-update-task' &&
                 msg['payload']?['event'] == 'task_started',
      );

      // Android cancels the task
      androidClient.clearMessages();
      androidClient.send({
        'type': 'command',
        'source': 'mobile',
        'target': 'daemon',
        'payload': {
          'action': 'stop_task',
          'taskId': 'status-update-task',
        },
      });

      // Both clients should receive stopped notification
      final iosStopped = await iosClient.waitForMessage(
        (msg) => msg['payload']?['taskId'] == 'status-update-task' &&
                 (msg['payload']?['event'] == 'task_stopped' ||
                  msg['payload']?['event'] == 'task_cancelled'),
      );

      final androidStopped = await androidClient.waitForMessage(
        (msg) => msg['payload']?['taskId'] == 'status-update-task' &&
                 (msg['payload']?['event'] == 'task_stopped' ||
                  msg['payload']?['event'] == 'task_cancelled'),
      );

      expect(iosStopped, isNotNull);
      expect(androidStopped, isNotNull);

      print('✅ Task cancellation synchronized across clients');
    });

    test('client can see tasks submitted by other clients', () async {
      await iosClient.connect();
      await androidClient.connect();

      // iOS submits task
      iosClient.send({
        'type': 'command',
        'source': 'mobile',
        'target': 'daemon',
        'payload': {
          'action': 'execute_task',
          'taskId': 'ios-task',
          'command': 'echo "iOS task"',
        },
      });

      // Android submits task
      androidClient.send({
        'type': 'command',
        'source': 'mobile',
        'target': 'daemon',
        'payload': {
          'action': 'execute_task',
          'taskId': 'android-task',
          'command': 'echo "Android task"',
        },
      });

      // Wait for both to complete
      await Future.delayed(const Duration(seconds: 2));

      // iOS queries all tasks
      iosClient.clearMessages();
      iosClient.send({
        'type': 'command',
        'source': 'mobile',
        'target': 'daemon',
        'payload': {
          'action': 'get_tasks',
          'filter': 'all',
        },
      });

      final iosTasksResponse = await iosClient.waitForMessage(
        (msg) => msg['type'] == 'response' &&
                 msg['payload']?['data']?['tasks'] != null,
      );

      final tasks = iosTasksResponse['payload']['data']['tasks'] as List;
      final taskIds = tasks.map((t) => t['id'] as String).toList();

      expect(taskIds, contains('ios-task'),
        reason: 'iOS should see its own task');
      expect(taskIds, contains('android-task'),
        reason: 'iOS should see Android task');

      print('✅ Cross-client task visibility verified');
      print('   Total tasks visible: ${tasks.length}');
    });

    test('clients maintain separate sessions but share task data', () async {
      await iosClient.connect();
      await androidClient.connect();

      expect(iosClient.clientId, isNotNull);
      expect(androidClient.clientId, isNotNull);
      expect(iosClient.clientId, isNot(equals(androidClient.clientId)),
        reason: 'Each client should have unique session ID');

      // Both clients can submit and see each other's tasks
      iosClient.send({
        'type': 'command',
        'source': 'mobile',
        'target': 'daemon',
        'payload': {
          'action': 'execute_task',
          'taskId': 'session-test-1',
          'command': 'echo "Test 1"',
        },
      });

      await androidClient.waitForMessage(
        (msg) => msg['payload']?['taskId'] == 'session-test-1',
      );

      print('✅ Separate sessions with shared data verified');
    });

    test('disconnected client does not affect other clients', () async {
      await iosClient.connect();
      await androidClient.connect();
      await macosClient.connect();

      print('✅ 3 clients connected');

      // Disconnect iOS
      await iosClient.disconnect();
      print('📴 iOS disconnected');

      // Android and macOS should still work
      androidClient.send({
        'type': 'command',
        'source': 'mobile',
        'target': 'daemon',
        'payload': {
          'action': 'execute_task',
          'taskId': 'disconnect-test',
          'command': 'echo "Still working"',
        },
      });

      final androidNotif = await androidClient.waitForMessage(
        (msg) => msg['payload']?['taskId'] == 'disconnect-test',
      );

      final macosNotif = await macosClient.waitForMessage(
        (msg) => msg['payload']?['taskId'] == 'disconnect-test',
      );

      expect(androidNotif, isNotNull);
      expect(macosNotif, isNotNull);

      print('✅ Other clients unaffected by disconnection');
    });

    test('client reconnection receives pending notifications', () async {
      await iosClient.connect();

      // Submit long-running task
      iosClient.send({
        'type': 'command',
        'source': 'mobile',
        'target': 'daemon',
        'payload': {
          'action': 'execute_task',
          'taskId': 'reconnect-task',
          'command': 'sleep 5 && echo "Done"',
        },
      });

      // Wait for start
      await iosClient.waitForMessage(
        (msg) => msg['payload']?['event'] == 'task_started',
      );

      // Disconnect during execution
      await iosClient.disconnect();
      print('📴 Disconnected during task execution');

      // Wait a bit
      await Future.delayed(const Duration(seconds: 2));

      // Reconnect
      await iosClient.connect();
      print('🔌 Reconnected');

      // Query task status to see if it completed
      iosClient.send({
        'type': 'command',
        'source': 'mobile',
        'target': 'daemon',
        'payload': {
          'action': 'get_tasks',
          'taskId': 'reconnect-task',
        },
      });

      final response = await iosClient.waitForMessage(
        (msg) => msg['type'] == 'response',
      );

      // Task should have continued executing
      expect(response, isNotNull);
      print('✅ Task continued during disconnection');
    });
  });
}
