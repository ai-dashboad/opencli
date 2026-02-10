import 'dart:async';
import 'models/unified_message.dart';

/// Abstract base class for all message channels
abstract class BaseChannel {
  /// Channel type identifier (e.g., 'telegram', 'whatsapp', 'slack')
  String get channelType;

  /// Whether the channel is currently active
  bool get isActive;

  /// Initialize the channel with configuration
  Future<void> initialize(Map<String, dynamic> config);

  /// Send a message to a user
  Future<void> sendMessage(
    String userId,
    String content, {
    MessageType type = MessageType.text,
    String? replyToMessageId,
    Map<String, dynamic>? metadata,
  });

  /// Send an image
  Future<void> sendImage(
    String userId,
    String imageUrl, {
    String? caption,
    String? replyToMessageId,
  });

  /// Send a file
  Future<void> sendFile(
    String userId,
    String fileUrl, {
    String? caption,
    String? replyToMessageId,
  });

  /// Receive messages stream
  Stream<UnifiedMessage> get messageStream;

  /// Check if a user is authorized to use this channel
  Future<bool> isAuthorized(String userId);

  /// Close the channel connection
  Future<void> close();

  /// Handle errors
  Stream<ChannelError> get errorStream;
}

/// Channel error class
class ChannelError {
  final String channelType;
  final String message;
  final dynamic error;
  final StackTrace? stackTrace;
  final DateTime timestamp;

  ChannelError({
    required this.channelType,
    required this.message,
    this.error,
    this.stackTrace,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() => '[$channelType] $message: $error';
}
