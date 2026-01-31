import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;

/// Manages notifications across multiple channels
class NotificationManager {
  final Map<String, NotificationChannel> _channels = {};
  final StreamController<NotificationEvent> _eventController =
      StreamController.broadcast();

  Stream<NotificationEvent> get events => _eventController.stream;

  /// Register notification channel
  void registerChannel(String name, NotificationChannel channel) {
    _channels[name] = channel;
    print('Notification channel registered: $name');
  }

  /// Send notification to specific channel
  Future<void> send(
    String channelName,
    Notification notification,
  ) async {
    final channel = _channels[channelName];
    if (channel == null) {
      throw Exception('Channel not found: $channelName');
    }

    try {
      await channel.send(notification);

      _eventController.add(NotificationEvent(
        channelName: channelName,
        notification: notification,
        success: true,
        timestamp: DateTime.now(),
      ));
    } catch (e) {
      _eventController.add(NotificationEvent(
        channelName: channelName,
        notification: notification,
        success: false,
        error: e.toString(),
        timestamp: DateTime.now(),
      ));
      rethrow;
    }
  }

  /// Send notification to multiple channels
  Future<void> sendToAll(
    List<String> channelNames,
    Notification notification,
  ) async {
    await Future.wait(
      channelNames.map((name) => send(name, notification)),
    );
  }

  /// Broadcast notification to all channels
  Future<void> broadcast(Notification notification) async {
    await Future.wait(
      _channels.keys.map((name) => send(name, notification)),
    );
  }

  /// Get channel
  NotificationChannel? getChannel(String name) {
    return _channels[name];
  }

  /// Remove channel
  void removeChannel(String name) {
    _channels.remove(name);
  }

  /// Dispose resources
  Future<void> dispose() async {
    await _eventController.close();
  }
}

/// Notification model
class Notification {
  final String title;
  final String message;
  final NotificationPriority priority;
  final Map<String, dynamic>? data;
  final String? link;
  final List<String>? recipients;

  Notification({
    required this.title,
    required this.message,
    this.priority = NotificationPriority.normal,
    this.data,
    this.link,
    this.recipients,
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'message': message,
      'priority': priority.name,
      if (data != null) 'data': data,
      if (link != null) 'link': link,
      if (recipients != null) 'recipients': recipients,
    };
  }
}

enum NotificationPriority { low, normal, high, urgent }

/// Notification event
class NotificationEvent {
  final String channelName;
  final Notification notification;
  final bool success;
  final String? error;
  final DateTime timestamp;

  NotificationEvent({
    required this.channelName,
    required this.notification,
    required this.success,
    this.error,
    required this.timestamp,
  });
}

/// Base notification channel interface
abstract class NotificationChannel {
  String get name;
  Future<void> send(Notification notification);
}

/// Email notification channel
class EmailChannel implements NotificationChannel {
  @override
  final String name = 'email';

  final String smtpHost;
  final int smtpPort;
  final String username;
  final String password;
  final String fromAddress;
  final String fromName;

  EmailChannel({
    required this.smtpHost,
    required this.smtpPort,
    required this.username,
    required this.password,
    required this.fromAddress,
    this.fromName = 'OpenCLI',
  });

  @override
  Future<void> send(Notification notification) async {
    // Note: Would need mailer package for actual implementation
    // This is a placeholder
    print('EMAIL: To: ${notification.recipients?.join(", ")}');
    print('EMAIL: Subject: ${notification.title}');
    print('EMAIL: Body: ${notification.message}');

    // Simulated email sending
    await Future.delayed(Duration(milliseconds: 100));
  }
}

/// Slack notification channel
class SlackChannel implements NotificationChannel {
  @override
  final String name = 'slack';

  final String webhookUrl;
  final String? defaultChannel;
  final String? username;
  final String? iconEmoji;

  SlackChannel({
    required this.webhookUrl,
    this.defaultChannel,
    this.username,
    this.iconEmoji,
  });

  @override
  Future<void> send(Notification notification) async {
    final payload = {
      'text': notification.title,
      'attachments': [
        {
          'text': notification.message,
          'color': _getColor(notification.priority),
          if (notification.link != null)
            'actions': [
              {
                'type': 'button',
                'text': 'View Details',
                'url': notification.link,
              }
            ],
        }
      ],
      if (defaultChannel != null) 'channel': defaultChannel,
      if (username != null) 'username': username,
      if (iconEmoji != null) 'icon_emoji': iconEmoji,
    };

    final response = await http.post(
      Uri.parse(webhookUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode != 200) {
      throw Exception('Slack notification failed: ${response.body}');
    }
  }

  String _getColor(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.low:
        return 'good';
      case NotificationPriority.normal:
        return '#439FE0';
      case NotificationPriority.high:
        return 'warning';
      case NotificationPriority.urgent:
        return 'danger';
    }
  }
}

/// Discord notification channel
class DiscordChannel implements NotificationChannel {
  @override
  final String name = 'discord';

  final String webhookUrl;
  final String? username;
  final String? avatarUrl;

  DiscordChannel({
    required this.webhookUrl,
    this.username,
    this.avatarUrl,
  });

  @override
  Future<void> send(Notification notification) async {
    final payload = {
      'content': '**${notification.title}**\n${notification.message}',
      if (username != null) 'username': username,
      if (avatarUrl != null) 'avatar_url': avatarUrl,
      'embeds': [
        {
          'title': notification.title,
          'description': notification.message,
          'color': _getColor(notification.priority),
          if (notification.link != null) 'url': notification.link,
        }
      ],
    };

    final response = await http.post(
      Uri.parse(webhookUrl),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(payload),
    );

    if (response.statusCode != 204 && response.statusCode != 200) {
      throw Exception('Discord notification failed: ${response.body}');
    }
  }

