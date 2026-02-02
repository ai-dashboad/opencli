import 'dart:io';
import 'package:yaml/yaml.dart';
import 'error_collector.dart';
import 'issue_reporter.dart';

/// User consent status for telemetry
enum ConsentStatus {
  /// User has not been asked yet
  notAsked,
  /// User has granted consent
  granted,
  /// User has denied consent
  denied,
}

/// Telemetry configuration loaded from config file
class TelemetryConfig {
  /// Whether telemetry is enabled
  final bool enabled;

  /// Whether to anonymize data
  final bool anonymous;

  /// Whether to report errors automatically
  final bool reportErrors;

  /// Whether to report usage statistics
  final bool reportUsage;

  /// User consent status
  final ConsentStatus consent;

  /// Minimum severity level to report
  final ErrorSeverity minSeverity;

  /// Maximum issues per hour
  final int maxIssuesPerHour;

  /// GitHub repository for issue reporting
  final String? githubRepo;

  /// Custom reporting endpoint
  final String? customEndpoint;

  /// List of categories to exclude from reporting
  final List<String> excludeCategories;

  const TelemetryConfig({
    this.enabled = true,
    this.anonymous = true,
    this.reportErrors = true,
    this.reportUsage = false,
    this.consent = ConsentStatus.notAsked,
    this.minSeverity = ErrorSeverity.error,
    this.maxIssuesPerHour = 5,
    this.githubRepo,
    this.customEndpoint,
    this.excludeCategories = const [],
  });

  /// Default configuration
  factory TelemetryConfig.defaults() => const TelemetryConfig();

  /// Load from YAML configuration
  factory TelemetryConfig.fromYaml(YamlMap yaml) {
    return TelemetryConfig(
      enabled: yaml['enabled'] as bool? ?? true,
      anonymous: yaml['anonymous'] as bool? ?? true,
      reportErrors: yaml['report_errors'] as bool? ?? true,
      reportUsage: yaml['report_usage'] as bool? ?? false,
      consent: _parseConsent(yaml['consent'] as String?),
      minSeverity: _parseSeverity(yaml['min_severity'] as String?),
      maxIssuesPerHour: yaml['max_issues_per_hour'] as int? ?? 5,
      githubRepo: yaml['github_repo'] as String?,
      customEndpoint: yaml['custom_endpoint'] as String?,
      excludeCategories: (yaml['exclude_categories'] as YamlList?)
          ?.cast<String>()
          .toList() ?? [],
    );
  }

  /// Load from config file
  static Future<TelemetryConfig> load([String? configPath]) async {
    final path = configPath ?? _defaultConfigPath();
    final file = File(path);

    if (!await file.exists()) {
      return TelemetryConfig.defaults();
    }

    try {
      final content = await file.readAsString();
      final yaml = loadYaml(content) as YamlMap;
      final telemetry = yaml['telemetry'] as YamlMap?;

      if (telemetry == null) {
        return TelemetryConfig.defaults();
      }

      return TelemetryConfig.fromYaml(telemetry);
    } catch (e) {
      print('[TelemetryConfig] Failed to load config: $e');
      return TelemetryConfig.defaults();
    }
  }

  static String _defaultConfigPath() {
    final home = Platform.environment['HOME'] ?? '.';
    return '$home/.opencli/config.yaml';
  }

  static ConsentStatus _parseConsent(String? value) {
    switch (value) {
      case 'granted':
        return ConsentStatus.granted;
      case 'denied':
        return ConsentStatus.denied;
      default:
        return ConsentStatus.notAsked;
    }
  }

  static ErrorSeverity _parseSeverity(String? value) {
    switch (value) {
      case 'debug':
        return ErrorSeverity.debug;
      case 'info':
        return ErrorSeverity.info;
      case 'warning':
        return ErrorSeverity.warning;
      case 'critical':
        return ErrorSeverity.critical;
      default:
        return ErrorSeverity.error;
    }
  }

  /// Convert to IssueReporterConfig
  IssueReporterConfig toIssueReporterConfig() {
    return IssueReporterConfig(
      enabled: enabled && reportErrors && consent == ConsentStatus.granted,
      githubRepo: githubRepo,
      customEndpoint: customEndpoint,
      minSeverity: minSeverity,
      maxIssuesPerHour: maxIssuesPerHour,
      deduplicateIssues: true,
    );
  }

  /// Check if telemetry should be active
  bool get isActive => enabled && consent == ConsentStatus.granted;

  /// Check if error reporting should be active
  bool get shouldReportErrors => isActive && reportErrors;

  /// Check if usage reporting should be active
  bool get shouldReportUsage => isActive && reportUsage;

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'anonymous': anonymous,
    'reportErrors': reportErrors,
    'reportUsage': reportUsage,
    'consent': consent.name,
    'minSeverity': minSeverity.name,
    'maxIssuesPerHour': maxIssuesPerHour,
    'githubRepo': githubRepo,
    'customEndpoint': customEndpoint,
    'excludeCategories': excludeCategories,
  };
}

