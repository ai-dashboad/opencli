import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Information about a local AI model.
class LocalModelInfo {
  final String id;
  final String name;
  final String type; // text2img, img2video, text2video, style_transfer
  final List<String> capabilities;
  final double sizeGb;
  final String description;
  final List<String> tags;
  final bool downloaded;
  final double diskSizeMb;

  LocalModelInfo({
    required this.id,
    required this.name,
    required this.type,
    required this.capabilities,
    required this.sizeGb,
    required this.description,
    required this.tags,
    required this.downloaded,
    required this.diskSizeMb,
  });

  factory LocalModelInfo.fromJson(Map<String, dynamic> json) {
    return LocalModelInfo(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      type: json['type'] as String? ?? '',
      capabilities:
          (json['capabilities'] as List?)?.cast<String>() ?? [],
      sizeGb: (json['size_gb'] as num?)?.toDouble() ?? 0,
      description: json['description'] as String? ?? '',
      tags: (json['tags'] as List?)?.cast<String>() ?? [],
      downloaded: json['downloaded'] as bool? ?? false,
      diskSizeMb: (json['disk_size_mb'] as num?)?.toDouble() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'type': type,
        'capabilities': capabilities,
        'size_gb': sizeGb,
        'description': description,
        'tags': tags,
        'downloaded': downloaded,
        'disk_size_mb': diskSizeMb,
      };
}

/// Result from local model inference.
class LocalInferenceResult {
  final bool success;
  final String? imageBase64;
  final String? videoBase64;
  final String? error;
  final String? model;
  final Map<String, dynamic> metadata;
  final Map<String, dynamic> data;

  LocalInferenceResult({
    required this.success,
    this.imageBase64,
    this.videoBase64,
    this.error,
    this.model,
    this.metadata = const {},
    this.data = const {},
  });
}

/// Environment status for local inference.
class LocalEnvironment {
  final bool ok;
  final String pythonVersion;
  final String? torchVersion;
  final String device;
  final String? gpu;
  final List<String> missingPackages;
  final bool venvExists;

  LocalEnvironment({
    required this.ok,
    required this.pythonVersion,
    this.torchVersion,
    required this.device,
    this.gpu,
    required this.missingPackages,
    required this.venvExists,
  });

  Map<String, dynamic> toJson() => {
        'ok': ok,
        'python_version': pythonVersion,
        'torch_version': torchVersion,
        'device': device,
        'gpu': gpu,
        'missing_packages': missingPackages,
        'venv_exists': venvExists,
      };
}

/// Manages local AI model inference via Python subprocess.
class LocalModelManager {
  String? _inferScriptPath;
  String? _pythonPath;
  // ignore: unused_field
  bool _initialized = false;

  /// Initialize the manager by locating the inference script.
  Future<void> initialize() async {
    _inferScriptPath = await _findInferScript();
    _pythonPath = await _findPython();
    _initialized = true;

    if (_inferScriptPath != null) {
      print('[LocalModelManager] Inference script: $_inferScriptPath');
    } else {
      print('[LocalModelManager] Warning: infer.py not found');
    }

    if (_pythonPath != null) {
      print('[LocalModelManager] Python: $_pythonPath');
    } else {
      print('[LocalModelManager] Warning: Python not found');
    }
  }

  bool get isAvailable => _inferScriptPath != null && _pythonPath != null;

  /// Re-detect Python executable (e.g., after setup.sh runs).
  Future<void> refreshPython() async {
    _pythonPath = await _findPython();
    _inferScriptPath ??= await _findInferScript();
    print('[LocalModelManager] Refreshed Python: $_pythonPath');
  }

