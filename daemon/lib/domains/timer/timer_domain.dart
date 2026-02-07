import 'dart:async';
import 'dart:io';
import '../domain.dart';

class TimerDomain extends TaskDomain {
  @override
  String get id => 'timer';
  @override
  String get name => 'Timer & Alarms';
  @override
  String get description => 'Set timers, alarms, countdowns, and pomodoro sessions';
  @override
  String get icon => 'timer';
  @override
  int get colorHex => 0xFF009688;

  /// Active timers
  static final Map<String, Timer> _activeTimers = {};
  static final Map<String, DateTime> _timerEndTimes = {};
  static final Map<String, String> _timerLabels = {};

  @override
  List<String> get taskTypes => [
    'timer_set', 'timer_cancel', 'timer_status', 'timer_pomodoro',
  ];

  @override
  List<DomainIntentPattern> get intentPatterns => [
    DomainIntentPattern(
      pattern: RegExp(r'^(?:set\s+)?(?:a\s+)?timer\s+(?:for\s+)?(\d+)\s*(min(?:ute)?s?|sec(?:ond)?s?|hour?s?)(?:\s+(.+))?$', caseSensitive: false),
      taskType: 'timer_set',
      extractData: (m) {
        final amount = int.parse(m.group(1)!);
        final unit = m.group(2)!.toLowerCase();
        int minutes = amount;
        if (unit.startsWith('sec')) minutes = (amount / 60).ceil();
        if (unit.startsWith('hour') || unit.startsWith('hr')) minutes = amount * 60;
        return {'minutes': minutes, 'label': m.group(3) ?? 'Timer'};
      },
    ),
    DomainIntentPattern(
      pattern: RegExp(r'^(\d+)\s*(?:min(?:ute)?s?)\s+timer$', caseSensitive: false),
      taskType: 'timer_set',
      extractData: (m) => {'minutes': int.parse(m.group(1)!), 'label': 'Timer'},
    ),
    DomainIntentPattern(
      pattern: RegExp(r'^(?:start\s+)?pomodoro$', caseSensitive: false),
      taskType: 'timer_pomodoro',
      extractData: (_) => {},
    ),
    DomainIntentPattern(
      pattern: RegExp(r'^(?:focus\s+timer)\s*(\d+)?$', caseSensitive: false),
      taskType: 'timer_pomodoro',
      extractData: (m) => {'minutes': int.tryParse(m.group(1) ?? '') ?? 25},
    ),
    DomainIntentPattern(
      pattern: RegExp(r'^(?:cancel|stop)\s+timer$', caseSensitive: false),
      taskType: 'timer_cancel',
      extractData: (_) => {},
    ),
    DomainIntentPattern(
      pattern: RegExp(r'^(?:timer\s+status|how\s+much\s+time\s+left)$', caseSensitive: false),
      taskType: 'timer_status',
      extractData: (_) => {},
    ),
  ];

  @override
  List<DomainOllamaIntent> get ollamaIntents => [
    DomainOllamaIntent(
      intentName: 'timer_set',
      description: 'Set a countdown timer',
      parameters: {'minutes': 'duration in minutes', 'label': 'optional label'},
      examples: [
        OllamaExample(input: 'set timer for 25 minutes', intentJson: '{"intent": "timer_set", "confidence": 0.95, "parameters": {"minutes": 25, "label": "Timer"}}'),
        OllamaExample(input: 'timer 10 min cooking', intentJson: '{"intent": "timer_set", "confidence": 0.95, "parameters": {"minutes": 10, "label": "cooking"}}'),
      ],
    ),
    DomainOllamaIntent(
      intentName: 'timer_pomodoro',
      description: 'Start a pomodoro focus timer (25 min work + 5 min break)',
      parameters: {},
      examples: [
        OllamaExample(input: 'start pomodoro', intentJson: '{"intent": "timer_pomodoro", "confidence": 0.95, "parameters": {}}'),
      ],
    ),
  ];

