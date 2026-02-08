import 'dart:io';
import '../domain.dart';

class CalendarDomain extends TaskDomain {
  @override
  String get id => 'calendar';
  @override
  String get name => 'Calendar';
  @override
  String get description =>
      'Schedule, list, and manage calendar events via Calendar.app';
  @override
  String get icon => 'calendar_today';
  @override
  int get colorHex => 0xFF2196F3;

  @override
  List<String> get taskTypes =>
      ['calendar_add_event', 'calendar_list_events', 'calendar_delete_event'];

  @override
  List<DomainIntentPattern> get intentPatterns => [
        // "schedule meeting at 3pm" / "add event dentist tomorrow 2pm"
        DomainIntentPattern(
          pattern: RegExp(
              r'^(?:schedule|add\s+(?:an?\s+)?(?:event|meeting|appointment)|create\s+(?:an?\s+)?(?:event|meeting))\s+(?:about\s+|titled?\s+|for\s+|with\s+)?(.+?)(?:\s+(?:at|on|for|tomorrow|today)\s*(.+))?$',
              caseSensitive: false),
          taskType: 'calendar_add_event',
          extractData: (m) =>
              {'title': m.group(1)!.trim(), 'datetime_raw': m.group(2) ?? ''},
        ),
        // "meeting with Alice tomorrow at 3pm"
        DomainIntentPattern(
          pattern: RegExp(
              r'^meeting\s+(?:with\s+)?(.+?)\s+(today|tomorrow|monday|tuesday|wednesday|thursday|friday|saturday|sunday)(?:\s+(?:at\s+)?(.+))?$',
              caseSensitive: false),
          taskType: 'calendar_add_event',
          extractData: (m) => {
            'title': 'Meeting with ${m.group(1)!.trim()}',
            'datetime_raw': '${m.group(2)} ${m.group(3) ?? ''}'.trim()
          },
        ),
        // "what's on my calendar" / "my schedule today" / "agenda"
        DomainIntentPattern(
          pattern: RegExp(
              r"^(?:what'?s?\s+on\s+my\s+(?:calendar|schedule)|my\s+(?:calendar|schedule|agenda)(?:\s+(?:for\s+)?(today|tomorrow))?|agenda(?:\s+(?:for\s+)?(today|tomorrow))?)$",
              caseSensitive: false),
          taskType: 'calendar_list_events',
          extractData: (m) => {'date_raw': m.group(1) ?? m.group(2) ?? 'today'},
        ),
        // "cancel meeting X" / "delete event X"
        DomainIntentPattern(
          pattern: RegExp(
              r'^(?:cancel|delete|remove)\s+(?:the\s+)?(?:meeting|event|appointment)\s+(?:about\s+|titled?\s+)?(.+)$',
              caseSensitive: false),
          taskType: 'calendar_delete_event',
          extractData: (m) => {'title': m.group(1)!.trim()},
        ),
      ];

  @override
  List<DomainOllamaIntent> get ollamaIntents => [
        DomainOllamaIntent(
          intentName: 'calendar_add_event',
          description: 'Add an event to Calendar.app',
          parameters: {
            'title': 'event title',
            'datetime_raw': 'date/time string'
          },
          examples: [
            OllamaExample(
                input: 'schedule meeting at 3pm tomorrow',
                intentJson:
                    '{"intent": "calendar_add_event", "confidence": 0.95, "parameters": {"title": "meeting", "datetime_raw": "tomorrow 3pm"}}'),
            OllamaExample(
                input: 'add dentist appointment Friday 10am',
                intentJson:
                    '{"intent": "calendar_add_event", "confidence": 0.95, "parameters": {"title": "dentist appointment", "datetime_raw": "Friday 10am"}}'),
          ],
        ),
        DomainOllamaIntent(
          intentName: 'calendar_list_events',
          description: 'List calendar events for today or a specific date',
          parameters: {'date_raw': 'date (today, tomorrow, etc.)'},
          examples: [
            OllamaExample(
                input: "what's on my calendar today",
                intentJson:
                    '{"intent": "calendar_list_events", "confidence": 0.95, "parameters": {"date_raw": "today"}}'),
            OllamaExample(
                input: 'my schedule tomorrow',
                intentJson:
                    '{"intent": "calendar_list_events", "confidence": 0.95, "parameters": {"date_raw": "tomorrow"}}'),
          ],
        ),
      ];

  @override
  Map<String, DomainDisplayConfig> get displayConfigs => {
        'calendar_add_event': const DomainDisplayConfig(
            cardType: 'calendar',
            titleTemplate: 'Event Created',
            icon: 'event',
            colorHex: 0xFF2196F3),
        'calendar_list_events': const DomainDisplayConfig(
            cardType: 'calendar',
            titleTemplate: 'Calendar',
            icon: 'calendar_today',
            colorHex: 0xFF2196F3),
        'calendar_delete_event': const DomainDisplayConfig(
            cardType: 'calendar',
            titleTemplate: 'Event Deleted',
            icon: 'event_busy',
            colorHex: 0xFF2196F3),
      };

  @override
  Future<Map<String, dynamic>> executeTask(
      String taskType, Map<String, dynamic> data) async {
    switch (taskType) {
      case 'calendar_add_event':
        return _addEvent(data);
      case 'calendar_list_events':
        return _listEvents(data);
      case 'calendar_delete_event':
        return _deleteEvent(data);
      default:
        return {'success': false, 'error': 'Unknown calendar task: $taskType'};
    }
  }

