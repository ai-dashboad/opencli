import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:yaml/yaml.dart';
import '../domain.dart';
import 'providers/video_provider.dart';
import 'providers/provider_registry.dart';
import 'prompt_builder.dart';

class MediaCreationDomain extends TaskDomain {
  @override
  String get id => 'media_creation';
  @override
  String get name => 'Media Creation';
  @override
  String get description =>
      'Create animated videos from photos using effects like Ken Burns zoom/pan';
  @override
  String get icon => 'movie_creation';
  @override
  int get colorHex => 0xFF7C4DFF;

  String? _ffmpegPath;
  final VideoProviderRegistry _providerRegistry = VideoProviderRegistry();

  @override
  List<String> get taskTypes => [
        'media_animate_photo',
        'media_create_slideshow',
        'media_ai_generate_video',
      ];

  @override
  List<DomainIntentPattern> get intentPatterns => [
        DomainIntentPattern(
          pattern: RegExp(
            r'^(?:animate|create\s+(?:a\s+)?(?:video|animation)\s+(?:from|of|with))\s+(?:this\s+)?(?:photo|picture|image)$',
            caseSensitive: false,
          ),
          taskType: 'media_animate_photo',
          extractData: (_) => {'effect': 'ken_burns'},
        ),
        DomainIntentPattern(
          pattern: RegExp(
            r'^(?:make|create)\s+(?:an?\s+)?(?:ad|advertisement|promo(?:tional)?(?:\s+video)?)\s+(?:from|with|of)\s+(?:this\s+)?(?:photo|picture|image)$',
            caseSensitive: false,
          ),
          taskType: 'media_animate_photo',
          extractData: (_) =>
              {'effect': 'ken_burns', 'style': 'ad', 'duration': 8},
        ),
        DomainIntentPattern(
          pattern: RegExp(
            r'^(?:create|make)\s+(?:a\s+)?(?:video\s+)?slideshow(?:\s+(?:from|with)\s+(?:these\s+)?(?:photos|images|pictures))?$',
            caseSensitive: false,
          ),
          taskType: 'media_create_slideshow',
          extractData: (_) => {'transition': 'fade'},
        ),
        DomainIntentPattern(
          pattern: RegExp(
            r'^(?:animate|create\s+(?:a\s+)?(?:video|animation)\s+(?:from|of|with))\s+(?:this\s+)?(?:photo|picture|image)\s+(?:with\s+)?(\w+)(?:\s+effect)?$',
            caseSensitive: false,
          ),
          taskType: 'media_animate_photo',
          extractData: (m) =>
              {'effect': m.group(1)?.toLowerCase() ?? 'ken_burns'},
        ),
        // AI video generation patterns
        DomainIntentPattern(
          pattern: RegExp(
            r'^(?:generate|create)\s+(?:an?\s+)?(?:ai|cinematic|professional)\s+video\s+(?:from|of|with)\s+(?:this\s+)?(?:photo|picture|image)$',
            caseSensitive: false,
          ),
          taskType: 'media_ai_generate_video',
          extractData: (_) => {'style': 'cinematic'},
        ),
        DomainIntentPattern(
          pattern: RegExp(
            r'^(?:make|create)\s+(?:an?\s+)?(?:tiktok|social\s+media|ad|commercial)\s+video\s+(?:from|with|of)\s+(?:this\s+)?(?:photo|picture|image)$',
            caseSensitive: false,
          ),
          taskType: 'media_ai_generate_video',
          extractData: (_) => {'style': 'adPromo'},
        ),
      ];

