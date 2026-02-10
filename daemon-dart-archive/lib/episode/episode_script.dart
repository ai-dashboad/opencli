/// Data models for anime episode scripts.
///
/// An EpisodeScript contains scenes, each with dialogue lines,
/// character definitions, and visual descriptions for AI generation.

class EpisodeScript {
  final String id;
  String title;
  String synopsis;
  List<CharacterDefinition> characters;
  List<EpisodeScene> scenes;
  String language; // zh-CN, ja-JP, en-US
  String style; // cinematic, anime, etc.
  DateTime createdAt;
  DateTime updatedAt;

  EpisodeScript({
    required this.id,
    required this.title,
    this.synopsis = '',
    this.characters = const [],
    this.scenes = const [],
    this.language = 'zh-CN',
    this.style = 'anime',
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'synopsis': synopsis,
        'characters': characters.map((c) => c.toJson()).toList(),
        'scenes': scenes.map((s) => s.toJson()).toList(),
        'language': language,
        'style': style,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory EpisodeScript.fromJson(Map<String, dynamic> json) {
    return EpisodeScript(
      id: json['id'] as String,
      title: json['title'] as String? ?? 'Untitled',
      synopsis: json['synopsis'] as String? ?? '',
      characters: (json['characters'] as List?)
              ?.map((c) =>
                  CharacterDefinition.fromJson(c as Map<String, dynamic>))
              .toList() ??
          [],
      scenes: (json['scenes'] as List?)
              ?.map((s) => EpisodeScene.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      language: json['language'] as String? ?? 'zh-CN',
      style: json['style'] as String? ?? 'anime',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  /// Total estimated duration in seconds.
  int get estimatedDurationSeconds =>
      scenes.fold(0, (sum, s) => sum + s.estimatedDurationSeconds);
}

class EpisodeScene {
  final String id;
  String title;
  int order;
  String visualDescription; // Image generation prompt
  String settingDescription; // Location/atmosphere/narration
  List<DialogueLine> dialogue;
  List<String> characterIds; // Characters in this scene
  String? bgmTrack; // Background music path or name
  double bgmVolume; // 0.0 - 1.0
  String transition; // fade, cut, dissolve, wipe
  int videoDurationSeconds; // Per-clip duration
  List<SceneShot> shots; // Multi-shot decomposition (empty = legacy single-shot)
  String? generatedImagePath;
  String? generatedVideoPath;
  String? generatedAudioPath;

  EpisodeScene({
    required this.id,
    this.title = '',
    this.order = 0,
    this.visualDescription = '',
    this.settingDescription = '',
    this.dialogue = const [],
    this.characterIds = const [],
    this.bgmTrack,
    this.bgmVolume = 0.3,
    this.transition = 'fade',
    this.videoDurationSeconds = 5,
    this.shots = const [],
    this.generatedImagePath,
    this.generatedVideoPath,
    this.generatedAudioPath,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'order': order,
        'visual_description': visualDescription,
        'setting_description': settingDescription,
        'dialogue': dialogue.map((d) => d.toJson()).toList(),
        'character_ids': characterIds,
        'bgm_track': bgmTrack,
        'bgm_volume': bgmVolume,
        'transition': transition,
        'video_duration_seconds': videoDurationSeconds,
        'shots': shots.map((s) => s.toJson()).toList(),
        'generated_image_path': generatedImagePath,
        'generated_video_path': generatedVideoPath,
        'generated_audio_path': generatedAudioPath,
      };

  factory EpisodeScene.fromJson(Map<String, dynamic> json) {
    return EpisodeScene(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      order: json['order'] as int? ?? 0,
      visualDescription: json['visual_description'] as String? ??
          json['visual_prompt'] as String? ?? '',
      settingDescription: json['setting_description'] as String? ??
          json['narration'] as String? ?? '',
      dialogue: (json['dialogue'] as List?)
              ?.map((d) => DialogueLine.fromJson(d as Map<String, dynamic>))
              .toList() ??
          [],
      characterIds: (json['character_ids'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      bgmTrack: json['bgm_track'] as String? ??
          json['bgm_style'] as String?,
      bgmVolume: (json['bgm_volume'] as num?)?.toDouble() ?? 0.3,
      transition: json['transition'] as String? ?? 'fade',
      videoDurationSeconds: json['video_duration_seconds'] as int? ??
          (json['duration_seconds'] as int?) ?? 5,
      shots: (json['shots'] as List?)
              ?.map((s) => SceneShot.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
      generatedImagePath: json['generated_image_path'] as String?,
      generatedVideoPath: json['generated_video_path'] as String?,
      generatedAudioPath: json['generated_audio_path'] as String?,
    );
  }

  /// Estimated duration: dialogue time + padding for visuals.
  int get estimatedDurationSeconds {
    final dialogueDuration = dialogue.fold(0.0, (sum, d) => sum + d.estimatedDurationSeconds);
    return (dialogueDuration + 2).ceil().clamp(videoDurationSeconds, 60);
  }
}

class DialogueLine {
  final String characterId;
  String text;
  String? voice; // TTS voice ID override
  double rate; // Speech rate
  String emotion; // neutral, angry, sad, happy, excited
  double startTime; // Seconds from scene start (for subtitles)

  DialogueLine({
    required this.characterId,
    required this.text,
    this.voice,
    this.rate = 1.0,
    this.emotion = 'neutral',
    this.startTime = 0,
  });

  Map<String, dynamic> toJson() => {
        'character_id': characterId,
        'text': text,
        'voice': voice,
        'rate': rate,
        'emotion': emotion,
        'start_time': startTime,
      };

  factory DialogueLine.fromJson(Map<String, dynamic> json) {
    return DialogueLine(
      characterId: json['character_id'] as String? ?? 'narrator',
      text: json['text'] as String? ?? '',
      voice: json['voice'] as String?,
      rate: (json['rate'] as num?)?.toDouble() ?? 1.0,
      emotion: json['emotion'] as String? ?? 'neutral',
      startTime: (json['start_time'] as num?)?.toDouble() ?? 0,
    );
  }

  /// Rough estimate: ~4 chars/second for Chinese, ~12 chars/second for English.
  double get estimatedDurationSeconds {
    final charCount = text.length;
    // Detect CJK characters
    final cjkCount = text.runes.where((r) => r > 0x4E00 && r < 0x9FFF).length;
    if (cjkCount > charCount / 2) {
      return charCount / 4.0; // Chinese ~4 chars/sec
    }
    return charCount / 12.0; // English ~12 chars/sec
  }
}

/// A single shot within a scene — the atomic unit of cinematic composition.
///
/// Each scene is decomposed into 2-4 shots with distinct camera angles,
/// framing, and motion to create cinematic variety.
class SceneShot {
  final String id;
  String visualDescription;
  String cameraMotion; // zoom_in, zoom_out, pan_left, pan_right, tilt_up, tilt_down, static
  String shotType; // establishing, medium, close_up, over_shoulder, wide
  String cameraAngle; // eye_level, low_angle, high_angle
  int durationSeconds; // 2-5 seconds per shot
  String? generatedImagePath;
  String? generatedVideoPath;

  SceneShot({
    required this.id,
    this.visualDescription = '',
    this.cameraMotion = 'static',
    this.shotType = 'medium',
    this.cameraAngle = 'eye_level',
    this.durationSeconds = 3,
    this.generatedImagePath,
    this.generatedVideoPath,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'visual_description': visualDescription,
        'camera_motion': cameraMotion,
        'shot_type': shotType,
        'camera_angle': cameraAngle,
        'duration_seconds': durationSeconds,
        'generated_image_path': generatedImagePath,
        'generated_video_path': generatedVideoPath,
      };

  factory SceneShot.fromJson(Map<String, dynamic> json) {
    return SceneShot(
      id: json['id'] as String? ?? '',
      visualDescription: json['visual_description'] as String? ?? '',
      cameraMotion: json['camera_motion'] as String? ?? 'static',
      shotType: json['shot_type'] as String? ?? 'medium',
      cameraAngle: json['camera_angle'] as String? ?? 'eye_level',
      durationSeconds: json['duration_seconds'] as int? ?? 3,
      generatedImagePath: json['generated_image_path'] as String?,
      generatedVideoPath: json['generated_video_path'] as String?,
    );
  }
}

class CharacterDefinition {
  final String id;
  String name;
  String visualDescription; // For consistent image generation
  String defaultVoice; // TTS voice ID
  String personality; // For AI dialogue generation
  String? referenceImagePath; // IP-Adapter reference

  CharacterDefinition({
    required this.id,
    required this.name,
    this.visualDescription = '',
    this.defaultVoice = 'zh-CN-XiaoxiaoNeural',
    this.personality = '',
    this.referenceImagePath,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'visual_description': visualDescription,
        'default_voice': defaultVoice,
        'personality': personality,
        'reference_image_path': referenceImagePath,
      };

  factory CharacterDefinition.fromJson(Map<String, dynamic> json) {
    return CharacterDefinition(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'Character',
      visualDescription: json['visual_description'] as String? ?? '',
      defaultVoice: json['default_voice'] as String? ??
          json['voice_id'] as String? ?? 'zh-CN-XiaoxiaoNeural',
      personality: json['personality'] as String? ?? '',
      referenceImagePath: json['reference_image_path'] as String?,
    );
  }
}