  /// Check the Python environment status.
  Future<LocalEnvironment> checkEnvironment() async {
    // Re-detect python in case venv was just created
    await refreshPython();

    // Check if venv exists
    final venvDir = _findVenvDir();
    final venvExists = venvDir != null && await Directory(venvDir).exists();

    if (!isAvailable) {
      return LocalEnvironment(
        ok: false,
        pythonVersion: 'not found',
        device: 'unknown',
        missingPackages: ['python3'],
        venvExists: venvExists,
      );
    }

    try {
      final result = await _runInferAction({'action': 'check_env'});
      return LocalEnvironment(
        ok: result['ok'] as bool? ?? false,
        pythonVersion: result['python_version'] as String? ?? 'unknown',
        torchVersion: result['torch_version'] as String?,
        device: result['device'] as String? ?? 'cpu',
        gpu: result['gpu'] as String?,
        missingPackages:
            (result['missing'] as List?)?.cast<String>() ?? [],
        venvExists: venvExists,
      );
    } catch (e) {
      return LocalEnvironment(
        ok: false,
        pythonVersion: 'error',
        device: 'unknown',
        missingPackages: ['unknown (check failed: $e)'],
        venvExists: venvExists,
      );
    }
  }

  /// List all available models with download status.
  Future<List<LocalModelInfo>> listModels() async {
    if (!isAvailable) {
      return _fallbackModelList();
    }

    try {
      final result = await _runInferAction({'action': 'list_models'});
      final list = result['_list'] as List?;
      if (list != null) {
        return list
            .map((m) => LocalModelInfo.fromJson(m as Map<String, dynamic>))
            .toList();
      }
      return _fallbackModelList();
    } catch (e) {
      print('[LocalModelManager] listModels error: $e');
      return _fallbackModelList();
    }
  }

  /// Get status of a specific model.
  Future<LocalModelInfo> getModelStatus(String modelId) async {
    if (!isAvailable) {
      return _fallbackModelInfo(modelId);
    }

    try {
      final result = await _runInferAction({
        'action': 'model_status',
        'model_id': modelId,
      });
      return LocalModelInfo.fromJson(result);
    } catch (e) {
      return _fallbackModelInfo(modelId);
    }
  }

  /// Download a model.
  Future<Map<String, dynamic>> downloadModel(
    String modelId, {
    void Function(double progress, String message)? onProgress,
  }) async {
    if (!isAvailable) {
      return {'error': 'Local inference not available. Run setup.sh first.'};
    }

    try {
      // Use long timeout for downloads
      final result = await _runInferAction(
        {'action': 'download', 'model_id': modelId},
        timeout: const Duration(minutes: 30),
        onStdoutLine: (line) {
          try {
            final data = jsonDecode(line);
            if (data is Map && data.containsKey('progress')) {
              onProgress?.call(
                (data['progress'] as num).toDouble(),
                data['message'] as String? ?? 'Downloading...',
              );
            }
          } catch (_) {}
        },
      );
      return result;
    } catch (e) {
      return {'error': 'Download failed: $e'};
    }
  }

  /// Delete a downloaded model.
  Future<Map<String, dynamic>> deleteModel(String modelId) async {
    final home = Platform.environment['HOME'] ?? '/tmp';
    final modelDir = Directory('$home/.opencli/models/$modelId');

    if (!await modelDir.exists()) {
      return {'error': 'Model not found'};
    }

    try {
      await modelDir.delete(recursive: true);
      return {'success': true, 'model_id': modelId};
    } catch (e) {
      return {'error': 'Delete failed: $e'};
    }
  }

  /// Generate an image using a local model.
  Future<LocalInferenceResult> generateImage({
    required String modelId,
    required String prompt,
    String? negativePrompt,
    int? width,
    int? height,
    int steps = 30,
    double guidanceScale = 7.5,
    int? seed,
  }) async {
    if (!isAvailable) {
      return LocalInferenceResult(
        success: false,
        error: 'Local inference not available',
      );
    }

    try {
      final params = {
        'action': 'generate_image',
        'model': modelId,
        'prompt': prompt,
        if (negativePrompt != null) 'negative_prompt': negativePrompt,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
        'steps': steps,
        'guidance_scale': guidanceScale,
        if (seed != null) 'seed': seed,
      };

      final result = await _runInferAction(
        params,
        timeout: const Duration(minutes: 10),
      );

      if (result['success'] == true) {
        return LocalInferenceResult(
          success: true,
          imageBase64: result['image_base64'] as String?,
          model: modelId,
          metadata: result,
        );
      } else {
        return LocalInferenceResult(
          success: false,
          error: result['error'] as String? ?? 'Unknown error',
          model: modelId,
        );
      }
    } catch (e) {
      return LocalInferenceResult(
        success: false,
        error: 'Inference error: $e',
        model: modelId,
      );
    }
  }