  @override
  List<DomainOllamaIntent> get ollamaIntents => [
        DomainOllamaIntent(
          intentName: 'media_animate_photo',
          description:
              'Create an animated video from a single photo using effects like Ken Burns zoom/pan, zoom in/out, pan left/right, pulse',
          parameters: {
            'effect':
                'animation effect: ken_burns, zoom_in, zoom_out, pan_left, pan_right, pulse (default: ken_burns)',
            'duration': 'video duration in seconds (default: 5)',
          },
          examples: [
            OllamaExample(
              input: 'animate this photo',
              intentJson:
                  '{"intent": "media_animate_photo", "confidence": 0.95, "parameters": {"effect": "ken_burns", "duration": 5}}',
            ),
            OllamaExample(
              input: 'make an ad from this picture',
              intentJson:
                  '{"intent": "media_animate_photo", "confidence": 0.90, "parameters": {"effect": "ken_burns", "duration": 8, "style": "ad"}}',
            ),
            OllamaExample(
              input: 'create video from photo with zoom effect',
              intentJson:
                  '{"intent": "media_animate_photo", "confidence": 0.95, "parameters": {"effect": "zoom_in", "duration": 5}}',
            ),
          ],
        ),
        DomainOllamaIntent(
          intentName: 'media_create_slideshow',
          description:
              'Create a slideshow video from multiple photos with transitions',
          parameters: {
            'transition': 'transition type: fade, slide, zoom (default: fade)',
            'duration_per_image': 'seconds per image (default: 3)',
          },
          examples: [
            OllamaExample(
              input: 'create slideshow from photos',
              intentJson:
                  '{"intent": "media_create_slideshow", "confidence": 0.95, "parameters": {"transition": "fade", "duration_per_image": 3}}',
            ),
          ],
        ),
        DomainOllamaIntent(
          intentName: 'media_ai_generate_video',
          description:
              'Generate a cinematic AI video from a photo using cloud AI services (Replicate, Runway, Kling, Luma)',
          parameters: {
            'provider':
                'AI provider: replicate, runway, kling, luma (default: auto-select first configured)',
            'style':
                'style preset: cinematic, adPromo, socialMedia, calmAesthetic, epic, mysterious (default: cinematic)',
            'custom_prompt':
                'optional custom cinematic prompt (overrides style preset)',
            'duration': 'video duration in seconds (default: 5)',
          },
          examples: [
            OllamaExample(
              input: 'generate AI video from this photo',
              intentJson:
                  '{"intent": "media_ai_generate_video", "confidence": 0.95, "parameters": {"style": "cinematic"}}',
            ),
            OllamaExample(
              input: 'create a TikTok ad video from this picture',
              intentJson:
                  '{"intent": "media_ai_generate_video", "confidence": 0.90, "parameters": {"style": "adPromo"}}',
            ),
            OllamaExample(
              input: 'make a cinematic video with Runway',
              intentJson:
                  '{"intent": "media_ai_generate_video", "confidence": 0.95, "parameters": {"provider": "runway", "style": "cinematic"}}',
            ),
          ],
        ),
      ];

  @override
  Map<String, DomainDisplayConfig> get displayConfigs => {
        'media_animate_photo': const DomainDisplayConfig(
          cardType: 'media_creation',
          titleTemplate: 'Photo Animation',
          subtitleTemplate: 'Effect: \${effect}',
          icon: 'movie_creation',
          colorHex: 0xFF7C4DFF,
        ),
        'media_create_slideshow': const DomainDisplayConfig(
          cardType: 'media_creation',
          titleTemplate: 'Slideshow',
          icon: 'slideshow',
          colorHex: 0xFF7C4DFF,
        ),
        'media_ai_generate_video': const DomainDisplayConfig(
          cardType: 'media_creation',
          titleTemplate: 'AI Video',
          subtitleTemplate: '\${style} via \${provider}',
          icon: 'auto_awesome',
          colorHex: 0xFF7C4DFF,
        ),
      };

  @override
  Future<void> initialize() async {
    final result = await Process.run('which', ['ffmpeg']);
    if (result.exitCode != 0) {
      print(
          '[MediaCreationDomain] Warning: FFmpeg not found. Install via: brew install ffmpeg');
    } else {
      _ffmpegPath = (result.stdout as String).trim();
      print('[MediaCreationDomain] FFmpeg found at: $_ffmpegPath');
    }

    // Load AI video provider config from ~/.opencli/config.yaml
    try {
      final home = Platform.environment['HOME'] ?? '/tmp';
      final configFile = File('$home/.opencli/config.yaml');
      if (await configFile.exists()) {
        final content = await configFile.readAsString();
        final yaml = loadYaml(content);
        if (yaml is YamlMap) {
          final aiVideo = yaml['ai_video'];
          if (aiVideo is YamlMap) {
            final config = _yamlToMap(aiVideo);
            _providerRegistry.configureFromConfig(config);
            final configured = _providerRegistry.configuredProviders;
            if (configured.isNotEmpty) {
              print('[MediaCreationDomain] AI video providers configured: '
                  '${configured.map((p) => p.displayName).join(', ')}');
            }
          }
        }
      }
    } catch (e) {
      print('[MediaCreationDomain] Could not load AI video config: $e');
    }
  }

