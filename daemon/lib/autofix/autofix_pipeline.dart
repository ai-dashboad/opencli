import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../telemetry/telemetry.dart';
import 'issue_analyzer.dart';

/// Fix status in the pipeline
enum FixStatus {
  /// Fix is being analyzed
  analyzing,

  /// Fix is being generated
  generating,

  /// Fix is being tested
  testing,

  /// Fix passed tests, pending review
  pendingReview,

  /// Fix is in canary release
  canary,

  /// Fix is in gradual rollout
  rollout,

  /// Fix is released to all users
  released,

  /// Fix failed at some stage
  failed,

  /// Fix was rejected
  rejected,
}

/// Represents a fix in the pipeline
class Fix {
  final String id;
  final String issueId;
  final AnalyzedIssue analysis;
  final DateTime createdAt;
  FixStatus status;
  String? fixDescription;
  String? codeChanges;
  String? pullRequestUrl;
  double rolloutPercentage;
  List<String> affectedFiles;
  Map<String, dynamic> testResults;
  String? failureReason;

  Fix({
    required this.id,
    required this.issueId,
    required this.analysis,
    required this.createdAt,
    this.status = FixStatus.analyzing,
    this.fixDescription,
    this.codeChanges,
    this.pullRequestUrl,
    this.rolloutPercentage = 0.0,
    this.affectedFiles = const [],
    this.testResults = const {},
    this.failureReason,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'issueId': issueId,
        'analysis': analysis.toJson(),
        'createdAt': createdAt.toIso8601String(),
        'status': status.name,
        'fixDescription': fixDescription,
        'codeChanges': codeChanges,
        'pullRequestUrl': pullRequestUrl,
        'rolloutPercentage': rolloutPercentage,
        'affectedFiles': affectedFiles,
        'testResults': testResults,
        'failureReason': failureReason,
      };
}

/// Configuration for the autofix pipeline
class AutofixConfig {
  /// Whether autofix is enabled
  final bool enabled;

  /// GitHub repository for creating PRs
  final String? githubRepo;

  /// GitHub token for API access
  final String? githubToken;

  /// Rollout stages
  final List<RolloutStage> rolloutStages;

  /// Minimum confidence for auto-fix
  final double minConfidenceForAutofix;

  /// Maximum fixes per day
  final int maxFixesPerDay;

  const AutofixConfig({
    this.enabled = true,
    this.githubRepo,
    this.githubToken,
    this.rolloutStages = const [
      RolloutStage(name: 'canary', percentage: 1, durationHours: 24),
      RolloutStage(name: 'gradual', percentage: 10, durationHours: 48),
      RolloutStage(name: 'full', percentage: 100, durationHours: 0),
    ],
    this.minConfidenceForAutofix = 0.8,
    this.maxFixesPerDay = 10,
  });
}

/// Rollout stage configuration
class RolloutStage {
  final String name;
  final int percentage;
  final int durationHours;
  final double errorThreshold;

  const RolloutStage({
    required this.name,
    required this.percentage,
    this.durationHours = 24,
    this.errorThreshold = 0.05,
  });
}

/// Autofix pipeline manager
class AutofixPipeline {
  final IssueAnalyzer _analyzer;
  final ErrorCollector? _errorCollector;
  final AutofixConfig config;

  /// Fixes in the pipeline
  final Map<String, Fix> _fixes = {};

  /// Fixes created today
  int _fixesToday = 0;
  DateTime? _lastFixDate;

  /// Listeners for fix status changes
  final List<void Function(Fix)> _statusListeners = [];

  /// Rollout timer
  Timer? _rolloutTimer;

  AutofixPipeline({
    required IssueAnalyzer analyzer,
    ErrorCollector? errorCollector,
    this.config = const AutofixConfig(),
  })  : _analyzer = analyzer,
        _errorCollector = errorCollector;

  /// Start the pipeline
  void start() {
    if (!config.enabled) {
      print('[AutofixPipeline] Pipeline disabled');
      return;
    }

    // Listen to errors if collector is available
    _errorCollector?.errorStream.listen(_handleError);

    // Start rollout monitoring
    _rolloutTimer = Timer.periodic(
      const Duration(minutes: 30),
      (_) => _checkRolloutProgress(),
    );

    print('[AutofixPipeline] Pipeline started');
  }

  /// Stop the pipeline
  void stop() {
    _rolloutTimer?.cancel();
    print('[AutofixPipeline] Pipeline stopped');
  }

  /// Handle incoming error
  Future<void> _handleError(ErrorReport error) async {
    // Check daily limit
    if (!_canCreateFix()) {
      print('[AutofixPipeline] Daily fix limit reached');
      return;
    }

    // Analyze the error
    final analysis = await _analyzer.analyze(error);

    // Only auto-fix high confidence issues
    if (analysis.confidence < config.minConfidenceForAutofix) {
      print(
          '[AutofixPipeline] Low confidence (${analysis.confidence}), skipping auto-fix');
      return;
    }

    // Create fix
    await createFix(error, analysis);
  }

