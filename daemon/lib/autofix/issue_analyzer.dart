import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../telemetry/telemetry.dart';

/// Issue classification result
enum IssueClassification {
  /// Known issue with existing solution
  knownWithSolution,

  /// Known issue type but new instance
  knownPattern,

  /// Completely new issue
  unknown,

  /// User error or configuration issue
  userError,

  /// Environmental issue (OS, dependencies)
  environmental,

  /// Performance issue
  performance,
}

/// Analyzed issue with root cause and suggestions
class AnalyzedIssue {
  final String issueId;
  final IssueClassification classification;
  final double confidence;
  final String summary;
  final String? rootCause;
  final List<String> suggestedFixes;
  final List<String> relatedIssues;
  final Map<String, dynamic> metadata;

  const AnalyzedIssue({
    required this.issueId,
    required this.classification,
    required this.confidence,
    required this.summary,
    this.rootCause,
    this.suggestedFixes = const [],
    this.relatedIssues = const [],
    this.metadata = const {},
  });

  Map<String, dynamic> toJson() => {
    'issueId': issueId,
    'classification': classification.name,
    'confidence': confidence,
    'summary': summary,
    'rootCause': rootCause,
    'suggestedFixes': suggestedFixes,
    'relatedIssues': relatedIssues,
    'metadata': metadata,
  };
}

/// Issue pattern for matching known issues
class IssuePattern {
  final String id;
  final String name;
  final RegExp pattern;
  final String solution;
  final IssueClassification classification;

  const IssuePattern({
    required this.id,
    required this.name,
    required this.pattern,
    required this.solution,
    this.classification = IssueClassification.knownWithSolution,
  });
}

/// AI-powered issue analysis engine
class IssueAnalyzer {
  /// Known issue patterns
  final List<IssuePattern> _knownPatterns = [];

  /// Historical issues for learning
  final List<AnalyzedIssue> _analyzedHistory = [];

  /// AI endpoint for advanced analysis
  final String? aiEndpoint;

  /// Local AI (Ollama) endpoint
  final String ollamaEndpoint;

  IssueAnalyzer({
    this.aiEndpoint,
    this.ollamaEndpoint = 'http://localhost:11434',
  }) {
    _initializeKnownPatterns();
  }

  /// Initialize known issue patterns
  void _initializeKnownPatterns() {
    _knownPatterns.addAll([
      // Connection issues
      IssuePattern(
        id: 'conn-timeout',
        name: 'Connection Timeout',
        pattern: RegExp(r'(connection|socket)\s*(timeout|timed out)', caseSensitive: false),
        solution: 'Check network connectivity and ensure the daemon is running on the expected port.',
        classification: IssueClassification.environmental,
      ),
      IssuePattern(
        id: 'conn-refused',
        name: 'Connection Refused',
        pattern: RegExp(r'connection\s*refused', caseSensitive: false),
        solution: 'Ensure the daemon is running. Try restarting with: opencli-daemon',
        classification: IssueClassification.environmental,
      ),

      // Permission issues
      IssuePattern(
        id: 'perm-denied',
        name: 'Permission Denied',
        pattern: RegExp(r'permission\s*denied|access\s*denied|unauthorized', caseSensitive: false),
        solution: 'Check file permissions and ensure the user has appropriate access rights.',
        classification: IssueClassification.userError,
      ),

      // File not found
      IssuePattern(
        id: 'file-not-found',
        name: 'File Not Found',
        pattern: RegExp(r'(file|directory)\s*(not\s*found|does\s*not\s*exist)', caseSensitive: false),
        solution: 'Verify the file path is correct and the file exists.',
        classification: IssueClassification.userError,
      ),

      // App not found
      IssuePattern(
        id: 'app-not-found',
        name: 'Application Not Found',
        pattern: RegExp(r'(application|app|program)\s*(not\s*found|cannot\s*find)', caseSensitive: false),
        solution: 'Check if the application is installed and the name is correct.',
        classification: IssueClassification.userError,
      ),

      // Memory issues
      IssuePattern(
        id: 'out-of-memory',
        name: 'Out of Memory',
        pattern: RegExp(r'out\s*of\s*memory|memory\s*exhausted|heap\s*overflow', caseSensitive: false),
        solution: 'Reduce memory usage or increase system memory. Try restarting the daemon.',
        classification: IssueClassification.performance,
      ),

      // JSON parse errors
      IssuePattern(
        id: 'json-parse',
        name: 'JSON Parse Error',
        pattern: RegExp(r'(json|format)\s*(parse|parsing|syntax)\s*error', caseSensitive: false),
        solution: 'Check the input format. Ensure JSON is properly formatted.',
        classification: IssueClassification.userError,
      ),

      // Null pointer / null reference
      IssuePattern(
        id: 'null-error',
        name: 'Null Reference Error',
        pattern: RegExp(r'(null|undefined)\s*(pointer|reference|object|value)|cannot\s*read\s*property', caseSensitive: false),
        solution: 'This is likely a bug. Please report the issue with steps to reproduce.',
        classification: IssueClassification.knownPattern,
      ),

      // Timeout
      IssuePattern(
        id: 'timeout',
        name: 'Operation Timeout',
        pattern: RegExp(r'(operation|task|request)\s*timed?\s*out', caseSensitive: false),
        solution: 'The operation took too long. Try again or check if the target is responsive.',
        classification: IssueClassification.performance,
      ),

      // Capability not found
      IssuePattern(
        id: 'capability-not-found',
        name: 'Capability Not Found',
        pattern: RegExp(r'(capability|task\s*type|executor)\s*not\s*found', caseSensitive: false),
        solution: 'The requested capability is not available. Check for updates or install the required capability package.',
        classification: IssueClassification.userError,
      ),

      // Device not paired
      IssuePattern(
        id: 'device-not-paired',
        name: 'Device Not Paired',
        pattern: RegExp(r'device\s*not\s*(paired|authenticated)', caseSensitive: false),
        solution: 'Pair your device by scanning the QR code from the desktop app.',
        classification: IssueClassification.userError,
      ),
    ]);
  }