  /// Convert YamlMap to regular Map recursively.
  Map<String, dynamic> _yamlToMap(YamlMap yaml) {
    final map = <String, dynamic>{};
    for (final entry in yaml.entries) {
      final key = entry.key.toString();
      final value = entry.value;
      if (value is YamlMap) {
        map[key] = _yamlToMap(value);
      } else if (value is YamlList) {
        map[key] = value.toList();
      } else {
        // Resolve env vars like ${REPLICATE_API_TOKEN}
        if (value is String && value.startsWith(r'${') && value.endsWith('}')) {
          final envVar = value.substring(2, value.length - 1);
          map[key] = Platform.environment[envVar] ?? value;
        } else {
          map[key] = value;
        }
      }
    }
    return map;
  }

  @override
  Future<Map<String, dynamic>> executeTask(
    String taskType,
    Map<String, dynamic> taskData,
  ) async {
    switch (taskType) {
      case 'media_animate_photo':
        return _animatePhoto(taskData);
      case 'media_create_slideshow':
        return _createSlideshow(taskData);
      case 'media_ai_generate_video':
        return _aiGenerateVideo(taskData);
      default:
        return {
          'success': false,
          'error': 'Unknown media task: $taskType',
          'domain': 'media_creation',
        };
    }
  }

  @override
  Future<Map<String, dynamic>> executeTaskWithProgress(
    String taskType,
    Map<String, dynamic> taskData, {
    ProgressCallback? onProgress,
  }) async {
    if (taskType == 'media_ai_generate_video') {
      return _aiGenerateVideo(taskData, onProgress: onProgress);
    }
    return executeTask(taskType, taskData);
  }

