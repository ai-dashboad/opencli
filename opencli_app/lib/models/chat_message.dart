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

  Map<String, dynamic> toJson() {
    // Filter out image_base64 from result to avoid storing large blobs
    Map<String, dynamic>? filteredResult;
    if (result != null) {
      filteredResult = Map<String, dynamic>.from(result!);
      filteredResult.remove('image_base64');
      filteredResult.remove('video_base64');
    }

    return {
      'id': id,
      'content': content,
      'isUser': isUser,
      'timestamp': timestamp.toIso8601String(),
      'status': status.name,
      'taskType': taskType,
      'result': filteredResult,
    };
  }

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] as String,
      content: json['content'] as String,
      isUser: json['isUser'] as bool,
      timestamp: DateTime.parse(json['timestamp'] as String),
      status: MessageStatus.values.firstWhere(
        (e) => e.name == json['status'],
        orElse: () => MessageStatus.delivered,
      ),
      taskType: json['taskType'] as String?,
      result: json['result'] != null
          ? Map<String, dynamic>.from(json['result'] as Map)
          : null,
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
