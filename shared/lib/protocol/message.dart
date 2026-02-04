/// OpenCLI 统一消息协议
/// 用于所有客户端（Desktop、Mobile、Web）与 Daemon 之间的通信
library opencli_protocol;

import 'dart:convert';

/// 消息类型枚举
enum MessageType {
  /// 命令消息 - 客户端向 Daemon 发送命令
  command,

  /// 状态消息 - Daemon 向客户端广播状态
  status,

  /// 通知消息 - 任务完成、错误等通知
  notification,

  /// 响应消息 - Daemon 对命令的响应
  response,

  /// 心跳消息 - 保持连接活跃
  heartbeat,
}

/// 客户端类型枚举
enum ClientType {
  desktop,  // macOS/Windows/Linux
  mobile,   // iOS/Android
  web,      // Web UI
  cli,      // Command Line Interface
}

/// 目标类型枚举
enum TargetType {
  daemon,     // 发送到 Daemon
  broadcast,  // 广播到所有客户端
  specific,   // 发送到特定客户端
}

/// OpenCLI 统一消息格式
class OpenCLIMessage {
  /// 消息唯一 ID
  final String id;

  /// 消息类型
  final MessageType type;

  /// 消息来源客户端类型
  final ClientType source;

  /// 消息目标
  final TargetType target;

  /// 目标客户端 ID（当 target 为 specific 时使用）
  final String? targetClientId;

  /// 消息负载数据
  final Map<String, dynamic> payload;

  /// 时间戳（毫秒）
  final int timestamp;

  /// 优先级（0-10，10 最高）
  final int priority;

  OpenCLIMessage({
    required this.id,
    required this.type,
    required this.source,
    required this.target,
    this.targetClientId,
    required this.payload,
    int? timestamp,
    this.priority = 5,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  /// 从 JSON 创建消息
  factory OpenCLIMessage.fromJson(Map<String, dynamic> json) {
    return OpenCLIMessage(
      id: json['id'] as String,
      type: MessageType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => MessageType.command,
      ),
      source: ClientType.values.firstWhere(
        (e) => e.name == json['source'],
        orElse: () => ClientType.desktop,
      ),
      target: TargetType.values.firstWhere(
        (e) => e.name == json['target'],
        orElse: () => TargetType.daemon,
      ),
      targetClientId: json['targetClientId'] as String?,
      payload: json['payload'] as Map<String, dynamic>,
      timestamp: json['timestamp'] as int,
      priority: json['priority'] as int? ?? 5,
    );
  }

  /// 转换为 JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name,
      'source': source.name,
      'target': target.name,
      if (targetClientId != null) 'targetClientId': targetClientId,
      'payload': payload,
      'timestamp': timestamp,
      'priority': priority,
    };
  }

  /// 转换为 JSON 字符串
  String toJsonString() => jsonEncode(toJson());

  /// 从 JSON 字符串创建消息
  factory OpenCLIMessage.fromJsonString(String jsonString) {
    return OpenCLIMessage.fromJson(jsonDecode(jsonString));
  }

  @override
  String toString() => toJsonString();
}

/// 命令消息构建器
class CommandMessageBuilder {
  /// 执行任务命令
  static OpenCLIMessage executeTask({
    required ClientType source,
    required String taskId,
    Map<String, dynamic>? params,
  }) {
    return OpenCLIMessage(
      id: _generateId(),
      type: MessageType.command,
      source: source,
      target: TargetType.daemon,
      payload: {
        'action': 'execute_task',
        'taskId': taskId,
        'params': params ?? {},
      },
      priority: 8,
    );
  }

  /// 停止任务命令
  static OpenCLIMessage stopTask({
    required ClientType source,
    required String taskId,
  }) {
    return OpenCLIMessage(
      id: _generateId(),
      type: MessageType.command,
      source: source,
      target: TargetType.daemon,
      payload: {
        'action': 'stop_task',
        'taskId': taskId,
      },
      priority: 10,
    );
  }

  /// 获取任务列表命令
  static OpenCLIMessage getTasks({
    required ClientType source,
    String? filter,
  }) {
    return OpenCLIMessage(
      id: _generateId(),
      type: MessageType.command,
      source: source,
      target: TargetType.daemon,
      payload: {
        'action': 'get_tasks',
        if (filter != null) 'filter': filter,
      },
    );
  }