  /// Generate video using a cloud AI provider with progress reporting.
  Future<Map<String, dynamic>> _aiGenerateVideo(
    Map<String, dynamic> data, {
    ProgressCallback? onProgress,
  }) async {
    final imageBase64 = data['image_base64'] as String?;
    if (imageBase64 == null || imageBase64.isEmpty) {
      return {
        'success': false,
        'error': 'No image provided. Please attach a photo first.',
        'domain': 'media_creation',
        'card_type': 'media_creation',
      };
    }

    // Select provider
    final providerId = data['provider'] as String?;
    final configured = _providerRegistry.configuredProviders;

    if (configured.isEmpty) {
      return {
        'success': false,
        'error': 'No AI video providers configured. '
            'Add API keys to ~/.opencli/config.yaml under ai_video.api_keys',
        'domain': 'media_creation',
        'card_type': 'media_creation',
      };
    }

    final provider = providerId != null
        ? _providerRegistry.get(providerId)
        : configured.first;

    if (provider == null || !provider.isConfigured) {
      return {
        'success': false,
        'error': 'Provider "${providerId ?? "unknown"}" is not configured. '
            'Available: ${configured.map((p) => p.id).join(", ")}',
        'domain': 'media_creation',
        'card_type': 'media_creation',
      };
    }

    // Build prompt — route by scenario, mode, or default
    final customPrompt = data['custom_prompt'] as String?;
    final styleName = data['style'] as String? ?? 'cinematic';
    final modeName = data['mode'] as String?;
    final scenario = data['scenario'] as String?;
    final String prompt;

    if (customPrompt != null && customPrompt.isNotEmpty) {
      prompt = customPrompt;
    } else if (scenario == 'product') {
      prompt = PromptBuilder.buildProductPromoPrompt(
        productName: data['product_name'] as String? ?? 'Product',
        productDescription: data['custom_prompt'] as String?,
        aspectRatio: data['aspect_ratio'] as String? ?? '16:9',
        durationSeconds: (data['duration'] as num?)?.toInt() ?? 15,
        style: styleName,
      );
      print(
          '[MediaCreationDomain] Product promo prompt (${prompt.length} chars)');
    } else if (scenario == 'portrait') {
      prompt = PromptBuilder.buildPortraitEffectPrompt(
        effect: data['effect'] as String? ?? 'cinematic_zoom',
        aspectRatio: data['aspect_ratio'] as String? ?? '9:16',
        durationSeconds: (data['duration'] as num?)?.toInt() ?? 10,
      );
      print(
          '[MediaCreationDomain] Portrait effect prompt (${prompt.length} chars)');
    } else if (scenario == 'novel') {
      prompt = PromptBuilder.buildNovelToAnimePrompt(
        novelText: data['input_text'] as String? ?? '',
        animeStyle: styleName,
        durationSeconds: (data['duration'] as num?)?.toInt() ?? 30,
      );
      print(
          '[MediaCreationDomain] Novel-to-anime prompt (${prompt.length} chars)');
    } else if (modeName == 'production') {
      final preset = PromptBuilder.parseStyle(styleName);
      prompt = PromptBuilder.buildProductionPrompt(
        inputText: data['input_text'] as String? ?? 'A cinematic scene',
        hasImage: imageBase64.isNotEmpty,
        durationSeconds: (data['duration'] as num?)?.toInt() ?? 5,
        aspectRatio: data['aspect_ratio'] as String? ?? '16:9',
        style: preset,
      );
      print(
          '[MediaCreationDomain] Production prompt generated (${prompt.length} chars)');
    } else {
      final preset = PromptBuilder.parseStyle(styleName);
      prompt = PromptBuilder.buildFromPreset(
        preset,
        userHint: data['user_hint'] as String?,
        subjectDescription: data['subject'] as String?,
      );
    }

    final duration = (data['duration'] as num?)?.toInt() ?? 5;

    // Adapt prompt for the specific provider's API requirements
    final adaptedParams = PromptBuilder.adaptForProvider(
      provider.id,
      prompt,
      durationSeconds: duration,
      aspectRatio: data['aspect_ratio'] as String?,
    );
    final adaptedPrompt = adaptedParams['prompt'] as String? ?? prompt;

    onProgress?.call({
      'progress': 0.05,
      'status_message': 'Submitting to ${provider.displayName}...',
      'provider': provider.id,
      'style': styleName,
      'generation_type': 'ai',
    });

    try {
      // Submit job
      final submission = await provider.submitJob(
        imageBase64: imageBase64,
        prompt: adaptedPrompt,
        durationSeconds: duration,
        extraParams: {
          ...adaptedParams..remove('prompt'),
          ...data['extra_params'] as Map<String, dynamic>? ?? {},
        },
      );

      print(
          '[MediaCreationDomain] AI video job submitted: ${submission.jobId} via ${provider.displayName}');

      onProgress?.call({
        'progress': 0.10,
        'status_message': 'Job queued at ${provider.displayName}...',
        'job_id': submission.jobId,
        'provider': provider.id,
        'style': styleName,
        'generation_type': 'ai',
      });

      // Poll loop: every 5s for up to 6 minutes
      const pollInterval = Duration(seconds: 5);
      const maxWait = Duration(minutes: 6);
      final deadline = DateTime.now().add(maxWait);

      while (DateTime.now().isBefore(deadline)) {
        await Future.delayed(pollInterval);

        final status = await provider.pollJob(submission.jobId);

        switch (status.state) {
          case VideoJobState.completed:
            onProgress?.call({
              'progress': 0.90,
              'status_message': 'Downloading video...',
              'provider': provider.id,
              'style': styleName,
              'generation_type': 'ai',
            });

            // Download the video
            final videoBytes = await provider.downloadVideo(status.videoUrl!);
            final videoBase64 = base64Encode(videoBytes);
            final sizeMB = (videoBytes.length / 1024 / 1024).toStringAsFixed(1);

            return {
              'success': true,
              'video_base64': videoBase64,
              'provider': provider.id,
              'provider_name': provider.displayName,
              'style': styleName,
              'prompt': prompt,
              'duration': duration,
              'size_bytes': videoBytes.length,
              'generation_type': 'ai',
              'message':
                  'AI video generated via ${provider.displayName} ($sizeMB MB)',
              'domain': 'media_creation',
              'card_type': 'media_creation',
            };

          case VideoJobState.failed:
            return {
              'success': false,
              'error': status.error ?? 'AI video generation failed',
              'provider': provider.id,
              'generation_type': 'ai',
              'domain': 'media_creation',
              'card_type': 'media_creation',
            };

          case VideoJobState.processing:
          case VideoJobState.queued:
            onProgress?.call({
              'progress': status.progress ?? 0.2,
              'status_message': status.statusMessage ?? 'Generating...',
              'provider': provider.id,
              'style': styleName,
              'generation_type': 'ai',
            });
        }
      }

      // Timed out
      return {
        'success': false,
        'error': 'AI video generation timed out after 6 minutes',
        'provider': provider.id,
        'generation_type': 'ai',
        'domain': 'media_creation',
        'card_type': 'media_creation',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'AI video generation error: $e',
        'provider': provider.id,
        'generation_type': 'ai',
        'domain': 'media_creation',
        'card_type': 'media_creation',
      };
    }
  }

