import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Message queue system for distributed task processing
class MessageQueue {
  final MessageQueueConfig config;
  late MessageQueueAdapter _adapter;
  final Map<String, List<MessageHandler>> _handlers = {};
  final StreamController<MessageEvent> _eventController =
      StreamController.broadcast();

  Stream<MessageEvent> get events => _eventController.stream;

  MessageQueue({required this.config}) {
    _adapter = _createAdapter(config);
  }

  /// Initialize message queue
  Future<void> initialize() async {
    await _adapter.connect();
    print('Message queue initialized: ${config.type}');
  }

  /// Publish message to queue
  Future<void> publish(
    String queue,
    Map<String, dynamic> message, {
    int priority = 5,
    Duration? delay,
    Duration? ttl,
  }) async {
    final queueMessage = QueueMessage(
      id: _generateMessageId(),
      queue: queue,
      data: message,
      priority: priority,
      timestamp: DateTime.now(),
      delay: delay,
      ttl: ttl,
    );

    await _adapter.publish(queueMessage);

    _eventController.add(MessageEvent(
      type: MessageEventType.published,
      message: queueMessage,
      timestamp: DateTime.now(),
    ));
  }

  /// Subscribe to queue
  Future<void> subscribe(String queue, MessageHandler handler) async {
    _handlers.putIfAbsent(queue, () => []).add(handler);
    await _adapter.subscribe(queue, _handleMessage);
  }

  /// Unsubscribe from queue
  Future<void> unsubscribe(String queue, MessageHandler handler) async {
    _handlers[queue]?.remove(handler);
    if (_handlers[queue]?.isEmpty ?? false) {
      await _adapter.unsubscribe(queue);
    }
  }

  /// Handle incoming message
  Future<void> _handleMessage(QueueMessage message) async {
    final handlers = _handlers[message.queue] ?? [];

    for (final handler in handlers) {
      try {
        await handler(message);

        _eventController.add(MessageEvent(
          type: MessageEventType.processed,
          message: message,
          timestamp: DateTime.now(),
        ));
      } catch (e) {
        _eventController.add(MessageEvent(
          type: MessageEventType.failed,
          message: message,
          error: e.toString(),
          timestamp: DateTime.now(),
        ));

        // Retry logic could be added here
      }
    }
  }

  /// Get queue statistics
  Future<QueueStats> getStats(String queue) async {
    return await _adapter.getStats(queue);
  }

  /// Purge queue
  Future<void> purge(String queue) async {
    await _adapter.purge(queue);
  }

  /// Close connection
  Future<void> close() async {
    await _adapter.disconnect();
    await _eventController.close();
  }

  /// Create adapter based on config
  MessageQueueAdapter _createAdapter(MessageQueueConfig config) {
    switch (config.type) {
      case MessageQueueType.memory:
        return InMemoryAdapter();
      case MessageQueueType.redis:
        return RedisAdapter(config);
      case MessageQueueType.rabbitmq:
        return RabbitMQAdapter(config);
      case MessageQueueType.kafka:
        return KafkaAdapter(config);
    }
  }

  String _generateMessageId() {
    return 'msg_${DateTime.now().millisecondsSinceEpoch}';
  }
}

/// Message queue configuration
class MessageQueueConfig {
  final MessageQueueType type;
  final String? host;
  final int? port;
  final String? username;
  final String? password;
  final Map<String, dynamic>? options;

  MessageQueueConfig({
    required this.type,
    this.host,
    this.port,
    this.username,
    this.password,
    this.options,
  });

  factory MessageQueueConfig.memory() {
    return MessageQueueConfig(type: MessageQueueType.memory);
  }

  factory MessageQueueConfig.redis({
    required String host,
    int port = 6379,
    String? password,
  }) {
    return MessageQueueConfig(
      type: MessageQueueType.redis,
      host: host,
      port: port,
      password: password,
    );
  }

  factory MessageQueueConfig.rabbitmq({
    required String host,
    int port = 5672,
    required String username,
    required String password,
  }) {
    return MessageQueueConfig(
      type: MessageQueueType.rabbitmq,
      host: host,
      port: port,
      username: username,
      password: password,
    );
  }
}

