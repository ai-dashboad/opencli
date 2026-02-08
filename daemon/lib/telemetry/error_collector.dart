import 'dart:async';
import 'dart:io';
import 'dart:convert';

/// Error severity levels
enum ErrorSeverity {
  debug,
  info,
  warning,
  error,
  critical,
}

/// Collected error information
class ErrorReport {
  final String id;
  final DateTime timestamp;
  final ErrorSeverity severity;
  final String message;
  final String? stackTrace;
  final Map<String, dynamic> context;
  final SystemInfo systemInfo;

  ErrorReport({
    required this.id,
    required this.timestamp,
    required this.severity,
    required this.message,
    this.stackTrace,
    required this.context,
    required this.systemInfo,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'severity': severity.name,
        'message': message,
        'stackTrace': stackTrace,
        'context': context,
        'systemInfo': systemInfo.toJson(),
      };

  /// Sanitize sensitive information from the error report
  Map<String, dynamic> toSanitizedJson() {
    final sanitized = toJson();

    // Sanitize paths - replace home directory with ~
    final home = Platform.environment['HOME'] ?? '';
    if (home.isNotEmpty) {
      sanitized['message'] =
          (sanitized['message'] as String).replaceAll(home, '~');
      if (sanitized['stackTrace'] != null) {
        sanitized['stackTrace'] =
            (sanitized['stackTrace'] as String).replaceAll(home, '~');
      }
    }

    // Remove sensitive context keys
    final sensitiveKeys = [
      'api_key',
      'password',
      'token',
      'secret',
      'auth',
      'credential'
    ];
    final context = Map<String, dynamic>.from(sanitized['context'] as Map);
    context.removeWhere(
        (key, _) => sensitiveKeys.any((s) => key.toLowerCase().contains(s)));
    sanitized['context'] = context;

    return sanitized;
  }
}

/// System information collected with errors
class SystemInfo {
  final String platform;
  final String platformVersion;
  final String hostname;
  final int processorCount;
  final String dartVersion;
  final String appVersion;
  final String deviceId;

  SystemInfo({
    required this.platform,
    required this.platformVersion,
    required this.hostname,
    required this.processorCount,
    required this.dartVersion,
    required this.appVersion,
    required this.deviceId,
  });

  factory SystemInfo.collect(String appVersion, String deviceId) {
    return SystemInfo(
      platform: Platform.operatingSystem,
      platformVersion: Platform.operatingSystemVersion,
      hostname: _sanitizeHostname(Platform.localHostname),
      processorCount: Platform.numberOfProcessors,
      dartVersion: Platform.version.split(' ').first,
      appVersion: appVersion,
      deviceId: deviceId,
    );
  }

  static String _sanitizeHostname(String hostname) {
    // Hash the hostname to anonymize while keeping uniqueness
    final bytes = utf8.encode(hostname);
    var hash = 0;
    for (var byte in bytes) {
      hash = (hash * 31 + byte) & 0xFFFFFFFF;
    }
    return 'host-${hash.toRadixString(16)}';
  }

  Map<String, dynamic> toJson() => {
        'platform': platform,
        'platformVersion': platformVersion,
        'hostname': hostname,
        'processorCount': processorCount,
        'dartVersion': dartVersion,
        'appVersion': appVersion,
        'deviceId': deviceId,
      };
}

/// Collects and manages error reports
class ErrorCollector {
  final String appVersion;
  final String deviceId;
  final bool anonymize;
  final int maxStoredErrors;

  final List<ErrorReport> _errors = [];
  final StreamController<ErrorReport> _errorStream =
      StreamController.broadcast();

  late final SystemInfo _systemInfo;
  int _errorCounter = 0;

  ErrorCollector({
    required this.appVersion,
    required this.deviceId,
    this.anonymize = true,
    this.maxStoredErrors = 100,
  }) {
    _systemInfo = SystemInfo.collect(appVersion, deviceId);
    _setupGlobalErrorHandling();
  }

  /// Stream of collected errors
  Stream<ErrorReport> get errorStream => _errorStream.stream;