  /// Generate a video using a local model.
  Future<LocalInferenceResult> generateVideo({
    required String modelId,
    String? prompt,
    String? imageBase64,
    int frames = 16,
    int steps = 25,
  }) async {
    if (!isAvailable) {
      return LocalInferenceResult(
        success: false,
        error: 'Local inference not available',
      );
    }

    try {
      final params = {
        'action': 'generate_video',
        'model': modelId,
        if (prompt != null) 'prompt': prompt,
        if (imageBase64 != null) 'image_base64': imageBase64,
        'frames': frames,
        'steps': steps,
      };

      final result = await _runInferAction(
        params,
        timeout: const Duration(minutes: 15),
      );

      if (result['success'] == true) {
        return LocalInferenceResult(
          success: true,
          videoBase64: result['video_base64'] as String?,
          model: modelId,
          metadata: result,
        );
      } else {
        return LocalInferenceResult(
          success: false,
          error: result['error'] as String? ?? 'Unknown error',
          model: modelId,
        );
      }
    } catch (e) {
      return LocalInferenceResult(
        success: false,
        error: 'Inference error: $e',
        model: modelId,
      );
    }
  }

  /// Apply style transfer using AnimeGAN.
  Future<LocalInferenceResult> styleTransfer({
    required String imageBase64,
    String style = 'face_paint_512_v2',
  }) async {
    if (!isAvailable) {
      return LocalInferenceResult(
        success: false,
        error: 'Local inference not available',
      );
    }

    try {
      final result = await _runInferAction(
        {
          'action': 'style_transfer',
          'image_base64': imageBase64,
          'style': style,
        },
        timeout: const Duration(minutes: 5),
      );

      if (result['success'] == true) {
        return LocalInferenceResult(
          success: true,
          imageBase64: result['image_base64'] as String?,
          model: 'animegan_v3',
          metadata: result,
        );
      } else {
        return LocalInferenceResult(
          success: false,
          error: result['error'] as String? ?? 'Unknown error',
          model: 'animegan_v3',
        );
      }
    } catch (e) {
      return LocalInferenceResult(
        success: false,
        error: 'Style transfer error: $e',
        model: 'animegan_v3',
      );
    }
  }

  /// Generate video using AnimateDiff V3 with MotionLoRA camera control.
  Future<LocalInferenceResult> generateVideoV3({
    required String prompt,
    String? negativePrompt,
    String? cameraMotion,
    String? styleLora,
    double stylLoraWeight = 0.7,
    int frames = 24,
    int width = 512,
    int height = 512,
    int steps = 25,
    int? seed,
  }) async {
    if (!isAvailable) {
      return LocalInferenceResult(
        success: false,
        error: 'Local inference not available',
      );
    }

    try {
      final params = {
        'action': 'generate_video_v3',
        'prompt': prompt,
        if (negativePrompt != null) 'negative_prompt': negativePrompt,
        if (cameraMotion != null) 'camera_motion': cameraMotion,
        if (styleLora != null) 'style_lora': styleLora,
        'style_lora_weight': stylLoraWeight,
        'frames': frames,
        'width': width,
        'height': height,
        'steps': steps,
        if (seed != null) 'seed': seed,
      };

      final result = await _runInferAction(
        params,
        timeout: const Duration(minutes: 15),
      );

      if (result['success'] == true) {
        return LocalInferenceResult(
          success: true,
          videoBase64: result['video_base64'] as String?,
          model: 'animatediff_v3',
          metadata: result,
        );
      } else {
        return LocalInferenceResult(
          success: false,
          error: result['error'] as String? ?? 'Unknown error',
          model: 'animatediff_v3',
        );
      }
    } catch (e) {
      return LocalInferenceResult(
        success: false,
        error: 'V3 video inference error: $e',
        model: 'animatediff_v3',
      );
    }
  }