  Future<Map<String, dynamic>> _addEvent(Map<String, dynamic> data) async {
    final title = data['title'] as String? ?? 'Event';
    final datetimeRaw = data['datetime_raw'] as String? ?? '';

    // Create event at the specified time (1 hour duration default)
    // Calendar.app AppleScript handles relative dates poorly, so we construct the date
    final script = '''
tell application "Calendar"
  tell calendar "Home"
    set eventTitle to "$title"
    set startDate to current date
    ${_buildDateScript(datetimeRaw)}
    set endDate to startDate + (1 * hours)
    set newEvent to make new event with properties {summary:eventTitle, start date:startDate, end date:endDate}
    return summary of newEvent & " at " & (start date of newEvent as string)
  end tell
end tell''';

    try {
      final result = await Process.run('osascript', ['-e', script]);
      final output = (result.stdout as String).trim();
      return {
        'success': result.exitCode == 0,
        'title': title,
        'datetime': datetimeRaw,
        'message': result.exitCode == 0
            ? 'Created: $output'
            : (result.stderr as String).trim(),
        'domain': 'calendar',
        'card_type': 'calendar',
      };
    } catch (e) {
      return {'success': false, 'error': 'Error: $e', 'domain': 'calendar'};
    }
  }

  String _buildDateScript(String datetimeRaw) {
    final lower = datetimeRaw.toLowerCase().trim();
    final parts = <String>[];

    if (lower.contains('tomorrow')) {
      parts.add('set startDate to startDate + (1 * days)');
    }

    // Parse time like "3pm", "10:30am", "15:00"
    final timeMatch =
        RegExp(r'(\d{1,2})(?::(\d{2}))?\s*(am|pm)?', caseSensitive: false)
            .firstMatch(lower);
    if (timeMatch != null) {
      var hour = int.parse(timeMatch.group(1)!);
      final minute = int.tryParse(timeMatch.group(2) ?? '') ?? 0;
      final ampm = timeMatch.group(3)?.toLowerCase();
      if (ampm == 'pm' && hour < 12) hour += 12;
      if (ampm == 'am' && hour == 12) hour = 0;
      parts.add('set hours of startDate to $hour');
      parts.add('set minutes of startDate to $minute');
      parts.add('set seconds of startDate to 0');
    }

    // Parse day names
    final days = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday'
    ];
    for (int i = 0; i < days.length; i++) {
      if (lower.contains(days[i])) {
        // Calculate days until next occurrence
        parts.add('''
    set targetDay to ${i + 2}
    if targetDay > 7 then set targetDay to targetDay - 7
    set currentDay to weekday of startDate as integer
    set dayDiff to targetDay - currentDay
    if dayDiff <= 0 then set dayDiff to dayDiff + 7
    set startDate to startDate + (dayDiff * days)''');
        break;
      }
    }

    return parts.join('\n    ');
  }

  Future<Map<String, dynamic>> _listEvents(Map<String, dynamic> data) async {
    final dateRaw = (data['date_raw'] as String? ?? 'today').toLowerCase();
    final dayOffset = dateRaw.contains('tomorrow') ? 1 : 0;

    final script = '''
tell application "Calendar"
  set today to current date
  set hours of today to 0
  set minutes of today to 0
  set seconds of today to 0
  set startOfDay to today + ($dayOffset * days)
  set endOfDay to startOfDay + (1 * days)
  set output to ""
  repeat with cal in calendars
    repeat with evt in (events of cal whose start date >= startOfDay and start date < endOfDay)
      set evtTime to time string of start date of evt
      set output to output & evtTime & " - " & summary of evt & "\\n"
    end repeat
  end repeat
  if output is "" then
    return "No events ${dateRaw == 'tomorrow' ? 'tomorrow' : 'today'}"
  end if
  return output
end tell''';

    try {
      final result = await Process.run('osascript', ['-e', script]);
      final output = (result.stdout as String).trim();
      final events =
          output.split('\n').where((s) => s.trim().isNotEmpty).toList();
      return {
        'success': result.exitCode == 0,
        'date': dateRaw,
        'events': events,
        'count': events.length,
        'raw': output,
        'domain': 'calendar',
        'card_type': 'calendar',
      };
    } catch (e) {
      return {'success': false, 'error': 'Error: $e', 'domain': 'calendar'};
    }
  }

  Future<Map<String, dynamic>> _deleteEvent(Map<String, dynamic> data) async {
    final title = data['title'] as String? ?? '';
    final script = '''
tell application "Calendar"
  set deleted to false
  repeat with cal in calendars
    repeat with evt in (events of cal whose summary contains "$title")
      delete evt
      set deleted to true
    end repeat
  end repeat
  if deleted then
    return "Deleted events matching: $title"
  else
    return "No events found matching: $title"
  end if
end tell''';

    try {
      final result = await Process.run('osascript', ['-e', script]);
      final output = (result.stdout as String).trim();
      return {
        'success': result.exitCode == 0,
        'title': title,
        'message': output,
        'domain': 'calendar',
        'card_type': 'calendar',
      };
    } catch (e) {
      return {'success': false, 'error': 'Error: $e', 'domain': 'calendar'};
    }
  }
}
