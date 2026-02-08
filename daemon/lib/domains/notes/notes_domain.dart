import 'dart:io';
import '../domain.dart';

class NotesDomain extends TaskDomain {
  @override
  String get id => 'notes';
  @override
  String get name => 'Notes';
  @override
  String get description => 'Create, search, and list notes via Notes.app';
  @override
  String get icon => 'note';
  @override
  int get colorHex => 0xFFFFC107;

  @override
  List<String> get taskTypes => ['notes_create', 'notes_search', 'notes_list'];

  @override
  List<DomainIntentPattern> get intentPatterns => [
        DomainIntentPattern(
          pattern: RegExp(
              r'^(?:create|make|new)\s+(?:a\s+)?note\s+(?:about\s+|titled?\s+)?(.+)$',
              caseSensitive: false),
          taskType: 'notes_create',
          extractData: (m) =>
              {'title': m.group(1)!.trim(), 'body': m.group(1)!.trim()},
        ),
        DomainIntentPattern(
          pattern: RegExp(r'^note:\s*(.+)$', caseSensitive: false),
          taskType: 'notes_create',
          extractData: (m) =>
              {'title': m.group(1)!.trim(), 'body': m.group(1)!.trim()},
        ),
        DomainIntentPattern(
          pattern: RegExp(
              r'^(?:search|find)\s+notes?\s+(?:about\s+|for\s+)?(.+)$',
              caseSensitive: false),
          taskType: 'notes_search',
          extractData: (m) => {'query': m.group(1)!.trim()},
        ),
        DomainIntentPattern(
          pattern: RegExp(r'^(?:show|list)\s+(?:my\s+)?(?:recent\s+)?notes$',
              caseSensitive: false),
          taskType: 'notes_list',
          extractData: (_) => {},
        ),
      ];

  @override
  List<DomainOllamaIntent> get ollamaIntents => [
        DomainOllamaIntent(
          intentName: 'notes_create',
          description: 'Create a new note in Notes.app',
          parameters: {'title': 'note title', 'body': 'note content'},
          examples: [
            OllamaExample(
                input: 'create note about shopping list',
                intentJson:
                    '{"intent": "notes_create", "confidence": 0.95, "parameters": {"title": "shopping list", "body": "shopping list"}}'),
            OllamaExample(
                input: 'note: meeting ideas for project',
                intentJson:
                    '{"intent": "notes_create", "confidence": 0.95, "parameters": {"title": "meeting ideas for project", "body": "meeting ideas for project"}}'),
          ],
        ),
        DomainOllamaIntent(
          intentName: 'notes_search',
          description: 'Search notes by keyword',
          parameters: {'query': 'search term'},
          examples: [
            OllamaExample(
                input: 'find notes about recipes',
                intentJson:
                    '{"intent": "notes_search", "confidence": 0.95, "parameters": {"query": "recipes"}}'),
          ],
        ),
        DomainOllamaIntent(
          intentName: 'notes_list',
          description: 'List recent notes',
          examples: [
            OllamaExample(
                input: 'show my notes',
                intentJson:
                    '{"intent": "notes_list", "confidence": 0.95, "parameters": {}}'),
          ],
        ),
      ];

  @override
  Map<String, DomainDisplayConfig> get displayConfigs => {
        'notes_create': const DomainDisplayConfig(
            cardType: 'notes',
            titleTemplate: 'Note Created',
            icon: 'note_add',
            colorHex: 0xFFFFC107),
        'notes_search': const DomainDisplayConfig(
            cardType: 'notes',
            titleTemplate: 'Notes Search',
            icon: 'search',
            colorHex: 0xFFFFC107),
        'notes_list': const DomainDisplayConfig(
            cardType: 'notes',
            titleTemplate: 'Recent Notes',
            icon: 'note',
            colorHex: 0xFFFFC107),
      };

  @override
  Future<Map<String, dynamic>> executeTask(
      String taskType, Map<String, dynamic> data) async {
    switch (taskType) {
      case 'notes_create':
        return _createNote(data);
      case 'notes_search':
        return _searchNotes(data);
      case 'notes_list':
        return _listNotes();
      default:
        return {'success': false, 'error': 'Unknown notes task: $taskType'};
    }
  }

  Future<Map<String, dynamic>> _createNote(Map<String, dynamic> data) async {
    final title = data['title'] as String? ?? 'Untitled';
    final body = data['body'] as String? ?? '';
    final script = '''
tell application "Notes"
  make new note at folder "Notes" with properties {name:"$title", body:"$body"}
  return "Created note: $title"
end tell''';
    try {
      final result = await Process.run('osascript', ['-e', script]);
      return {
        'success': result.exitCode == 0,
        'title': title,
        'message': (result.stdout as String).trim(),
        'domain': 'notes',
        'card_type': 'notes',
      };
    } catch (e) {
      return {'success': false, 'error': 'Error: $e', 'domain': 'notes'};
    }
  }

  Future<Map<String, dynamic>> _searchNotes(Map<String, dynamic> data) async {
    final query = data['query'] as String? ?? '';
    final script = '''
tell application "Notes"
  set output to ""
  set noteCount to 0
  repeat with n in notes of folder "Notes"
    if name of n contains "$query" or body of n contains "$query" then
      set output to output & name of n & "\\n"
      set noteCount to noteCount + 1
      if noteCount >= 10 then exit repeat
    end if
  end repeat
  if output is "" then
    return "No notes found matching: $query"
  end if
  return output
end tell''';
    try {
      final result = await Process.run('osascript', ['-e', script]);
      final output = (result.stdout as String).trim();
      final items =
          output.split('\n').where((s) => s.trim().isNotEmpty).toList();
      return {
        'success': result.exitCode == 0,
        'query': query,
        'items': items,
        'count': items.length,
        'domain': 'notes',
        'card_type': 'notes',
      };
    } catch (e) {
      return {'success': false, 'error': 'Error: $e', 'domain': 'notes'};
    }
  }

  Future<Map<String, dynamic>> _listNotes() async {
    final script = '''
tell application "Notes"
  set output to ""
  set noteList to notes of folder "Notes"
  set maxCount to 10
  if (count of noteList) < maxCount then set maxCount to count of noteList
  repeat with i from 1 to maxCount
    set n to item i of noteList
    set output to output & name of n & "\\n"
  end repeat
  if output is "" then
    return "No notes found"
  end if
  return output
end tell''';
    try {
      final result = await Process.run('osascript', ['-e', script]);
      final output = (result.stdout as String).trim();
      final items =
          output.split('\n').where((s) => s.trim().isNotEmpty).toList();
      return {
        'success': result.exitCode == 0,
        'items': items,
        'count': items.length,
        'domain': 'notes',
        'card_type': 'notes',
      };
    } catch (e) {
      return {'success': false, 'error': 'Error: $e', 'domain': 'notes'};
    }
  }
}
