import 'domain.dart';
import 'timer/timer_domain.dart';
import 'calculator/calculator_domain.dart';
import 'music/music_domain.dart';
import 'reminders/reminders_domain.dart';
import 'calendar/calendar_domain.dart';
import 'notes/notes_domain.dart';
import 'weather/weather_domain.dart';
import 'email/email_domain.dart';
import 'contacts/contacts_domain.dart';
import 'messages/messages_domain.dart';
import 'translation/translation_domain.dart';
import 'files_media/files_media_domain.dart';
import 'media_creation/media_creation_domain.dart';

/// Central registry that collects all TaskDomain instances and provides:
/// 1. Executor registration into MobileTaskHandler
/// 2. Intent pattern collection for IntentRecognizer
/// 3. Auto-generated Ollama classification prompt
/// 4. Display config lookup for Flutter result rendering
class DomainRegistry {
  final List<TaskDomain> _domains = [];
  final Map<String, TaskDomain> _domainById = {};
  final Map<String, TaskDomain> _domainByTaskType = {};

  /// Register a domain
  void register(TaskDomain domain) {
    _domains.add(domain);
    _domainById[domain.id] = domain;
    for (final taskType in domain.taskTypes) {
      _domainByTaskType[taskType] = domain;
    }
  }

  /// Get all registered domains
  List<TaskDomain> get domains => List.unmodifiable(_domains);

  /// Get a domain by ID
  TaskDomain? getDomain(String id) => _domainById[id];

  /// Get the domain that handles a task type
  TaskDomain? getDomainForTaskType(String taskType) =>
      _domainByTaskType[taskType];

  /// Check if a task type is handled by any domain
  bool handlesTaskType(String taskType) =>
      _domainByTaskType.containsKey(taskType);

  /// Execute a domain task
  Future<Map<String, dynamic>> executeTask(
    String taskType,
    Map<String, dynamic> taskData,
  ) async {
    final domain = _domainByTaskType[taskType];
    if (domain == null) {
      return {
        'success': false,
        'error': 'No domain handles task type: $taskType'
      };
    }
    return await domain.executeTask(taskType, taskData);
  }

  /// Get all intent patterns across all domains
  List<DomainIntentPattern> get allIntentPatterns {
    return _domains.expand((d) => d.intentPatterns).toList();
  }

  /// Get all task types across all domains
  List<String> get allTaskTypes {
    return _domains.expand((d) => d.taskTypes).toList();
  }

  /// Auto-generate the Ollama prompt section from domain metadata
  String generateOllamaPromptSection() {
    final buffer = StringBuffer();
    int intentNumber = 12; // Continue from existing 11 intents

    for (final domain in _domains) {
      for (final intent in domain.ollamaIntents) {
        buffer.write(
            '$intentNumber. **${intent.intentName}** - ${intent.description}');

        if (intent.parameters.isNotEmpty) {
          final paramStr = intent.parameters.entries
              .map((e) => '${e.key}: ${e.value}')
              .join(', ');
          buffer.write(' (params: $paramStr)');
        }
        buffer.writeln();

        for (final example in intent.examples) {
          buffer.writeln('    "${example.input}" -> ${example.intentJson}');
        }
        buffer.writeln();
        intentNumber++;
      }
    }

    return buffer.toString();
  }

  /// Get display config for a task type
  DomainDisplayConfig? getDisplayConfig(String taskType) {
    final domain = _domainByTaskType[taskType];
    if (domain == null) return null;
    return domain.displayConfigs[taskType];
  }

  /// Initialize all domains
  Future<void> initializeAll() async {
    for (final domain in _domains) {
      try {
        await domain.initialize();
        print(
            '[DomainRegistry] Initialized domain: ${domain.id} (${domain.taskTypes.length} task types)');
      } catch (e) {
        print(
            '[DomainRegistry] Warning: Failed to initialize domain ${domain.id}: $e');
      }
    }
    print(
        '[DomainRegistry] Registered ${_domains.length} domains with ${_domainByTaskType.length} task types');
  }

  /// Dispose all domains
  Future<void> disposeAll() async {
    for (final domain in _domains) {
      try {
        await domain.dispose();
      } catch (e) {
        print(
            '[DomainRegistry] Warning: Failed to dispose domain ${domain.id}: $e');
      }
    }
  }

  /// Get registry statistics
  Map<String, dynamic> getStats() {
    return {
      'domainCount': _domains.length,
      'taskTypeCount': _domainByTaskType.length,
      'domains': _domains
          .map((d) => <String, dynamic>{
                'id': d.id,
                'name': d.name,
                'taskTypes': d.taskTypes,
                'intentPatterns': d.intentPatterns.length,
                'ollamaIntents': d.ollamaIntents.length,
              })
          .toList(),
    };
  }
}

/// Factory function that creates and registers all built-in domains.
DomainRegistry createBuiltinDomainRegistry() {
  final registry = DomainRegistry();
  registry.register(TimerDomain());
  registry.register(CalculatorDomain());
  registry.register(MusicDomain());
  registry.register(RemindersDomain());
  registry.register(CalendarDomain());
  registry.register(NotesDomain());
  registry.register(WeatherDomain());
  registry.register(EmailDomain());
  registry.register(ContactsDomain());
  registry.register(MessagesDomain());
  registry.register(TranslationDomain());
  registry.register(FilesMediaDomain());
  registry.register(MediaCreationDomain());
  return registry;
}
