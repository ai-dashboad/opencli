import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:yaml/yaml.dart';
import '../domain.dart';
import 'providers/video_provider.dart';
import 'providers/provider_registry.dart';
import 'prompt_builder.dart';
import 'local_model_manager.dart';

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
  final LocalModelManager _localModelManager = LocalModelManager();
  late final VideoProviderRegistry _providerRegistry;

  @override
  List<String> get taskTypes => [
        'media_animate_photo',
        'media_create_slideshow',
        'media_ai_generate_video',
        'media_ai_generate_image',
        'media_local_generate_image',
        'media_local_generate_video',
        'media_local_style_transfer',
      ];

  /// Expose the local model manager for API endpoints.
  LocalModelManager get localModelManager => _localModelManager;

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
        // AI image generation patterns
        DomainIntentPattern(
          pattern: RegExp(
            r'^(?:generate|create)\s+(?:an?\s+)?(?:ai\s+)?(?:image|picture|photo)\s+(?:of|showing|with)\s+(.+)$',
            caseSensitive: false,
          ),
          taskType: 'media_ai_generate_image',
          extractData: (m) => {'prompt': m.group(1)?.trim() ?? ''},
        ),
        DomainIntentPattern(
          pattern: RegExp(
            r'^(?:generate|create|make)\s+(?:an?\s+)?(?:image|picture|illustration|artwork)\s*$',
            caseSensitive: false,
          ),
          taskType: 'media_ai_generate_image',
          extractData: (_) => {},
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
        DomainOllamaIntent(
          intentName: 'media_ai_generate_image',
          description:
              'Generate an AI image from a text prompt using cloud AI services (Replicate Flux model). Can also transform a reference image.',
          parameters: {
            'prompt':
                'text description of the image to generate (required)',
            'style':
                'style hint: photorealistic, illustration, anime, oil_painting, watercolor, 3d_render (default: photorealistic)',
            'aspect_ratio':
                'output aspect ratio: 1:1, 16:9, 9:16, 4:3, 3:4 (default: 1:1)',
            'negative_prompt':
                'things to avoid in the generated image (optional)',
          },
          examples: [
            OllamaExample(
              input: 'generate an image of a sunset over mountains',
              intentJson:
                  '{"intent": "media_ai_generate_image", "confidence": 0.95, "parameters": {"prompt": "a sunset over mountains"}}',
            ),
            OllamaExample(
              input: 'create a picture of a cute robot in anime style',
              intentJson:
                  '{"intent": "media_ai_generate_image", "confidence": 0.95, "parameters": {"prompt": "a cute robot", "style": "anime"}}',
            ),
            OllamaExample(
              input: 'make an AI image of a futuristic city in 16:9',
              intentJson:
                  '{"intent": "media_ai_generate_image", "confidence": 0.90, "parameters": {"prompt": "a futuristic city", "aspect_ratio": "16:9"}}',
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
        'media_ai_generate_image': const DomainDisplayConfig(
          cardType: 'media_creation',
          titleTemplate: 'AI Image',
          subtitleTemplate: '\${style}',
          icon: 'auto_awesome',
          colorHex: 0xFF7C4DFF,
        ),
        'media_local_generate_image': const DomainDisplayConfig(
          cardType: 'media_creation',
          titleTemplate: 'Local Image',
          subtitleTemplate: '\${model}',
          icon: 'computer',
          colorHex: 0xFF7C4DFF,
        ),
        'media_local_generate_video': const DomainDisplayConfig(
          cardType: 'media_creation',
          titleTemplate: 'Local Video',
          subtitleTemplate: '\${model}',
          icon: 'computer',
          colorHex: 0xFF7C4DFF,
        ),
        'media_local_style_transfer': const DomainDisplayConfig(
          cardType: 'media_creation',
          titleTemplate: 'Style Transfer',
          subtitleTemplate: 'AnimeGAN \${style}',
          icon: 'style',
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

    // Initialize local model manager
    try {
      await _localModelManager.initialize();
      if (_localModelManager.isAvailable) {
        print('[MediaCreationDomain] Local inference available');
      }
    } catch (e) {
      print('[MediaCreationDomain] Local inference not available: $e');
    }

    // Create provider registry with local model support
    _providerRegistry = VideoProviderRegistry(
      localModelManager: _localModelManager.isAvailable ? _localModelManager : null,
    );

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

  /// Reload providers from config file (called on config change).
  Future<void> reloadProviders() async {
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
            print('[MediaCreationDomain] Providers reloaded: '
                '${configured.map((p) => p.displayName).join(', ')}');
          }
        }
      }
    } catch (e) {
      print('[MediaCreationDomain] Could not reload providers: $e');
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
      case 'media_ai_generate_image':
        return _aiGenerateImage(taskData);
      case 'media_local_generate_image':
        return _localGenerateImage(taskData);
      case 'media_local_generate_video':
        return _localGenerateVideo(taskData);
      case 'media_local_style_transfer':
        return _localStyleTransfer(taskData);
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
    if (taskType == 'media_ai_generate_image') {
      return _aiGenerateImage(taskData, onProgress: onProgress);
    }
    if (taskType == 'media_local_generate_image') {
      return _localGenerateImage(taskData, onProgress: onProgress);
    }
    if (taskType == 'media_local_generate_video') {
      return _localGenerateVideo(taskData, onProgress: onProgress);
    }
    if (taskType == 'media_local_style_transfer') {
      return _localStyleTransfer(taskData, onProgress: onProgress);
    }
    return executeTask(taskType, taskData);
  }

  /// Generate video using a cloud AI provider with progress reporting.
  Future<Map<String, dynamic>> _aiGenerateVideo(
    Map<String, dynamic> data, {
    ProgressCallback? onProgress,
  }) async {
    final imageBase64 = data['image_base64'] as String?;

    // Route to Pollinations first — it supports txt2vid (no image needed)
    final requestedProvider = data['provider'] as String?;
    if (requestedProvider == 'pollinations') {
      final prompt = data['custom_prompt'] as String? ??
          data['input_text'] as String? ??
          'A cinematic scene';
      final style = data['style'] as String? ?? 'cinematic';
      final aspectRatio = data['aspect_ratio'] as String? ?? '16:9';
      final duration = (data['duration'] as num?)?.toInt() ?? 5;
      return await _generateVideoPollinations(
          prompt, aspectRatio, style, duration, imageBase64, onProgress);
    }

    // Non-Pollinations providers require an image for img2vid
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

  /// Generate an image using AI providers with progress reporting.
  Future<Map<String, dynamic>> _aiGenerateImage(
    Map<String, dynamic> data, {
    ProgressCallback? onProgress,
  }) async {
    final prompt = data['prompt'] as String?;
    if (prompt == null || prompt.trim().isEmpty) {
      return {
        'success': false,
        'error': 'No prompt provided. Please describe the image you want to generate.',
        'domain': 'media_creation',
        'card_type': 'media_creation',
      };
    }

    // Build the full prompt with style hints
    final style = data['style'] as String? ?? 'photorealistic';
    final negativePrompt = data['negative_prompt'] as String?;
    final aspectRatio = data['aspect_ratio'] as String? ?? '1:1';
    final referenceImageBase64 = data['reference_image_base64'] as String?;
    final styledPrompt = _buildImagePrompt(prompt, style);

    // Route to the selected provider
    final provider = data['provider'] as String? ?? 'replicate';
    switch (provider) {
      case 'pollinations':
        return await _generateImagePollinations(
            styledPrompt, aspectRatio, style, onProgress);
      case 'gemini':
        return await _generateImageGemini(
            styledPrompt, aspectRatio, style, onProgress);
      default:
        break; // Fall through to Replicate below
    }

    // --- Replicate provider (default) ---
    final replicateProvider = _providerRegistry.get('replicate');
    if (replicateProvider == null || !replicateProvider.isConfigured) {
      return {
        'success': false,
        'error': 'Replicate API key not configured. '
            'Add your API key to ~/.opencli/config.yaml under ai_video.api_keys.replicate',
        'domain': 'media_creation',
        'card_type': 'media_creation',
      };
    }

    onProgress?.call({
      'progress': 0.05,
      'status_message': 'Submitting image generation to Replicate...',
      'provider': 'replicate',
      'style': style,
      'generation_type': 'ai_image',
    });

    // Use the Replicate API directly for Flux model (different input schema from video)
    // Access the API token via the provider's headers by making a direct HTTP call
    final home = Platform.environment['HOME'] ?? '/tmp';
    final configFile = File('$home/.opencli/config.yaml');
    String? apiToken;
    try {
      if (await configFile.exists()) {
        final content = await configFile.readAsString();
        final yaml = loadYaml(content);
        if (yaml is YamlMap) {
          final aiVideo = yaml['ai_video'];
          if (aiVideo is YamlMap) {
            var token = aiVideo['api_keys']?['replicate'];
            if (token is String &&
                token.startsWith(r'${') &&
                token.endsWith('}')) {
              final envVar = token.substring(2, token.length - 1);
              token = Platform.environment[envVar] ?? token;
            }
            if (token is String &&
                token.isNotEmpty &&
                !token.startsWith(r'${')) {
              apiToken = token;
            }
          }
        }
      }
    } catch (e) {
      // Fall through to error below
    }

    if (apiToken == null) {
      return {
        'success': false,
        'error': 'Could not read Replicate API key from config.',
        'domain': 'media_creation',
        'card_type': 'media_creation',
      };
    }

    final client = http.Client();
    const baseUrl = 'https://api.replicate.com/v1';
    const model = 'black-forest-labs/flux-schnell';
    final headers = {
      'Authorization': 'Bearer $apiToken',
      'Content-Type': 'application/json',
    };

    try {
      // Build input parameters for Flux
      final input = <String, dynamic>{
        'prompt': styledPrompt,
        'aspect_ratio': aspectRatio,
        'output_format': 'png',
        'output_quality': 90,
        'num_outputs': 1,
        'go_fast': true,
      };

      if (negativePrompt != null && negativePrompt.isNotEmpty) {
        // Flux-schnell doesn't natively support negative prompts,
        // so we append it to the prompt as guidance
        input['prompt'] = '$styledPrompt. Avoid: $negativePrompt';
      }

      if (referenceImageBase64 != null && referenceImageBase64.isNotEmpty) {
        input['image'] = 'data:image/jpeg;base64,$referenceImageBase64';
      }

      // Submit prediction
      final response = await client.post(
        Uri.parse('$baseUrl/models/$model/predictions'),
        headers: headers,
        body: jsonEncode({'input': input}),
      );

      if (response.statusCode != 201 && response.statusCode != 200) {
        final body = jsonDecode(response.body);
        return {
          'success': false,
          'error':
              'Replicate submit failed: ${body['detail'] ?? response.statusCode}',
          'domain': 'media_creation',
          'card_type': 'media_creation',
        };
      }

      final submitData = jsonDecode(response.body);
      final jobId = submitData['id'] as String;

      print(
          '[MediaCreationDomain] AI image job submitted: $jobId via Replicate Flux');

      onProgress?.call({
        'progress': 0.15,
        'status_message': 'Image generation queued...',
        'job_id': jobId,
        'provider': 'replicate',
        'style': style,
        'generation_type': 'ai_image',
      });

      // Poll loop: every 2s for up to 3 minutes (images are much faster than video)
      const pollInterval = Duration(seconds: 2);
      const maxWait = Duration(minutes: 3);
      final deadline = DateTime.now().add(maxWait);

      while (DateTime.now().isBefore(deadline)) {
        await Future.delayed(pollInterval);

        final pollResponse = await client.get(
          Uri.parse('$baseUrl/predictions/$jobId'),
          headers: headers,
        );

        if (pollResponse.statusCode != 200) {
          continue; // Retry on transient errors
        }

        final pollData = jsonDecode(pollResponse.body);
        final status = pollData['status'] as String;

        switch (status) {
          case 'succeeded':
            onProgress?.call({
              'progress': 0.85,
              'status_message': 'Downloading generated image...',
              'provider': 'replicate',
              'style': style,
              'generation_type': 'ai_image',
            });

            // Get output URL - Flux returns a list of URLs
            final output = pollData['output'];
            final imageUrl =
                output is List ? output.first as String : output as String;

            // Download the image
            final imageResponse = await http.get(Uri.parse(imageUrl));
            if (imageResponse.statusCode != 200) {
              return {
                'success': false,
                'error':
                    'Failed to download generated image: HTTP ${imageResponse.statusCode}',
                'domain': 'media_creation',
                'card_type': 'media_creation',
              };
            }

            final imageBytes = imageResponse.bodyBytes;
            final imageBase64 = base64Encode(imageBytes);
            final sizeKB = (imageBytes.length / 1024).toStringAsFixed(0);

            return {
              'success': true,
              'image_base64': imageBase64,
              'image_url': imageUrl,
              'provider': 'replicate',
              'provider_name': 'Replicate',
              'model': model,
              'style': style,
              'prompt': styledPrompt,
              'aspect_ratio': aspectRatio,
              'size_bytes': imageBytes.length,
              'generation_type': 'ai_image',
              'message':
                  'AI image generated via Replicate Flux ($sizeKB KB)',
              'domain': 'media_creation',
              'card_type': 'media_creation',
            };

          case 'failed':
          case 'canceled':
            return {
              'success': false,
              'error': pollData['error']?['message'] as String? ??
                  'Image generation failed',
              'provider': 'replicate',
              'generation_type': 'ai_image',
              'domain': 'media_creation',
              'card_type': 'media_creation',
            };

          case 'processing':
            // Estimate progress from logs
            final logs = pollData['logs'] as String?;
            double progress = 0.4;
            if (logs != null) {
              final percentMatch = RegExp(r'(\d+)%').allMatches(logs);
              if (percentMatch.isNotEmpty) {
                final pct =
                    int.tryParse(percentMatch.last.group(1)!) ?? 40;
                progress = (pct / 100.0).clamp(0.2, 0.8);
              }
            }
            onProgress?.call({
              'progress': progress,
              'status_message': 'Generating image...',
              'provider': 'replicate',
              'style': style,
              'generation_type': 'ai_image',
            });

          default: // starting, queued
            onProgress?.call({
              'progress': 0.10,
              'status_message': 'Queued...',
              'provider': 'replicate',
              'style': style,
              'generation_type': 'ai_image',
            });
        }
      }

      // Timed out
      return {
        'success': false,
        'error': 'AI image generation timed out after 3 minutes',
        'provider': 'replicate',
        'generation_type': 'ai_image',
        'domain': 'media_creation',
        'card_type': 'media_creation',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'AI image generation error: $e',
        'provider': 'replicate',
        'generation_type': 'ai_image',
        'domain': 'media_creation',
        'card_type': 'media_creation',
      };
    } finally {
      client.close();
    }
  }

  /// Build an enhanced prompt with style hints for image generation.
  String _buildImagePrompt(String basePrompt, String style) {
    final stylePrefix = switch (style) {
      'photorealistic' => 'A photorealistic, high-quality photograph of',
      'illustration' => 'A detailed digital illustration of',
      'anime' => 'An anime-style illustration of',
      'oil_painting' => 'An oil painting in classical style of',
      'watercolor' => 'A delicate watercolor painting of',
      '3d_render' => 'A high-quality 3D render of',
      _ => 'A high-quality image of',
    };

    // If the prompt already starts with common articles, use the style prefix
    // directly followed by the prompt content
    final trimmed = basePrompt.trim();
    if (trimmed.toLowerCase().startsWith('a ') ||
        trimmed.toLowerCase().startsWith('an ') ||
        trimmed.toLowerCase().startsWith('the ')) {
      return '$stylePrefix ${trimmed.substring(trimmed.indexOf(' ') + 1)}';
    }
    return '$stylePrefix $trimmed';
  }

  /// Generate an image using Pollinations.ai (free, no API key needed).
  Future<Map<String, dynamic>> _generateImagePollinations(
    String prompt,
    String aspectRatio,
    String style,
    ProgressCallback? onProgress,
  ) async {
    // Convert aspect ratio to pixel dimensions
    final (width, height) = switch (aspectRatio) {
      '16:9' => (1280, 720),
      '9:16' => (720, 1280),
      '4:3' => (1024, 768),
      '3:4' => (768, 1024),
      _ => (1024, 1024),
    };

    onProgress?.call({
      'progress': 0.1,
      'status_message': 'Generating image via Pollinations.ai...',
      'provider': 'pollinations',
      'style': style,
      'generation_type': 'ai_image',
    });

    try {
      final url = Uri.parse(
        'https://image.pollinations.ai/prompt/'
        '${Uri.encodeComponent(prompt)}'
        '?width=$width&height=$height&model=flux&nologo=true',
      );

      print('[MediaCreationDomain] Pollinations request: $url');

      onProgress?.call({
        'progress': 0.3,
        'status_message': 'Waiting for Pollinations.ai response...',
        'provider': 'pollinations',
        'style': style,
        'generation_type': 'ai_image',
      });

      final response = await http.get(url);

      if (response.statusCode != 200) {
        return {
          'success': false,
          'error':
              'Pollinations.ai returned HTTP ${response.statusCode}',
          'provider': 'pollinations',
          'generation_type': 'ai_image',
          'domain': 'media_creation',
          'card_type': 'media_creation',
        };
      }

      final imageBytes = response.bodyBytes;
      final imageBase64 = base64Encode(imageBytes);
      final sizeKB = (imageBytes.length / 1024).toStringAsFixed(0);

      print(
          '[MediaCreationDomain] Pollinations image received: $sizeKB KB');

      onProgress?.call({
        'progress': 1.0,
        'status_message': 'Image generated!',
        'provider': 'pollinations',
        'style': style,
        'generation_type': 'ai_image',
      });

      return {
        'success': true,
        'image_base64': imageBase64,
        'provider': 'pollinations',
        'provider_name': 'Pollinations.ai',
        'model': 'flux',
        'style': style,
        'prompt': prompt,
        'aspect_ratio': aspectRatio,
        'size_bytes': imageBytes.length,
        'generation_type': 'ai_image',
        'message': 'AI image generated via Pollinations.ai FLUX ($sizeKB KB)',
        'domain': 'media_creation',
        'card_type': 'media_creation',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Pollinations.ai error: $e',
        'provider': 'pollinations',
        'generation_type': 'ai_image',
        'domain': 'media_creation',
        'card_type': 'media_creation',
      };
    }
  }

  /// Generate a video using Pollinations.ai (free, no API key needed).
  /// Supports both text-to-video and image-to-video via seedance model.
  Future<Map<String, dynamic>> _generateVideoPollinations(
    String prompt,
    String aspectRatio,
    String style,
    int duration,
    String? imageBase64,
    ProgressCallback? onProgress,
  ) async {
    // Clamp duration for seedance: 2-10 seconds
    final clampedDuration = duration.clamp(2, 10);

    onProgress?.call({
      'progress': 0.05,
      'status_message': 'Submitting video to Pollinations.ai...',
      'provider': 'pollinations',
      'style': style,
      'generation_type': 'ai_video',
    });

    try {
      // Build URL — same endpoint as images, but with video model
      final params = <String, String>{
        'model': 'seedance',
        'duration': '$clampedDuration',
        'aspectRatio': aspectRatio.replaceAll(':', ':'), // 16:9 format
        'nologo': 'true',
      };

      // For image-to-video, save the image as a temp file and pass its URL
      // Pollinations expects an image URL for img2vid
      if (imageBase64 != null && imageBase64.isNotEmpty) {
        // Write temp image file for reference
        final home = Platform.environment['HOME'] ?? '/tmp';
        final tempDir = Directory('$home/.opencli/temp');
        if (!await tempDir.exists()) await tempDir.create(recursive: true);
        final tempFile = File('${tempDir.path}/pollinations_ref_${DateTime.now().millisecondsSinceEpoch}.jpg');
        await tempFile.writeAsBytes(base64Decode(imageBase64));
        // Pollinations img2vid requires a public URL — use data URI instead
        params['image'] = 'data:image/jpeg;base64,$imageBase64';
      }

      final queryString = params.entries
          .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
          .join('&');

      final url = Uri.parse(
        'https://image.pollinations.ai/prompt/'
        '${Uri.encodeComponent(prompt)}'
        '?$queryString',
      );

      print('[MediaCreationDomain] Pollinations video request: model=seedance, duration=$clampedDuration');

      onProgress?.call({
        'progress': 0.15,
        'status_message': 'Generating video via Pollinations.ai (this may take 30-60s)...',
        'provider': 'pollinations',
        'style': style,
        'generation_type': 'ai_video',
      });

      // Pollinations video is synchronous — single GET, returns mp4 bytes
      // Can take 30-120 seconds for video generation
      final client = http.Client();
      try {
        final request = http.Request('GET', url);
        final streamedResponse = await client.send(request).timeout(
              const Duration(minutes: 5),
            );

        if (streamedResponse.statusCode != 200) {
          final body = await streamedResponse.stream.bytesToString();
          return {
            'success': false,
            'error': 'Pollinations.ai video returned HTTP ${streamedResponse.statusCode}: $body',
            'provider': 'pollinations',
            'generation_type': 'ai_video',
            'domain': 'media_creation',
            'card_type': 'media_creation',
          };
        }

        onProgress?.call({
          'progress': 0.5,
          'status_message': 'Downloading video from Pollinations.ai...',
          'provider': 'pollinations',
          'style': style,
          'generation_type': 'ai_video',
        });

        final videoBytes = await streamedResponse.stream.toBytes();
        final videoBase64 = base64Encode(videoBytes);
        final sizeMB = (videoBytes.length / 1024 / 1024).toStringAsFixed(1);

        print('[MediaCreationDomain] Pollinations video received: $sizeMB MB');

        onProgress?.call({
          'progress': 1.0,
          'status_message': 'Video generated!',
          'provider': 'pollinations',
          'style': style,
          'generation_type': 'ai_video',
        });

        return {
          'success': true,
          'video_base64': videoBase64,
          'provider': 'pollinations',
          'provider_name': 'Pollinations.ai',
          'model': 'seedance',
          'style': style,
          'prompt': prompt,
          'duration': clampedDuration,
          'size_bytes': videoBytes.length,
          'generation_type': 'ai_video',
          'message': 'AI video generated via Pollinations.ai Seedance ($sizeMB MB)',
          'domain': 'media_creation',
          'card_type': 'media_creation',
        };
      } finally {
        client.close();
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Pollinations.ai video error: $e',
        'provider': 'pollinations',
        'generation_type': 'ai_video',
        'domain': 'media_creation',
        'card_type': 'media_creation',
      };
    }
  }

  /// Generate an image using Google Gemini (free tier).
  Future<Map<String, dynamic>> _generateImageGemini(
    String prompt,
    String aspectRatio,
    String style,
    ProgressCallback? onProgress,
  ) async {
    // Read Gemini API key from config
    final home = Platform.environment['HOME'] ?? '/tmp';
    final configFile = File('$home/.opencli/config.yaml');
    String? apiKey;
    try {
      if (await configFile.exists()) {
        final content = await configFile.readAsString();
        final yaml = loadYaml(content);
        if (yaml is YamlMap) {
          var key = yaml['models']?['gemini']?['api_key'];
          if (key is String &&
              key.startsWith(r'${') &&
              key.endsWith('}')) {
            final envVar = key.substring(2, key.length - 1);
            key = Platform.environment[envVar] ?? key;
          }
          if (key is String &&
              key.isNotEmpty &&
              !key.startsWith(r'${')) {
            apiKey = key;
          }
        }
      }
    } catch (e) {
      // Fall through
    }

    if (apiKey == null) {
      return {
        'success': false,
        'error': 'Google API key not configured. '
            'Set GOOGLE_API_KEY environment variable or add it to '
            '~/.opencli/config.yaml under models.gemini.api_key',
        'domain': 'media_creation',
        'card_type': 'media_creation',
      };
    }

    onProgress?.call({
      'progress': 0.1,
      'status_message': 'Generating image via Google Gemini...',
      'provider': 'gemini',
      'style': style,
      'generation_type': 'ai_image',
    });

    final client = http.Client();
    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/'
        'gemini-2.0-flash-exp:generateContent?key=$apiKey',
      );

      print('[MediaCreationDomain] Gemini image generation request');

      onProgress?.call({
        'progress': 0.3,
        'status_message': 'Waiting for Gemini response...',
        'provider': 'gemini',
        'style': style,
        'generation_type': 'ai_image',
      });

      final response = await client.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': 'Generate an image: $prompt'}
              ]
            }
          ],
          'generationConfig': {
            'responseModalities': ['TEXT', 'IMAGE'],
          },
        }),
      );

      if (response.statusCode != 200) {
        final body = jsonDecode(response.body);
        final errorMsg = body['error']?['message'] ?? 'HTTP ${response.statusCode}';
        return {
          'success': false,
          'error': 'Gemini API error: $errorMsg',
          'provider': 'gemini',
          'generation_type': 'ai_image',
          'domain': 'media_creation',
          'card_type': 'media_creation',
        };
      }

      final data = jsonDecode(response.body);
      final candidates = data['candidates'] as List?;
      if (candidates == null || candidates.isEmpty) {
        return {
          'success': false,
          'error': 'Gemini returned no candidates',
          'provider': 'gemini',
          'generation_type': 'ai_image',
          'domain': 'media_creation',
          'card_type': 'media_creation',
        };
      }

      // Find the inlineData part containing the image
      final parts = candidates[0]['content']?['parts'] as List? ?? [];
      String? imageBase64;
      String? mimeType;
      for (final part in parts) {
        if (part is Map && part['inlineData'] != null) {
          imageBase64 = part['inlineData']['data'] as String?;
          mimeType = part['inlineData']['mimeType'] as String?;
          break;
        }
      }

      if (imageBase64 == null) {
        return {
          'success': false,
          'error': 'Gemini did not return an image. It may not support '
              'image generation in this region or model.',
          'provider': 'gemini',
          'generation_type': 'ai_image',
          'domain': 'media_creation',
          'card_type': 'media_creation',
        };
      }

      final imageBytes = base64Decode(imageBase64);
      final sizeKB = (imageBytes.length / 1024).toStringAsFixed(0);

      print(
          '[MediaCreationDomain] Gemini image received: $sizeKB KB ($mimeType)');

      onProgress?.call({
        'progress': 1.0,
        'status_message': 'Image generated!',
        'provider': 'gemini',
        'style': style,
        'generation_type': 'ai_image',
      });

      return {
        'success': true,
        'image_base64': imageBase64,
        'provider': 'gemini',
        'provider_name': 'Google Gemini',
        'model': 'gemini-2.0-flash-exp',
        'style': style,
        'prompt': prompt,
        'aspect_ratio': aspectRatio,
        'size_bytes': imageBytes.length,
        'generation_type': 'ai_image',
        'message':
            'AI image generated via Google Gemini ($sizeKB KB)',
        'domain': 'media_creation',
        'card_type': 'media_creation',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Gemini error: $e',
        'provider': 'gemini',
        'generation_type': 'ai_image',
        'domain': 'media_creation',
        'card_type': 'media_creation',
      };
    } finally {
      client.close();
    }
  }

  /// Generate an image using a local model (Waifu Diffusion, Animagine, Pony).
  Future<Map<String, dynamic>> _localGenerateImage(
    Map<String, dynamic> data, {
    ProgressCallback? onProgress,
  }) async {
    if (!_localModelManager.isAvailable) {
      return {
        'success': false,
        'error': 'Local inference not available. Run local-inference/setup.sh first.',
        'domain': 'media_creation',
        'card_type': 'media_creation',
      };
    }

    final prompt = data['prompt'] as String?;
    if (prompt == null || prompt.trim().isEmpty) {
      return {
        'success': false,
        'error': 'No prompt provided.',
        'domain': 'media_creation',
        'card_type': 'media_creation',
      };
    }

    final modelId = data['model'] as String? ?? 'waifu_diffusion';
    final width = (data['width'] as num?)?.toInt();
    final height = (data['height'] as num?)?.toInt();
    final steps = (data['steps'] as num?)?.toInt() ?? 30;
    final negativePrompt = data['negative_prompt'] as String?;

    onProgress?.call({
      'progress': 0.05,
      'status_message': 'Starting local model ($modelId)...',
      'provider': 'local',
      'model': modelId,
      'generation_type': 'local_image',
    });

    final result = await _localModelManager.generateImage(
      modelId: modelId,
      prompt: prompt,
      negativePrompt: negativePrompt,
      width: width,
      height: height,
      steps: steps,
    );

    if (result.success && result.imageBase64 != null) {
      return {
        'success': true,
        'image_base64': result.imageBase64,
        'provider': 'local',
        'model': modelId,
        'generation_type': 'local_image',
        'message': 'Image generated locally via $modelId',
        'domain': 'media_creation',
        'card_type': 'media_creation',
      };
    }

    return {
      'success': false,
      'error': result.error ?? 'Local image generation failed',
      'provider': 'local',
      'model': modelId,
      'generation_type': 'local_image',
      'domain': 'media_creation',
      'card_type': 'media_creation',
    };
  }

  /// Generate a video using a local model (AnimateDiff or SVD).
  Future<Map<String, dynamic>> _localGenerateVideo(
    Map<String, dynamic> data, {
    ProgressCallback? onProgress,
  }) async {
    if (!_localModelManager.isAvailable) {
      return {
        'success': false,
        'error': 'Local inference not available. Run local-inference/setup.sh first.',
        'domain': 'media_creation',
        'card_type': 'media_creation',
      };
    }

    final modelId = data['model'] as String? ?? 'animatediff';
    final prompt = data['prompt'] as String?;
    final imageBase64 = data['image_base64'] as String?;
    final frames = (data['frames'] as num?)?.toInt() ?? 16;

    onProgress?.call({
      'progress': 0.05,
      'status_message': 'Starting local video model ($modelId)...',
      'provider': 'local',
      'model': modelId,
      'generation_type': 'local_video',
    });

    final result = await _localModelManager.generateVideo(
      modelId: modelId,
      prompt: prompt,
      imageBase64: imageBase64,
      frames: frames,
    );

    if (result.success && result.videoBase64 != null) {
      final sizeBytes = result.videoBase64!.length * 3 ~/ 4;
      final sizeMB = (sizeBytes / 1024 / 1024).toStringAsFixed(1);

      return {
        'success': true,
        'video_base64': result.videoBase64,
        'provider': 'local',
        'model': modelId,
        'generation_type': 'local_video',
        'size_bytes': sizeBytes,
        'message': 'Video generated locally via $modelId ($sizeMB MB)',
        'domain': 'media_creation',
        'card_type': 'media_creation',
      };
    }

    return {
      'success': false,
      'error': result.error ?? 'Local video generation failed',
      'provider': 'local',
      'model': modelId,
      'generation_type': 'local_video',
      'domain': 'media_creation',
      'card_type': 'media_creation',
    };
  }

  /// Apply style transfer using AnimeGAN.
  Future<Map<String, dynamic>> _localStyleTransfer(
    Map<String, dynamic> data, {
    ProgressCallback? onProgress,
  }) async {
    if (!_localModelManager.isAvailable) {
      return {
        'success': false,
        'error': 'Local inference not available. Run local-inference/setup.sh first.',
        'domain': 'media_creation',
        'card_type': 'media_creation',
      };
    }

    final imageBase64 = data['image_base64'] as String?;
    if (imageBase64 == null || imageBase64.isEmpty) {
      return {
        'success': false,
        'error': 'No image provided for style transfer.',
        'domain': 'media_creation',
        'card_type': 'media_creation',
      };
    }

    final style = data['style'] as String? ?? 'face_paint_512_v2';

    onProgress?.call({
      'progress': 0.1,
      'status_message': 'Applying anime style transfer...',
      'provider': 'local',
      'model': 'animegan_v3',
      'generation_type': 'style_transfer',
    });

    final result = await _localModelManager.styleTransfer(
      imageBase64: imageBase64,
      style: style,
    );

    if (result.success && result.imageBase64 != null) {
      return {
        'success': true,
        'image_base64': result.imageBase64,
        'provider': 'local',
        'model': 'animegan_v3',
        'style': style,
        'generation_type': 'style_transfer',
        'message': 'Style transfer applied via AnimeGAN v3',
        'domain': 'media_creation',
        'card_type': 'media_creation',
      };
    }

    return {
      'success': false,
      'error': result.error ?? 'Style transfer failed',
      'provider': 'local',
      'model': 'animegan_v3',
      'generation_type': 'style_transfer',
      'domain': 'media_creation',
      'card_type': 'media_creation',
    };
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
