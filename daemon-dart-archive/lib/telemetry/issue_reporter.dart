import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'error_collector.dart';
import 'package:opencli_daemon/database/app_database.dart';

/// Configuration for issue reporting
class IssueReporterConfig {
  /// Whether issue reporting is enabled
  final bool enabled;

  /// GitHub repository for creating issues (owner/repo)
  final String? githubRepo;

  /// GitHub API token for creating issues
  final String? githubToken;

  /// Custom issue reporting endpoint
  final String? customEndpoint;

  /// Minimum severity level to report
  final ErrorSeverity minSeverity;

  /// Rate limit: max issues per hour
  final int maxIssuesPerHour;

  /// Whether to deduplicate similar issues
  final bool deduplicateIssues;

  /// Local storage path for pending issues
  final String localStoragePath;

  IssueReporterConfig({
    this.enabled = true,
    this.githubRepo,
    this.githubToken,
    this.customEndpoint,
    this.minSeverity = ErrorSeverity.error,
    this.maxIssuesPerHour = 5,
    this.deduplicateIssues = true,
    String? localStoragePath,
  }) : localStoragePath = localStoragePath ?? _defaultStoragePath();

  static String _defaultStoragePath() {
    final home = Platform.environment['HOME'] ?? '.';
    return '$home/.opencli/data/pending_issues.json';
  }
}

/// Issue to be reported
class Issue {
  final String id;
  final String title;
  final String body;
  final List<String> labels;
  final ErrorReport sourceError;
  final DateTime createdAt;
  bool reported;
  String? remoteId;

  Issue({
    required this.id,
    required this.title,
    required this.body,
    required this.labels,
    required this.sourceError,
    DateTime? createdAt,
    this.reported = false,
    this.remoteId,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'body': body,
        'labels': labels,
        'sourceErrorId': sourceError.id,
        'createdAt': createdAt.toIso8601String(),
        'reported': reported,
        'remoteId': remoteId,
      };

  /// Generate issue fingerprint for deduplication
  String get fingerprint {
    // Create fingerprint from error message (first line) and stack trace (first frame)
    final messageLine = sourceError.message.split('\n').first;
    final stackLine = sourceError.stackTrace?.split('\n').firstWhere(
              (line) => line.contains('.dart'),
              orElse: () => '',
            ) ??
        '';
    return '${messageLine.hashCode}-${stackLine.hashCode}';
  }
}

/// Reports errors as GitHub issues or to custom endpoint
class IssueReporter {
  final IssueReporterConfig config;
  final ErrorCollector errorCollector;

  final List<Issue> _pendingIssues = [];
  final List<Issue> _reportedIssues = [];
  final Set<String> _reportedFingerprints = {};
  final List<DateTime> _recentReports = [];

  StreamSubscription<ErrorReport>? _errorSubscription;
  Timer? _batchReportTimer;

  IssueReporter({
    required this.config,
    required this.errorCollector,
  }) {
    if (config.enabled) {
      _startListening();
      _loadPendingIssues();
      _startBatchReporting();
    }
  }

  /// Start listening to error stream
  void _startListening() {
    _errorSubscription = errorCollector.errorStream.listen(_handleError);
  }

  /// Handle incoming error
  void _handleError(ErrorReport error) {
    // Check severity threshold
    if (error.severity.index < config.minSeverity.index) {
      return;
    }

    // Create issue
    final issue = _createIssue(error);

    // Check for duplicates
    if (config.deduplicateIssues &&
        _reportedFingerprints.contains(issue.fingerprint)) {
      print('[IssueReporter] Skipping duplicate issue: ${issue.title}');
      return;
    }

    _pendingIssues.add(issue);
    _savePendingIssues();
  }

  /// Create issue from error report
  Issue _createIssue(ErrorReport error) {
    final title = _generateTitle(error);
    final body = _generateBody(error);
    final labels = _generateLabels(error);

    return Issue(
      id: 'issue-${error.id}',
      title: title,
      body: body,
      labels: labels,
      sourceError: error,
    );
  }

  /// Generate issue title from error
  String _generateTitle(ErrorReport error) {
    final severity = error.severity.name.toUpperCase();
    final message = error.message.split('\n').first;

    // Truncate if too long
    final truncatedMessage =
        message.length > 80 ? '${message.substring(0, 77)}...' : message;

    return '[$severity] $truncatedMessage';
  }

  /// Generate issue body from error
  String _generateBody(ErrorReport error) {
    final sanitized = error.toSanitizedJson();
    final buffer = StringBuffer();

    buffer.writeln('## Error Details');
    buffer.writeln('');
    buffer.writeln('**Severity:** ${error.severity.name}');
    buffer.writeln('**Timestamp:** ${error.timestamp.toIso8601String()}');
    buffer.writeln('**Error ID:** `${error.id}`');
    buffer.writeln('');

    buffer.writeln('### Message');
    buffer.writeln('```');
    buffer.writeln(sanitized['message']);
    buffer.writeln('```');
    buffer.writeln('');

    if (error.stackTrace != null) {
      buffer.writeln('### Stack Trace');
      buffer.writeln('```');
      buffer.writeln(sanitized['stackTrace']);
      buffer.writeln('```');
      buffer.writeln('');
    }

    buffer.writeln('### Context');
    buffer.writeln('```json');
    buffer.writeln(
        const JsonEncoder.withIndent('  ').convert(sanitized['context']));
    buffer.writeln('```');
    buffer.writeln('');

    buffer.writeln('### System Information');
    buffer.writeln('');
    final sysInfo = sanitized['systemInfo'] as Map<String, dynamic>;
    buffer.writeln('| Property | Value |');
    buffer.writeln('|----------|-------|');
    sysInfo.forEach((key, value) {
      buffer.writeln('| $key | `$value` |');
    });
    buffer.writeln('');

    buffer.writeln('---');
    buffer.writeln('*Automatically generated by OpenCLI Error Reporter*');

    return buffer.toString();
  }