/// Manages telemetry consent and configuration
class TelemetryManager {
  TelemetryConfig config;
  ErrorCollector? errorCollector;
  IssueReporter? issueReporter;

  final String appVersion;
  final String deviceId;

  TelemetryManager({
    required this.appVersion,
    required this.deviceId,
    TelemetryConfig? config,
  }) : config = config ?? TelemetryConfig.defaults();

  /// Initialize telemetry system
  Future<void> initialize() async {
    config = await TelemetryConfig.load();

    if (!config.enabled) {
      print('[Telemetry] Telemetry is disabled');
      return;
    }

    // Initialize error collector
    errorCollector = ErrorCollector(
      appVersion: appVersion,
      deviceId: deviceId,
      anonymize: config.anonymous,
    );

    // Initialize issue reporter if consent granted
    if (config.shouldReportErrors) {
      issueReporter = IssueReporter(
        config: config.toIssueReporterConfig(),
        errorCollector: errorCollector!,
      );
      print('[Telemetry] Error reporting enabled');
    } else {
      print('[Telemetry] Error reporting disabled (consent: ${config.consent.name})');
    }
  }

  /// Record an error
  void recordError(
    String message, {
    ErrorSeverity severity = ErrorSeverity.error,
    String? stackTrace,
    Map<String, dynamic>? context,
  }) {
    errorCollector?.collectError(
      message,
      severity: severity,
      stackTrace: stackTrace,
      context: context,
    );
  }

  /// Record an exception
  void recordException(Object exception, [StackTrace? stackTrace]) {
    errorCollector?.collectException(exception, stackTrace);
  }

  /// Update user consent
  Future<void> updateConsent(ConsentStatus newConsent) async {
    final configPath = TelemetryConfig._defaultConfigPath();
    final file = File(configPath);

    // Update config in memory
    config = TelemetryConfig(
      enabled: config.enabled,
      anonymous: config.anonymous,
      reportErrors: config.reportErrors,
      reportUsage: config.reportUsage,
      consent: newConsent,
      minSeverity: config.minSeverity,
      maxIssuesPerHour: config.maxIssuesPerHour,
      githubRepo: config.githubRepo,
      customEndpoint: config.customEndpoint,
      excludeCategories: config.excludeCategories,
    );

    // If consent granted and not already reporting, start
    if (newConsent == ConsentStatus.granted && issueReporter == null && errorCollector != null) {
      issueReporter = IssueReporter(
        config: config.toIssueReporterConfig(),
        errorCollector: errorCollector!,
      );
    }

    // If consent denied, stop reporting
    if (newConsent == ConsentStatus.denied) {
      issueReporter?.dispose();
      issueReporter = null;
    }

    // Update config file
    try {
      if (await file.exists()) {
        final content = await file.readAsString();
        final updatedContent = _updateConsentInYaml(content, newConsent);
        await file.writeAsString(updatedContent);
      }
    } catch (e) {
      print('[TelemetryManager] Failed to save consent: $e');
    }
  }

  String _updateConsentInYaml(String content, ConsentStatus consent) {
    // Simple approach: add or update consent line in telemetry section
    final lines = content.split('\n');
    final result = <String>[];
    var inTelemetrySection = false;
    var consentUpdated = false;

    for (var line in lines) {
      if (line.startsWith('telemetry:')) {
        inTelemetrySection = true;
        result.add(line);
        continue;
      }

      if (inTelemetrySection) {
        if (line.startsWith('  consent:')) {
          result.add('  consent: ${consent.name}');
          consentUpdated = true;
          continue;
        }

        // Check if we've left the telemetry section
        if (line.isNotEmpty && !line.startsWith(' ') && !line.startsWith('#')) {
          if (!consentUpdated) {
            // Add consent before leaving section
            result.add('  consent: ${consent.name}');
            consentUpdated = true;
          }
          inTelemetrySection = false;
        }
      }

      result.add(line);
    }

    // If telemetry section exists but consent wasn't added
    if (inTelemetrySection && !consentUpdated) {
      result.add('  consent: ${consent.name}');
    }

    return result.join('\n');
  }

  /// Get telemetry statistics
  Map<String, dynamic> getStats() {
    return {
      'config': config.toJson(),
      'errorCollector': {
        'totalErrors': errorCollector?.errors.length ?? 0,
      },
      'issueReporter': issueReporter?.getStats() ?? {'status': 'disabled'},
    };
  }

  /// Force sync pending issues
  Future<int> syncPendingIssues() async {
    return await issueReporter?.forceReportAll() ?? 0;
  }

  /// Dispose resources
  void dispose() {
    issueReporter?.dispose();
    errorCollector?.dispose();
  }
}