  /// Upscale an image using Real-ESRGAN (anime-optimized 4x).
  Future<LocalInferenceResult> upscaleImage({
    required String imageBase64,
    int scale = 4,
  }) async {
    if (!isAvailable) {
      return LocalInferenceResult(success: false, error: 'Local inference not available');
    }

    try {
      final result = await _runInferAction({
        'action': 'upscale',
        'input_type': 'image',
        'image_base64': imageBase64,
        'scale': scale,
      }, timeout: const Duration(minutes: 5));

      if (result['success'] == true) {
        return LocalInferenceResult(
          success: true,
          imageBase64: result['image_base64'] as String?,
          model: 'realesrgan',
          metadata: result,
        );
      }
      return LocalInferenceResult(
        success: false,
        error: result['error'] as String? ?? 'Upscale failed',
        model: 'realesrgan',
      );
    } catch (e) {
      return LocalInferenceResult(
        success: false,
        error: 'Upscale error: $e',
        model: 'realesrgan',
      );
    }
  }

  /// Generate video using ControlNet + AnimateDiff V3 hybrid pipeline.
  ///
  /// Takes a reference keyframe image, extracts lineart/pose/depth,
  /// then generates consistent animated video using ControlNet guidance.
  Future<LocalInferenceResult> generateControlNetVideo({
    required String referenceImageBase64,
    required String prompt,
    String controlType = 'lineart_anime',
    String? negativePrompt,
    String? cameraMotion,
    String? styleLora,
    double controlnetConditioningScale = 0.7,
    int frames = 24,
    int width = 512,
    int height = 512,
    int steps = 25,
    int? seed,
  }) async {
    if (!isAvailable) {
      return LocalInferenceResult(
        success: false,
        error: 'Local inference not available',
      );
    }

    try {
      final params = {
        'action': 'generate_controlnet_video',
        'reference_image_base64': referenceImageBase64,
        'prompt': prompt,
        'control_type': controlType,
        'controlnet_conditioning_scale': controlnetConditioningScale,
        'frames': frames,
        'width': width,
        'height': height,
        'steps': steps,
        if (negativePrompt != null) 'negative_prompt': negativePrompt,
        if (cameraMotion != null) 'camera_motion': cameraMotion,
        if (styleLora != null) 'style_lora': styleLora,
        if (seed != null) 'seed': seed,
      };

      final result = await _runInferAction(
        params,
        timeout: const Duration(minutes: 20),
      );

      if (result['success'] == true) {
        return LocalInferenceResult(
          success: true,
          videoBase64: result['video_base64'] as String?,
          model: 'controlnet_animatediff_v3',
          metadata: result,
        );
      } else {
        return LocalInferenceResult(
          success: false,
          error: result['error'] as String? ?? 'Unknown error',
          model: 'controlnet_animatediff_v3',
        );
      }
    } catch (e) {
      return LocalInferenceResult(
        success: false,
        error: 'ControlNet video error: $e',
        model: 'controlnet_animatediff_v3',
      );
    }
  }

  /// Extract a control signal (lineart/depth/pose) from an image.
  Future<LocalInferenceResult> extractControlSignal({
    required String imageBase64,
    String controlType = 'lineart_anime',
  }) async {
    if (!isAvailable) {
      return LocalInferenceResult(
        success: false,
        error: 'Local inference not available',
      );
    }

    try {
      final result = await _runInferAction({
        'action': 'extract_control',
        'image_base64': imageBase64,
        'control_type': controlType,
      }, timeout: const Duration(minutes: 5));

      if (result['success'] == true) {
        return LocalInferenceResult(
          success: true,
          imageBase64: result['control_image_base64'] as String?,
          metadata: result,
        );
      }
      return LocalInferenceResult(
        success: false,
        error: result['error'] as String? ?? 'Extraction failed',
      );
    } catch (e) {
      return LocalInferenceResult(
        success: false,
        error: 'Control signal extraction error: $e',
      );
    }
  }

