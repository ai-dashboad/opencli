/// OpenCLI AutoFix Module
///
/// Provides AI-powered issue analysis and automatic fix generation
/// with gradual rollout capabilities.
///
/// Usage:
/// ```dart
/// final analyzer = IssueAnalyzer();
/// final pipeline = AutofixPipeline(
///   analyzer: analyzer,
///   errorCollector: errorCollector,
///   config: AutofixConfig(
///     enabled: true,
///     githubRepo: 'user/opencli',
///     githubToken: 'ghp_...',
///   ),
/// );
///
/// pipeline.start();
///
/// // Manually create a fix
/// final analysis = await analyzer.analyze(errorReport);
/// final fix = await pipeline.createFix(errorReport, analysis);
/// ```

library autofix;

export 'issue_analyzer.dart';
export 'autofix_pipeline.dart';