  /// Analyze an error report
  Future<AnalyzedIssue> analyze(ErrorReport error) async {
    // Try pattern matching first
    final patternMatch = _matchKnownPattern(error);
    if (patternMatch != null) {
      return patternMatch;
    }

    // Try AI analysis if available
    final aiAnalysis = await _analyzeWithAI(error);
    if (aiAnalysis != null) {
      return aiAnalysis;
    }

    // Fall back to basic analysis
    return _basicAnalysis(error);
  }

  /// Match against known patterns
  AnalyzedIssue? _matchKnownPattern(ErrorReport error) {
    final message = error.message.toLowerCase();
    final stackTrace = error.stackTrace?.toLowerCase() ?? '';
    final combined = '$message $stackTrace';

    for (final pattern in _knownPatterns) {
      if (pattern.pattern.hasMatch(combined)) {
        return AnalyzedIssue(
          issueId: error.id,
          classification: pattern.classification,
          confidence: 0.85,
          summary: pattern.name,
          rootCause: 'Matched known pattern: ${pattern.name}',
          suggestedFixes: [pattern.solution],
          relatedIssues: _findRelatedIssues(pattern.id),
          metadata: {
            'patternId': pattern.id,
            'matchType': 'pattern',
          },
        );
      }
    }

    return null;
  }

  /// Analyze with AI
  Future<AnalyzedIssue?> _analyzeWithAI(ErrorReport error) async {
    try {
      // Try local Ollama first
      final ollamaResult = await _queryOllama(error);
      if (ollamaResult != null) {
        return ollamaResult;
      }

      // Try cloud AI endpoint if configured
      if (aiEndpoint != null) {
        final cloudResult = await _queryCloudAI(error);
        if (cloudResult != null) {
          return cloudResult;
        }
      }
    } catch (e) {
      print('[IssueAnalyzer] AI analysis failed: $e');
    }

    return null;
  }