  /// Check if we can create a fix today
  bool _canCreateFix() {
    final today = DateTime.now();
    if (_lastFixDate == null ||
        _lastFixDate!.day != today.day ||
        _lastFixDate!.month != today.month ||
        _lastFixDate!.year != today.year) {
      _fixesToday = 0;
      _lastFixDate = today;
    }

    return _fixesToday < config.maxFixesPerDay;
  }

  /// Create a fix for an error
  Future<Fix> createFix(ErrorReport error, AnalyzedIssue analysis) async {
    final fixId = 'fix-${error.id}';
    _fixesToday++;

    final fix = Fix(
      id: fixId,
      issueId: error.id,
      analysis: analysis,
      createdAt: DateTime.now(),
      status: FixStatus.analyzing,
    );

    _fixes[fixId] = fix;
    _notifyListeners(fix);

    // Start the fix pipeline
    _processFix(fix);

    return fix;
  }

  /// Process a fix through the pipeline
  Future<void> _processFix(Fix fix) async {
    try {
      // Step 1: Generate fix code
      fix.status = FixStatus.generating;
      _notifyListeners(fix);

      final generatedFix = await _generateFix(fix);
      if (generatedFix == null) {
        fix.status = FixStatus.failed;
        fix.failureReason = 'Failed to generate fix';
        _notifyListeners(fix);
        return;
      }

      fix.fixDescription = generatedFix['description'];
      fix.codeChanges = generatedFix['code'];
      fix.affectedFiles = List<String>.from(generatedFix['files'] ?? []);

      // Step 2: Run tests
      fix.status = FixStatus.testing;
      _notifyListeners(fix);

      final testPassed = await _runTests(fix);
      if (!testPassed) {
        fix.status = FixStatus.failed;
        fix.failureReason = 'Tests failed';
        _notifyListeners(fix);
        return;
      }

      // Step 3: Create PR if GitHub is configured
      if (config.githubRepo != null && config.githubToken != null) {
        fix.status = FixStatus.pendingReview;
        _notifyListeners(fix);

        final prUrl = await _createPullRequest(fix);
        if (prUrl != null) {
          fix.pullRequestUrl = prUrl;
        }
      }

      // Step 4: Start canary rollout
      fix.status = FixStatus.canary;
      fix.rolloutPercentage = config.rolloutStages.first.percentage.toDouble();
      _notifyListeners(fix);

      print('[AutofixPipeline] Fix ${fix.id} started canary rollout');
    } catch (e) {
      fix.status = FixStatus.failed;
      fix.failureReason = e.toString();
      _notifyListeners(fix);
      print('[AutofixPipeline] Fix ${fix.id} failed: $e');
    }
  }

  /// Generate fix code using AI
  Future<Map<String, dynamic>?> _generateFix(Fix fix) async {
    try {
      // Try local Ollama
      final prompt = _buildFixPrompt(fix);

      final response = await http
          .post(
            Uri.parse('http://localhost:11434/api/generate'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'model': 'qwen2.5:3b',
              'prompt': prompt,
              'stream': false,
            }),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return _parseFixResponse(data['response'] as String);
      }
    } catch (e) {
      print('[AutofixPipeline] Fix generation failed: $e');
    }

    // Fall back to suggested fixes from analysis
    if (fix.analysis.suggestedFixes.isNotEmpty) {
      return {
        'description': fix.analysis.suggestedFixes.first,
        'code':
            '// Manual fix required\n// ${fix.analysis.suggestedFixes.join('\n// ')}',
        'files': [],
      };
    }

    return null;
  }

  /// Build prompt for fix generation
  String _buildFixPrompt(Fix fix) {
    return '''Generate a code fix for this issue:

Issue Summary: ${fix.analysis.summary}
Root Cause: ${fix.analysis.rootCause ?? 'Unknown'}
Classification: ${fix.analysis.classification.name}

Context:
- Platform: OpenCLI Daemon (Dart)
- Issue ID: ${fix.issueId}

Please provide:
1. Description of the fix
2. Code changes (as a diff or new code)
3. List of affected files

Respond in JSON format:
{
  "description": "...",
  "code": "...",
  "files": ["file1.dart", "file2.dart"]
}''';
  }

  /// Parse fix response from AI
  Map<String, dynamic>? _parseFixResponse(String response) {
    try {
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(response);
      if (jsonMatch != null) {
        return jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
      }
    } catch (e) {
      print('[AutofixPipeline] Failed to parse fix response: $e');
    }
    return null;
  }

  /// Run tests for a fix
  Future<bool> _runTests(Fix fix) async {
    try {
      // Run Dart tests
      final result = await Process.run('dart', ['test'], runInShell: true);

      fix.testResults = {
        'exitCode': result.exitCode,
        'stdout': result.stdout.toString().substring(0, 500),
        'stderr': result.stderr.toString().substring(0, 500),
      };

      return result.exitCode == 0;
    } catch (e) {
      fix.testResults = {'error': e.toString()};
      return false;
    }
  }