  int _getColor(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.low:
        return 0x95a5a6; // Gray
      case NotificationPriority.normal:
        return 0x3498db; // Blue
      case NotificationPriority.high:
        return 0xf39c12; // Orange
      case NotificationPriority.urgent:
        return 0xe74c3c; // Red
    }
  }
}

/// Telegram notification channel
class TelegramChannel implements NotificationChannel {
  @override
  final String name = 'telegram';

  final String botToken;
  final String chatId;

  TelegramChannel({
    required this.botToken,
    required this.chatId,
  });

  @override
  Future<void> send(Notification notification) async {
    final text = '*${notification.title}*\n\n${notification.message}';

    final response = await http.post(
      Uri.parse('https://api.telegram.org/bot$botToken/sendMessage'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'chat_id': chatId,
        'text': text,
        'parse_mode': 'Markdown',
        if (notification.link != null)
          'reply_markup': {
            'inline_keyboard': [
              [
                {
                  'text': 'View Details',
                  'url': notification.link,
                }
              ]
            ],
          },
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Telegram notification failed: ${response.body}');
    }
  }
}

/// Webhook notification channel
class WebhookChannel implements NotificationChannel {
  @override
  final String name = 'webhook';

  final String url;
  final Map<String, String>? headers;
  final String method;

  WebhookChannel({
    required this.url,
    this.headers,
    this.method = 'POST',
  });

  @override
  Future<void> send(Notification notification) async {
    final payload = notification.toJson();

    final request = http.Request(method, Uri.parse(url));
    request.headers['Content-Type'] = 'application/json';
    if (headers != null) {
      request.headers.addAll(headers!);
    }
    request.body = jsonEncode(payload);

    final response = await request.send();
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final body = await response.stream.bytesToString();
      throw Exception('Webhook notification failed: $body');
    }
  }
}

/// SMS notification channel (placeholder)
class SMSChannel implements NotificationChannel {
  @override
  final String name = 'sms';

  final String provider; // twilio, nexmo, etc.
  final String accountId;
  final String authToken;
  final String fromNumber;

  SMSChannel({
    required this.provider,
    required this.accountId,
    required this.authToken,
    required this.fromNumber,
  });

  @override
  Future<void> send(Notification notification) async {
    // Would need provider-specific implementation
    print('SMS: ${notification.message}');
    await Future.delayed(Duration(milliseconds: 100));
  }
}

/// Push notification channel (placeholder)
class PushNotificationChannel implements NotificationChannel {
  @override
  final String name = 'push';

  final String provider; // fcm, apns
  final String serverKey;

  PushNotificationChannel({
    required this.provider,
    required this.serverKey,
  });

  @override
  Future<void> send(Notification notification) async {
    // Would need provider-specific implementation (FCM, APNs)
    print('PUSH: ${notification.title}');
    await Future.delayed(Duration(milliseconds: 100));
  }
}

/// Desktop notification channel
class DesktopNotificationChannel implements NotificationChannel {
  @override
  final String name = 'desktop';

  @override
  Future<void> send(Notification notification) async {
    // Platform-specific desktop notifications
    // macOS: osascript -e 'display notification "message" with title "title"'
    // Linux: notify-send "title" "message"
    // Windows: Would need Windows API calls

    print('DESKTOP NOTIFICATION: ${notification.title}');
    print('${notification.message}');

    // Placeholder implementation
    await Future.delayed(Duration(milliseconds: 100));
  }
}

/// Notification template system
class NotificationTemplate {
  final String id;
  final String title;
  final String message;
  final Map<String, String>? variables;

  NotificationTemplate({
    required this.id,
    required this.title,
    required this.message,
    this.variables,
  });

  /// Render template with variables
  Notification render(Map<String, dynamic> data) {
    var renderedTitle = title;
    var renderedMessage = message;

    data.forEach((key, value) {
      renderedTitle = renderedTitle.replaceAll('{{$key}}', value.toString());
      renderedMessage = renderedMessage.replaceAll('{{$key}}', value.toString());
    });

    return Notification(
      title: renderedTitle,
      message: renderedMessage,
    );
  }
}

/// Notification templates manager
class NotificationTemplateManager {
  final Map<String, NotificationTemplate> _templates = {};

  /// Register template
  void registerTemplate(NotificationTemplate template) {
    _templates[template.id] = template;
  }

  /// Get template
  NotificationTemplate? getTemplate(String id) {
    return _templates[id];
  }

  /// Render template
  Notification? render(String templateId, Map<String, dynamic> data) {
    final template = _templates[templateId];
    return template?.render(data);
  }

  /// Register common templates
  void registerCommonTemplates() {
    registerTemplate(NotificationTemplate(
      id: 'task_completed',
      title: 'Task Completed',
      message: 'Task "{{task_name}}" has been completed successfully.',
    ));

    registerTemplate(NotificationTemplate(
      id: 'task_failed',
      title: 'Task Failed',
      message: 'Task "{{task_name}}" failed with error: {{error}}',
    ));

    registerTemplate(NotificationTemplate(
      id: 'worker_offline',
      title: 'Worker Offline',
      message: 'Worker "{{worker_name}}" has gone offline.',
    ));

    registerTemplate(NotificationTemplate(
      id: 'system_alert',
      title: 'System Alert',
      message: 'System alert: {{message}}',
    ));
  }
}
