import 'dart:convert';
import 'package:http/http.dart' as http;
import 'episode_script.dart';

/// AI-assisted script generation from narrative text.
///
/// Uses Ollama (local LLM) to convert narrative text into
/// structured EpisodeScript JSON with scenes, dialogue, and
/// visual descriptions.
class ScriptGenerator {
  final String ollamaUrl;
  final String model;

  ScriptGenerator({
    this.ollamaUrl = 'http://localhost:11434',
    this.model = 'llama3.2',
  });

  /// Generate an EpisodeScript from narrative text.
  Future<EpisodeScript> generate({
    required String narrativeText,
    String language = 'zh-CN',
    String style = 'anime',
    int maxScenes = 8,
  }) async {
    final prompt = _buildPrompt(narrativeText, language, style, maxScenes);

    final response = await http.post(
      Uri.parse('$ollamaUrl/api/generate'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'model': model,
        'prompt': prompt,
        'stream': false,
        'format': 'json',
        'options': {
          'temperature': 0.7,
          'num_predict': 4096,
        },
      }),
    ).timeout(const Duration(minutes: 3));

    if (response.statusCode != 200) {
      throw Exception('Ollama error: HTTP ${response.statusCode}');
    }

    final data = jsonDecode(response.body);
    final responseText = data['response'] as String? ?? '';

    // Parse the JSON response into an EpisodeScript
    final scriptJson = jsonDecode(responseText) as Map<String, dynamic>;
    return _parseGeneratedScript(scriptJson, language, style);
  }

  String _buildPrompt(String text, String language, String style, int maxScenes) {
    return '''You are a professional anime screenwriter. Convert the following narrative text into a structured anime episode script in JSON format.

NARRATIVE TEXT:
$text

REQUIREMENTS:
- Language: $language
- Visual style: $style
- Maximum scenes: $maxScenes
- Each scene needs a vivid visual description (for AI image generation)
- Include character dialogue with emotion tags
- Assign appropriate background music mood per scene

OUTPUT FORMAT (JSON):
{
  "title": "Episode title",
  "synopsis": "Brief summary",
  "characters": [
    {
      "id": "character_id",
      "name": "Character Name",
      "visual_description": "Detailed appearance for AI image gen: hair color, outfit, build, distinguishing features",
      "personality": "Brief personality traits",
      "default_voice": "${_defaultVoice(language)}"
    }
  ],
  "scenes": [
    {
      "id": "scene_1",
      "order": 0,
      "visual_description": "Detailed anime scene description for AI image generation. Include: composition, lighting, character poses, background elements, camera angle",
      "setting_description": "Location and atmosphere",
      "dialogue": [
        {
          "character_id": "character_id",
          "text": "Dialogue text in $language",
          "emotion": "neutral|angry|sad|happy|excited|fearful|serious",
          "start_time": 0
        }
      ],
      "bgm_track": "mood: epic|calm|tense|romantic|mysterious|action",
      "bgm_volume": 0.3,
      "transition": "fade|cut|dissolve",
      "video_duration_seconds": 5
    }
  ]
}

Generate the script now. Only output valid JSON, no markdown.''';
  }

  String _defaultVoice(String language) => switch (language) {
        'zh-CN' => 'zh-CN-YunjianNeural',
        'ja-JP' => 'ja-JP-KeitaNeural',
        'ko-KR' => 'ko-KR-InJoonNeural',
        _ => 'en-US-GuyNeural',
      };

  EpisodeScript _parseGeneratedScript(
      Map<String, dynamic> json, String language, String style) {
    final id = 'ep_${DateTime.now().millisecondsSinceEpoch}';

    final characters = (json['characters'] as List? ?? [])
        .map((c) => CharacterDefinition.fromJson(c as Map<String, dynamic>))
        .toList();

    // Add narrator if not present
    if (!characters.any((c) => c.id == 'narrator')) {
      characters.insert(
        0,
        CharacterDefinition(
          id: 'narrator',
          name: 'Narrator',
          defaultVoice: _defaultVoice(language),
        ),
      );
    }

    final scenes = (json['scenes'] as List? ?? [])
        .map((s) => EpisodeScene.fromJson(s as Map<String, dynamic>))
        .toList();

    // Ensure scene ordering
    for (int i = 0; i < scenes.length; i++) {
      scenes[i].order = i;
    }

    return EpisodeScript(
      id: id,
      title: json['title'] as String? ?? 'Untitled Episode',
      synopsis: json['synopsis'] as String? ?? '',
      characters: characters,
      scenes: scenes,
      language: language,
      style: style,
    );
  }
}
