import 'dart:async';
import 'dart:collection';

/// Task scheduler with cron-like functionality
class TaskScheduler {
  final Map<String, ScheduledTask> _tasks = {};
  final Map<String, Timer> _timers = {};
  final StreamController<SchedulerEvent> _eventController =
      StreamController.broadcast();

  Stream<SchedulerEvent> get events => _eventController.stream;

  /// Schedule a task
  String schedule({
    required String name,
    required Schedule schedule,
    required TaskCallback callback,
    bool enabled = true,
    Map<String, dynamic>? metadata,
  }) {
    final taskId = _generateTaskId();

    final task = ScheduledTask(
      id: taskId,
      name: name,
      schedule: schedule,
      callback: callback,
      enabled: enabled,
      metadata: metadata ?? {},
      createdAt: DateTime.now(),
    );

    _tasks[taskId] = task;

    if (enabled) {
      _scheduleTask(task);
    }

    print('Task scheduled: $name ($taskId) - ${schedule.description}');

    return taskId;
  }

  /// Schedule task with cron expression
  String scheduleCron({
    required String name,
    required String cronExpression,
    required TaskCallback callback,
    bool enabled = true,
    Map<String, dynamic>? metadata,
  }) {
    return schedule(
      name: name,
      schedule: CronSchedule(cronExpression),
      callback: callback,
      enabled: enabled,
      metadata: metadata,
    );
  }

  /// Schedule task at fixed interval
  String scheduleInterval({
    required String name,
    required Duration interval,
    required TaskCallback callback,
    bool enabled = true,
    Map<String, dynamic>? metadata,
  }) {
    return schedule(
      name: name,
      schedule: IntervalSchedule(interval),
      callback: callback,
      enabled: enabled,
      metadata: metadata,
    );
  }

  /// Schedule task at specific time daily
  String scheduleDaily({
    required String name,
    required int hour,
    required int minute,
    required TaskCallback callback,
    bool enabled = true,
    Map<String, dynamic>? metadata,
  }) {
    return schedule(
      name: name,
      schedule: DailySchedule(hour, minute),
      callback: callback,
      enabled: enabled,
      metadata: metadata,
    );
  }

  /// Schedule one-time task
  String scheduleOnce({
    required String name,
    required DateTime runAt,
    required TaskCallback callback,
    Map<String, dynamic>? metadata,
  }) {
    return schedule(
      name: name,
      schedule: OnceSchedule(runAt),
      callback: callback,
      enabled: true,
      metadata: metadata,
    );
  }

  /// Cancel scheduled task
  void cancel(String taskId) {
    _timers[taskId]?.cancel();
    _timers.remove(taskId);
    _tasks.remove(taskId);
    print('Task cancelled: $taskId');
  }

  /// Enable task
  void enable(String taskId) {
    final task = _tasks[taskId];
    if (task != null) {
      task.enabled = true;
      _scheduleTask(task);
      print('Task enabled: $taskId');
    }
  }

  /// Disable task
  void disable(String taskId) {
    final task = _tasks[taskId];
    if (task != null) {
      task.enabled = false;
      _timers[taskId]?.cancel();
      _timers.remove(taskId);
      print('Task disabled: $taskId');
    }
  }

  /// Get scheduled task
  ScheduledTask? getTask(String taskId) {
    return _tasks[taskId];
  }

  /// List all tasks
  List<ScheduledTask> listTasks() {
    return _tasks.values.toList();
  }

  /// Run task immediately
  Future<void> runNow(String taskId) async {
    final task = _tasks[taskId];
    if (task != null) {
      await _executeTask(task);
    }
  }

  /// Schedule task execution
  void _scheduleTask(ScheduledTask task) {
    _timers[task.id]?.cancel();

    final nextRun = task.schedule.getNextRun();
    if (nextRun == null) {
      // One-time task that has already run
      return;
    }

    final delay = nextRun.difference(DateTime.now());

    _timers[task.id] = Timer(delay, () async {
      await _executeTask(task);

      // Reschedule if recurring
      if (task.schedule.isRecurring) {
        _scheduleTask(task);
      }
    });

    print('Next run for ${task.name}: $nextRun');
  }

