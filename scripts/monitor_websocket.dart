#!/usr/bin/env dart
/// 实时监听 WebSocket 通信

import 'dart:io';
import 'dart:convert';

void main() async {
  print('👂 监听 WebSocket 通信 (ws://localhost:9876)');
  print('按 Ctrl+C 停止\n');
  print('=' * 60);

  try {
    final ws = await WebSocket.connect('ws://localhost:9876');
    print('✅ 已连接到 WebSocket\n');

    ws.listen(
      (message) {
        final timestamp = DateTime.now().toString().substring(11, 19);
        try {
          final data = jsonDecode(message);
          final type = data['type'];

          print('[$timestamp] 📨 收到消息:');
          print('   类型: $type');

          if (type == 'task_submitted') {
            print('   任务类型: ${data['task_type']}');
            print('   优先级: ${data['priority']}');
          } else if (type == 'task_update') {
            print('   状态: ${data['status']}');
            print('   结果: ${data['result']}');
          } else if (type == 'auth_success') {
            print('   设备: ${data['device_id']}');
          }

          print('');
        } catch (e) {
          print('[$timestamp] 原始消息: $message\n');
        }
      },
      onError: (error) {
        print('❌ 错误: $error');
      },
      onDone: () {
        print('\n🔌 连接已关闭');
      },
    );

    // 保持监听
    await Future.delayed(Duration(hours: 1));
  } catch (e) {
    print('❌ 连接失败: $e');
  }
}
