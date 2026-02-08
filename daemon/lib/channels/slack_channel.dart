import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'base_channel.dart';
import 'models/unified_message.dart';

/// Slack Bot channel implementation
class SlackChannel extends BaseChannel {
  @override
  String get channelType => 'slack';

  String? _botToken;
  String? _appToken;
  List<String>? _allowedUsers;
  bool _isActive = false;

  final _messageController = StreamController<UnifiedMessage>.broadcast();
  final _errorController = StreamController<ChannelError>.broadcast();

  @override
  bool get isActive => _isActive;

  @override
  Stream<UnifiedMessage> get messageStream => _messageController.stream;

  @override
  Stream<ChannelError> get errorStream => _errorController.stream;

  @override
  Future<void> initialize(Map<String, dynamic> config) async {
    _botToken = config['bot_token'] as String?;
    _appToken = config['app_token'] as String?;
    _allowedUsers = (config['allowed_users'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .toList();

    if (_botToken == null) {
      throw Exception('Slack bot_token is required');
    }

    // Test API connection
    try {
      final response = await http.post(
        Uri.parse('https://slack.com/api/auth.test'),
        headers: {
          'Authorization': 'Bearer $_botToken',
          'Content-Type': 'application/json',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['ok'] == true) {
          print('✓ Slack bot connected: @${data['user']} in ${data['team']}');
          _isActive = true;
        } else {
          throw Exception('Failed to verify bot: ${data['error']}');
        }
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      _errorController.add(ChannelError(
        channelType: channelType,
        message: 'Failed to initialize Slack bot',
        error: e,
      ));
      rethrow;
    }
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
      'channel': userId,
      'text': content,
      if (replyToMessageId != null) 'thread_ts': replyToMessageId,
    };

    final response = await http.post(
      Uri.parse('https://slack.com/api/chat.postMessage'),
      headers: {
        'Authorization': 'Bearer $_botToken',
        'Content-Type': 'application/json',
      },
      body: json.encode(params),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['ok'] != true) {
        throw Exception('Failed to send message: ${data['error']}');
      }
    } else {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
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
      'channel': userId,
      'attachments': [
        {
          'image_url': imageUrl,
          if (caption != null) 'text': caption,
        }
      ],
      if (replyToMessageId != null) 'thread_ts': replyToMessageId,
    };

    final response = await http.post(
      Uri.parse('https://slack.com/api/chat.postMessage'),
      headers: {
        'Authorization': 'Bearer $_botToken',
        'Content-Type': 'application/json',
      },
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
    // Slack file upload requires different API
    await sendMessage(userId, caption ?? 'File: $fileUrl');
  }

  @override
  Future<bool> isAuthorized(String userId) async {
    if (_allowedUsers == null) return true;
    return _allowedUsers!.contains(userId);
  }

  @override
  Future<void> close() async {
    _isActive = false;
    await _messageController.close();
    await _errorController.close();
    print('✓ Slack channel closed');
  }

  /// Handle incoming event (call this from your HTTP server)
  Future<void> handleIncomingEvent(Map<String, dynamic> eventData) async {
    final event = eventData['event'];
    if (event == null) return;

    final eventType = event['type'] as String?;
    if (eventType != 'message') return;

    // Ignore bot messages
    if (event['bot_id'] != null) return;

    final userId = event['user'] as String?;
    final text = event['text'] as String?;
    final ts = event['ts'] as String?;
    final channel = event['channel'] as String?;

    if (userId == null || text == null || ts == null || channel == null) return;

    // Check authorization
    if (!await isAuthorized(userId)) {
      await sendMessage(
          channel, '⚠️ Unauthorized. Please contact the administrator.');
      return;
    }

    final unifiedMessage = UnifiedMessage(
      id: ts,
      channelType: channelType,
      channelId: channel,
      userId: userId,
      content: text,
      type: MessageType.text,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        (double.parse(ts) * 1000).toInt(),
      ),
    );

    _messageController.add(unifiedMessage);
  }
}