  /// Execute task
  Future<void> _executeTask(ScheduledTask task) async {
    if (!task.enabled) return;

    final startTime = DateTime.now();

    _eventController.add(SchedulerEvent(
      type: SchedulerEventType.started,
      taskId: task.id,
      taskName: task.name,
      timestamp: startTime,
    ));

    try {
      await task.callback();

      task.lastRun = startTime;
      task.runCount++;

      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);

      _eventController.add(SchedulerEvent(
        type: SchedulerEventType.completed,
        taskId: task.id,
        taskName: task.name,
        timestamp: endTime,
        duration: duration,
      ));

      print('Task completed: ${task.name} (${duration.inMilliseconds}ms)');
    } catch (e, stackTrace) {
      task.lastError = e.toString();
      task.errorCount++;

      _eventController.add(SchedulerEvent(
        type: SchedulerEventType.failed,
        taskId: task.id,
        taskName: task.name,
        timestamp: DateTime.now(),
        error: e.toString(),
      ));

      print('Task failed: ${task.name} - $e');
      print(stackTrace);
    }
  }

  /// Stop all tasks
  void stopAll() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    print('All tasks stopped');
  }

  /// Close scheduler
  Future<void> close() async {
    stopAll();
    await _eventController.close();
  }

  String _generateTaskId() {
    return 'task_${DateTime.now().millisecondsSinceEpoch}';
  }
}

/// Task callback
typedef TaskCallback = Future<void> Function();

/// Scheduled task
class ScheduledTask {
  final String id;
  final String name;
  final Schedule schedule;
  final TaskCallback callback;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;

  bool enabled;
  DateTime? lastRun;
  String? lastError;
  int runCount;
  int errorCount;

  ScheduledTask({
    required this.id,
    required this.name,
    required this.schedule,
    required this.callback,
    required this.enabled,
    required this.metadata,
    required this.createdAt,
    this.lastRun,
    this.lastError,
    this.runCount = 0,
    this.errorCount = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'schedule': schedule.description,
      'enabled': enabled,
      'created_at': createdAt.toIso8601String(),
      if (lastRun != null) 'last_run': lastRun!.toIso8601String(),
      if (lastError != null) 'last_error': lastError,
      'run_count': runCount,
      'error_count': errorCount,
      'metadata': metadata,
    };
  }
}

/// Base schedule interface
abstract class Schedule {
  DateTime? getNextRun();
  bool get isRecurring;
  String get description;
}

/// Interval schedule (every X duration)
class IntervalSchedule implements Schedule {
  final Duration interval;
  DateTime? _lastRun;

  IntervalSchedule(this.interval);

  @override
  DateTime? getNextRun() {
    final now = DateTime.now();
    if (_lastRun == null) {
      _lastRun = now;
      return now;
    }

    _lastRun = _lastRun!.add(interval);
    return _lastRun;
  }

  @override
  bool get isRecurring => true;

  @override
  String get description => 'Every ${interval.inSeconds}s';
}

/// Daily schedule (at specific time each day)
class DailySchedule implements Schedule {
  final int hour;
  final int minute;

  DailySchedule(this.hour, this.minute);

  @override
  DateTime? getNextRun() {
    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day, hour, minute);

    if (next.isBefore(now)) {
      next = next.add(Duration(days: 1));
    }

    return next;
  }

  @override
  bool get isRecurring => true;

  @override
  String get description =>
      'Daily at ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

/// Weekly schedule
class WeeklySchedule implements Schedule {
  final int weekday; // 1-7 (Monday-Sunday)
  final int hour;
  final int minute;

  WeeklySchedule(this.weekday, this.hour, this.minute);

  @override
  DateTime? getNextRun() {
    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day, hour, minute);

    while (next.weekday != weekday || next.isBefore(now)) {
      next = next.add(Duration(days: 1));
    }

    return next;
  }

  @override
  bool get isRecurring => true;

  @override
  String get description {
    const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return 'Weekly on ${weekdays[weekday - 1]} at ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }
}

/// Monthly schedule
class MonthlySchedule implements Schedule {
  final int day;
  final int hour;
  final int minute;