  Future<Map<String, dynamic>> _animatePhoto(Map<String, dynamic> data) async {
    // Check FFmpeg
    if (_ffmpegPath == null) {
      final check = await Process.run('which', ['ffmpeg']);
      if (check.exitCode != 0) {
        return {
          'success': false,
          'error': 'FFmpeg not installed. Install via: brew install ffmpeg',
          'domain': 'media_creation',
          'card_type': 'media_creation',
        };
      }
      _ffmpegPath = (check.stdout as String).trim();
    }

    // Validate image input
    final imageBase64 = data['image_base64'] as String?;
    if (imageBase64 == null || imageBase64.isEmpty) {
      return {
        'success': false,
        'error':
            'No image provided. Please attach a photo first, then type "animate this photo".',
        'domain': 'media_creation',
        'card_type': 'media_creation',
      };
    }

    final effect = data['effect'] as String? ?? 'ken_burns';
    final duration = (data['duration'] as num?)?.toInt() ?? 5;
    final aspectRatio = data['aspect_ratio'] as String? ?? '16:9';
    final (outW, outH) = _resolutionForAspect(aspectRatio);
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    final home = Platform.environment['HOME'] ?? '/tmp';
    final tempDir = '$home/.opencli/media_temp';
    await Directory(tempDir).create(recursive: true);

    final inputPath = '$tempDir/input_$timestamp.jpg';
    final outputPath = '$tempDir/output_$timestamp.mp4';

    try {
      // Write image to temp file
      final imageBytes = base64Decode(imageBase64);
      await File(inputPath).writeAsBytes(imageBytes);

      // Build FFmpeg filter — always pre-scale to output resolution before zoompan
      // to avoid zoompan's extremely slow internal upscaling on small images
      final fps = 25;
      final totalFrames = duration * fps;
      final zoompanFilter =
          _buildZoompanFilter(effect, totalFrames, outW, outH);
      final filter =
          'scale=$outW:$outH:force_original_aspect_ratio=increase:flags=lanczos,crop=$outW:$outH,$zoompanFilter';

      // Run FFmpeg with production quality settings
      final result = await Process.run(_ffmpegPath!, [
        '-y',
        '-loop',
        '1',
        '-i',
        inputPath,
        '-vf',
        filter,
        '-t',
        '$duration',
        '-pix_fmt',
        'yuv420p',
        '-c:v',
        'libx264',
        '-preset',
        'medium',
        '-crf',
        '18',
        '-profile:v',
        'high',
        '-level',
        '4.2',
        '-movflags',
        '+faststart',
        outputPath,
      ]).timeout(const Duration(seconds: 120));

      if (result.exitCode != 0) {
        final stderr = (result.stderr as String).trim();
        // Extract last meaningful line from ffmpeg stderr
        final lines = stderr.split('\n').where((l) => l.isNotEmpty).toList();
        final errorLine =
            lines.isNotEmpty ? lines.last : 'Unknown FFmpeg error';
        return {
          'success': false,
          'error': 'FFmpeg processing failed: $errorLine',
          'domain': 'media_creation',
          'card_type': 'media_creation',
        };
      }

      // Read output and base64 encode
      final videoFile = File(outputPath);
      if (await videoFile.exists()) {
        final videoBytes = await videoFile.readAsBytes();
        final videoBase64 = base64Encode(videoBytes);
        final sizeMB = (videoBytes.length / 1024 / 1024).toStringAsFixed(1);

        return {
          'success': true,
          'video_base64': videoBase64,
          'video_path': outputPath,
          'effect': effect,
          'duration': duration,
          'size_bytes': videoBytes.length,
          'message': 'Created ${duration}s $effect animation ($sizeMB MB)',
          'domain': 'media_creation',
          'card_type': 'media_creation',
        };
      }

      return {
        'success': false,
        'error': 'Output video file was not created',
        'domain': 'media_creation',
        'card_type': 'media_creation',
      };
    } catch (e) {
      if (e is TimeoutException) {
        return {
          'success': false,
          'error': 'FFmpeg timed out after 120 seconds',
          'domain': 'media_creation',
          'card_type': 'media_creation',
        };
      }
      return {
        'success': false,
        'error': 'Error creating animation: $e',
        'domain': 'media_creation',
        'card_type': 'media_creation',
      };
    } finally {
      // Clean up input file
      try {
        await File(inputPath).delete();
      } catch (_) {}
    }
  }