enum MessageQueueType { memory, redis, rabbitmq, kafka }

/// Queue message
class QueueMessage {
  final String id;
  final String queue;
  final Map<String, dynamic> data;
  final int priority;
  final DateTime timestamp;
  final Duration? delay;
  final Duration? ttl;
  int retryCount;

  QueueMessage({
    required this.id,
    required this.queue,
    required this.data,
    this.priority = 5,
    required this.timestamp,
    this.delay,
    this.ttl,
    this.retryCount = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'queue': queue,
      'data': data,
      'priority': priority,
      'timestamp': timestamp.toIso8601String(),
      if (delay != null) 'delay': delay!.inMilliseconds,
      if (ttl != null) 'ttl': ttl!.inMilliseconds,
      'retry_count': retryCount,
    };
  }

  factory QueueMessage.fromJson(Map<String, dynamic> json) {
    return QueueMessage(
      id: json['id'] as String,
      queue: json['queue'] as String,
      data: json['data'] as Map<String, dynamic>,
      priority: json['priority'] as int? ?? 5,
      timestamp: DateTime.parse(json['timestamp'] as String),
      delay: json['delay'] != null
          ? Duration(milliseconds: json['delay'] as int)
          : null,
      ttl: json['ttl'] != null ? Duration(milliseconds: json['ttl'] as int) : null,
      retryCount: json['retry_count'] as int? ?? 0,
    );
  }
}

/// Message handler function
typedef MessageHandler = Future<void> Function(QueueMessage message);

/// Message event
class MessageEvent {
  final MessageEventType type;
  final QueueMessage message;
  final String? error;
  final DateTime timestamp;

  MessageEvent({
    required this.type,
    required this.message,
    this.error,
    required this.timestamp,
  });
}

enum MessageEventType { published, processed, failed }

/// Queue statistics
class QueueStats {
  final String queue;
  final int messageCount;
  final int consumerCount;
  final int publishRate;
  final int consumeRate;

  QueueStats({
    required this.queue,
    required this.messageCount,
    required this.consumerCount,
    required this.publishRate,
    required this.consumeRate,
  });
}

/// Base message queue adapter
abstract class MessageQueueAdapter {
  Future<void> connect();
  Future<void> disconnect();
  Future<void> publish(QueueMessage message);
  Future<void> subscribe(String queue, MessageHandler handler);
  Future<void> unsubscribe(String queue);
  Future<QueueStats> getStats(String queue);
  Future<void> purge(String queue);
}

/// In-memory adapter for development/testing
class InMemoryAdapter implements MessageQueueAdapter {
  final Map<String, Queue<QueueMessage>> _queues = {};
  final Map<String, List<MessageHandler>> _subscribers = {};
  final Map<String, Timer> _timers = {};

  @override
  Future<void> connect() async {}

  @override
  Future<void> disconnect() async {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
  }

  @override
  Future<void> publish(QueueMessage message) async {
    final queue = _queues.putIfAbsent(message.queue, () => Queue());

    if (message.delay != null) {
      // Delayed message
      Timer(message.delay!, () => queue.add(message));
    } else {
      queue.add(message);
    }

    _processQueue(message.queue);
  }

  @override
  Future<void> subscribe(String queue, MessageHandler handler) async {
    _subscribers.putIfAbsent(queue, () => []).add(handler);
  }

  @override
  Future<void> unsubscribe(String queue) async {
    _subscribers.remove(queue);
    _timers[queue]?.cancel();
    _timers.remove(queue);
  }

  @override
  Future<QueueStats> getStats(String queue) async {
    return QueueStats(
      queue: queue,
      messageCount: _queues[queue]?.length ?? 0,
      consumerCount: _subscribers[queue]?.length ?? 0,
      publishRate: 0,
      consumeRate: 0,
    );
  }

  @override
  Future<void> purge(String queue) async {
    _queues[queue]?.clear();
  }

