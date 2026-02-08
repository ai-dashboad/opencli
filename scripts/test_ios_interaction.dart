#!/usr/bin/env dart
/// 测试 iOS 与 Daemon 的交互
/// 模拟发送任务并监听响应

import 'dart:io';
import 'dart:convert';

void main() async {
  print('🧪 测试 iOS <-> Daemon 交互\n');
  print('=' * 60);

  // 1. 检查 Daemon 状态
  print('\n1️⃣  检查 Daemon 状态...');
  final statusResponse = await HttpClient()
      .getUrl(Uri.parse('http://localhost:9875/status'))
      .then((request) => request.close())
      .then((response) => response.transform(utf8.decoder).join());

  final status = jsonDecode(statusResponse);
  print('   ✅ Daemon 版本: ${status['daemon']['version']}');
  print('   ✅ 运行时间: ${status['daemon']['uptime_seconds']} 秒');
  print('   ✅ 连接客户端: ${status['mobile']['connected_clients']}');
  print('   📱 客户端 ID: ${status['mobile']['client_ids']}');

  // 2. 连接 WebSocket
  print('\n2️⃣  连接到 WebSocket (ws://localhost:9876)...');
  try {
    final ws = await WebSocket.connect('ws://localhost:9876');
    print('   ✅ WebSocket 连接成功');

    // 3. 发送认证
    print('\n3️⃣  发送认证信息...');
    final deviceId = 'test-device-${DateTime.now().millisecondsSinceEpoch}';
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    ws.add(jsonEncode({
      'type': 'auth',
      'device_id': deviceId,
      'token': 'test-token',
      'timestamp': timestamp,
    }));

    // 监听响应
    bool authenticated = false;
    final responses = <String>[];

    ws.listen(
      (message) {
        final data = jsonDecode(message);
        responses.add(message);

        if (data['type'] == 'auth_success') {
          authenticated = true;
          print('   ✅ 认证成功！');
        } else if (data['type'] == 'task_submitted') {
          print('   ✅ 任务已提交: ${data['task_type']}');
        } else if (data['type'] == 'task_update') {
          print('   📊 任务更新: ${data['status']}');
        }
      },
      onError: (error) => print('   ❌ 错误: $error'),
      onDone: () => print('   🔌 连接关闭'),
    );

    await Future.delayed(Duration(seconds: 2));

    if (authenticated) {
      // 4. 测试发送任务
      print('\n4️⃣  测试发送任务...');

      final testTasks = [
        {'type': 'system_info', 'data': {}},
        {'type': 'screenshot', 'data': {}},
      ];

      for (final task in testTasks) {
        print('\n   📤 发送任务: ${task['type']}');
        ws.add(jsonEncode({
          'type': 'submit_task',
          'task_type': task['type'],
          'task_data': task['data'],
          'priority': 5,
        }));

        await Future.delayed(Duration(seconds: 1));
      }

      // 等待响应
      print('\n   ⏳ 等待任务响应...');
      await Future.delayed(Duration(seconds: 3));

      print('\n   📨 收到的消息总数: ${responses.length}');
    }

    await ws.close();
    print('\n✅ 测试完成');
  } catch (e) {
    print('   ❌ WebSocket 连接失败: $e');
  }

  // 5. 再次检查状态
  print('\n5️⃣  测试后状态检查...');
  final finalStatus = await HttpClient()
      .getUrl(Uri.parse('http://localhost:9875/status'))
      .then((request) => request.close())
      .then((response) => response.transform(utf8.decoder).join());

  final final_data = jsonDecode(finalStatus);
  print('   📱 当前连接客户端: ${final_data['mobile']['connected_clients']}');
  print('   📊 总请求数: ${final_data['daemon']['total_requests']}');

  print('\n' + '=' * 60);
  print('🎉 交互测试完成！');
}