  /// Generate labels based on error
  List<String> _generateLabels(ErrorReport error) {
    final labels = <String>['auto-generated', 'bug'];

    // Severity label
    labels.add('severity:${error.severity.name}');

    // Platform label
    labels.add('platform:${error.systemInfo.platform}');

    // Context-based labels
    final context = error.context;
    if (context.containsKey('source')) {
      labels.add('source:${context['source']}');
    }

    return labels;
  }

  /// Start batch reporting timer
  void _startBatchReporting() {
    // Check for pending issues every 5 minutes
    _batchReportTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _processPendingIssues();
    });
  }

  /// Process pending issues
  Future<void> _processPendingIssues() async {
    if (_pendingIssues.isEmpty) return;

    // Check rate limit
    _cleanupRecentReports();
    if (_recentReports.length >= config.maxIssuesPerHour) {
      print('[IssueReporter] Rate limit reached, waiting...');
      return;
    }

    // Report issues one by one with rate limiting
    final toReport = _pendingIssues
        .take(config.maxIssuesPerHour - _recentReports.length)
        .toList();

    for (final issue in toReport) {
      try {
        await _reportIssue(issue);
        _pendingIssues.remove(issue);
        _reportedIssues.add(issue);
        _reportedFingerprints.add(issue.fingerprint);
        _recentReports.add(DateTime.now());
      } catch (e) {
        print('[IssueReporter] Failed to report issue: $e');
        // Will retry on next cycle
      }
    }

    _savePendingIssues();
  }

  /// Report a single issue
  Future<void> _reportIssue(Issue issue) async {
    if (config.githubRepo != null && config.githubToken != null) {
      await _reportToGitHub(issue);
    } else if (config.customEndpoint != null) {
      await _reportToCustomEndpoint(issue);
    } else {
      // Store locally only
      print(
          '[IssueReporter] No reporting endpoint configured, storing locally');
      issue.reported = true;
    }
  }

  /// Report issue to GitHub
  Future<void> _reportToGitHub(Issue issue) async {
    final url = 'https://api.github.com/repos/${config.githubRepo}/issues';

    final response = await http.post(
      Uri.parse(url),
      headers: {
        'Authorization': 'token ${config.githubToken}',
        'Accept': 'application/vnd.github.v3+json',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'title': issue.title,
        'body': issue.body,
        'labels': issue.labels,
      }),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body);
      issue.remoteId = data['number'].toString();
      issue.reported = true;
      print('[IssueReporter] Created GitHub issue #${issue.remoteId}');
    } else {
      throw Exception(
          'GitHub API error: ${response.statusCode} ${response.body}');
    }
  }

  /// Report issue to custom endpoint
  Future<void> _reportToCustomEndpoint(Issue issue) async {
    final response = await http.post(
      Uri.parse(config.customEndpoint!),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode(issue.toJson()),
    );

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final data = jsonDecode(response.body);
      issue.remoteId = data['id']?.toString();
      issue.reported = true;
      print('[IssueReporter] Reported issue to custom endpoint');
    } else {
      throw Exception('Custom endpoint error: ${response.statusCode}');
    }
  }

  /// Cleanup old entries from recent reports
  void _cleanupRecentReports() {
    final oneHourAgo = DateTime.now().subtract(const Duration(hours: 1));
    _recentReports.removeWhere((dt) => dt.isBefore(oneHourAgo));
  }

  /// Save a pending issue to SQLite
  Future<void> _savePendingIssues() async {
    try {
      final db = AppDatabase.instance;
      if (!db.isInitialized) return;

      for (final issue in _pendingIssues) {
        await db.insertIssue({
          'id': issue.id,
          'title': issue.title,
          'body': issue.body,
          'labels': jsonEncode(issue.labels),
          'fingerprint': issue.fingerprint,
          'created_at': issue.createdAt.millisecondsSinceEpoch,
          'reported': issue.reported ? 1 : 0,
          'remote_id': issue.remoteId,
        });
      }
    } catch (e) {
      print('[IssueReporter] Failed to save pending issues: $e');
    }
  }

  /// Load fingerprints from SQLite for deduplication
  Future<void> _loadPendingIssues() async {
    try {
      final db = AppDatabase.instance;
      if (!db.isInitialized) return;

      final fingerprints = await db.getReportedFingerprints();
      _reportedFingerprints.addAll(fingerprints);

      print(
          '[IssueReporter] Loaded ${_reportedFingerprints.length} fingerprints for deduplication');
    } catch (e) {
      print('[IssueReporter] Failed to load pending issues: $e');
    }
  }

  /// Force report all pending issues
  Future<int> forceReportAll() async {
    var reported = 0;
    for (final issue in List.from(_pendingIssues)) {
      try {
        await _reportIssue(issue);
        _pendingIssues.remove(issue);
        _reportedIssues.add(issue);
        reported++;
      } catch (e) {
        print('[IssueReporter] Failed to report: $e');
      }
    }
    _savePendingIssues();
    return reported;
  }

  /// Get statistics
  Map<String, dynamic> getStats() {
    return {
      'pendingIssues': _pendingIssues.length,
      'reportedIssues': _reportedIssues.length,
      'uniqueFingerprints': _reportedFingerprints.length,
      'recentReports': _recentReports.length,
      'rateLimit':
          '${_recentReports.length}/${config.maxIssuesPerHour} per hour',
    };
  }

  /// Dispose resources
  void dispose() {
    _errorSubscription?.cancel();
    _batchReportTimer?.cancel();
    _savePendingIssues();
  }
}
