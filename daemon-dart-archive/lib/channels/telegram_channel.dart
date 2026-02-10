import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'base_channel.dart';
import 'models/unified_message.dart';

/// Telegram Bot channel implementation
class TelegramChannel extends BaseChannel {
  @override
  String get channelType => 'telegram';

  String? _botToken;
  List<String>? _allowedUsers;
  bool _isActive = false;
  int _lastUpdateId = 0;

  final _messageController = StreamController<UnifiedMessage>.broadcast();
  final _errorController = StreamController<ChannelError>.broadcast();

  Timer? _pollingTimer;

  @override
  bool get isActive => _isActive;

  @override
  Stream<UnifiedMessage> get messageStream => _messageController.stream;

  @override
  Stream<ChannelError> get errorStream => _errorController.stream;

  @override
  Future<void> initialize(Map<String, dynamic> config) async {
    _botToken = config['token'] as String?;
    _allowedUsers = (config['allowed_users'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .toList();

    if (_botToken == null || _botToken!.isEmpty) {
      throw Exception('Telegram bot token is required');
    }

    // Test connection
    try {
      final response = await http.get(
        Uri.parse('https://api.telegram.org/bot$_botToken/getMe'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['ok'] == true) {
          print('✓ Telegram bot connected: @${data['result']['username']}');
          _isActive = true;
          _startPolling();
        } else {
          throw Exception('Failed to verify bot: ${data['description']}');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      _errorController.add(ChannelError(
        channelType: channelType,
        message: 'Failed to initialize Telegram bot',
        error: e,
      ));
      rethrow;
    }
  }

  /// Start polling for updates
  void _startPolling() {
    _pollingTimer = Timer.periodic(Duration(seconds: 2), (_) async {
      try {
        await _pollUpdates();
      } catch (e) {
        _errorController.add(ChannelError(
          channelType: channelType,
          message: 'Polling error',
          error: e,
        ));
      }
    });
  }

  /// Poll for new messages
  Future<void> _pollUpdates() async {
    final response = await http.get(
      Uri.parse(
        'https://api.telegram.org/bot$_botToken/getUpdates?offset=${_lastUpdateId + 1}&timeout=30',
      ),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['ok'] == true) {
        final updates = data['result'] as List<dynamic>;

        for (final update in updates) {
          _lastUpdateId = update['update_id'] as int;
          await _processUpdate(update);
        }
      }
    }
  }

  /// Process a single update
  Future<void> _processUpdate(Map<String, dynamic> update) async {
    final message = update['message'];
    if (message == null) return;

    final from = message['from'];
    final chat = message['chat'];
    final text = message['text'] as String?;

    if (from == null || chat == null || text == null) return;

    final userId = from['id'].toString();

    // Check authorization
    if (_allowedUsers != null && !_allowedUsers!.contains(userId)) {
      await sendMessage(
        userId,
        '⚠️ Unauthorized. Please contact the administrator.',
      );
      return;
    }

    // Convert to unified message
    final unifiedMessage = UnifiedMessage(
      id: message['message_id'].toString(),
      channelType: channelType,
      channelId: chat['id'].toString(),
      userId: userId,
      username: from['username'] as String?,
      content: text,
      type: MessageType.text,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (message['date'] as int) * 1000,
      ),
    );

    _messageController.add(unifiedMessage);
  }

  @override
  Future<void> sendMessage(
    String userId,
    String content, {
    MessageType type = MessageType.text,
    String? replyToMessageId,
    Map<String, dynamic>? metadata,
  }) async {
    final params = {
      'chat_id': userId,
      'text': content,
      if (replyToMessageId != null) 'reply_to_message_id': replyToMessageId,
    };

    final response = await http.post(
      Uri.parse('https://api.telegram.org/bot$_botToken/sendMessage'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(params),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to send message: ${response.body}');
    }
  }

  @override
  Future<void> sendImage(
    String userId,
    String imageUrl, {
    String? caption,
    String? replyToMessageId,
  }) async {
    final params = {
      'chat_id': userId,
      'photo': imageUrl,
      if (caption != null) 'caption': caption,
      if (replyToMessageId != null) 'reply_to_message_id': replyToMessageId,
    };

    final response = await http.post(
      Uri.parse('https://api.telegram.org/bot$_botToken/sendPhoto'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(params),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to send image: ${response.body}');
    }
  }

  @override
  Future<void> sendFile(
    String userId,
    String fileUrl, {
    String? caption,
    String? replyToMessageId,
  }) async {
    final params = {
      'chat_id': userId,
      'document': fileUrl,
      if (caption != null) 'caption': caption,
      if (replyToMessageId != null) 'reply_to_message_id': replyToMessageId,
    };

    final response = await http.post(
      Uri.parse('https://api.telegram.org/bot$_botToken/sendDocument'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(params),
    );

    if (response.statusCode != 200) {
      throw Exception('Failed to send file: ${response.body}');
    }
  }

  @override
  Future<bool> isAuthorized(String userId) async {
    if (_allowedUsers == null) return true;
    return _allowedUsers!.contains(userId);
  }

  @override
  Future<void> close() async {
    _pollingTimer?.cancel();
    _isActive = false;
    await _messageController.close();
    await _errorController.close();
    print('✓ Telegram channel closed');
  }
}