  MonthlySchedule(this.day, this.hour, this.minute);

  @override
  DateTime? getNextRun() {
    final now = DateTime.now();
    var next = DateTime(now.year, now.month, day, hour, minute);

    if (next.isBefore(now)) {
      // Move to next month
      if (now.month == 12) {
        next = DateTime(now.year + 1, 1, day, hour, minute);
      } else {
        next = DateTime(now.year, now.month + 1, day, hour, minute);
      }
    }

    return next;
  }

  @override
  bool get isRecurring => true;

  @override
  String get description =>
      'Monthly on day $day at ${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
}

/// One-time schedule
class OnceSchedule implements Schedule {
  final DateTime runAt;
  bool _hasRun = false;

  OnceSchedule(this.runAt);

  @override
  DateTime? getNextRun() {
    if (_hasRun || runAt.isBefore(DateTime.now())) {
      return null;
    }
    _hasRun = true;
    return runAt;
  }

  @override
  bool get isRecurring => false;

  @override
  String get description => 'Once at ${runAt.toIso8601String()}';
}

/// Cron schedule (simplified cron expression support)
class CronSchedule implements Schedule {
  final String expression;
  final CronParser _parser;

  CronSchedule(this.expression) : _parser = CronParser(expression);

  @override
  DateTime? getNextRun() {
    return _parser.getNextRun();
  }

  @override
  bool get isRecurring => true;

  @override
  String get description => 'Cron: $expression';
}

/// Simplified cron parser
class CronParser {
  final String expression;
  final List<int>? minutes;
  final List<int>? hours;
  final List<int>? days;
  final List<int>? months;
  final List<int>? weekdays;

  CronParser(this.expression)
      : minutes = _parseField(expression.split(' ')[0], 0, 59),
        hours = _parseField(expression.split(' ')[1], 0, 23),
        days = _parseField(expression.split(' ')[2], 1, 31),
        months = _parseField(expression.split(' ')[3], 1, 12),
        weekdays = expression.split(' ').length > 4
            ? _parseField(expression.split(' ')[4], 0, 6)
            : null;

  DateTime? getNextRun() {
    var next = DateTime.now().add(Duration(minutes: 1));

    // Find next matching time (simplified)
    for (var i = 0; i < 365 * 24 * 60; i++) {
      if (_matches(next)) {
        return next;
      }
      next = next.add(Duration(minutes: 1));
    }

    return null;
  }

  bool _matches(DateTime time) {
    if (minutes != null && !minutes!.contains(time.minute)) return false;
    if (hours != null && !hours!.contains(time.hour)) return false;
    if (days != null && !days!.contains(time.day)) return false;
    if (months != null && !months!.contains(time.month)) return false;
    if (weekdays != null && !weekdays!.contains(time.weekday % 7)) return false;
    return true;
  }

  static List<int>? _parseField(String field, int min, int max) {
    if (field == '*') return null;

    if (field.contains(',')) {
      return field.split(',').map((e) => int.parse(e)).toList();
    }

    if (field.contains('/')) {
      final parts = field.split('/');
      final step = int.parse(parts[1]);
      return List.generate((max - min) ~/ step + 1, (i) => min + i * step);
    }

    if (field.contains('-')) {
      final parts = field.split('-');
      final start = int.parse(parts[0]);
      final end = int.parse(parts[1]);
      return List.generate(end - start + 1, (i) => start + i);
    }

    return [int.parse(field)];
  }
}

/// Scheduler event
class SchedulerEvent {
  final SchedulerEventType type;
  final String taskId;
  final String taskName;
  final DateTime timestamp;
  final Duration? duration;
  final String? error;

  SchedulerEvent({
    required this.type,
    required this.taskId,
    required this.taskName,
    required this.timestamp,
    this.duration,
    this.error,
  });

  Map<String, dynamic> toJson() {
    return {
      'type': type.name,
      'task_id': taskId,
      'task_name': taskName,
      'timestamp': timestamp.toIso8601String(),
      if (duration != null) 'duration_ms': duration!.inMilliseconds,
      if (error != null) 'error': error,
    };
  }
}

enum SchedulerEventType { started, completed, failed }