  /// Query local Ollama for analysis
  Future<AnalyzedIssue?> _queryOllama(ErrorReport error) async {
    try {
      final prompt = _buildAnalysisPrompt(error);

      final response = await http.post(
        Uri.parse('$ollamaEndpoint/api/generate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': 'qwen2.5:3b',
          'prompt': prompt,
          'stream': false,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final result = data['response'] as String;
        return _parseAIResponse(error.id, result);
      }
    } catch (e) {
      print('[IssueAnalyzer] Ollama query failed: $e');
    }

    return null;
  }

  /// Query cloud AI for analysis
  Future<AnalyzedIssue?> _queryCloudAI(ErrorReport error) async {
    try {
      final response = await http.post(
        Uri.parse('$aiEndpoint/analyze'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'error': error.toSanitizedJson(),
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return AnalyzedIssue(
          issueId: error.id,
          classification: _parseClassification(data['classification']),
          confidence: (data['confidence'] as num).toDouble(),
          summary: data['summary'] as String,
          rootCause: data['rootCause'] as String?,
          suggestedFixes: (data['suggestedFixes'] as List<dynamic>?)?.cast<String>() ?? [],
          relatedIssues: (data['relatedIssues'] as List<dynamic>?)?.cast<String>() ?? [],
          metadata: {'source': 'cloud_ai'},
        );
      }
    } catch (e) {
      print('[IssueAnalyzer] Cloud AI query failed: $e');
    }

    return null;
  }

  /// Build analysis prompt for AI
  String _buildAnalysisPrompt(ErrorReport error) {
    return '''Analyze this error and provide:
1. Classification (known_with_solution, known_pattern, unknown, user_error, environmental, performance)
2. Root cause
3. Suggested fixes

Error Message: ${error.message}
Stack Trace: ${error.stackTrace ?? 'N/A'}
Severity: ${error.severity.name}
Context: ${jsonEncode(error.context)}
Platform: ${error.systemInfo.platform}

Respond in JSON format:
{
  "classification": "...",
  "confidence": 0.0-1.0,
  "summary": "...",
  "rootCause": "...",
  "suggestedFixes": ["...", "..."]
}''';
  }

  /// Parse AI response into AnalyzedIssue
  AnalyzedIssue? _parseAIResponse(String issueId, String response) {
    try {
      // Extract JSON from response
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(response);
      if (jsonMatch == null) return null;

      final data = jsonDecode(jsonMatch.group(0)!);

      return AnalyzedIssue(
        issueId: issueId,
        classification: _parseClassification(data['classification']),
        confidence: (data['confidence'] as num?)?.toDouble() ?? 0.5,
        summary: data['summary'] as String? ?? 'Unknown issue',
        rootCause: data['rootCause'] as String?,
        suggestedFixes: (data['suggestedFixes'] as List<dynamic>?)?.cast<String>() ?? [],
        metadata: {'source': 'ollama'},
      );
    } catch (e) {
      print('[IssueAnalyzer] Failed to parse AI response: $e');
      return null;
    }
  }

  /// Parse classification string to enum
  IssueClassification _parseClassification(String? value) {
    switch (value?.toLowerCase()) {
      case 'known_with_solution':
        return IssueClassification.knownWithSolution;
      case 'known_pattern':
        return IssueClassification.knownPattern;
      case 'user_error':
        return IssueClassification.userError;
      case 'environmental':
        return IssueClassification.environmental;
      case 'performance':
        return IssueClassification.performance;
      default:
        return IssueClassification.unknown;
    }
  }

  /// Basic analysis without AI
  AnalyzedIssue _basicAnalysis(ErrorReport error) {
    final severity = error.severity;
    final classification = severity == ErrorSeverity.critical
        ? IssueClassification.unknown
        : IssueClassification.knownPattern;

    return AnalyzedIssue(
      issueId: error.id,
      classification: classification,
      confidence: 0.3,
      summary: 'Error: ${error.message.split('\n').first}',
      rootCause: 'Unable to determine root cause automatically',
      suggestedFixes: [
        'Try restarting the daemon',
        'Check the logs for more details',
        'Report this issue if it persists',
      ],
      metadata: {'source': 'basic'},
    );
  }

  /// Find related issues from history
  List<String> _findRelatedIssues(String patternId) {
    return _analyzedHistory
        .where((issue) => issue.metadata['patternId'] == patternId)
        .take(5)
        .map((issue) => issue.issueId)
        .toList();
  }

  /// Add pattern to known patterns
  void addPattern(IssuePattern pattern) {
    _knownPatterns.add(pattern);
  }

  /// Get analysis statistics
  Map<String, dynamic> getStats() {
    final byClassification = <String, int>{};
    for (final issue in _analyzedHistory) {
      final key = issue.classification.name;
      byClassification[key] = (byClassification[key] ?? 0) + 1;
    }

    return {
      'knownPatterns': _knownPatterns.length,
      'analyzedIssues': _analyzedHistory.length,
      'byClassification': byClassification,
    };
  }
}
