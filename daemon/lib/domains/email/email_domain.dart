import 'dart:io';
import '../domain.dart';

class EmailDomain extends TaskDomain {
  @override
  String get id => 'email';
  @override
  String get name => 'Email';
  @override
  String get description => 'Compose emails and check inbox via Mail.app';
  @override
  String get icon => 'email';
  @override
  int get colorHex => 0xFFF44336;

  @override
  List<String> get taskTypes => ['email_compose', 'email_check'];

  @override
  List<DomainIntentPattern> get intentPatterns => [
        DomainIntentPattern(
          pattern: RegExp(
              r'^(?:email|send\s+(?:an?\s+)?email\s+to)\s+(\S+@\S+)\s+(?:about|re|regarding)\s+(.+)$',
              caseSensitive: false),
          taskType: 'email_compose',
          extractData: (m) =>
              {'to': m.group(1)!, 'subject': m.group(2)!.trim()},
        ),
        DomainIntentPattern(
          pattern: RegExp(
              r'^(?:email|send\s+(?:an?\s+)?email\s+to)\s+(.+?)\s+(?:about|re|regarding)\s+(.+)$',
              caseSensitive: false),
          taskType: 'email_compose',
          extractData: (m) =>
              {'to': m.group(1)!.trim(), 'subject': m.group(2)!.trim()},
        ),
        DomainIntentPattern(
          pattern: RegExp(
              r'^(?:check\s+(?:my\s+)?email|any\s+new\s+mail|unread\s+emails?|inbox)$',
              caseSensitive: false),
          taskType: 'email_check',
          extractData: (_) => {},
        ),
      ];

  @override
  List<DomainOllamaIntent> get ollamaIntents => [
        DomainOllamaIntent(
          intentName: 'email_compose',
          description: 'Compose and open a new email in Mail.app',
          parameters: {'to': 'recipient', 'subject': 'email subject'},
          examples: [
            OllamaExample(
                input: 'email john@example.com about the meeting',
                intentJson:
                    '{"intent": "email_compose", "confidence": 0.95, "parameters": {"to": "john@example.com", "subject": "the meeting"}}'),
            OllamaExample(
                input: 'send email to the team about standup',
                intentJson:
                    '{"intent": "email_compose", "confidence": 0.95, "parameters": {"to": "the team", "subject": "standup"}}'),
          ],
        ),
        DomainOllamaIntent(
          intentName: 'email_check',
          description: 'Check for unread emails in inbox',
          examples: [
            OllamaExample(
                input: 'check my email',
                intentJson:
                    '{"intent": "email_check", "confidence": 0.95, "parameters": {}}'),
            OllamaExample(
                input: 'any new mail',
                intentJson:
                    '{"intent": "email_check", "confidence": 0.95, "parameters": {}}'),
          ],
        ),
      ];

  @override
  Map<String, DomainDisplayConfig> get displayConfigs => {
        'email_compose': const DomainDisplayConfig(
            cardType: 'email',
            titleTemplate: 'Email Composed',
            icon: 'send',
            colorHex: 0xFFF44336),
        'email_check': const DomainDisplayConfig(
            cardType: 'email',
            titleTemplate: 'Inbox',
            icon: 'inbox',
            colorHex: 0xFFF44336),
      };

  @override
  Future<Map<String, dynamic>> executeTask(
      String taskType, Map<String, dynamic> data) async {
    switch (taskType) {
      case 'email_compose':
        return _composeEmail(data);
      case 'email_check':
        return _checkEmail();
      default:
        return {'success': false, 'error': 'Unknown email task: $taskType'};
    }
  }

  Future<Map<String, dynamic>> _composeEmail(Map<String, dynamic> data) async {
    final to = data['to'] as String? ?? '';
    final subject = data['subject'] as String? ?? '';
    final script = '''
tell application "Mail"
  set newMsg to make new outgoing message with properties {subject:"$subject", content:"", visible:true}
  tell newMsg
    make new to recipient at end of to recipients with properties {address:"$to"}
  end tell
  activate
end tell''';
    try {
      final result = await Process.run('osascript', ['-e', script]);
      return {
        'success': result.exitCode == 0,
        'to': to,
        'subject': subject,
        'message': result.exitCode == 0
            ? 'Email draft opened for $to'
            : (result.stderr as String).trim(),
        'domain': 'email',
        'card_type': 'email',
      };
    } catch (e) {
      return {'success': false, 'error': 'Error: $e', 'domain': 'email'};
    }
  }

  Future<Map<String, dynamic>> _checkEmail() async {
    final script = '''
tell application "Mail"
  check for new mail
  set unreadCount to unread count of inbox
  return unreadCount as string
end tell''';
    try {
      final result = await Process.run('osascript', ['-e', script]);
      final count = int.tryParse((result.stdout as String).trim()) ?? 0;
      return {
        'success': result.exitCode == 0,
        'unread_count': count,
        'message':
            count > 0 ? 'You have $count unread email(s)' : 'No unread emails',
        'domain': 'email',
        'card_type': 'email',
      };
    } catch (e) {
      return {'success': false, 'error': 'Error: $e', 'domain': 'email'};
    }
  }
}
