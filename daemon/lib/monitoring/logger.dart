import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Structured logging system with multiple log levels and output targets
class Logger {
  final String name;
  final LogLevel minLevel;
  final List<LogOutput> outputs;
  final Map<String, dynamic> defaultContext;

  Logger({
    required this.name,
    this.minLevel = LogLevel.info,
    List<LogOutput>? outputs,
    Map<String, dynamic>? defaultContext,
  })  : outputs = outputs ?? [ConsoleLogOutput()],
        defaultContext = defaultContext ?? {};

  /// Log debug message
  void debug(String message,
      {Map<String, dynamic>? context, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.debug, message,
        context: context, error: error, stackTrace: stackTrace);
  }

  /// Log info message
  void info(String message,
      {Map<String, dynamic>? context, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.info, message,
        context: context, error: error, stackTrace: stackTrace);
  }

  /// Log warning message
  void warn(String message,
      {Map<String, dynamic>? context, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.warn, message,
        context: context, error: error, stackTrace: stackTrace);
  }

  /// Log error message
  void error(String message,
      {Map<String, dynamic>? context, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.error, message,
        context: context, error: error, stackTrace: stackTrace);
  }

  /// Log fatal message
  void fatal(String message,
      {Map<String, dynamic>? context, Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.fatal, message,
        context: context, error: error, stackTrace: stackTrace);
  }

  /// Internal logging method
  void _log(
    LogLevel level,
    String message, {
    Map<String, dynamic>? context,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (level.index < minLevel.index) return;

    final entry = LogEntry(
      timestamp: DateTime.now(),
      level: level,
      logger: name,
      message: message,
      context: {...defaultContext, ...?context},
      error: error,
      stackTrace: stackTrace,
    );

    for (final output in outputs) {
      output.write(entry);
    }
  }

  /// Create child logger with additional context
  Logger child(String childName, {Map<String, dynamic>? additionalContext}) {
    return Logger(
      name: '$name.$childName',
      minLevel: minLevel,
      outputs: outputs,
      defaultContext: {...defaultContext, ...?additionalContext},
    );
  }
}

/// Log entry
class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String logger;
  final String message;
  final Map<String, dynamic> context;
  final Object? error;
  final StackTrace? stackTrace;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.logger,
    required this.message,
    required this.context,
    this.error,
    this.stackTrace,
  });

  /// Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'level': level.name,
      'logger': logger,
      'message': message,
      if (context.isNotEmpty) 'context': context,
      if (error != null) 'error': error.toString(),
      if (stackTrace != null) 'stackTrace': stackTrace.toString(),
    };
  }

  /// Convert to formatted string
  String toFormattedString() {
    final buffer = StringBuffer();
    buffer.write('[${timestamp.toIso8601String()}] ');
    buffer.write('[${level.name.toUpperCase()}] ');
    buffer.write('[$logger] ');
    buffer.write(message);

    if (context.isNotEmpty) {
      buffer.write(' | Context: ${jsonEncode(context)}');
    }

    if (error != null) {
      buffer.write('\nError: $error');
    }

    if (stackTrace != null) {
      buffer.write('\nStack Trace:\n$stackTrace');
    }

    return buffer.toString();
  }
}

/// Log levels
enum LogLevel {
  debug,
  info,
  warn,
  error,
  fatal,
}

/// Base class for log outputs
abstract class LogOutput {
  void write(LogEntry entry);
  Future<void> flush() async {}
  Future<void> close() async {}
}

/// Console log output
class ConsoleLogOutput implements LogOutput {
  final bool colored;

  ConsoleLogOutput({this.colored = true});

  @override
  void write(LogEntry entry) {
    final text = colored ? _colorize(entry) : entry.toFormattedString();
    print(text);
  }

  String _colorize(LogEntry entry) {
    const reset = '\x1B[0m';
    const colors = {
      LogLevel.debug: '\x1B[36m', // Cyan
      LogLevel.info: '\x1B[32m', // Green
      LogLevel.warn: '\x1B[33m', // Yellow
      LogLevel.error: '\x1B[31m', // Red
      LogLevel.fatal: '\x1B[35m', // Magenta
    };

    final color = colors[entry.level] ?? '';
    return '$color${entry.toFormattedString()}$reset';
  }
}

/// File log output
class FileLogOutput implements LogOutput {
  final String filePath;
  final bool rotateDaily;
  final int maxFileSize;
  IOSink? _sink;
  DateTime? _lastRotation;

  FileLogOutput({
    required this.filePath,
    this.rotateDaily = true,
    this.maxFileSize = 10 * 1024 * 1024, // 10MB
  });