  Future<Map<String, dynamic>> _createSlideshow(
      Map<String, dynamic> data) async {
    // Check FFmpeg
    if (_ffmpegPath == null) {
      final check = await Process.run('which', ['ffmpeg']);
      if (check.exitCode != 0) {
        return {
          'success': false,
          'error': 'FFmpeg not installed. Install via: brew install ffmpeg',
          'domain': 'media_creation',
          'card_type': 'media_creation',
        };
      }
      _ffmpegPath = (check.stdout as String).trim();
    }

    // Check for multiple images
    final imagesBase64 = data['images_base64'] as List?;
    final singleImage = data['image_base64'] as String?;

    if ((imagesBase64 == null || imagesBase64.isEmpty) &&
        (singleImage == null || singleImage.isEmpty)) {
      return {
        'success': false,
        'error': 'No images provided. Please attach photos first.',
        'domain': 'media_creation',
        'card_type': 'media_creation',
      };
    }

    // If only one image, use animate with ken_burns as fallback
    if (imagesBase64 == null || imagesBase64.length < 2) {
      final imageData = Map<String, dynamic>.from(data);
      imageData['image_base64'] = singleImage ?? imagesBase64?.first;
      imageData['effect'] = 'ken_burns';
      imageData['duration'] = 5;
      return _animatePhoto(imageData);
    }

    final transition = data['transition'] as String? ?? 'fade';
    final durationPerImage = (data['duration_per_image'] as num?)?.toInt() ?? 3;
    final aspectRatio = data['aspect_ratio'] as String? ?? '16:9';
    final (outW, outH) = _resolutionForAspect(aspectRatio);
    final timestamp = DateTime.now().millisecondsSinceEpoch;

    final home = Platform.environment['HOME'] ?? '/tmp';
    final tempDir = '$home/.opencli/media_temp';
    await Directory(tempDir).create(recursive: true);

    final inputPaths = <String>[];
    final outputPath = '$tempDir/slideshow_$timestamp.mp4';

    try {
      // Write all images to temp files
      for (int i = 0; i < imagesBase64.length; i++) {
        final path = '$tempDir/slide_${timestamp}_$i.jpg';
        final bytes = base64Decode(imagesBase64[i] as String);
        await File(path).writeAsBytes(bytes);
        inputPaths.add(path);
      }

      // Create concat file for FFmpeg
      final concatPath = '$tempDir/concat_$timestamp.txt';
      final concatContent = inputPaths
          .map((p) => "file '$p'\nduration $durationPerImage")
          .join('\n');
      await File(concatPath)
          .writeAsString('$concatContent\nfile \'${inputPaths.last}\'\n');

      // Total duration
      final totalDuration = imagesBase64.length * durationPerImage;

      // Run FFmpeg with concat demuxer (production quality)
      final result = await Process.run(_ffmpegPath!, [
        '-y',
        '-f',
        'concat',
        '-safe',
        '0',
        '-i',
        concatPath,
        '-vf',
        'scale=$outW:$outH:force_original_aspect_ratio=decrease,pad=$outW:$outH:(ow-iw)/2:(oh-ih)/2,fps=25',
        '-t',
        '$totalDuration',
        '-pix_fmt',
        'yuv420p',
        '-c:v',
        'libx264',
        '-preset',
        'medium',
        '-crf',
        '18',
        '-profile:v',
        'high',
        '-level',
        '4.2',
        '-movflags',
        '+faststart',
        outputPath,
      ]).timeout(const Duration(seconds: 120));

      if (result.exitCode != 0) {
        final stderr = (result.stderr as String).trim();
        final lines = stderr.split('\n').where((l) => l.isNotEmpty).toList();
        final errorLine = lines.isNotEmpty ? lines.last : 'Unknown error';
        return {
          'success': false,
          'error': 'Slideshow creation failed: $errorLine',
          'domain': 'media_creation',
          'card_type': 'media_creation',
        };
      }

      // Read output
      final videoFile = File(outputPath);
      if (await videoFile.exists()) {
        final videoBytes = await videoFile.readAsBytes();
        final videoBase64 = base64Encode(videoBytes);
        final sizeMB = (videoBytes.length / 1024 / 1024).toStringAsFixed(1);

        return {
          'success': true,
          'video_base64': videoBase64,
          'video_path': outputPath,
          'transition': transition,
          'image_count': imagesBase64.length,
          'duration': totalDuration,
          'size_bytes': videoBytes.length,
          'message':
              'Created slideshow with ${imagesBase64.length} images ($sizeMB MB)',
          'domain': 'media_creation',
          'card_type': 'media_creation',
        };
      }

      return {
        'success': false,
        'error': 'Slideshow output file was not created',
        'domain': 'media_creation',
        'card_type': 'media_creation',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Error creating slideshow: $e',
        'domain': 'media_creation',
        'card_type': 'media_creation',
      };
    } finally {
      // Clean up temp files
      for (final path in inputPaths) {
        try {
          await File(path).delete();
        } catch (_) {}
      }
      try {
        await File('$tempDir/concat_$timestamp.txt').delete();
      } catch (_) {}
    }
  }

