import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'base_channel.dart';
import 'models/unified_message.dart';

/// Discord Bot channel implementation
class DiscordChannel extends BaseChannel {
  @override
  String get channelType => 'discord';

  String? _botToken;
  String? _guildId;
  List<String>? _allowedUsers;
  bool _isActive = false;
  int _lastSequence = 0;
  String? _sessionId;

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
    _guildId = config['guild_id'] as String?;
    _allowedUsers = (config['allowed_users'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .toList();

    if (_botToken == null) {
      throw Exception('Discord bot_token is required');
    }

    // Test bot connection
    try {
      final response = await http.get(
        Uri.parse('https://discord.com/api/v10/users/@me'),
        headers: {
          'Authorization': 'Bot $_botToken',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('✓ Discord bot connected: ${data['username']}#${data['discriminator']}');
        _isActive = true;
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } catch (e) {
      _errorController.add(ChannelError(
        channelType: channelType,
        message: 'Failed to initialize Discord bot',
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
    final params = <String, dynamic>{
      'content': content,
    };

    if (replyToMessageId != null) {
      params['message_reference'] = {
        'message_id': replyToMessageId,
      };
    }

    final response = await http.post(
      Uri.parse('https://discord.com/api/v10/channels/$userId/messages'),
      headers: {
        'Authorization': 'Bot $_botToken',
        'Content-Type': 'application/json',
      },
      body: json.encode(params),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
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
    final params = <String, dynamic>{
      'embeds': [
        {
          'image': {
            'url': imageUrl,
          }
        }
      ],
    };

    if (caption != null) {
      params['content'] = caption;
    }

    if (replyToMessageId != null) {
      params['message_reference'] = {
        'message_id': replyToMessageId,
      };
    }

    final response = await http.post(
      Uri.parse('https://discord.com/api/v10/channels/$userId/messages'),
      headers: {
        'Authorization': 'Bot $_botToken',
        'Content-Type': 'application/json',
      },
      body: json.encode(params),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
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
    // Discord file upload requires multipart/form-data
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
    print('✓ Discord channel closed');
  }

  /// Handle incoming message event (call this from your gateway/webhook)
  Future<void> handleIncomingMessage(Map<String, dynamic> messageData) async {
    final author = messageData['author'];
    if (author == null) return;

    // Ignore bot messages
    if (author['bot'] == true) return;

    final userId = author['id'] as String?;
    final content = messageData['content'] as String?;
    final messageId = messageData['id'] as String?;
    final channelId = messageData['channel_id'] as String?;

    if (userId == null || content == null || messageId == null || channelId == null) {
      return;
    }

    // Check authorization
    if (!await isAuthorized(userId)) {
      await sendMessage(channelId, '⚠️ Unauthorized. Please contact the administrator.');
      return;
    }

    final unifiedMessage = UnifiedMessage(
      id: messageId,
      channelType: channelType,
      channelId: channelId,
      userId: userId,
      username: author['username'] as String?,
      content: content,
      type: MessageType.text,
      timestamp: DateTime.parse(messageData['timestamp'] as String),
    );

    _messageController.add(unifiedMessage);
  }
}
