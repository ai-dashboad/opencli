import 'dart:async';
import 'package:shelf/shelf.dart';
import 'package:shelf_web_socket/shelf_web_socket.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:opencli_shared/protocol/message.dart';

/// WebSocket 消息处理器
/// 处理来自所有客户端（Desktop、Mobile、Web）的消息
class MessageHandler {
  /// 已连接的客户端
  final Map<String, WebSocketChannel> _clients = {};

  /// 消息处理器映射
  final Map<String, Future<Map<String, dynamic>> Function(Map<String, dynamic>)>
      _handlers = {};

  MessageHandler() {
    _registerHandlers();
  }

  /// 注册消息处理器
  void _registerHandlers() {
    // 执行任务
    _handlers['execute_task'] = _handleExecuteTask;

    // 停止任务
    _handlers['stop_task'] = _handleStopTask;

    // 获取任务列表
    _handlers['get_tasks'] = _handleGetTasks;

    // 获取 AI 模型列表
    _handlers['get_models'] = _handleGetModels;

    // 发送聊天消息
    _handlers['send_chat'] = _handleSendChat;

    // 获取状态
    _handlers['get_status'] = _handleGetStatus;
  }

  /// 创建 WebSocket 处理器
  Handler get handler {
    return webSocketHandler((WebSocketChannel webSocket) {
      final clientId = _generateClientId();
      _clients[clientId] = webSocket;

      print('📱 Client connected: $clientId (Total: ${_clients.length})');

      // 发送欢迎消息
      _sendWelcomeMessage(webSocket, clientId);

      // 监听消息
      webSocket.stream.listen(
        (dynamic message) {
          _handleMessage(clientId, message);
        },
        onDone: () {
          _clients.remove(clientId);
          print('📱 Client disconnected: $clientId (Total: ${_clients.length})');
        },
        onError: (error) {
          print('❌ WebSocket error for $clientId: $error');
          _clients.remove(clientId);
        },
      );
    });
  }

  /// 发送欢迎消息
  void _sendWelcomeMessage(WebSocketChannel webSocket, String clientId) {
    final welcome = OpenCLIMessage(
      id: _generateId(),
      type: MessageType.notification,
      source: ClientType.desktop,
      target: TargetType.specific,
      payload: {
        'event': 'connected',
        'clientId': clientId,
        'message': 'Welcome to OpenCLI Daemon',
        'version': '0.2.0',
      },
    );

    webSocket.sink.add(welcome.toJsonString());
  }

  /// 处理接收到的消息
  Future<void> _handleMessage(String clientId, dynamic rawMessage) async {
    try {
      // 解析消息
      final message = OpenCLIMessage.fromJsonString(rawMessage as String);

      print('📨 Message from $clientId: ${message.type.name} - ${message.payload['action']}');

      // 根据消息类型处理
      if (message.type == MessageType.command) {
        await _handleCommand(clientId, message);
      } else if (message.type == MessageType.heartbeat) {
        await _handleHeartbeat(clientId, message);
      }
    } catch (e) {
      print('❌ Failed to handle message: $e');
      _sendErrorResponse(clientId, 'unknown', 'Invalid message format: $e');
    }
  }

  /// 处理命令消息
  Future<void> _handleCommand(String clientId, OpenCLIMessage message) async {
    final action = message.payload['action'] as String?;

    if (action == null) {
      _sendErrorResponse(clientId, message.id, 'Missing action in command');
      return;
    }

    // 查找处理器
    final handler = _handlers[action];

    if (handler == null) {
      _sendErrorResponse(clientId, message.id, 'Unknown action: $action');
      return;
    }

    try {
      // 执行处理器
      final result = await handler(message.payload);

      // 发送成功响应
      final response = ResponseMessageBuilder.success(
        requestId: message.id,
        data: result,
      );

      _sendToClient(clientId, response);
    } catch (e) {
      print('❌ Handler error for $action: $e');
      _sendErrorResponse(clientId, message.id, 'Handler error: $e');
    }
  }

  /// 处理心跳消息
  Future<void> _handleHeartbeat(String clientId, OpenCLIMessage message) async {
    // 回复心跳
    final pong = OpenCLIMessage(
      id: _generateId(),
      type: MessageType.heartbeat,
      source: ClientType.desktop,
      target: TargetType.specific,
      payload: {'pong': true},
    );

    _sendToClient(clientId, pong);
  }

  // ========== 命令处理器 ==========

  /// 处理执行任务命令
  Future<Map<String, dynamic>> _handleExecuteTask(Map<String, dynamic> payload) async {
    final taskId = payload['taskId'] as String;
    final params = payload['params'] as Map<String, dynamic>? ?? {};

    print('🚀 Executing task: $taskId with params: $params');

    // TODO: 实际执行任务逻辑
    // 这里需要集成任务执行系统

    // 模拟任务执行
    await Future.delayed(Duration(seconds: 2));

    // 广播任务进度
    _broadcast(NotificationMessageBuilder.taskProgress(
      taskId: taskId,
      progress: 0.5,
      message: 'Task in progress...',
    ));

    await Future.delayed(Duration(seconds: 2));

    // 广播任务完成
    _broadcast(NotificationMessageBuilder.taskCompleted(
      taskId: taskId,
      taskName: 'Task $taskId',
      result: {'output': 'Task completed successfully'},
    ));

    return {
      'taskId': taskId,
      'status': 'started',
      'message': 'Task execution started',
    };
  }

