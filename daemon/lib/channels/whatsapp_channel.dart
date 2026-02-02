import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'base_channel.dart';
import 'models/unified_message.dart';

/// WhatsApp Bot channel implementation (via Twilio API)
class WhatsAppChannel extends BaseChannel {
  @override
  String get channelType => 'whatsapp';

  String? _accountSid;
  String? _authToken;
  String? _phoneNumber;
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
    _accountSid = config['account_sid'] as String?;
    _authToken = config['auth_token'] as String?;
    _phoneNumber = config['phone_number'] as String?;
    _allowedUsers = (config['allowed_users'] as List<dynamic>?)
        ?.map((e) => e.toString())
        .toList();

    if (_accountSid == null || _authToken == null || _phoneNumber == null) {
      throw Exception('WhatsApp configuration incomplete (account_sid, auth_token, phone_number required)');
    }

    // Test Twilio credentials
    try {
      final response = await http.get(
        Uri.parse('https://api.twilio.com/2010-04-01/Accounts/$_accountSid.json'),
        headers: {
          'Authorization': 'Basic ${base64Encode(utf8.encode('$_accountSid:$_authToken'))}',
        },
      );

      if (response.statusCode == 200) {
        print('✓ WhatsApp channel connected via Twilio');
        _isActive = true;
      } else {
        throw Exception('Failed to verify Twilio credentials: ${response.body}');
      }
    } catch (e) {
      _errorController.add(ChannelError(
        channelType: channelType,
        message: 'Failed to initialize WhatsApp channel',
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
      'From': 'whatsapp:$_phoneNumber',
      'To': 'whatsapp:$userId',
      'Body': content,
    };

    final response = await http.post(
      Uri.parse('https://api.twilio.com/2010-04-01/Accounts/$_accountSid/Messages.json'),
      headers: {
        'Authorization': 'Basic ${base64Encode(utf8.encode('$_accountSid:$_authToken'))}',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: params,
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to send WhatsApp message: ${response.body}');
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
      'From': 'whatsapp:$_phoneNumber',
      'To': 'whatsapp:$userId',
      'MediaUrl': imageUrl,
      if (caption != null) 'Body': caption,
    };

    final response = await http.post(
      Uri.parse('https://api.twilio.com/2010-04-01/Accounts/$_accountSid/Messages.json'),
      headers: {
        'Authorization': 'Basic ${base64Encode(utf8.encode('$_accountSid:$_authToken'))}',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: params,
    );

    if (response.statusCode != 201) {
      throw Exception('Failed to send WhatsApp image: ${response.body}');
    }
  }

  @override
  Future<void> sendFile(
    String userId,
    String fileUrl, {
    String? caption,
    String? replyToMessageId,
  }) async {
    await sendImage(userId, fileUrl, caption: caption);
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
    print('✓ WhatsApp channel closed');
  }

  /// Handle incoming webhook (call this from your HTTP server)
  Future<void> handleIncomingMessage(Map<String, dynamic> webhookData) async {
    final from = webhookData['From'] as String?;
    final body = webhookData['Body'] as String?;
    final messageSid = webhookData['MessageSid'] as String?;

    if (from == null || body == null || messageSid == null) return;

    // Extract phone number from "whatsapp:+1234567890" format
    final userId = from.replaceAll('whatsapp:', '');

    // Check authorization
    if (!await isAuthorized(userId)) {
      await sendMessage(userId, '⚠️ Unauthorized. Please contact the administrator.');
      return;
    }

    final unifiedMessage = UnifiedMessage(
      id: messageSid,
      channelType: channelType,
      channelId: userId,
      userId: userId,
      content: body,
      type: MessageType.text,
      timestamp: DateTime.now(),
    );

    _messageController.add(unifiedMessage);
  }
}
