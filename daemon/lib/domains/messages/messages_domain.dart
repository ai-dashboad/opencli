import 'dart:io';
import '../domain.dart';

class MessagesDomain extends TaskDomain {
  @override
  String get id => 'messages';
  @override
  String get name => 'Messages';
  @override
  String get description => 'Send iMessages via Messages.app';
  @override
  String get icon => 'chat';
  @override
  int get colorHex => 0xFF4CAF50;

  @override
  List<String> get taskTypes => ['messages_send'];

  @override
  List<DomainIntentPattern> get intentPatterns => [
        DomainIntentPattern(
          pattern: RegExp(
              r'^(?:send\s+(?:a\s+)?message|text|imessage)\s+(?:to\s+)?(.+?)\s+(?:saying|that|:)\s+(.+)$',
              caseSensitive: false),
          taskType: 'messages_send',
          extractData: (m) =>
              {'recipient': m.group(1)!.trim(), 'message': m.group(2)!.trim()},
        ),
        DomainIntentPattern(
          pattern: RegExp(r'^(?:message|text)\s+(.+)$', caseSensitive: false),
          taskType: 'messages_send',
          extractData: (m) => {'recipient': m.group(1)!.trim(), 'message': ''},
          confidence: 0.7,
        ),
      ];

  @override
  List<DomainOllamaIntent> get ollamaIntents => [
        DomainOllamaIntent(
          intentName: 'messages_send',
          description: 'Send an iMessage to a contact',
          parameters: {
            'recipient': 'person or phone number',
            'message': 'message text'
          },
          examples: [
            OllamaExample(
                input: 'text mom saying I will be late',
                intentJson:
                    '{"intent": "messages_send", "confidence": 0.95, "parameters": {"recipient": "mom", "message": "I will be late"}}'),
            OllamaExample(
                input: 'send message to John: meeting at 3',
                intentJson:
                    '{"intent": "messages_send", "confidence": 0.95, "parameters": {"recipient": "John", "message": "meeting at 3"}}'),
          ],
        ),
      ];

  @override
  Map<String, DomainDisplayConfig> get displayConfigs => {
        'messages_send': const DomainDisplayConfig(
            cardType: 'messages',
            titleTemplate: 'Message Sent',
            icon: 'send',
            colorHex: 0xFF4CAF50),
      };

  @override
  Future<Map<String, dynamic>> executeTask(
      String taskType, Map<String, dynamic> data) async {
    if (taskType == 'messages_send') return _sendMessage(data);
    return {'success': false, 'error': 'Unknown messages task: $taskType'};
  }

  Future<Map<String, dynamic>> _sendMessage(Map<String, dynamic> data) async {
    final recipient = data['recipient'] as String? ?? '';
    final message = data['message'] as String? ?? '';

    if (message.isEmpty) {
      // Open Messages.app with recipient but no message
      try {
        await Process.run('open', ['-a', 'Messages']);
        return {
          'success': true,
          'recipient': recipient,
          'message': 'Opened Messages app',
          'domain': 'messages',
          'card_type': 'messages',
        };
      } catch (e) {
        return {'success': false, 'error': 'Error: $e', 'domain': 'messages'};
      }
    }

    // Try to find the recipient's phone number first
    final script = '''
tell application "Contacts"
  set found to every person whose name contains "$recipient"
  if (count of found) > 0 then
    set p to item 1 of found
    try
      set pPhone to value of first phone of p
      tell application "Messages"
        set targetService to 1st account whose service type = iMessage
        set targetBuddy to participant pPhone of targetService
        send "$message" to targetBuddy
      end tell
      return "Message sent to " & name of p
    on error errMsg
      return "Error: " & errMsg
    end try
  else
    return "Contact not found: $recipient"
  end if
end tell''';

    try {
      final result = await Process.run('osascript', ['-e', script]);
      final output = (result.stdout as String).trim();
      return {
        'success': result.exitCode == 0 && output.startsWith('Message sent'),
        'recipient': recipient,
        'message_text': message,
        'result': output,
        'domain': 'messages',
        'card_type': 'messages',
      };
    } catch (e) {
      return {'success': false, 'error': 'Error: $e', 'domain': 'messages'};
    }
  }
}