  void _processQueue(String queueName) {
    if (_timers.containsKey(queueName)) return;

    _timers[queueName] = Timer.periodic(Duration(milliseconds: 100), (_) async {
      final queue = _queues[queueName];
      final handlers = _subscribers[queueName];

      if (queue == null || queue.isEmpty || handlers == null || handlers.isEmpty) {
        return;
      }

      final message = queue.removeFirst();

      // Check TTL
      if (message.ttl != null) {
        final age = DateTime.now().difference(message.timestamp);
        if (age > message.ttl!) {
          return; // Message expired
        }
      }

      for (final handler in handlers) {
        try {
          await handler(message);
        } catch (e) {
          // Error handling - could implement retry logic here
          print('Message processing error: $e');
        }
      }
    });
  }
}

/// Redis adapter
class RedisAdapter implements MessageQueueAdapter {
  final MessageQueueConfig config;

  RedisAdapter(this.config);

  @override
  Future<void> connect() async {
    // Would need redis package
    throw UnimplementedError('Redis adapter requires redis package');
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> publish(QueueMessage message) async {
    throw UnimplementedError();
  }

  @override
  Future<void> subscribe(String queue, MessageHandler handler) async {
    throw UnimplementedError();
  }

  @override
  Future<void> unsubscribe(String queue) async {
    throw UnimplementedError();
  }

  @override
  Future<QueueStats> getStats(String queue) async {
    throw UnimplementedError();
  }

  @override
  Future<void> purge(String queue) async {
    throw UnimplementedError();
  }
}

/// RabbitMQ adapter
class RabbitMQAdapter implements MessageQueueAdapter {
  final MessageQueueConfig config;

  RabbitMQAdapter(this.config);

  @override
  Future<void> connect() async {
    // Would need dart_amqp package
    throw UnimplementedError('RabbitMQ adapter requires dart_amqp package');
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> publish(QueueMessage message) async {
    throw UnimplementedError();
  }

  @override
  Future<void> subscribe(String queue, MessageHandler handler) async {
    throw UnimplementedError();
  }

  @override
  Future<void> unsubscribe(String queue) async {
    throw UnimplementedError();
  }

  @override
  Future<QueueStats> getStats(String queue) async {
    throw UnimplementedError();
  }

  @override
  Future<void> purge(String queue) async {
    throw UnimplementedError();
  }
}

/// Kafka adapter
class KafkaAdapter implements MessageQueueAdapter {
  final MessageQueueConfig config;

  KafkaAdapter(this.config);

  @override
  Future<void> connect() async {
    throw UnimplementedError('Kafka adapter requires kafka package');
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> publish(QueueMessage message) async {
    throw UnimplementedError();
  }

  @override
  Future<void> subscribe(String queue, MessageHandler handler) async {
    throw UnimplementedError();
  }

  @override
  Future<void> unsubscribe(String queue) async {
    throw UnimplementedError();
  }

  @override
  Future<QueueStats> getStats(String queue) async {
    throw UnimplementedError();
  }

  @override
  Future<void> purge(String queue) async {
    throw UnimplementedError();
  }
}

/// Dead letter queue handler
class DeadLetterQueue {
  final MessageQueue messageQueue;
  final String dlqName;
  final int maxRetries;

  DeadLetterQueue({
    required this.messageQueue,
    this.dlqName = 'dead_letter_queue',
    this.maxRetries = 3,
  });

  /// Process message with retry logic
  Future<void> processWithRetry(
    QueueMessage message,
    MessageHandler handler,
  ) async {
    try {
      await handler(message);
    } catch (e) {
      message.retryCount++;

      if (message.retryCount >= maxRetries) {
        // Send to dead letter queue
        await messageQueue.publish(dlqName, {
          'original_message': message.toJson(),
          'error': e.toString(),
          'failed_at': DateTime.now().toIso8601String(),
        });
      } else {
        // Retry with exponential backoff
        final delay = Duration(seconds: 2 * message.retryCount);
        await messageQueue.publish(
          message.queue,
          message.data,
          priority: message.priority,
          delay: delay,
        );
      }
    }
  }
}