  /// All collected errors
  List<ErrorReport> get errors => List.unmodifiable(_errors);

  /// Setup global error handling
  void _setupGlobalErrorHandling() {
    // Catch uncaught async errors
    runZonedGuarded(() {}, (error, stackTrace) {
      collectError(
        error.toString(),
        severity: ErrorSeverity.critical,
        stackTrace: stackTrace.toString(),
        context: {'source': 'uncaught_async'},
      );
    });
  }

  /// Generate unique error ID
  String _generateErrorId() {
    _errorCounter++;
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    return '${deviceId.substring(0, 8)}-$timestamp-$_errorCounter';
  }

  /// Collect an error
  ErrorReport collectError(
    String message, {
    ErrorSeverity severity = ErrorSeverity.error,
    String? stackTrace,
    Map<String, dynamic>? context,
  }) {
    final report = ErrorReport(
      id: _generateErrorId(),
      timestamp: DateTime.now(),
      severity: severity,
      message: message,
      stackTrace: stackTrace,
      context: context ?? {},
      systemInfo: _systemInfo,
    );

    _errors.add(report);
    _errorStream.add(report);

    // Trim old errors if over limit
    while (_errors.length > maxStoredErrors) {
      _errors.removeAt(0);
    }

    // Log locally
    _logError(report);

    return report;
  }

  /// Collect exception with automatic stack trace
  ErrorReport collectException(
    Object exception, [
    StackTrace? stackTrace,
    Map<String, dynamic>? context,
  ]) {
    return collectError(
      exception.toString(),
      severity: _severityFromException(exception),
      stackTrace: stackTrace?.toString(),
      context: {
        'exceptionType': exception.runtimeType.toString(),
        ...?context,
      },
    );
  }

  /// Determine severity from exception type
  ErrorSeverity _severityFromException(Object exception) {
    if (exception is StateError || exception is RangeError) {
      return ErrorSeverity.critical;
    }
    if (exception is IOException) {
      return ErrorSeverity.error;
    }
    if (exception is FormatException) {
      return ErrorSeverity.warning;
    }
    return ErrorSeverity.error;
  }

  /// Log error locally
  void _logError(ErrorReport report) {
    final prefix = '[${report.severity.name.toUpperCase()}]';
    final message =
        '$prefix ${report.timestamp.toIso8601String()} - ${report.message}';

    if (report.severity == ErrorSeverity.critical ||
        report.severity == ErrorSeverity.error) {
      stderr.writeln(message);
    } else {
      print(message);
    }
  }

  /// Get errors by severity
  List<ErrorReport> getErrorsBySeverity(ErrorSeverity severity) {
    return _errors.where((e) => e.severity == severity).toList();
  }

  /// Get errors since a specific time
  List<ErrorReport> getErrorsSince(DateTime since) {
    return _errors.where((e) => e.timestamp.isAfter(since)).toList();
  }

  /// Clear all errors
  void clear() {
    _errors.clear();
  }

  /// Export errors as JSON (sanitized if anonymize is true)
  List<Map<String, dynamic>> exportErrors() {
    if (anonymize) {
      return _errors.map((e) => e.toSanitizedJson()).toList();
    }
    return _errors.map((e) => e.toJson()).toList();
  }

  /// Save errors to file
  Future<void> saveToFile(String path) async {
    final file = File(path);
    final json = jsonEncode(exportErrors());
    await file.writeAsString(json);
  }

  /// Load errors from file
  Future<void> loadFromFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      final json = await file.readAsString();
      final List<dynamic> data = jsonDecode(json);
      // Note: This is for persistence, not full restoration
      // Loaded errors won't have full ErrorReport objects
      print('Loaded ${data.length} historical errors from $path');
    }
  }

  /// Dispose of resources
  void dispose() {
    _errorStream.close();
  }
}

/// Extension for easy error collection on futures
extension ErrorCollectorFutureExtension<T> on Future<T> {
  Future<T> collectErrors(ErrorCollector collector,
      {Map<String, dynamic>? context}) {
    return catchError((error, stackTrace) {
      collector.collectException(error, stackTrace, context);
      throw error;
    });
  }
}