  /// 获取 AI 模型列表命令
  static OpenCLIMessage getModels({
    required ClientType source,
  }) {
    return OpenCLIMessage(
      id: _generateId(),
      type: MessageType.command,
      source: source,
      target: TargetType.daemon,
      payload: {
        'action': 'get_models',
      },
    );
  }

  /// 发送 AI 对话命令
  static OpenCLIMessage sendChatMessage({
    required ClientType source,
    required String message,
    String? conversationId,
    String? modelId,
  }) {
    return OpenCLIMessage(
      id: _generateId(),
      type: MessageType.command,
      source: source,
      target: TargetType.daemon,
      payload: {
        'action': 'send_chat',
        'message': message,
        if (conversationId != null) 'conversationId': conversationId,
        if (modelId != null) 'modelId': modelId,
      },
      priority: 7,
    );
  }

  /// 获取 Daemon 状态命令
  static OpenCLIMessage getStatus({
    required ClientType source,
  }) {
    return OpenCLIMessage(
      id: _generateId(),
      type: MessageType.command,
      source: source,
      target: TargetType.daemon,
      payload: {
        'action': 'get_status',
      },
    );
  }

  /// 生成唯一 ID
  static String _generateId() {
    return '${DateTime.now().millisecondsSinceEpoch}_${_randomString(6)}';
  }

  static String _randomString(int length) {
    const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
    return List.generate(
      length,
      (index) => chars[(DateTime.now().microsecond + index) % chars.length],
    ).join();
  }
}

/// 响应消息构建器
class ResponseMessageBuilder {
  /// 成功响应
  static OpenCLIMessage success({
    required String requestId,
    Map<String, dynamic>? data,
  }) {
    return OpenCLIMessage(
      id: _generateId(),
      type: MessageType.response,
      source: ClientType.desktop, // Daemon 作为 desktop 类型
      target: TargetType.specific,
      payload: {
        'requestId': requestId,
        'status': 'success',
        'data': data ?? {},
      },
    );
  }

  /// 错误响应
  static OpenCLIMessage error({
    required String requestId,
    required String errorMessage,
    String? errorCode,
  }) {
    return OpenCLIMessage(
      id: _generateId(),
      type: MessageType.response,
      source: ClientType.desktop,
      target: TargetType.specific,
      payload: {
        'requestId': requestId,
        'status': 'error',
        'error': {
          'message': errorMessage,
          if (errorCode != null) 'code': errorCode,
        },
      },
      priority: 8,
    );
  }

  static String _generateId() => CommandMessageBuilder._generateId();
}

/// 通知消息构建器
class NotificationMessageBuilder {
  /// 任务完成通知
  static OpenCLIMessage taskCompleted({
    required String taskId,
    required String taskName,
    required Map<String, dynamic> result,
  }) {
    return OpenCLIMessage(
      id: _generateId(),
      type: MessageType.notification,
      source: ClientType.desktop,
      target: TargetType.broadcast,
      payload: {
        'event': 'task_completed',
        'taskId': taskId,
        'taskName': taskName,
        'result': result,
      },
      priority: 7,
    );
  }

  /// 任务失败通知
  static OpenCLIMessage taskFailed({
    required String taskId,
    required String taskName,
    required String error,
  }) {
    return OpenCLIMessage(
      id: _generateId(),
      type: MessageType.notification,
      source: ClientType.desktop,
      target: TargetType.broadcast,
      payload: {
        'event': 'task_failed',
        'taskId': taskId,
        'taskName': taskName,
        'error': error,
      },
      priority: 8,
    );
  }

  /// 任务进度更新通知
  static OpenCLIMessage taskProgress({
    required String taskId,
    required double progress,
    String? message,
  }) {
    return OpenCLIMessage(
      id: _generateId(),
      type: MessageType.notification,
      source: ClientType.desktop,
      target: TargetType.broadcast,
      payload: {
        'event': 'task_progress',
        'taskId': taskId,
        'progress': progress,
        if (message != null) 'message': message,
      },
      priority: 5,
    );
  }

  /// Daemon 状态变化通知
  static OpenCLIMessage daemonStatusChanged({
    required Map<String, dynamic> status,
  }) {
    return OpenCLIMessage(
      id: _generateId(),
      type: MessageType.notification,
      source: ClientType.desktop,
      target: TargetType.broadcast,
      payload: {
        'event': 'daemon_status_changed',
        'status': status,
      },
      priority: 6,
    );
  }

  static String _generateId() => CommandMessageBuilder._generateId();
}