  /// Map aspect ratio string to output resolution (1080p for all).
  (int, int) _resolutionForAspect(String ratio) => switch (ratio) {
        '9:16' => (1080, 1920),
        '1:1' => (1080, 1080),
        _ => (1920, 1080),
      };

  String _buildZoompanFilter(String effect, int totalFrames, int w, int h) {
    final s = '${w}x$h';
    switch (effect) {
      case 'zoom_in':
        return "zoompan=z='min(zoom+0.002,2.0)':d=$totalFrames:x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':s=$s:fps=25";
      case 'zoom_out':
        return "zoompan=z='if(eq(on,1),1.5,max(zoom-0.002,1.0))':d=$totalFrames:x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':s=$s:fps=25";
      case 'pan_left':
        return "zoompan=z='1.3':d=$totalFrames:x='iw*on/$totalFrames':y='ih/2-(ih/zoom/2)':s=$s:fps=25";
      case 'pan_right':
        return "zoompan=z='1.3':d=$totalFrames:x='iw-iw*on/$totalFrames':y='ih/2-(ih/zoom/2)':s=$s:fps=25";
      case 'pulse':
        final halfFrames = totalFrames ~/ 2;
        return "zoompan=z='1+0.15*sin(on*PI/$halfFrames)':d=$totalFrames:x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':s=$s:fps=25";
      case 'ken_burns':
      default:
        return "zoompan=z='min(zoom+0.0015,1.5)':d=$totalFrames:x='iw/2-(iw/zoom/2)':y='ih/4-(ih/zoom/4)':s=$s:fps=25";
    }
  }
}