  /// Upscale a video file frame-by-frame using Real-ESRGAN.
  Future<Map<String, dynamic>> upscaleVideoPath({
    required String videoPath,
    int scale = 4,
  }) async {
    if (!isAvailable) {
      return {'success': false, 'error': 'Local inference not available'};
    }

    try {
      final result = await _runInferAction({
        'action': 'upscale_video_path',
        'video_path': videoPath,
        'scale': scale,
      }, timeout: const Duration(minutes: 30));

      return result;
    } catch (e) {
      return {'success': false, 'error': 'Video upscale error: $e'};
    }
  }

  /// Interpolate video frames using RIFE for smoother motion.
  /// Returns path to the interpolated video.
  Future<Map<String, dynamic>> interpolateVideo({
    required String videoPath,
    int multiplier = 2,
  }) async {
    if (!isAvailable) {
      return {'success': false, 'error': 'Local inference not available'};
    }

    try {
      final result = await _runInferAction({
        'action': 'interpolate',
        'video_path': videoPath,
        'multiplier': multiplier,
      }, timeout: const Duration(minutes: 10));

      return result;
    } catch (e) {
      return {'success': false, 'error': 'Interpolation error: $e'};
    }
  }

  /// Run an IP-Adapter action (encode_reference, generate_with_reference, list_references).
  Future<LocalInferenceResult> runIPAdapter({
    required String action,
    required Map<String, dynamic> params,
  }) async {
    if (!isAvailable) {
      return LocalInferenceResult(
        success: false,
        error: 'Local inference not available',
      );
    }

    try {
      // IP-Adapter uses its own script
      final home = Platform.environment['HOME'] ?? '.';
      final ipScript = [
        'local-inference/ip_adapter.py',
        '../local-inference/ip_adapter.py',
        '$home/development/opencli/local-inference/ip_adapter.py',
      ].map((p) => File(p)).firstWhere(
        (f) => f.existsSync(),
        orElse: () => File('ip_adapter.py'),
      );

      if (!ipScript.existsSync()) {
        return LocalInferenceResult(
          success: false,
          error: 'ip_adapter.py not found',
        );
      }

      final python = _pythonPath!;
      final process = await Process.start(
        python,
        [ipScript.absolute.path],
        environment: _pythonEnv(),
      );

      process.stdin.write(jsonEncode({...params, 'action': action}));
      await process.stdin.close();

      final stdout = StringBuffer();
      await for (final line
          in process.stdout.transform(utf8.decoder).transform(const LineSplitter())) {
        stdout.writeln(line);
      }
      // Drain stderr
      await process.stderr.drain<void>();

      final exitCode = await process.exitCode
          .timeout(const Duration(minutes: 5), onTimeout: () {
        process.kill();
        throw TimeoutException('IP-Adapter process timed out');
      });

      if (exitCode != 0) {
        return LocalInferenceResult(
          success: false,
          error: 'IP-Adapter exited with code $exitCode',
        );
      }

      final lines = stdout.toString().trim().split('\n');
      final lastLine = lines.isNotEmpty ? lines.last : '{}';
      final result = jsonDecode(lastLine) as Map<String, dynamic>;

      return LocalInferenceResult(
        success: result['success'] == true,
        imageBase64: result['image_base64'] as String?,
        error: result['error'] as String?,
        data: result,
      );
    } catch (e) {
      return LocalInferenceResult(
        success: false,
        error: 'IP-Adapter error: $e',
      );
    }
  }

  // ---- Private helpers ----