  @override
  void write(LogEntry entry) {
    _ensureSink();
    _checkRotation();
    _sink?.writeln(entry.toFormattedString());
  }

  void _ensureSink() {
    if (_sink == null) {
      final file = File(_getFilePath());
      file.parent.createSync(recursive: true);
      _sink = file.openWrite(mode: FileMode.append);
      _lastRotation = DateTime.now();
    }
  }

  void _checkRotation() {
    if (rotateDaily) {
      final now = DateTime.now();
      if (_lastRotation != null &&
          (now.day != _lastRotation!.day ||
              now.month != _lastRotation!.month ||
              now.year != _lastRotation!.year)) {
        _rotate();
      }
    }

    // Check file size
    final file = File(_getFilePath());
    if (file.existsSync() && file.lengthSync() > maxFileSize) {
      _rotate();
    }
  }

  void _rotate() {
    _sink?.close();
    final oldPath = _getFilePath();
    final newPath = '$oldPath.${DateTime.now().millisecondsSinceEpoch}';
    File(oldPath).renameSync(newPath);
    _sink = null;
    _lastRotation = DateTime.now();
  }

  String _getFilePath() {
    if (rotateDaily) {
      final date = DateTime.now();
      final dateStr =
          '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      return '$filePath.$dateStr.log';
    }
    return filePath;
  }

  @override
  Future<void> flush() async {
    await _sink?.flush();
  }

  @override
  Future<void> close() async {
    await _sink?.close();
    _sink = null;
  }
}

/// JSON log output for structured logging
class JsonLogOutput implements LogOutput {
  final String filePath;
  IOSink? _sink;

  JsonLogOutput({required this.filePath});

  @override
  void write(LogEntry entry) {
    _sink ??= File(filePath).openWrite(mode: FileMode.append);
    _sink?.writeln(jsonEncode(entry.toJson()));
  }

  @override
  Future<void> flush() async {
    await _sink?.flush();
  }

  @override
  Future<void> close() async {
    await _sink?.close();
    _sink = null;
  }
}

/// Syslog output
class SyslogOutput implements LogOutput {
  final String host;
  final int port;
  final String appName;
  Socket? _socket;

  SyslogOutput({
    this.host = 'localhost',
    this.port = 514,
    required this.appName,
  });

  @override
  void write(LogEntry entry) {
    _ensureSocket();
    final message = _formatSyslog(entry);
    _socket?.write(message);
  }

  void _ensureSocket() {
    if (_socket == null) {
      Socket.connect(host, port).then((socket) {
        _socket = socket;
      }).catchError((e) {
        print('Failed to connect to syslog: $e');
      });
    }
  }

  String _formatSyslog(LogEntry entry) {
    final priority = _getPriority(entry.level);
    final timestamp = entry.timestamp.toIso8601String();
    return '<$priority>$timestamp $appName: ${entry.message}\n';
  }

  int _getPriority(LogLevel level) {
    // Facility: user (1) << 3
    // Severity: debug(7), info(6), warn(4), error(3), fatal(2)
    final facility = 1 << 3;
    final severity = {
      LogLevel.debug: 7,
      LogLevel.info: 6,
      LogLevel.warn: 4,
      LogLevel.error: 3,
      LogLevel.fatal: 2,
    }[level]!;
    return facility | severity;
  }

  @override
  Future<void> close() async {
    await _socket?.close();
    _socket = null;
  }
}

/// Global logger instance
class LoggerFactory {
  static final Map<String, Logger> _loggers = {};
  static LogLevel _defaultLevel = LogLevel.info;
  static List<LogOutput> _defaultOutputs = [ConsoleLogOutput()];

  /// Get or create logger
  static Logger getLogger(String name) {
    return _loggers.putIfAbsent(
      name,
      () => Logger(
        name: name,
        minLevel: _defaultLevel,
        outputs: _defaultOutputs,
      ),
    );
  }

  /// Configure default settings
  static void configure({
    LogLevel? defaultLevel,
    List<LogOutput>? defaultOutputs,
  }) {
    if (defaultLevel != null) _defaultLevel = defaultLevel;
    if (defaultOutputs != null) _defaultOutputs = defaultOutputs;
  }

  /// Flush all loggers
  static Future<void> flushAll() async {
    for (final logger in _loggers.values) {
      for (final output in logger.outputs) {
        await output.flush();
      }
    }
  }

  /// Close all loggers
  static Future<void> closeAll() async {
    for (final logger in _loggers.values) {
      for (final output in logger.outputs) {
        await output.close();
      }
    }
    _loggers.clear();
  }
}