  @override
  Map<String, DomainDisplayConfig> get displayConfigs => {
    'timer_set': const DomainDisplayConfig(
      cardType: 'timer', titleTemplate: 'Timer: \${label}',
      subtitleTemplate: '\${minutes} minutes', icon: 'timer', colorHex: 0xFF009688,
    ),
    'timer_status': const DomainDisplayConfig(
      cardType: 'timer', titleTemplate: 'Timer Status',
      icon: 'timer', colorHex: 0xFF009688,
    ),
    'timer_pomodoro': const DomainDisplayConfig(
      cardType: 'timer', titleTemplate: 'Pomodoro',
      subtitleTemplate: '25 min focus', icon: 'self_improvement', colorHex: 0xFF009688,
    ),
  };

  @override
  Future<Map<String, dynamic>> executeTask(String taskType, Map<String, dynamic> data) async {
    switch (taskType) {
      case 'timer_set':
        return _setTimer(data);
      case 'timer_cancel':
        return _cancelTimer();
      case 'timer_status':
        return _timerStatus();
      case 'timer_pomodoro':
        return _startPomodoro(data);
      default:
        return {'success': false, 'error': 'Unknown timer task: $taskType'};
    }
  }

  Map<String, dynamic> _setTimer(Map<String, dynamic> data) {
    final minutes = (data['minutes'] as num?)?.toInt() ?? 5;
    final label = data['label'] as String? ?? 'Timer';
    final id = 'timer_${DateTime.now().millisecondsSinceEpoch}';

    // Cancel any existing timer
    _cancelAllTimers();

    _timerEndTimes[id] = DateTime.now().add(Duration(minutes: minutes));
    _timerLabels[id] = label;
    _activeTimers[id] = Timer(Duration(minutes: minutes), () {
      Process.run('osascript', ['-e',
        'display notification "$label completed! ($minutes min)" with title "OpenCLI Timer" sound name "Glass"']);
      _activeTimers.remove(id);
      _timerEndTimes.remove(id);
      _timerLabels.remove(id);
    });

    return {
      'success': true,
      'timer_id': id,
      'minutes': minutes,
      'label': label,
      'ends_at': _timerEndTimes[id]!.toIso8601String(),
      'domain': 'timer',
      'card_type': 'timer',
    };
  }

  Map<String, dynamic> _cancelTimer() {
    if (_activeTimers.isEmpty) {
      return {'success': true, 'message': 'No active timers', 'domain': 'timer'};
    }
    final count = _activeTimers.length;
    _cancelAllTimers();
    return {'success': true, 'message': 'Cancelled $count timer(s)', 'domain': 'timer'};
  }

  Map<String, dynamic> _timerStatus() {
    if (_activeTimers.isEmpty) {
      return {'success': true, 'active': false, 'message': 'No active timers', 'domain': 'timer'};
    }

    final timers = <Map<String, dynamic>>[];
    for (final entry in _timerEndTimes.entries) {
      final remaining = entry.value.difference(DateTime.now());
      timers.add({
        'id': entry.key,
        'label': _timerLabels[entry.key] ?? 'Timer',
        'remaining_seconds': remaining.inSeconds,
        'ends_at': entry.value.toIso8601String(),
      });
    }

    return {
      'success': true,
      'active': true,
      'timers': timers,
      'domain': 'timer',
      'card_type': 'timer',
    };
  }

  Map<String, dynamic> _startPomodoro(Map<String, dynamic> data) {
    final minutes = (data['minutes'] as num?)?.toInt() ?? 25;
    return _setTimer({'minutes': minutes, 'label': 'Pomodoro Focus'});
  }

  void _cancelAllTimers() {
    for (final timer in _activeTimers.values) {
      timer.cancel();
    }
    _activeTimers.clear();
    _timerEndTimes.clear();
    _timerLabels.clear();
  }
}