  /// 处理停止任务命令
  Future<Map<String, dynamic>> _handleStopTask(Map<String, dynamic> payload) async {
    final taskId = payload['taskId'] as String;

    print('🛑 Stopping task: $taskId');

    // TODO: 实际停止任务逻辑

    return {
      'taskId': taskId,
      'status': 'stopped',
    };
  }

  /// 处理获取任务列表命令
  Future<Map<String, dynamic>> _handleGetTasks(Map<String, dynamic> payload) async {
    final filter = payload['filter'] as String?;

    print('📋 Getting tasks (filter: $filter)');

    // TODO: 从数据库获取任务列表

    // 模拟数据
    final tasks = [
      {
        'id': 'task-1',
        'name': 'Deploy to Production',
        'status': 'running',
        'progress': 0.65,
      },
      {
        'id': 'task-2',
        'name': 'Run Tests',
        'status': 'completed',
        'progress': 1.0,
      },
      {
        'id': 'task-3',
        'name': 'Build Docker Image',
        'status': 'pending',
        'progress': 0.0,
      },
    ];

    return {
      'tasks': filter != null
          ? tasks.where((t) => t['status'] == filter).toList()
          : tasks,
      'total': tasks.length,
    };
  }

  /// 处理获取 AI 模型列表命令
  Future<Map<String, dynamic>> _handleGetModels(Map<String, dynamic> payload) async {
    print('🤖 Getting AI models');

    // TODO: 从配置获取可用模型

    final models = [
      {
        'id': 'claude-sonnet-3.5',
        'name': 'Claude Sonnet 3.5',
        'provider': 'Anthropic',
        'available': true,
      },
      {
        'id': 'gpt-4-turbo',
        'name': 'GPT-4 Turbo',
        'provider': 'OpenAI',
        'available': true,
      },
      {
        'id': 'gemini-pro',
        'name': 'Gemini Pro',
        'provider': 'Google',
        'available': false,
      },
    ];

    return {
      'models': models,
      'default': 'claude-sonnet-3.5',
    };
  }

  /// 处理发送聊天消息命令
  Future<Map<String, dynamic>> _handleSendChat(Map<String, dynamic> payload) async {
    final message = payload['message'] as String;
    final conversationId = payload['conversationId'] as String?;
    final modelId = payload['modelId'] as String?;

    print('💬 Chat message: $message (conversation: $conversationId, model: $modelId)');

    // TODO: 调用 AI API

    // 模拟 AI 响应
    await Future.delayed(Duration(seconds: 1));

    return {
      'conversationId': conversationId ?? _generateId(),
      'response': 'This is a simulated AI response to: "$message"',
      'model': modelId ?? 'claude-sonnet-3.5',
    };
  }

  /// 处理获取状态命令
  Future<Map<String, dynamic>> _handleGetStatus(Map<String, dynamic> payload) async {
    return {
      'daemon': {
        'version': '0.2.0',
        'uptime_seconds': _getUptime(),
        'memory_mb': _getMemoryUsage(),
      },
      'mobile': {
        'connected_clients': _clients.length,
      },
    };
  }

  // ========== 工具方法 ==========

  /// 发送消息给特定客户端
  void _sendToClient(String clientId, OpenCLIMessage message) {
    final client = _clients[clientId];
    if (client != null) {
      try {
        client.sink.add(message.toJsonString());
      } catch (e) {
        print('❌ Failed to send to $clientId: $e');
      }
    }
  }

  /// 广播消息给所有客户端
  void _broadcast(OpenCLIMessage message) {
    print('📢 Broadcasting: ${message.type.name} - ${message.payload['event']}');

    for (final entry in _clients.entries) {
      _sendToClient(entry.key, message);
    }
  }

  /// 发送错误响应
  void _sendErrorResponse(String clientId, String requestId, String errorMessage) {
    final response = ResponseMessageBuilder.error(
      requestId: requestId,
      errorMessage: errorMessage,
    );

    _sendToClient(clientId, response);
  }

  /// 生成客户端 ID
  String _generateClientId() {
    return 'client_${DateTime.now().millisecondsSinceEpoch}_${_randomString(4)}';
  }

  /// 生成消息 ID
  String _generateId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${_randomString(6)}';
  }

  /// 生成随机字符串
  String _randomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(
      length,
      (index) => chars[(DateTime.now().microsecond + index) % chars.length],
    ).join();
  }

  /// 获取运行时间（秒）
  int _getUptime() {
    // TODO: 实际实现运行时间追踪
    return 3600; // 1小时
  }

  /// 获取内存使用（MB）
  double _getMemoryUsage() {
    // TODO: 实际实现内存使用追踪
    return 45.2;
  }

  /// 关闭所有连接
  void dispose() {
    for (final client in _clients.values) {
      client.sink.close();
    }
    _clients.clear();
  }
}
