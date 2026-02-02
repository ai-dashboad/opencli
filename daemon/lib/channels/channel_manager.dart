import 'dart:async';
import 'base_channel.dart';
import 'telegram_channel.dart';
import 'whatsapp_channel.dart';
import 'slack_channel.dart';
import 'discord_channel.dart';
import 'wechat_channel.dart';
import 'sms_channel.dart';
import 'models/unified_message.dart';
import 'models/channel_config.dart';

/// Manages multiple message channels
class ChannelManager {
  final Map<String, BaseChannel> _channels = {};
  final _messageController = StreamController<UnifiedMessage>.broadcast();
  final _errorController = StreamController<ChannelError>.broadcast();

  /// Stream of all incoming messages from all channels
  Stream<UnifiedMessage> get messageStream => _messageController.stream;

  /// Stream of all errors from all channels
  Stream<ChannelError> get errorStream => _errorController.stream;

  /// Get list of active channel types
  List<String> get activeChannels =>
      _channels.values.where((c) => c.isActive).map((c) => c.channelType).toList();

  /// Initialize all channels from configuration
  Future<void> initialize(Map<String, ChannelConfig> configs) async {
    print('🚀 Initializing channels...');

    for (final entry in configs.entries) {
      final channelType = entry.key;
      final config = entry.value;

      if (!config.enabled) {
        print('⏭️  Skipping disabled channel: $channelType');
        continue;
      }

      try {
        final channel = _createChannel(channelType);
        if (channel != null) {
          await channel.initialize(config.config);
          _channels[channelType] = channel;

          // Listen to messages
          channel.messageStream.listen(
            (message) => _messageController.add(message),
            onError: (error) => _errorController.add(error),
          );

          // Listen to errors
          channel.errorStream.listen(
            (error) => _errorController.add(error),
          );

          print('✓ Channel initialized: $channelType');
        }
      } catch (e, stack) {
        print('❌ Failed to initialize $channelType: $e');
        _errorController.add(ChannelError(
          channelType: channelType,
          message: 'Initialization failed',
          error: e,
          stackTrace: stack,
        ));
      }
    }

    print('✓ Channel manager initialized (${_channels.length} channels active)');
  }

  /// Create a channel instance by type
  BaseChannel? _createChannel(String channelType) {
    switch (channelType.toLowerCase()) {
      case 'telegram':
        return TelegramChannel();
      case 'whatsapp':
        return WhatsAppChannel();
      case 'slack':
        return SlackChannel();
      case 'discord':
        return DiscordChannel();
      case 'wechat':
        return WeChatChannel();
      case 'sms':
        return SMSChannel();
      default:
        print('⚠️  Unknown channel type: $channelType');
        return null;
    }
  }

  /// Send a reply to a specific channel
  Future<void> sendReply(
    String channelType,
    String userId,
    String content, {
    MessageType type = MessageType.text,
    String? replyToMessageId,
  }) async {
    final channel = _channels[channelType];
    if (channel == null) {
      throw Exception('Channel not found: $channelType');
    }

    await channel.sendMessage(
      userId,
      content,
      type: type,
      replyToMessageId: replyToMessageId,
    );
  }

  /// Send an image to a specific channel
  Future<void> sendImage(
    String channelType,
    String userId,
    String imageUrl, {
    String? caption,
  }) async {
    final channel = _channels[channelType];
    if (channel == null) {
      throw Exception('Channel not found: $channelType');
    }

    await channel.sendImage(userId, imageUrl, caption: caption);
  }

  /// Close all channels
  Future<void> close() async {
    print('🛑 Closing all channels...');
    for (final channel in _channels.values) {
      await channel.close();
    }
    _channels.clear();
    await _messageController.close();
    await _errorController.close();
    print('✓ All channels closed');
  }
}
