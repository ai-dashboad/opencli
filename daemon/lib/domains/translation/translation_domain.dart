import 'dart:io';
import 'dart:convert';
import '../domain.dart';

class TranslationDomain extends TaskDomain {
  @override
  String get id => 'translation';
  @override
  String get name => 'Translation';
  @override
  String get description => 'Translate text between languages using local AI (Ollama)';
  @override
  String get icon => 'translate';
  @override
  int get colorHex => 0xFF673AB7;

  @override
  List<String> get taskTypes => ['translation_translate'];

  @override
  List<DomainIntentPattern> get intentPatterns => [
    DomainIntentPattern(
      pattern: RegExp(r'^translate\s+(.+?)\s+(?:to|into)\s+(\w+)$', caseSensitive: false),
      taskType: 'translation_translate',
      extractData: (m) => {'text': m.group(1)!.trim(), 'target_language': m.group(2)!.trim()},
    ),
    DomainIntentPattern(
      pattern: RegExp(r'^how\s+do\s+you\s+say\s+(.+?)\s+in\s+(\w+)$', caseSensitive: false),
      taskType: 'translation_translate',
      extractData: (m) => {'text': m.group(1)!.trim(), 'target_language': m.group(2)!.trim()},
    ),
    DomainIntentPattern(
      pattern: RegExp(r'^(.+?)\s+in\s+(spanish|french|german|japanese|chinese|korean|italian|portuguese|russian|arabic|hindi)$', caseSensitive: false),
      taskType: 'translation_translate',
      extractData: (m) => {'text': m.group(1)!.trim(), 'target_language': m.group(2)!.trim()},
    ),
  ];

  @override
  List<DomainOllamaIntent> get ollamaIntents => [
    DomainOllamaIntent(
      intentName: 'translation_translate',
      description: 'Translate text to another language',
      parameters: {'text': 'text to translate', 'target_language': 'target language'},
      examples: [
        OllamaExample(input: 'translate hello to Spanish', intentJson: '{"intent": "translation_translate", "confidence": 0.95, "parameters": {"text": "hello", "target_language": "Spanish"}}'),
        OllamaExample(input: 'how do you say goodbye in French', intentJson: '{"intent": "translation_translate", "confidence": 0.95, "parameters": {"text": "goodbye", "target_language": "French"}}'),
      ],
    ),
  ];

  @override
  Map<String, DomainDisplayConfig> get displayConfigs => {
    'translation_translate': const DomainDisplayConfig(cardType: 'translation', titleTemplate: 'Translation', icon: 'translate', colorHex: 0xFF673AB7),
  };

  @override
  Future<Map<String, dynamic>> executeTask(String taskType, Map<String, dynamic> data) async {
    if (taskType == 'translation_translate') return _translate(data);
    return {'success': false, 'error': 'Unknown translation task: $taskType'};
  }

  Future<Map<String, dynamic>> _translate(Map<String, dynamic> data) async {
    final text = data['text'] as String? ?? '';
    final targetLang = data['target_language'] as String? ?? 'Spanish';

    try {
      // Use Ollama for translation
      final prompt = 'Translate the following text to $targetLang. Return ONLY the translated text, nothing else:\n\n$text';
      final body = jsonEncode({
        'model': 'qwen2.5:latest',
        'prompt': prompt,
        'stream': false,
      });

      final result = await Process.run('curl', [
        '-s', '-X', 'POST',
        'http://localhost:11434/api/generate',
        '-H', 'Content-Type: application/json',
        '-d', body,
      ]).timeout(const Duration(seconds: 30));

      if (result.exitCode != 0) {
        return {'success': false, 'error': 'Ollama not available', 'domain': 'translation'};
      }

      final json = jsonDecode(result.stdout as String);
      final translated = (json['response'] as String? ?? '').trim();

      if (translated.isEmpty) {
        return {'success': false, 'error': 'Translation failed', 'domain': 'translation'};
      }

      return {
        'success': true,
        'original': text,
        'translated': translated,
        'target_language': targetLang,
        'domain': 'translation', 'card_type': 'translation',
      };
    } catch (e) {
      return {'success': false, 'error': 'Translation error: $e', 'domain': 'translation'};
    }
  }
}