  /// Create a pull request for the fix
  Future<String?> _createPullRequest(Fix fix) async {
    if (config.githubRepo == null || config.githubToken == null) {
      return null;
    }

    try {
      // Create branch name
      final branchName = 'autofix/${fix.id}';

      // Create PR via GitHub API
      final response = await http.post(
        Uri.parse('https://api.github.com/repos/${config.githubRepo}/pulls'),
        headers: {
          'Authorization': 'token ${config.githubToken}',
          'Accept': 'application/vnd.github.v3+json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'title': '[AutoFix] ${fix.analysis.summary}',
          'body': _buildPRBody(fix),
          'head': branchName,
          'base': 'main',
        }),
      );

      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return data['html_url'] as String;
      }
    } catch (e) {
      print('[AutofixPipeline] Failed to create PR: $e');
    }

    return null;
  }

  /// Build PR body
  String _buildPRBody(Fix fix) {
    return '''## Auto-generated Fix

**Issue ID:** ${fix.issueId}
**Classification:** ${fix.analysis.classification.name}
**Confidence:** ${(fix.analysis.confidence * 100).toStringAsFixed(1)}%

### Root Cause
${fix.analysis.rootCause ?? 'Unknown'}

### Changes
${fix.fixDescription ?? 'See code changes'}

### Affected Files
${fix.affectedFiles.map((f) => '- `$f`').join('\n')}

### Test Results
```
${jsonEncode(fix.testResults)}
```

---
*This PR was automatically generated by OpenCLI AutoFix Pipeline*
''';
  }

  /// Check and advance rollout progress
  void _checkRolloutProgress() {
    for (final fix in _fixes.values) {
      if (fix.status == FixStatus.canary || fix.status == FixStatus.rollout) {
        _advanceRollout(fix);
      }
    }
  }

  /// Advance rollout to next stage
  void _advanceRollout(Fix fix) {
    // Find current stage
    final currentStage = config.rolloutStages.firstWhere(
      (stage) => stage.percentage >= fix.rolloutPercentage,
      orElse: () => config.rolloutStages.last,
    );

    // Check if enough time has passed
    final stageStartTime = fix.createdAt.add(Duration(
      hours: config.rolloutStages
          .takeWhile((s) => s.percentage < currentStage.percentage)
          .fold(0, (sum, s) => sum + s.durationHours),
    ));

    final stageEndTime =
        stageStartTime.add(Duration(hours: currentStage.durationHours));

    if (DateTime.now().isAfter(stageEndTime)) {
      // Check error rate
      // TODO: Implement actual error rate checking

      // Advance to next stage
      final currentIndex = config.rolloutStages.indexOf(currentStage);
      if (currentIndex < config.rolloutStages.length - 1) {
        final nextStage = config.rolloutStages[currentIndex + 1];
        fix.rolloutPercentage = nextStage.percentage.toDouble();
        fix.status = FixStatus.rollout;
        print(
            '[AutofixPipeline] Fix ${fix.id} advanced to ${nextStage.name} (${nextStage.percentage}%)');
      } else {
        fix.rolloutPercentage = 100;
        fix.status = FixStatus.released;
        print('[AutofixPipeline] Fix ${fix.id} fully released');
      }
      _notifyListeners(fix);
    }
  }

  /// Rollback a fix
  void rollback(String fixId, String reason) {
    final fix = _fixes[fixId];
    if (fix != null) {
      fix.status = FixStatus.rejected;
      fix.failureReason = 'Rolled back: $reason';
      fix.rolloutPercentage = 0;
      _notifyListeners(fix);
      print('[AutofixPipeline] Fix $fixId rolled back: $reason');
    }
  }

  /// Add status listener
  void addListener(void Function(Fix) listener) {
    _statusListeners.add(listener);
  }

  /// Remove status listener
  void removeListener(void Function(Fix) listener) {
    _statusListeners.remove(listener);
  }

  /// Notify listeners of fix status change
  void _notifyListeners(Fix fix) {
    for (final listener in _statusListeners) {
      listener(fix);
    }
  }

  /// Get all fixes
  List<Fix> getAllFixes() {
    return _fixes.values.toList();
  }

  /// Get fix by ID
  Fix? getFix(String id) {
    return _fixes[id];
  }

  /// Get statistics
  Map<String, dynamic> getStats() {
    final byStatus = <String, int>{};
    for (final fix in _fixes.values) {
      final key = fix.status.name;
      byStatus[key] = (byStatus[key] ?? 0) + 1;
    }

    return {
      'enabled': config.enabled,
      'totalFixes': _fixes.length,
      'fixesToday': _fixesToday,
      'maxFixesPerDay': config.maxFixesPerDay,
      'byStatus': byStatus,
      'rolloutStages': config.rolloutStages
          .map((s) => {
                'name': s.name,
                'percentage': s.percentage,
                'durationHours': s.durationHours,
              })
          .toList(),
    };
  }
}
