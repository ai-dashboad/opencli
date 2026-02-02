/// Unified message format for all channels (Telegram, WhatsApp, Slack, etc.)
class UnifiedMessage {
  /// Unique message ID
  final String id;

  /// Channel type: 'telegram', 'whatsapp', 'slack', 'discord', 'flutter_app', 'web'
  final String channelType;

  /// Channel-specific ID (chat ID, channel ID, etc.)
  final String channelId;

  /// User ID of the sender
  final String userId;

  /// Username or display name (optional)
  final String? username;

  /// Message content (text, caption, etc.)
  final String content;

  /// Message type
  final MessageType type;

  /// Timestamp when the message was sent
  final DateTime timestamp;

  /// Channel-specific metadata
  final Map<String, dynamic>? metadata;

  /// File URL if message contains a file
  final String? fileUrl;

  /// Reply to message ID (for threaded conversations)
  final String? replyToMessageId;

  UnifiedMessage({
    required this.id,
    required this.channelType,
    required this.channelId,
    required this.userId,
    this.username,
    required this.content,
    required this.type,
    required this.timestamp,
    this.metadata,
    this.fileUrl,
    this.replyToMessageId,
  });

  factory UnifiedMessage.fromJson(Map<String, dynamic> json) {
    return UnifiedMessage(
      id: json['id'] as String,
      channelType: json['channelType'] as String,
      channelId: json['channelId'] as String,
      userId: json['userId'] as String,
      username: json['username'] as String?,
      content: json['content'] as String,
      type: MessageTypeExtension.fromJson(json['type'] as String),
      timestamp: DateTime.parse(json['timestamp'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
      fileUrl: json['fileUrl'] as String?,
      replyToMessageId: json['replyToMessageId'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'channelType': channelType,
      'channelId': channelId,
      'userId': userId,
      if (username != null) 'username': username,
      'content': content,
      'type': type.toJson(),
      'timestamp': timestamp.toIso8601String(),
      if (metadata != null) 'metadata': metadata,
      if (fileUrl != null) 'fileUrl': fileUrl,
      if (replyToMessageId != null) 'replyToMessageId': replyToMessageId,
    };
  }

  @override
  String toString() =>
      'UnifiedMessage($channelType:$userId): $content';
}

/// Message type enumeration
enum MessageType {
  text,
  image,
  audio,
  video,
  file,
  location,
  contact,
  sticker,
  voice,
}

/// Message type JSON serialization
extension MessageTypeExtension on MessageType {
  String toJson() => name;

  static MessageType fromJson(String json) {
    return MessageType.values.firstWhere(
      (e) => e.name == json,
      orElse: () => MessageType.text,
    );
  }
}