  /// Run an action via the Python inference script.
  Future<Map<String, dynamic>> _runInferAction(
    Map<String, dynamic> params, {
    Duration timeout = const Duration(minutes: 2),
    void Function(String line)? onStdoutLine,
  }) async {
    final python = _pythonPath!;
    final script = _inferScriptPath!;

    final process = await Process.start(
      python,
      [script, '--stdin'],
      environment: _pythonEnv(),
    );

    // Write JSON to stdin
    process.stdin.write(jsonEncode(params));
    await process.stdin.close();

    final stdout = StringBuffer();
    final stderr = StringBuffer();

    // Read stdout line by line for progress
    await for (final line
        in process.stdout.transform(utf8.decoder).transform(const LineSplitter())) {
      stdout.writeln(line);
      onStdoutLine?.call(line);
    }

    await for (final line
        in process.stderr.transform(utf8.decoder).transform(const LineSplitter())) {
      stderr.writeln(line);
    }

    final exitCode = await process.exitCode.timeout(timeout, onTimeout: () {
      process.kill();
      throw TimeoutException('Python process timed out');
    });

    if (exitCode != 0) {
      throw Exception('Python exited with code $exitCode: ${stderr.toString().trim()}');
    }

    // Parse the last line of stdout as JSON (progress lines come before)
    final lines = stdout.toString().trim().split('\n');
    final lastLine = lines.isNotEmpty ? lines.last : '{}';

    try {
      final result = jsonDecode(lastLine);
      if (result is List) {
        return {'_list': result};
      }
      return result as Map<String, dynamic>;
    } catch (e) {
      throw FormatException('Invalid JSON from Python: $lastLine');
    }
  }

  /// Find the Python inference script.
  Future<String?> _findInferScript() async {
    final candidates = [
      'local-inference/infer.py',
      '../local-inference/infer.py',
      '../../local-inference/infer.py',
    ];

    // Also check relative to the project root
    final home = Platform.environment['HOME'] ?? '.';
    final opencliDirs = [
      '$home/development/opencli/local-inference/infer.py',
    ];

    for (final path in [...candidates, ...opencliDirs]) {
      final file = File(path);
      if (await file.exists()) {
        return file.absolute.path;
      }
    }
    return null;
  }

  /// Find Python executable (prefer venv).
  Future<String?> _findPython() async {
    // Check venv first
    final venvDir = _findVenvDir();
    if (venvDir != null) {
      final venvPython = '$venvDir/bin/python';
      if (await File(venvPython).exists()) {
        return venvPython;
      }
    }

    // Fall back to system python
    final result = await Process.run('which', ['python3']);
    if (result.exitCode == 0) {
      return (result.stdout as String).trim();
    }
    return null;
  }

  /// Find the venv directory.
  String? _findVenvDir() {
    final candidates = [
      'local-inference/.venv',
      '../local-inference/.venv',
      '../../local-inference/.venv',
    ];

    final home = Platform.environment['HOME'] ?? '.';
    candidates.add('$home/development/opencli/local-inference/.venv');

    for (final path in candidates) {
      if (Directory(path).existsSync()) {
        return Directory(path).absolute.path;
      }
    }
    return null;
  }

  /// Python environment variables.
  Map<String, String> _pythonEnv() {
    final env = Map<String, String>.from(Platform.environment);
    // Ensure PYTHONUNBUFFERED for real-time output
    env['PYTHONUNBUFFERED'] = '1';
    return env;
  }

  /// Fallback model list when Python is not available.
  List<LocalModelInfo> _fallbackModelList() {
    return _fallbackModels.entries
        .map((e) => LocalModelInfo(
              id: e.key,
              name: e.value['name'] as String,
              type: e.value['type'] as String,
              capabilities:
                  (e.value['capabilities'] as List).cast<String>(),
              sizeGb: e.value['size_gb'] as double,
              description: e.value['description'] as String,
              tags: (e.value['tags'] as List).cast<String>(),
              downloaded: false,
              diskSizeMb: 0,
            ))
        .toList();
  }

  LocalModelInfo _fallbackModelInfo(String modelId) {
    final info = _fallbackModels[modelId];
    if (info == null) {
      return LocalModelInfo(
        id: modelId,
        name: modelId,
        type: 'unknown',
        capabilities: [],
        sizeGb: 0,
        description: 'Unknown model',
        tags: [],
        downloaded: false,
        diskSizeMb: 0,
      );
    }
    return LocalModelInfo(
      id: modelId,
      name: info['name'] as String,
      type: info['type'] as String,
      capabilities: (info['capabilities'] as List).cast<String>(),
      sizeGb: info['size_gb'] as double,
      description: info['description'] as String,
      tags: (info['tags'] as List).cast<String>(),
      downloaded: false,
      diskSizeMb: 0,
    );
  }

