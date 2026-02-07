import 'dart:io';
import '../domain.dart';

class ContactsDomain extends TaskDomain {
  @override
  String get id => 'contacts';
  @override
  String get name => 'Contacts';
  @override
  String get description => 'Find contacts and make calls via Contacts.app and FaceTime';
  @override
  String get icon => 'contacts';
  @override
  int get colorHex => 0xFF4CAF50;

  @override
  List<String> get taskTypes => ['contacts_find', 'contacts_call'];

  @override
  List<DomainIntentPattern> get intentPatterns => [
    DomainIntentPattern(
      pattern: RegExp(r"^(?:find\s+contact|look\s+up|search\s+contacts?\s+for|what'?s?\s+.+?'?s?\s+(?:number|phone|email))\s+(.+)$", caseSensitive: false),
      taskType: 'contacts_find',
      extractData: (m) => {'name': m.group(1)!.trim()},
    ),
    DomainIntentPattern(
      pattern: RegExp(r'^(?:call|phone|dial|facetime)\s+(.+)$', caseSensitive: false),
      taskType: 'contacts_call',
      extractData: (m) => {'name': m.group(1)!.trim()},
    ),
  ];

  @override
  List<DomainOllamaIntent> get ollamaIntents => [
    DomainOllamaIntent(
      intentName: 'contacts_find',
      description: 'Search for a contact by name',
      parameters: {'name': 'contact name to search'},
      examples: [
        OllamaExample(input: 'find contact John', intentJson: '{"intent": "contacts_find", "confidence": 0.95, "parameters": {"name": "John"}}'),
        OllamaExample(input: "what's mom's number", intentJson: '{"intent": "contacts_find", "confidence": 0.95, "parameters": {"name": "mom"}}'),
      ],
    ),
    DomainOllamaIntent(
      intentName: 'contacts_call',
      description: 'Call a contact via FaceTime',
      parameters: {'name': 'person to call'},
      examples: [
        OllamaExample(input: 'call mom', intentJson: '{"intent": "contacts_call", "confidence": 0.95, "parameters": {"name": "mom"}}'),
      ],
    ),
  ];

  @override
  Map<String, DomainDisplayConfig> get displayConfigs => {
    'contacts_find': const DomainDisplayConfig(cardType: 'contacts', titleTemplate: 'Contact', icon: 'person', colorHex: 0xFF4CAF50),
    'contacts_call': const DomainDisplayConfig(cardType: 'contacts', titleTemplate: 'Calling', icon: 'phone', colorHex: 0xFF4CAF50),
  };

  @override
  Future<Map<String, dynamic>> executeTask(String taskType, Map<String, dynamic> data) async {
    switch (taskType) {
      case 'contacts_find':
        return _findContact(data);
      case 'contacts_call':
        return _callContact(data);
      default:
        return {'success': false, 'error': 'Unknown contacts task: $taskType'};
    }
  }

  Future<Map<String, dynamic>> _findContact(Map<String, dynamic> data) async {
    final name = data['name'] as String? ?? '';
    final script = '''
tell application "Contacts"
  set found to every person whose name contains "$name"
  set output to ""
  repeat with p in found
    set pName to name of p
    set pPhone to ""
    set pEmail to ""
    try
      set pPhone to value of first phone of p
    end try
    try
      set pEmail to value of first email of p
    end try
    set output to output & pName & " | " & pPhone & " | " & pEmail & "\\n"
  end repeat
  if output is "" then
    return "No contacts found matching: $name"
  end if
  return output
end tell''';
    try {
      final result = await Process.run('osascript', ['-e', script]);
      final output = (result.stdout as String).trim();
      final contacts = <Map<String, String>>[];
      for (final line in output.split('\n')) {
        if (line.trim().isEmpty) continue;
        final parts = line.split(' | ');
        contacts.add({
          'name': parts.isNotEmpty ? parts[0].trim() : '',
          'phone': parts.length > 1 ? parts[1].trim() : '',
          'email': parts.length > 2 ? parts[2].trim() : '',
        });
      }
      return {
        'success': result.exitCode == 0,
        'query': name,
        'contacts': contacts,
        'count': contacts.length,
        'domain': 'contacts', 'card_type': 'contacts',
      };
    } catch (e) {
      return {'success': false, 'error': 'Error: $e', 'domain': 'contacts'};
    }
  }

  Future<Map<String, dynamic>> _callContact(Map<String, dynamic> data) async {
    final name = data['name'] as String? ?? '';
    // First find the contact's phone number, then initiate call
    final script = '''
tell application "Contacts"
  set found to every person whose name contains "$name"
  if (count of found) > 0 then
    set p to item 1 of found
    set pName to name of p
    try
      set pPhone to value of first phone of p
      tell application "FaceTime" to open location "tel://" & pPhone
      return "Calling " & pName & " at " & pPhone
    on error
      return "No phone number for " & pName
    end try
  else
    return "Contact not found: $name"
  end if
end tell''';
    try {
      final result = await Process.run('osascript', ['-e', script]);
      final output = (result.stdout as String).trim();
      return {
        'success': result.exitCode == 0 && output.startsWith('Calling'),
        'name': name,
        'message': output,
        'domain': 'contacts', 'card_type': 'contacts',
      };
    } catch (e) {
      return {'success': false, 'error': 'Error: $e', 'domain': 'contacts'};
    }
  }
}
