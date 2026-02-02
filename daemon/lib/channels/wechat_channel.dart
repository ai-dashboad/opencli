import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'base_channel.dart';
import 'models/unified_message.dart';

/// WeChat Bot channel implementation (requires WeChat Official Account)
class WeChatChannel extends BaseChannel {
  @override
  String get channelType => 'wechat';

  String? _appId;
  String? _appSecret;
  String? _accessToken;
  List<String>? _allowedUsers;
  bool _isActive = false;

  Timer? _tokenRefreshTimer;

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
    _appId = config['app_id'] as String?;
    _appSecret = config['app_secret'] as String?;
    _allowedUsers = (config['allowed_users'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .toList();

    if (_appId == null || _appSecret == null) {
      throw Exception('WeChat app_id and app_secret are required');
    }

    // Get access token
    try {
      await _refreshAccessToken();

      // Refresh token every 2 hours (tokens expire in 2 hours)
      _tokenRefreshTimer = Timer.periodic(
        Duration(hours: 1, minutes: 50),
        (_) => _refreshAccessToken(),
      );

      print('✓ WeChat channel connected');
      _isActive = true;
    } catch (e) {
      _errorController.add(ChannelError(
        channelType: channelType,
        message: 'Failed to initialize WeChat channel',
        error: e,
      ));
      rethrow;
    }
  }

  /// Refresh WeChat access token
  Future<void> _refreshAccessToken() async {
    final response = await http.get(
      Uri.parse(
        'https://api.weixin.qq.com/cgi-bin/token?grant_type=client_credential&appid=$_appId&secret=$_appSecret',
      ),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['access_token'] != null) {
        _accessToken = data['access_token'] as String;
        print('✓ WeChat access token refreshed');
      } else {
        throw Exception('Failed to get access token: ${data['errmsg']}');
      }
    } else {
      throw Exception('HTTP ${response.statusCode}: ${response.body}');
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
    if (_accessToken == null) {
      throw Exception('Access token not available');
    }

    final params = {
      'touser': userId,
      'msgtype': 'text',
      'text': {
        'content': content,
      }
    };

    final response = await http.post(
      Uri.parse('https://api.weixin.qq.com/cgi-bin/message/custom/send?access_token=$_accessToken'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode(params),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['errcode'] != 0) {
        throw Exception('Failed to send message: ${data['errmsg']}');
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
    if (_accessToken == null) {
      throw Exception('Access token not available');
    }

    // WeChat requires uploading image first, then sending media_id
    // This is a simplified version
    final params = {
      'touser': userId,
      'msgtype': 'news',
      'news': {
        'articles': [
          {
            'title': caption ?? 'Image',
            'picurl': imageUrl,
            'url': imageUrl,
          }
        ]
      }
    };

    final response = await http.post(
      Uri.parse('https://api.weixin.qq.com/cgi-bin/message/custom/send?access_token=$_accessToken'),
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
    await sendMessage(userId, caption ?? 'File: $fileUrl');
  }

  @override
  Future<bool> isAuthorized(String userId) async {
    if (_allowedUsers == null) return true;
    return _allowedUsers!.contains(userId);
  }

  @override
  Future<void> close() async {
    _tokenRefreshTimer?.cancel();
    _isActive = false;
    await _messageController.close();
    await _errorController.close();
    print('✓ WeChat channel closed');
  }

  /// Handle incoming message (call this from your webhook server)
  Future<void> handleIncomingMessage(Map<String, dynamic> messageData) async {
    final fromUser = messageData['FromUserName'] as String?;
    final content = messageData['Content'] as String?;
    final msgId = messageData['MsgId'] as String?;

    if (fromUser == null || content == null || msgId == null) return;

    // Check authorization
    if (!await isAuthorized(fromUser)) {
      await sendMessage(fromUser, '⚠️ 未授权。请联系管理员。');
      return;
    }

    final unifiedMessage = UnifiedMessage(
      id: msgId,
      channelType: channelType,
      channelId: fromUser,
      userId: fromUser,
      content: content,
      type: MessageType.text,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        int.parse(messageData['CreateTime'].toString()) * 1000,
      ),
    );

    _messageController.add(unifiedMessage);
  }
}