  static const _fallbackModels = {
    'waifu_diffusion': {
      'name': 'Waifu Diffusion',
      'type': 'text2img',
      'capabilities': ['image'],
      'size_gb': 2.0,
      'description': 'Anime-style image generation based on Stable Diffusion 1.5',
      'tags': ['anime', 'illustration'],
    },
    'animagine_xl': {
      'name': 'Animagine XL 3.1',
      'type': 'text2img',
      'capabilities': ['image'],
      'size_gb': 6.5,
      'description': 'High-quality anime image generation based on SDXL',
      'tags': ['anime', 'illustration', 'xl'],
    },
    'pony_diffusion': {
      'name': 'Pony Diffusion V6 XL',
      'type': 'text2img',
      'capabilities': ['image'],
      'size_gb': 6.5,
      'description': 'Versatile anime/illustration model based on SDXL',
      'tags': ['anime', 'illustration', 'versatile', 'xl'],
    },
    'animatediff': {
      'name': 'AnimateDiff',
      'type': 'text2video',
      'capabilities': ['video', 'animation'],
      'size_gb': 4.5,
      'description': 'Generate short animated videos from text prompts',
      'tags': ['animation', 'video', 'motion'],
    },
    'stable_video_diffusion': {
      'name': 'Stable Video Diffusion',
      'type': 'img2video',
      'capabilities': ['video'],
      'size_gb': 4.0,
      'description': 'Generate video from a single image',
      'tags': ['video', 'img2vid'],
    },
    'animegan_v3': {
      'name': 'AnimeGAN v3',
      'type': 'style_transfer',
      'capabilities': ['image', 'style_transfer'],
      'size_gb': 0.1,
      'description': 'Transform photos into anime-style artwork',
      'tags': ['anime', 'style_transfer', 'lightweight'],
    },
    'animatediff_v3': {
      'name': 'AnimateDiff V3',
      'type': 'text2video',
      'capabilities': ['video', 'animation', 'camera_control'],
      'size_gb': 4.8,
      'description': 'AnimateDiff V3 with MotionLoRA camera control for cinematic video',
      'tags': ['animation', 'video', 'motion', 'camera', 'lora'],
    },
    'realesrgan': {
      'name': 'Real-ESRGAN Anime',
      'type': 'upscale',
      'capabilities': ['upscale'],
      'size_gb': 0.07,
      'description': '4x anime-optimized upscaling via Real-ESRGAN',
      'tags': ['upscale', 'super_resolution', 'anime'],
    },
    'controlnet_lineart_anime': {
      'name': 'ControlNet Lineart Anime',
      'type': 'controlnet',
      'capabilities': ['controlnet', 'lineart'],
      'size_gb': 1.4,
      'description': 'ControlNet for anime lineart-guided generation (SD1.5)',
      'tags': ['controlnet', 'lineart', 'anime', 'consistency'],
    },
    'controlnet_openpose': {
      'name': 'ControlNet OpenPose',
      'type': 'controlnet',
      'capabilities': ['controlnet', 'pose'],
      'size_gb': 1.4,
      'description': 'ControlNet for pose-guided generation (SD1.5)',
      'tags': ['controlnet', 'pose', 'skeleton', 'consistency'],
    },
    'controlnet_depth': {
      'name': 'ControlNet Depth',
      'type': 'controlnet',
      'capabilities': ['controlnet', 'depth'],
      'size_gb': 1.4,
      'description': 'ControlNet for depth-guided generation (SD1.5)',
      'tags': ['controlnet', 'depth', '3d', 'consistency'],
    },
    'ip_adapter_face': {
      'name': 'IP-Adapter FaceID',
      'type': 'ip_adapter',
      'capabilities': ['face_consistency', 'ip_adapter'],
      'size_gb': 1.5,
      'description': 'IP-Adapter for character face consistency across shots',
      'tags': ['face', 'consistency', 'ip_adapter', 'character'],
    },
  };
}
