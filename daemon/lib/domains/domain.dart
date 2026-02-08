/// Task Domain system for OpenCLI
///
/// Each domain (calendar, music, timer, etc.) is a self-contained unit that
/// provides its own executors, intent patterns, Ollama metadata, and display config.
/// Domains self-register at startup via DomainRegistry.

/// A single intent pattern for quick-path matching in IntentRecognizer
class DomainIntentPattern {
  final RegExp pattern;
  final String taskType;
  final Map<String, dynamic> Function(RegExpMatch match) extractData;
  final double confidence;

  const DomainIntentPattern({
    required this.pattern,
    required this.taskType,
    required this.extractData,
    this.confidence = 1.0,
  });
}

/// Ollama intent classification entry for auto-generated prompt
class DomainOllamaIntent {
  final String intentName;
  final String description;
  final Map<String, String> parameters;
  final List<OllamaExample> examples;

  const DomainOllamaIntent({
    required this.intentName,
    required this.description,
    this.parameters = const {},
    required this.examples,
  });
}

class OllamaExample {
  final String input;
  final String intentJson;

  const OllamaExample({required this.input, required this.intentJson});
}

/// Display configuration for rendering results in Flutter
class DomainDisplayConfig {
  final String cardType;
  final String titleTemplate;
  final String? subtitleTemplate;
  final String icon;
  final int colorHex;

  const DomainDisplayConfig({
    required this.cardType,
    required this.titleTemplate,
    this.subtitleTemplate,
    required this.icon,
    required this.colorHex,
  });
}

/// Callback for reporting progress during long-running tasks.
typedef ProgressCallback = void Function(Map<String, dynamic> progressData);

/// Abstract base class for all task domains.
///
/// Each domain provides:
/// - Intent patterns for quick-path matching (regex → taskType + data)
/// - Ollama metadata for AI-driven intent classification
/// - Task executors that handle the actual work
/// - Display config for Flutter result rendering
abstract class TaskDomain {
  /// Unique domain ID (e.g., 'calendar', 'music', 'timer')
  String get id;

  /// Human-readable name (e.g., 'Calendar', 'Music Player')
  String get name;

  /// Short description for Ollama prompt generation
  String get description;

  /// Icon identifier for Flutter display (Material Icons name)
  String get icon;

  /// Primary color hex for Flutter card theming
  int get colorHex;

  /// Supported platforms (defaults to macOS only)
  List<String> get supportedPlatforms => ['macos'];

  /// Intent patterns for the quick-path recognizer
  List<DomainIntentPattern> get intentPatterns;

  /// Ollama intent classification metadata (auto-generates prompt)
  List<DomainOllamaIntent> get ollamaIntents;

  /// Task types this domain handles (keys used for executor registration)
  List<String> get taskTypes;

  /// Execute a task by type
  Future<Map<String, dynamic>> executeTask(
    String taskType,
    Map<String, dynamic> taskData,
  );

  /// Display configuration for Flutter result rendering
  Map<String, DomainDisplayConfig> get displayConfigs => {};

  /// Execute a task with optional progress reporting for long-running tasks.
  /// Default implementation delegates to executeTask() ignoring progress.
  Future<Map<String, dynamic>> executeTaskWithProgress(
    String taskType,
    Map<String, dynamic> taskData, {
    ProgressCallback? onProgress,
  }) async {
    return executeTask(taskType, taskData);
  }

  /// Optional initialization (e.g., check if app is accessible)
  Future<void> initialize() async {}

  /// Optional cleanup
  Future<void> dispose() async {}
}
