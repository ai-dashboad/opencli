class ChatMessage {
  final String id;
  final String content;
  final bool isUser;
  final DateTime timestamp;
  final MessageStatus status;
  final String? taskType;
  final Map<String, dynamic>? result;

  ChatMessage({
    required this.id,
    required this.content,
    required this.isUser,
    required this.timestamp,
    this.status = MessageStatus.sent,
    this.taskType,
    this.result,
  });

  ChatMessage copyWith({
    String? id,
    String? content,
    bool? isUser,
    DateTime? timestamp,
    MessageStatus? status,
    String? taskType,
    Map<String, dynamic>? result,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      content: content ?? this.content,
      isUser: isUser ?? this.isUser,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      taskType: taskType ?? this.taskType,
      result: result ?? this.result,
    );
  }
}

enum MessageStatus {
  sending,
  sent,
  delivered,
  executing,
  completed,
  failed,
}
