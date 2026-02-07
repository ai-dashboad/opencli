import 'dart:io';
import '../domain.dart';

class RemindersDomain extends TaskDomain {
  @override
  String get id => 'reminders';
  @override
  String get name => 'Reminders';
  @override
  String get description => 'Add, list, and complete reminders via Reminders.app';
  @override
  String get icon => 'checklist';
  @override
  int get colorHex => 0xFFFF9800;

  @override
  List<String> get taskTypes => ['reminders_add', 'reminders_list', 'reminders_complete'];

  @override
  List<DomainIntentPattern> get intentPatterns => [
    // "remind me to buy groceries" / "add reminder call dentist"
    DomainIntentPattern(
      pattern: RegExp(r'^(?:remind\s+me\s+to|add\s+(?:a\s+)?reminder(?:\s+to)?)\s+(.+?)(?:\s+(?:at|by|on)\s+(.+))?$', caseSensitive: false),
      taskType: 'reminders_add',
      extractData: (m) => {'title': m.group(1)!.trim(), 'due': m.group(2)},
    ),
    // "add X to shopping list" / "add X to groceries"
    DomainIntentPattern(
      pattern: RegExp(r'^add\s+(.+?)\s+to\s+(?:my\s+)?(?:shopping\s+list|groceries|grocery\s+list)$', caseSensitive: false),
      taskType: 'reminders_add',
      extractData: (m) => {'title': m.group(1)!.trim(), 'list': 'Shopping'},
    ),
    // "show reminders" / "my reminders" / "list reminders"
    DomainIntentPattern(
      pattern: RegExp(r'^(?:show|list|my|check)\s*(?:my\s+)?reminders?$', caseSensitive: false),
      taskType: 'reminders_list',
      extractData: (_) => {},
    ),
    // "complete X" / "mark X done" / "done with X"
    DomainIntentPattern(
      pattern: RegExp(r'^(?:complete|finish|done\s+with|mark\s+.+?\s+(?:as\s+)?done)\s*(.+)?$', caseSensitive: false),
      taskType: 'reminders_complete',
      extractData: (m) => {'title': m.group(1)?.trim() ?? ''},
    ),
  ];

  @override
  List<DomainOllamaIntent> get ollamaIntents => [
    DomainOllamaIntent(
      intentName: 'reminders_add',
      description: 'Add a new reminder to Reminders.app',
      parameters: {'title': 'what to remember', 'due': 'optional due date/time'},
      examples: [
        OllamaExample(input: 'remind me to buy groceries', intentJson: '{"intent": "reminders_add", "confidence": 0.95, "parameters": {"title": "buy groceries"}}'),
        OllamaExample(input: 'remind me to call dentist at 3pm', intentJson: '{"intent": "reminders_add", "confidence": 0.95, "parameters": {"title": "call dentist", "due": "3pm"}}'),
        OllamaExample(input: 'add milk to shopping list', intentJson: '{"intent": "reminders_add", "confidence": 0.95, "parameters": {"title": "milk", "list": "Shopping"}}'),
      ],
    ),
    DomainOllamaIntent(
      intentName: 'reminders_list',
      description: 'Show pending reminders',
      examples: [
        OllamaExample(input: 'show my reminders', intentJson: '{"intent": "reminders_list", "confidence": 0.95, "parameters": {}}'),
      ],
    ),
    DomainOllamaIntent(
      intentName: 'reminders_complete',
      description: 'Mark a reminder as completed',
      parameters: {'title': 'reminder title to complete'},
      examples: [
        OllamaExample(input: 'done with buy groceries', intentJson: '{"intent": "reminders_complete", "confidence": 0.95, "parameters": {"title": "buy groceries"}}'),
      ],
    ),
  ];

  @override
  Map<String, DomainDisplayConfig> get displayConfigs => {
    'reminders_add': const DomainDisplayConfig(cardType: 'reminders', titleTemplate: 'Reminder Added', icon: 'add_task', colorHex: 0xFFFF9800),
    'reminders_list': const DomainDisplayConfig(cardType: 'reminders', titleTemplate: 'Reminders', icon: 'checklist', colorHex: 0xFFFF9800),
    'reminders_complete': const DomainDisplayConfig(cardType: 'reminders', titleTemplate: 'Reminder Completed', icon: 'task_alt', colorHex: 0xFFFF9800),
  };

  @override
  Future<Map<String, dynamic>> executeTask(String taskType, Map<String, dynamic> data) async {
    switch (taskType) {
      case 'reminders_add':
        return _addReminder(data);
      case 'reminders_list':
        return _listReminders();
      case 'reminders_complete':
        return _completeReminder(data);
      default:
        return {'success': false, 'error': 'Unknown reminders task: $taskType'};
    }
  }

  Future<Map<String, dynamic>> _addReminder(Map<String, dynamic> data) async {
    final title = data['title'] as String? ?? 'Reminder';
    final listName = data['list'] as String? ?? 'Reminders';
    final script = '''
tell application "Reminders"
  set myList to list "$listName"
  tell myList
    make new reminder with properties {name:"$title"}
  end tell
end tell''';
    try {
      final result = await Process.run('osascript', ['-e', script]);
      return {
        'success': result.exitCode == 0,
        'title': title,
        'list': listName,
        'message': result.exitCode == 0 ? 'Reminder "$title" added to $listName' : (result.stderr as String).trim(),
        'domain': 'reminders', 'card_type': 'reminders',
      };
    } catch (e) {
      return {'success': false, 'error': 'Error: $e', 'domain': 'reminders'};
    }
  }

  Future<Map<String, dynamic>> _listReminders() async {
    final script = '''
tell application "Reminders"
  set output to ""
  repeat with r in (reminders of list "Reminders" whose completed is false)
    set dueStr to ""
    try
      set dueStr to " (due: " & (due date of r as string) & ")"
    end try
    set output to output & name of r & dueStr & "\\n"
  end repeat
  if output is "" then
    return "No pending reminders"
  end if
  return output
end tell''';
    try {
      final result = await Process.run('osascript', ['-e', script]);
      final output = (result.stdout as String).trim();
      final items = output.split('\n').where((s) => s.trim().isNotEmpty).toList();
      return {
        'success': result.exitCode == 0,
        'items': items,
        'count': items.length,
        'raw': output,
        'domain': 'reminders', 'card_type': 'reminders',
      };
    } catch (e) {
      return {'success': false, 'error': 'Error: $e', 'domain': 'reminders'};
    }
  }

  Future<Map<String, dynamic>> _completeReminder(Map<String, dynamic> data) async {
    final title = data['title'] as String? ?? '';
    final script = '''
tell application "Reminders"
  set matchFound to false
  repeat with r in (reminders of list "Reminders" whose completed is false)
    if name of r contains "$title" then
      set completed of r to true
      set matchFound to true
      exit repeat
    end if
  end repeat
  if matchFound then
    return "Completed: $title"
  else
    return "No matching reminder found: $title"
  end if
end tell''';
    try {
      final result = await Process.run('osascript', ['-e', script]);
      final output = (result.stdout as String).trim();
      return {
        'success': result.exitCode == 0 && output.startsWith('Completed'),
        'title': title,
        'message': output,
        'domain': 'reminders', 'card_type': 'reminders',
      };
    } catch (e) {
      return {'success': false, 'error': 'Error: $e', 'domain': 'reminders'};
    }
  }
}
