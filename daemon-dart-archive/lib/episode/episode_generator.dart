import 'dart:convert';
import 'dart:io';
import 'episode_script.dart';
import 'ffmpeg_composer.dart';
import 'subtitle_generator.dart';
import '../domains/media_creation/tts/tts_registry.dart';
import '../domains/media_creation/local_model_manager.dart';
import '../domains/domain.dart';
import '../domains/domain_registry.dart';

/// Callback for generation progress updates.
typedef EpisodeProgressCallback = Future<void> Function(
    double progress, String phase, String message);

/// 10-phase cinematic episode generation orchestrator.
///
/// Phase 1:  Shot Decomposition     (0-2%)   — Auto-decompose scenes into 2-4 shots
/// Phase 2:  Shot Image Generation  (2-25%)  — Keyframe per shot with cinematic prompts
/// Phase 3:  Shot Video Generation  (25-45%) — AnimateDiff V3 + MotionLoRA per shot
/// Phase 4:  Post-Processing        (45-60%) — Upscale + RIFE + color grade per shot
/// Phase 5:  Shot Assembly          (60-65%) — Concat shots within scene (jump cuts)
/// Phase 6:  TTS Dialogue           (65-75%) — Edge TTS per character
/// Phase 7:  Subtitles              (75-78%) — ASS generation
/// Phase 8:  Audio Mix              (78-82%) — Voice + BGM
/// Phase 9:  Scene Assembly         (82-92%) — Video + audio + soft subs
/// Phase 10: Final Assembly         (92-100%) — Concat scenes with transitions
class EpisodeGenerator {
  final DomainRegistry domainRegistry;
  final TTSRegistry ttsRegistry;
  final FFmpegComposer ffmpegComposer;
  final SubtitleGenerator subtitleGenerator;
  CinematicPostProcessor? _postProcessor;

  EpisodeGenerator({
    required this.domainRegistry,
    required this.ttsRegistry,
    FFmpegComposer? ffmpegComposer,
    SubtitleGenerator? subtitleGenerator,
  })  : ffmpegComposer = ffmpegComposer ?? FFmpegComposer(),
        subtitleGenerator = subtitleGenerator ?? SubtitleGenerator();

  /// Base negative prompt shared across all shot types.
  static const _baseNegativePrompt =
      'low quality, worst quality, blurry, deformed, 3d, realistic photo';

  /// Shot-type-specific negative prompts for higher quality.
  static String negativePromptForShot(String shotType) {
    final extra = switch (shotType) {
      'close_up' => ', bad anatomy, deformed face, asymmetrical eyes, '
          'extra fingers, missing fingers, bad hands, ugly, disfigured',
      'establishing' => ', text, watermark, signature, border, frame, '
          'logo, username, artist name',
      'medium' => ', stiff pose, t-pose, unnatural proportions, '
          'bad anatomy, extra limbs',
      'over_shoulder' => ', bad anatomy, extra arms, fused bodies, '
          'wrong perspective, distorted depth',
      _ => ', bad anatomy, bad hands, extra digits, cropped, watermark, text',
    };
    return '$_baseNegativePrompt$extra';
  }

  /// Legacy constant for backward compat.
  static const animeNegativePrompt = _baseNegativePrompt;

