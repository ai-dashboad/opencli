import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/chat_message.dart';

/// Chat storage service that persists messages to the daemon's SQLite database
/// via REST API, replacing SharedPreferences.
class ChatStorageService {
  static const _baseUrl = 'http://localhost:9529/api/v1/chat';

  final _client = http.Client();

  /// Load messages from the server.
  Future<List<ChatMessage>> loadMessages() async {
    try {
      final response = await _client
          .get(Uri.parse('$_baseUrl/messages?limit=100'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body);
      final rows = data['messages'] as List<dynamic>? ?? [];

      return rows.map((r) {
        final map = r as Map<String, dynamic>;
        return ChatMessage(
          id: map['id'] as String? ?? '',
          content: map['content'] as String? ?? '',
          isUser: (map['is_user'] as int?) == 1,
          timestamp: DateTime.fromMillisecondsSinceEpoch(
              map['timestamp'] as int? ?? 0),
          status: _parseStatus(map['status'] as String?),
          taskType: map['task_type'] as String?,
          result: map['result'] != null
              ? (map['result'] is String
                  ? jsonDecode(map['result'] as String)
                  : map['result'] as Map<String, dynamic>?)
              : null,
        );
      }).toList().reversed.toList(); // API returns DESC, we want ASC
    } catch (e) {
      print('[ChatStorage] Failed to load messages: $e');
      return [];
    }
  }

  /// Save a single message to the server.
  Future<void> saveMessage(ChatMessage msg) async {
    try {
      // Filter out large base64 data from results
      Map<String, dynamic>? safeResult;
      if (msg.result != null) {
        safeResult = Map<String, dynamic>.from(msg.result!);
        safeResult.remove('image_base64');
        safeResult.remove('video_base64');
      }

      await _client
          .post(
            Uri.parse('$_baseUrl/messages'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'id': msg.id,
              'content': msg.content,
              'is_user': msg.isUser,
              'timestamp': msg.timestamp.millisecondsSinceEpoch,
              'status': msg.status.name,
              'task_type': msg.taskType,
              'result': safeResult != null ? jsonEncode(safeResult) : null,
            }),
          )
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      print('[ChatStorage] Failed to save message: $e');
    }
  }

  /// Clear all messages on the server.
  Future<void> clearMessages() async {
    try {
      await _client
          .delete(Uri.parse('$_baseUrl/messages'))
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      print('[ChatStorage] Failed to clear messages: $e');
    }
  }

  static MessageStatus _parseStatus(String? status) {
    switch (status) {
      case 'executing':
        return MessageStatus.executing;
      case 'sending':
        return MessageStatus.sending;
      case 'delivered':
        return MessageStatus.delivered;
      case 'failed':
        return MessageStatus.failed;
      default:
        return MessageStatus.completed;
    }
  }
}