  /// Generate a full episode from a script.
  ///
  /// [quality] controls the post-processing pipeline:
  ///   - 'draft': No upscale, no RIFE, no color grading (fastest)
  ///   - 'standard': Upscale + RIFE + color grading
  ///   - 'cinematic': Upscale + RIFE + color grading + film effects
  Future<Map<String, dynamic>> generate({
    required EpisodeScript script,
    String? imageProvider,
    String? videoProvider,
    String quality = 'draft',
    String? colorGradeLut,
    String? exportPlatform,
    EpisodeProgressCallback? onProgress,
  }) async {
    final home = Platform.environment['HOME'] ?? '/tmp';
    final workDir = '$home/.opencli/episodes/${script.id}';
    await Directory(workDir).create(recursive: true);

    final sceneCount = script.scenes.length;
    if (sceneCount == 0) {
      return {'success': false, 'error': 'No scenes in script'};
    }

    final tier = switch (quality) {
      'cinematic' => QualityTier.cinematic,
      'standard' => QualityTier.standard,
      _ => QualityTier.draft,
    };

    // Initialize post-processor for standard/cinematic tiers
    if (tier != QualityTier.draft) {
      final mediaCreation = domainRegistry.getDomain('media_creation');
      if (mediaCreation != null) {
        try {
          // Get local model manager from the domain
          final dynamic domain = mediaCreation;
          if (domain.localModelManager is LocalModelManager) {
            _postProcessor = CinematicPostProcessor(
              localModelManager: domain.localModelManager as LocalModelManager,
              ffmpegComposer: ffmpegComposer,
            );
          }
        } catch (_) {
          print('[EpisodeGenerator] Post-processor not available (no local model manager)');
        }
      }
    }

    // Use V3 for standard/cinematic if video provider is 'local'
    final effectiveVideoProvider = videoProvider;
    final useV3 = tier != QualityTier.draft &&
        (videoProvider == 'local' || videoProvider == 'local_v3');

    try {
      // ═══ Phase 1: Shot Decomposition ═══
      await onProgress?.call(0.01, 'shot_decomposition', 'Decomposing scenes into cinematic shots...');
      int totalShots = 0;
      for (final scene in script.scenes) {
        if (scene.shots.isEmpty) {
          scene.shots = _decomposeIntoShots(scene, script);
        }
        totalShots += scene.shots.length;
      }
      await onProgress?.call(0.02, 'shot_decomposition',
          'Decomposed $sceneCount scenes into $totalShots shots');

      // ═══ Phase 2: Shot Image Generation ═══
      await onProgress?.call(0.03, 'shot_images', 'Generating shot keyframes...');
      await _generateShotImages(
        script, workDir, imageProvider ?? 'local', onProgress, totalShots);

      // ═══ Phase 3: Shot Video Generation ═══
      await onProgress?.call(0.25, 'shot_videos', 'Animating shots into video clips...');
      await _generateShotVideos(
        script, workDir, effectiveVideoProvider, useV3, tier, onProgress, totalShots);

      // Resolve LUT file path
      String? lutPath;
      if (colorGradeLut != null && colorGradeLut.isNotEmpty) {
        final home = Platform.environment['HOME'] ?? '/tmp';
        final candidate = '$home/.opencli/luts/$colorGradeLut.cube';
        if (await File(candidate).exists()) {
          lutPath = candidate;
        }
      }

      // ═══ Phase 4: Post-Processing ═══
      if (tier != QualityTier.draft && _postProcessor != null) {
        await onProgress?.call(0.45, 'post_processing', 'Applying cinematic post-processing...');
        await _postProcessShots(script, workDir, tier, onProgress, totalShots, lutPath: lutPath);
      } else {
        await onProgress?.call(0.60, 'post_processing', 'Skipping post-processing (draft mode)');
      }

      // ═══ Phase 5: Shot Assembly (concat shots within each scene) ═══
      await onProgress?.call(0.60, 'shot_assembly', 'Assembling shots into scenes...');
      final sceneVideoPaths = await _assembleShots(script, workDir, onProgress);

      // ═══ Phase 6: TTS Dialogue ═══
      await onProgress?.call(0.65, 'tts', 'Generating voice dialogue...');
      final audioPaths = await _generateTTS(script, workDir, onProgress);

      // ═══ Phase 7: Subtitles ═══
      await onProgress?.call(0.75, 'subtitles', 'Creating subtitles...');
      final assPaths = await _generateSubtitles(script, workDir);

      // ═══ Phase 8: Audio Mix ═══
      await onProgress?.call(0.78, 'audio_mix', 'Mixing voice with background music...');
      final mixedAudioPaths = await _mixAudio(script, audioPaths, workDir, onProgress);

      // ═══ Phase 9: Scene Assembly ═══
      await onProgress?.call(0.82, 'scene_assembly', 'Assembling scenes with audio...');
      final assembledScenePaths = await _assembleScenes(
        script, sceneVideoPaths, mixedAudioPaths, assPaths, workDir, onProgress);

      // ═══ Phase 10: Final Assembly ═══
      await onProgress?.call(0.92, 'final_assembly', 'Assembling final episode...');
      var outputPath = await _assembleEpisode(script, assembledScenePaths, workDir);

      // Optional: Platform-specific encoding
      if (exportPlatform != null && exportPlatform.isNotEmpty && exportPlatform != 'default') {
        await onProgress?.call(0.97, 'final_assembly', 'Encoding for $exportPlatform...');
        try {
          final platformPath = '$workDir/${script.id}_${exportPlatform}.mp4';
          await ffmpegComposer.encodeForPlatform(
            inputPath: outputPath,
            outputPath: platformPath,
            platform: exportPlatform,
          );
          outputPath = platformPath;
        } catch (e) {
          print('[EpisodeGenerator] Platform encoding failed ($exportPlatform): $e');
        }
      }

      await onProgress?.call(1.0, 'complete', 'Episode generation complete!');

      final outputFile = File(outputPath);
      final sizeBytes = await outputFile.exists() ? await outputFile.length() : 0;
      final sizeMB = (sizeBytes / 1024 / 1024).toStringAsFixed(1);

      return {
        'success': true,
        'output_path': outputPath,
        'size_bytes': sizeBytes,
        'scenes': sceneCount,
        'total_shots': totalShots,
        'quality': quality,
        'message': 'Episode "${script.title}" generated ($sizeMB MB, $sceneCount scenes, $totalShots shots, $quality quality)',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Episode generation failed: $e',
      };
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // Phase 1: Shot Decomposition
  // ═══════════════════════════════════════════════════════════════════

  /// Auto-decompose a scene into 2-4 cinematic shots.
  List<SceneShot> _decomposeIntoShots(EpisodeScene scene, EpisodeScript script) {
    final totalDuration = scene.videoDurationSeconds;
    final hasMultipleCharacters = scene.characterIds.length >= 2;
    final shots = <SceneShot>[];

    // Shot 1: Establishing (30% duration) — pan, setting focus
    final establishDur = (totalDuration * 0.30).ceil().clamp(2, 5);
    shots.add(SceneShot(
      id: '${scene.id}_shot_1',
      visualDescription: _buildShotPrompt(
        scene, script, 'establishing',
        'Wide panoramic view, atmospheric perspective, environmental storytelling'),
      cameraMotion: 'pan_right',
      shotType: 'establishing',
      cameraAngle: 'eye_level',
      durationSeconds: establishDur,
    ));

    // Shot 2: Medium (30%) — zoom_in, character-focused
    final mediumDur = (totalDuration * 0.30).ceil().clamp(2, 5);
    shots.add(SceneShot(
      id: '${scene.id}_shot_2',
      visualDescription: _buildShotPrompt(
        scene, script, 'medium',
        'Character-focused, natural pose, balanced framing'),
      cameraMotion: 'zoom_in',
      shotType: 'medium',
      cameraAngle: 'eye_level',
      durationSeconds: mediumDur,
    ));

    // Shot 3: Close-up (25%) — static, face/expression for dialogue
    final closeUpDur = (totalDuration * 0.25).ceil().clamp(2, 4);
    shots.add(SceneShot(
      id: '${scene.id}_shot_3',
      visualDescription: _buildShotPrompt(
        scene, script, 'close_up',
        'Face detail, emotional expression, shallow depth of field, bokeh background'),
      cameraMotion: 'static',
      shotType: 'close_up',
      cameraAngle: 'eye_level',
      durationSeconds: closeUpDur,
    ));

    // Shot 4: Over-shoulder (15%) — only if 2+ characters
    if (hasMultipleCharacters) {
      final overShoulderDur = (totalDuration * 0.15).ceil().clamp(2, 3);
      shots.add(SceneShot(
        id: '${scene.id}_shot_4',
        visualDescription: _buildShotPrompt(
          scene, script, 'over_shoulder',
          'Depth layering, foreground blur, reaction focus'),
        cameraMotion: 'tilt_up',
        shotType: 'over_shoulder',
        cameraAngle: 'eye_level',
        durationSeconds: overShoulderDur,
      ));
    }

    return shots;
  }

  /// Build a cinematic Danbooru-tagged prompt for a specific shot type.
  String _buildShotPrompt(
    EpisodeScene scene,
    EpisodeScript script,
    String shotType,
    String compositionHint,
  ) {
    final quality = 'masterpiece, best quality, absurdres, ultra-detailed';

    // Shot-type Danbooru composition tags
    final composition = switch (shotType) {
      'establishing' => 'wide shot, panoramic, scenery focus, depth of field, '
          'atmospheric perspective, landscape',
      'medium' => 'cowboy shot, upper body, dynamic pose, looking at viewer, '
          'natural stance',
      'close_up' => 'portrait, close-up, face focus, detailed eyes, '
          'expressive face, bokeh background, shallow depth of field',
      'over_shoulder' => 'over shoulder, depth layering, foreground blur, '
          'two people, conversation, profile view',
      'wide' => 'wide shot, full body, epic scale, dramatic perspective',
      _ => compositionHint,
    };

    // Extract emotion Danbooru tags from dialogue
    final emotions = _extractEmotionTags(scene);

    // Character Danbooru descriptors
    final characters = _buildCharacterTags(scene, script);

    // Lighting inference from setting
    final lighting = _inferLighting(scene.settingDescription);

    final parts = <String>[
      quality,
      composition,
      if (characters.isNotEmpty) characters,
      scene.visualDescription,
      if (emotions.isNotEmpty) emotions,
      lighting,
      'anime coloring, ${script.style}',
    ];

    return parts.join(', ');
  }

  /// Build a video-specific prompt with motion verbs for AnimateDiff.
  String _buildVideoPrompt(SceneShot shot, EpisodeScene scene) {
    final motionVerbs = switch (shot.cameraMotion) {
      'zoom_in' => 'camera slowly pushing forward, focus sharpening, '
          'approaching subject',
      'zoom_out' => 'camera pulling back, revealing environment, '
          'widening perspective',
      'pan_left' => 'camera panning left, scenery scrolling right, '
          'smooth horizontal motion',
      'pan_right' => 'camera panning right, scenery scrolling left, '
          'smooth horizontal motion',
      'tilt_up' => 'camera tilting upward, revealing sky, vertical motion',
      'tilt_down' => 'camera tilting downward, descending view',
      _ => 'subtle breathing motion, blinking, hair swaying in wind',
    };

    final shotMotion = switch (shot.shotType) {
      'close_up' => 'subtle breathing, eye blinking, hair swaying, '
          'gentle expression change',
      'establishing' => 'clouds moving, leaves rustling, ambient motion, '
          'environmental animation',
      'medium' => 'natural body sway, gesture motion, cloth movement',
      'over_shoulder' => 'slight head turn, speaking motion, '
          'reactive body language',
      _ => 'natural motion, smooth animation',
    };

    final emotions = _extractEmotionTags(scene);

    return 'animated, moving, cinematic motion, smooth animation, '
        '$motionVerbs, $shotMotion, '
        '${shot.visualDescription}, '
        '${emotions.isNotEmpty ? "$emotions, " : ""}'
        'anime, high quality';
  }

  /// Map dialogue emotions to visual Danbooru tags.
  String _extractEmotionTags(EpisodeScene scene) {
    final emotionSet = <String>{};
    for (final line in scene.dialogue) {
      final tags = switch (line.emotion.toLowerCase()) {
        'happy' || 'joy' => 'smile, happy, bright eyes, warm expression',
        'sad' || 'grief' => 'crying, tears, downcast eyes, melancholic',
        'angry' || 'rage' => 'angry, furrowed brows, clenched fist, intense gaze',
        'excited' || 'surprised' => 'excited, open mouth, sparkling eyes, dynamic pose',
        'scared' || 'fear' => 'scared, wide eyes, trembling, defensive pose',
        'shy' || 'embarrassed' => 'blush, looking away, nervous, fidgeting',
        'determined' || 'serious' => 'determined expression, sharp gaze, confident stance',
        'love' || 'affection' => 'gentle smile, soft eyes, warm lighting, blush',
        _ => 'calm expression, serene',
      };
      emotionSet.add(tags);
    }
    return emotionSet.join(', ');
  }

  /// Build character Danbooru descriptors from scene characters.
  String _buildCharacterTags(EpisodeScene scene, EpisodeScript script) {
    final charTags = <String>[];
    final seenIds = <String>{};

    for (final line in scene.dialogue) {
      if (seenIds.contains(line.characterId)) continue;
      seenIds.add(line.characterId);

      final char = script.characters
          .where((c) => c.id == line.characterId)
          .firstOrNull;
      if (char == null || char.visualDescription.isEmpty) continue;

      charTags.add(char.visualDescription);
    }

    // Also add characters from characterIds that aren't in dialogue
    for (final cid in scene.characterIds) {
      if (seenIds.contains(cid)) continue;
      final char = script.characters
          .where((c) => c.id == cid)
          .firstOrNull;
      if (char != null && char.visualDescription.isNotEmpty) {
        charTags.add(char.visualDescription);
      }
    }

    return charTags.join(', ');
  }

  /// Infer lighting Danbooru tags from setting description.
  String _inferLighting(String settingDescription) {
    final lower = settingDescription.toLowerCase();

    if (lower.contains('night') || lower.contains('dark') || lower.contains('moonl')) {
      return 'night, moonlight, dark atmosphere, cool lighting, rim light';
    }
    if (lower.contains('sunset') || lower.contains('dusk') || lower.contains('evening')) {
      return 'sunset, golden hour, warm lighting, orange sky, long shadows';
    }
    if (lower.contains('sunrise') || lower.contains('dawn') || lower.contains('morning')) {
      return 'sunrise, soft morning light, warm glow, mist';
    }
    if (lower.contains('rain') || lower.contains('storm') || lower.contains('thunder')) {
      return 'rain, overcast, dramatic lighting, wet surfaces, lightning';
    }
    if (lower.contains('snow') || lower.contains('winter') || lower.contains('ice')) {
      return 'snow, cold atmosphere, white landscape, breath visible';
    }
    if (lower.contains('forest') || lower.contains('tree') || lower.contains('garden')) {
      return 'dappled light, sunbeams through foliage, natural green light';
    }
    if (lower.contains('indoor') || lower.contains('room') || lower.contains('classroom')) {
      return 'indoor lighting, soft ambient light, window light';
    }
    if (lower.contains('city') || lower.contains('street') || lower.contains('neon')) {
      return 'city lights, neon glow, urban atmosphere, reflections';
    }
    if (lower.contains('ocean') || lower.contains('sea') || lower.contains('beach')) {
      return 'ocean, sunlight on water, sparkling waves, bright sky';
    }

    return 'cinematic lighting, dramatic shadows, volumetric light';
  }

  // ═══════════════════════════════════════════════════════════════════
  // Phase 2: Shot Image Generation
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _generateShotImages(
    EpisodeScript script,
    String workDir,
    String provider,
    EpisodeProgressCallback? onProgress,
    int totalShots,
  ) async {
    final mediaCreation = domainRegistry.getDomain('media_creation');
    if (mediaCreation == null) return;

    int shotsDone = 0;
    for (int si = 0; si < script.scenes.length; si++) {
      final scene = script.scenes[si];

      // If no shots (backward compat), generate a single scene image
      if (scene.shots.isEmpty) {
        final imagePath = await _generateSceneImage(
          mediaCreation, scene, script, workDir, si, provider);
        if (imagePath != null) scene.generatedImagePath = imagePath;
        shotsDone++;
        final progress = 0.02 + (shotsDone / totalShots) * 0.23;
        await onProgress?.call(progress, 'shot_images',
            'Generated keyframe $shotsDone/$totalShots');
        continue;
      }

      // Generate per-shot keyframes
      for (int ji = 0; ji < scene.shots.length; ji++) {
        final shot = scene.shots[ji];
        final imagePath = await _generateShotImage(
          mediaCreation, shot, scene, script, workDir, si, ji, provider);
        if (imagePath != null) shot.generatedImagePath = imagePath;
        shotsDone++;
        final progress = 0.02 + (shotsDone / totalShots) * 0.23;
        await onProgress?.call(progress, 'shot_images',
            'Generated keyframe $shotsDone/$totalShots');
      }
    }
  }

  Future<String?> _generateShotImage(
    TaskDomain domain,
    SceneShot shot,
    EpisodeScene scene,
    EpisodeScript script,
    String workDir,
    int sceneIndex,
    int shotIndex,
    String provider,
  ) async {
    try {
      final prompt = shot.visualDescription.isNotEmpty
          ? shot.visualDescription
          : _buildShotPrompt(scene, script, shot.shotType, '');

      final String taskType;
      final Map<String, dynamic> taskData;
      if (provider == 'local') {
        taskType = 'media_local_generate_image';
        taskData = {
          'prompt': prompt,
          'model': 'animagine_xl',
          'width': 1024,
          'height': 1024,
          'steps': 28,
          'negative_prompt': negativePromptForShot(shot.shotType),
        };
      } else {
        taskType = 'media_ai_generate_image';
        taskData = {
          'prompt': prompt,
          'style': 'anime',
          'aspect_ratio': '16:9',
          'width': 1280,
          'height': 720,
          'provider': provider,
        };
      }

      print('[EpisodeGenerator] Generating image for scene $sceneIndex shot $shotIndex via $provider');
      final result = await domain.executeTask(taskType, taskData);

      if (result['success'] == true && result['image_base64'] != null) {
        final rawPath = '$workDir/scene_${sceneIndex}_shot_${shotIndex}_raw.png';
        final imagePath = '$workDir/scene_${sceneIndex}_shot_${shotIndex}_keyframe.png';
        final bytes = base64Decode(result['image_base64'] as String);
        await File(rawPath).writeAsBytes(bytes);
        await _resizeImage(rawPath, imagePath, 1280, 720);
        try { await File(rawPath).delete(); } catch (_) {}
        return imagePath;
      }
    } catch (e) {
      print('[EpisodeGenerator] Shot image gen failed (scene $sceneIndex, shot $shotIndex): $e');
    }
    return null;
  }

  /// Generate a single scene-level image (backward compatibility for scenes without shots).
  Future<String?> _generateSceneImage(
    TaskDomain domain,
    EpisodeScene scene,
    EpisodeScript script,
    String workDir,
    int index,
    String provider,
  ) async {
    try {
      final characterDescriptions = scene.dialogue
          .map((d) => script.characters
              .where((c) => c.id == d.characterId)
              .firstOrNull
              ?.visualDescription ?? '')
          .where((d) => d.isNotEmpty)
          .toSet()
          .join('. ');

      final prompt =
          '${scene.visualDescription}. '
          '${scene.settingDescription}. '
          '${characterDescriptions.isNotEmpty ? "Characters: $characterDescriptions. " : ""}'
          'Anime style, ${script.style}, high quality, detailed, '
          '16:9 aspect ratio, cinematic lighting';

      final String taskType;
      final Map<String, dynamic> taskData;
      if (provider == 'local') {
        taskType = 'media_local_generate_image';
        taskData = {
          'prompt': prompt,
          'model': 'animagine_xl',
          'width': 1024,
          'height': 1024,
          'steps': 28,
          'negative_prompt': negativePromptForShot('medium'),
        };
      } else {
        taskType = 'media_ai_generate_image';
        taskData = {
          'prompt': prompt,
          'style': 'anime',
          'aspect_ratio': '16:9',
          'width': 1280,
          'height': 720,
          'provider': provider,
        };
      }

      final result = await domain.executeTask(taskType, taskData);

      if (result['success'] == true && result['image_base64'] != null) {
        final rawPath = '$workDir/scene_${index}_keyframe_raw.png';
        final imagePath = '$workDir/scene_${index}_keyframe.png';
        final bytes = base64Decode(result['image_base64'] as String);
        await File(rawPath).writeAsBytes(bytes);
        await _resizeImage(rawPath, imagePath, 1280, 720);
        try { await File(rawPath).delete(); } catch (_) {}
        scene.generatedImagePath = imagePath;
        return imagePath;
      }
    } catch (e) {
      print('[EpisodeGenerator] Image gen failed for scene $index: $e');
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════
  // Phase 3: Shot Video Generation
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _generateShotVideos(
    EpisodeScript script,
    String workDir,
    String? provider,
    bool useV3,
    QualityTier tier,
    EpisodeProgressCallback? onProgress,
    int totalShots,
  ) async {
    final mediaCreation = domainRegistry.getDomain('media_creation');
    if (mediaCreation == null) return;

    int shotsDone = 0;

    for (int si = 0; si < script.scenes.length; si++) {
      final scene = script.scenes[si];

      // Backward compat: scenes without shots
      if (scene.shots.isEmpty) {
        final imagePath = scene.generatedImagePath;
        if (imagePath == null) { shotsDone++; continue; }

        final videoPath = await _generateSceneVideo(
          mediaCreation, imagePath, scene, workDir, si, provider, useV3, tier);
        if (videoPath != null) scene.generatedVideoPath = videoPath;
        shotsDone++;
        final progress = 0.25 + (shotsDone / totalShots) * 0.20;
        await onProgress?.call(progress, 'shot_videos',
            'Animated $shotsDone/$totalShots shots');
        continue;
      }

      // Process shots in batches of 3
      for (int batch = 0; batch < scene.shots.length; batch += 3) {
        final end = (batch + 3).clamp(0, scene.shots.length);
        final futures = <Future<void>>[];

        for (int ji = batch; ji < end; ji++) {
          futures.add(() async {
            final shot = scene.shots[ji];
            final imagePath = shot.generatedImagePath;
            if (imagePath == null) return;

            final videoPath = await _generateShotVideo(
              mediaCreation, shot, imagePath, workDir, si, ji, provider, useV3, tier, script);
            if (videoPath != null) shot.generatedVideoPath = videoPath;
          }());
        }

        await Future.wait(futures);
        shotsDone += (end - batch);
        final progress = 0.25 + (shotsDone / totalShots) * 0.20;
        await onProgress?.call(progress, 'shot_videos',
            'Animated $shotsDone/$totalShots shots');
      }
    }
  }

  Future<String?> _generateShotVideo(
    TaskDomain mediaCreation,
    SceneShot shot,
    String imagePath,
    String workDir,
    int sceneIndex,
    int shotIndex,
    String? provider,
    bool useV3,
    QualityTier tier,
    EpisodeScript script,
  ) async {
    try {
      final imageFile = File(imagePath);
      if (!await imageFile.exists()) return null;
      final imageBase64 = base64Encode(await imageFile.readAsBytes());

      // Use AnimateDiff V3 with optional ControlNet for standard/cinematic local
      if (useV3) {
        final frames = tier == QualityTier.draft ? 16 : 24;
        final videoPrompt = _buildVideoPrompt(shot, script.scenes[sceneIndex]);

        // Try ControlNet hybrid pipeline first (keyframe → lineart → ControlNet+AnimateDiff)
        if (tier != QualityTier.draft) {
          try {
            final cnResult = await mediaCreation.executeTask('media_local_controlnet_video', {
              'reference_image_base64': imageBase64,
              'prompt': videoPrompt,
              'negative_prompt': negativePromptForShot(shot.shotType),
              'control_type': 'lineart_anime',
              'camera_motion': shot.cameraMotion,
              'controlnet_conditioning_scale': _scaleForShotType(shot.shotType),
              'frames': frames,
              'width': 512,
              'height': 512,
              'steps': 25,
            });

            if (cnResult['success'] == true && cnResult['video_base64'] != null) {
              final videoPath = '$workDir/scene_${sceneIndex}_shot_${shotIndex}_clip.mp4';
              await File(videoPath).writeAsBytes(base64Decode(cnResult['video_base64'] as String));
              print('[EpisodeGenerator] ControlNet+V3 video success: scene $sceneIndex shot $shotIndex');
              return videoPath;
            }
            print('[EpisodeGenerator] ControlNet video failed, falling back to plain V3');
          } catch (e) {
            print('[EpisodeGenerator] ControlNet not available ($e), using plain V3');
          }
        }

        // Fallback: AnimateDiff V3 without ControlNet
        final result = await mediaCreation.executeTask('media_local_generate_video_v3', {
          'prompt': videoPrompt,
          'negative_prompt': negativePromptForShot(shot.shotType),
          'camera_motion': shot.cameraMotion,
          'frames': frames,
          'width': 512,
          'height': 512,
          'steps': 25,
        });

        if (result['success'] == true && result['video_base64'] != null) {
          final videoPath = '$workDir/scene_${sceneIndex}_shot_${shotIndex}_clip.mp4';
          await File(videoPath).writeAsBytes(base64Decode(result['video_base64'] as String));
          print('[EpisodeGenerator] V3 video success: scene $sceneIndex shot $shotIndex (${shot.cameraMotion})');
          return videoPath;
        }
      }

      // Use cloud provider or legacy local AnimateDiff
      if (provider != null && provider != 'none' && provider.isNotEmpty) {
        final String taskType;
        final Map<String, dynamic> taskData;

        if (provider == 'local') {
          taskType = 'media_local_generate_video';
          taskData = {
            'image_base64': imageBase64,
            'prompt': shot.visualDescription,
            'model': 'animatediff',
            'frames': 16,
          };
        } else {
          taskType = 'media_ai_generate_video';
          taskData = {
            'image_base64': imageBase64,
            'custom_prompt': shot.visualDescription,
            'style': 'cinematic',
            'duration': shot.durationSeconds,
            'provider': provider,
          };
        }

        final result = await mediaCreation.executeTask(taskType, taskData);
        if (result['success'] == true && result['video_base64'] != null) {
          final videoPath = '$workDir/scene_${sceneIndex}_shot_${shotIndex}_clip.mp4';
          await File(videoPath).writeAsBytes(base64Decode(result['video_base64'] as String));
          return videoPath;
        }
      }

      // Fallback: Ken Burns animation from keyframe
      return await _createKenBurnsForShot(
        mediaCreation, imagePath, shot, workDir, sceneIndex, shotIndex);
    } catch (e) {
      print('[EpisodeGenerator] Shot video failed (scene $sceneIndex, shot $shotIndex): $e');
      // Last resort: Ken Burns
      try {
        return await _createKenBurnsForShot(
          mediaCreation, imagePath, shot, workDir, sceneIndex, shotIndex);
      } catch (_) {}
    }
    return null;
  }

  /// Generate a scene-level video (backward compat for scenes without shots).
  Future<String?> _generateSceneVideo(
    TaskDomain mediaCreation,
    String imagePath,
    EpisodeScene scene,
    String workDir,
    int index,
    String? provider,
    bool useV3,
    QualityTier tier,
  ) async {
    try {
      final imageFile = File(imagePath);
      if (!await imageFile.exists()) return null;
      final imageBase64 = base64Encode(await imageFile.readAsBytes());

      if (provider == 'none' || provider == null || provider.isEmpty) {
        return await _createKenBurnsVideo(
          mediaCreation, imagePath, scene, workDir, index);
      }

      final String taskType;
      final Map<String, dynamic> taskData;
      if (provider == 'local') {
        taskType = 'media_local_generate_video';
        taskData = {
          'image_base64': imageBase64,
          'prompt': scene.visualDescription,
          'model': 'animatediff',
          'frames': 16,
        };
      } else {
        taskType = 'media_ai_generate_video';
        taskData = {
          'image_base64': imageBase64,
          'custom_prompt': scene.visualDescription,
          'style': 'cinematic',
          'duration': scene.videoDurationSeconds,
          'provider': provider,
        };
      }

      final result = await mediaCreation.executeTask(taskType, taskData);
      if (result['success'] == true && result['video_base64'] != null) {
        final videoPath = '$workDir/scene_${index}_clip.mp4';
        await File(videoPath).writeAsBytes(base64Decode(result['video_base64'] as String));
        scene.generatedVideoPath = videoPath;
        return videoPath;
      }

      // Fallback
      return await _createKenBurnsVideo(mediaCreation, imagePath, scene, workDir, index);
    } catch (e) {
      print('[EpisodeGenerator] Scene video failed for scene $index: $e');
      try {
        return await _createKenBurnsVideo(mediaCreation, imagePath, scene, workDir, index);
      } catch (_) {}
    }
    return null;
  }

  Future<String?> _createKenBurnsForShot(
    TaskDomain mediaCreation,
    String imagePath,
    SceneShot shot,
    String workDir,
    int sceneIndex,
    int shotIndex,
  ) async {
    try {
      final imageFile = File(imagePath);
      if (!await imageFile.exists()) return null;
      final imageBase64 = base64Encode(await imageFile.readAsBytes());

      // Map camera motion to Ken Burns effect
      final effect = switch (shot.cameraMotion) {
        'zoom_in' => 'zoom_in',
        'zoom_out' => 'zoom_out',
        'pan_left' => 'pan_left',
        'pan_right' => 'pan_right',
        'tilt_up' => 'zoom_in',
        'tilt_down' => 'zoom_out',
        _ => 'ken_burns',
      };

      final result = await mediaCreation.executeTask('media_animate_photo', {
        'image_base64': imageBase64,
        'effect': effect,
        'duration': shot.durationSeconds,
        'aspect_ratio': '16:9',
      });

      if (result['success'] == true && result['video_base64'] != null) {
        final videoPath = '$workDir/scene_${sceneIndex}_shot_${shotIndex}_clip.mp4';
        await File(videoPath).writeAsBytes(base64Decode(result['video_base64'] as String));
        return videoPath;
      }
    } catch (e) {
      print('[EpisodeGenerator] Ken Burns failed for shot (scene $sceneIndex, shot $shotIndex): $e');
    }
    return null;
  }

  Future<String?> _createKenBurnsVideo(
    TaskDomain mediaCreation,
    String imagePath,
    EpisodeScene scene,
    String workDir,
    int index,
  ) async {
    try {
      final imageFile = File(imagePath);
      if (!await imageFile.exists()) return null;
      final imageBase64 = base64Encode(await imageFile.readAsBytes());

      final effects = ['ken_burns', 'zoom_in', 'pan_left', 'zoom_out', 'pan_right'];
      final effect = effects[index % effects.length];

      final result = await mediaCreation.executeTask('media_animate_photo', {
        'image_base64': imageBase64,
        'effect': effect,
        'duration': scene.videoDurationSeconds,
        'aspect_ratio': '16:9',
      });

      if (result['success'] == true && result['video_base64'] != null) {
        final videoPath = '$workDir/scene_${index}_clip.mp4';
        await File(videoPath).writeAsBytes(base64Decode(result['video_base64'] as String));
        scene.generatedVideoPath = videoPath;
        return videoPath;
      }
    } catch (e) {
      print('[EpisodeGenerator] Ken Burns fallback failed for scene $index: $e');
    }
    return null;
  }

  // ═══════════════════════════════════════════════════════════════════
  // Phase 4: Post-Processing
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _postProcessShots(
    EpisodeScript script,
    String workDir,
    QualityTier tier,
    EpisodeProgressCallback? onProgress,
    int totalShots, {
    String? lutPath,
  }) async {
    if (_postProcessor == null) return;

    int shotsDone = 0;
    for (int si = 0; si < script.scenes.length; si++) {
      final scene = script.scenes[si];

      if (scene.shots.isEmpty && scene.generatedVideoPath != null) {
        final processed = await _postProcessor!.processShot(
          videoPath: scene.generatedVideoPath!,
          workDir: workDir,
          shotId: 'scene_$si',
          tier: tier,
          lutFile: lutPath,
        );
        scene.generatedVideoPath = processed;
        shotsDone++;
      } else {
        for (int ji = 0; ji < scene.shots.length; ji++) {
          final shot = scene.shots[ji];
          if (shot.generatedVideoPath == null) { shotsDone++; continue; }

          final processed = await _postProcessor!.processShot(
            videoPath: shot.generatedVideoPath!,
            workDir: workDir,
            shotId: 'scene_${si}_shot_$ji',
            tier: tier,
            lutFile: lutPath,
          );
          shot.generatedVideoPath = processed;
          shotsDone++;
        }
      }

      final progress = 0.45 + (shotsDone / totalShots) * 0.15;
      await onProgress?.call(progress, 'post_processing',
          'Post-processed $shotsDone/$totalShots shots');
    }
  }

  // ═══════════════════════════════════════════════════════════════════
  // Phase 5: Shot Assembly (concat shots within each scene)
  // ═══════════════════════════════════════════════════════════════════

  Future<List<String?>> _assembleShots(
    EpisodeScript script,
    String workDir,
    EpisodeProgressCallback? onProgress,
  ) async {
    final results = <String?>[];

    for (int si = 0; si < script.scenes.length; si++) {
      final scene = script.scenes[si];

      // If no multi-shot, use scene-level video
      if (scene.shots.isEmpty) {
        results.add(scene.generatedVideoPath);
        continue;
      }

      final shotVideos = scene.shots
          .map((s) => s.generatedVideoPath)
          .whereType<String>()
          .toList();

      if (shotVideos.isEmpty) {
        results.add(scene.generatedVideoPath); // Fallback
        continue;
      }

      if (shotVideos.length == 1) {
        results.add(shotVideos.first);
        continue;
      }

      // Concat shots with jump cuts (no transition between shots)
      try {
        final sceneVideoPath = '$workDir/scene_${si}_shots_assembled.mp4';
        await ffmpegComposer.concatVideos(
          videoPaths: shotVideos,
          outputPath: sceneVideoPath,
        );
        results.add(sceneVideoPath);
        scene.generatedVideoPath = sceneVideoPath;
        print('[EpisodeGenerator] Assembled ${shotVideos.length} shots for scene $si');
      } catch (e) {
        print('[EpisodeGenerator] Shot assembly failed for scene $si: $e');
        results.add(shotVideos.first); // Use first shot as fallback
      }

      final progress = 0.60 + ((si + 1) / script.scenes.length) * 0.05;
      await onProgress?.call(progress, 'shot_assembly',
          'Assembled shots for scene ${si + 1}/${script.scenes.length}');
    }

    return results;
  }

  // ═══════════════════════════════════════════════════════════════════
  // Phase 6: TTS Dialogue
  // ═══════════════════════════════════════════════════════════════════

  Future<List<String?>> _generateTTS(
    EpisodeScript script,
    String workDir,
    EpisodeProgressCallback? onProgress,
  ) async {
    final ttsProvider = ttsRegistry.defaultProvider;
    final results = List<String?>.filled(script.scenes.length, null);

    final futures = <Future<void>>[];
    for (int i = 0; i < script.scenes.length; i++) {
      futures.add(() async {
        final scene = script.scenes[i];
        if (scene.dialogue.isEmpty) return;

        final audioParts = <String>[];

        for (int j = 0; j < scene.dialogue.length; j++) {
          final line = scene.dialogue[j];
          final character = script.characters
              .where((c) => c.id == line.characterId)
              .firstOrNull;
          final voice = line.voice ?? character?.defaultVoice ?? 'zh-CN-XiaoxiaoNeural';

          final result = await ttsProvider.synthesize(
            text: line.text,
            voice: voice,
            rate: line.rate,
          );

          if (result.success && result.filePath != null) {
            audioParts.add(result.filePath!);
          }
        }

        if (audioParts.isNotEmpty) {
          final scenAudioPath = '$workDir/scene_${i}_voice.mp3';
          await ffmpegComposer.concatAudio(
            audioPaths: audioParts,
            outputPath: scenAudioPath,
          );
          scene.generatedAudioPath = scenAudioPath;
          results[i] = scenAudioPath;
        }
      }());
    }

    await Future.wait(futures);
    return results;
  }

  // ═══════════════════════════════════════════════════════════════════
  // Phase 7: Subtitles
  // ═══════════════════════════════════════════════════════════════════

  Future<List<String?>> _generateSubtitles(
    EpisodeScript script,
    String workDir,
  ) async {
    final results = <String?>[];

    for (int i = 0; i < script.scenes.length; i++) {
      final scene = script.scenes[i];
      if (scene.dialogue.isEmpty) {
        results.add(null);
        continue;
      }

      final assPath = '$workDir/scene_${i}_subs.ass';
      await subtitleGenerator.generateForScene(
        scene: scene,
        characters: script.characters,
        outputPath: assPath,
      );
      results.add(assPath);
    }

    return results;
  }

  // ═══════════════════════════════════════════════════════════════════
  // Phase 8: Audio Mix
  // ═══════════════════════════════════════════════════════════════════

  Future<List<String?>> _mixAudio(
    EpisodeScript script,
    List<String?> voicePaths,
    String workDir,
    EpisodeProgressCallback? onProgress,
  ) async {
    final results = List<String?>.from(voicePaths);

    final futures = <Future<void>>[];
    for (int i = 0; i < script.scenes.length; i++) {
      final voicePath = voicePaths[i];
      final scene = script.scenes[i];

      if (voicePath == null || scene.bgmTrack == null) continue;

      futures.add(() async {
        final bgmFile = File(scene.bgmTrack!);
        if (!await bgmFile.exists()) return;

        final mixedPath = '$workDir/scene_${i}_mixed.mp3';
        try {
          await ffmpegComposer.mixAudio(
            voicePath: voicePath,
            bgmPath: scene.bgmTrack!,
            outputPath: mixedPath,
            bgmVolume: scene.bgmVolume,
          );
          results[i] = mixedPath;
        } catch (e) {
          print('[EpisodeGenerator] Audio mix failed for scene $i: $e');
        }
      }());
    }

    await Future.wait(futures);
    return results;
  }

  // ═══════════════════════════════════════════════════════════════════
  // Phase 9: Scene Assembly
  // ═══════════════════════════════════════════════════════════════════

  Future<List<String?>> _assembleScenes(
    EpisodeScript script,
    List<String?> videoPaths,
    List<String?> audioPaths,
    List<String?> assPaths,
    String workDir,
    EpisodeProgressCallback? onProgress,
  ) async {
    final results = <String?>[];

    for (int i = 0; i < script.scenes.length; i++) {
      final videoPath = videoPaths[i];
      final audioPath = audioPaths[i];
      final assPath = assPaths[i];

      if (videoPath == null) {
        results.add(null);
        continue;
      }

      try {
        final assembledPath = '$workDir/scene_${i}_assembled.mp4';

        if (audioPath != null) {
          await ffmpegComposer.assembleEpisode(
            videoPath: videoPath,
            audioPath: audioPath,
            assSubtitlePath: assPath,
            outputPath: assembledPath,
          );
        } else if (assPath != null) {
          await ffmpegComposer.addSubtitles(
            videoPath: videoPath,
            assPath: assPath,
            outputPath: assembledPath,
          );
        } else {
          await File(videoPath).copy(assembledPath);
        }

        results.add(assembledPath);
        final progress = 0.82 + ((i + 1) / script.scenes.length) * 0.10;
        await onProgress?.call(progress, 'scene_assembly',
            'Assembled scene ${i + 1}/${script.scenes.length}');
      } catch (e) {
        print('[EpisodeGenerator] Scene assembly failed for scene $i: $e');
        results.add(videoPath);
      }
    }

    return results;
  }

  // ═══════════════════════════════════════════════════════════════════
  // Phase 10: Final Assembly
  // ═══════════════════════════════════════════════════════════════════

  Future<String> _assembleEpisode(
    EpisodeScript script,
    List<String?> scenePaths,
    String workDir,
  ) async {
    final validPaths = scenePaths.whereType<String>().toList();
    if (validPaths.isEmpty) {
      throw Exception('No assembled scenes to concatenate');
    }

    final outputPath = '$workDir/${script.id}_final.mp4';

    if (validPaths.length == 1) {
      await File(validPaths.first).copy(outputPath);
      return outputPath;
    }

    final hasTransitions = script.scenes.any((s) => s.transition != 'cut');

    if (hasTransitions && validPaths.length > 1) {
      var currentPath = validPaths.first;
      for (int i = 1; i < validPaths.length; i++) {
        final transitionType = script.scenes[i].transition;
        final tempPath = '$workDir/transition_temp_$i.mp4';

        if (transitionType == 'cut') {
          await ffmpegComposer.concatVideos(
            videoPaths: [currentPath, validPaths[i]],
            outputPath: tempPath,
          );
        } else {
          try {
            await ffmpegComposer.applyTransition(
              clipAPath: currentPath,
              clipBPath: validPaths[i],
              outputPath: tempPath,
              transition: transitionType,
              durationSeconds: 0.5,
            );
          } catch (_) {
            await ffmpegComposer.concatVideos(
              videoPaths: [currentPath, validPaths[i]],
              outputPath: tempPath,
            );
          }
        }

        if (currentPath.contains('transition_temp_')) {
          try { await File(currentPath).delete(); } catch (_) {}
        }
        currentPath = tempPath;
      }

      await File(currentPath).rename(outputPath);
    } else {
      await ffmpegComposer.concatVideos(
        videoPaths: validPaths,
        outputPath: outputPath,
      );
    }

    return outputPath;
  }

  // ═══════════════════════════════════════════════════════════════════
  // ControlNet Adaptive Parameters
  // ═══════════════════════════════════════════════════════════════════

  /// ControlNet conditioning scale adapted per shot type.
  /// Higher = more faithful to reference, lower = more creative freedom.
  double _scaleForShotType(String shotType) => switch (shotType) {
    'close_up' => 0.9,       // High: face consistency matters most
    'medium' => 0.7,         // Medium: allow some creative freedom
    'establishing' => 0.5,   // Low: scenery can be more creative
    'over_shoulder' => 0.8,  // High: two-person composition needs control
    _ => 0.7,
  };

  // ═══════════════════════════════════════════════════════════════════
  // Utilities
  // ═══════════════════════════════════════════════════════════════════

  Future<void> _resizeImage(
      String inputPath, String outputPath, int width, int height) async {
    final result = await Process.run('ffmpeg', [
      '-y',
      '-i', inputPath,
      '-vf',
      'scale=$width:$height:force_original_aspect_ratio=increase:flags=lanczos,crop=$width:$height',
      '-frames:v', '1',
      '-update', '1',
      outputPath,
    ]).timeout(const Duration(seconds: 30));

    if (result.exitCode != 0) {
      await File(inputPath).copy(outputPath);
    }
  }
}
