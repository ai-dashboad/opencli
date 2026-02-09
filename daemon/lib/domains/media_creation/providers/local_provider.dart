import 'dart:convert' show base64Decode;
import 'video_provider.dart';
import '../local_model_manager.dart';

/// Local video provider using AnimateDiff or Stable Video Diffusion.
/// Delegates to LocalModelManager for actual inference.
class LocalVideoProvider extends AIVideoProvider {
  final LocalModelManager _modelManager;
  String _selectedModel = 'stable_video_diffusion';
  bool _enabled = false;

  LocalVideoProvider(this._modelManager);

  @override
  String get id => 'local';
  @override
  String get displayName => 'Local';
  @override
  bool get isConfigured => _enabled && _modelManager.isAvailable;

  @override
  void configure(String value) {
    // value = 'true' or model ID like 'stable_video_diffusion'
    if (value == 'true' || value == 'enabled') {
      _enabled = true;
    } else if (value == 'false' || value == 'disabled') {
      _enabled = false;
    } else {
      _enabled = true;
      _selectedModel = value;
    }
  }

  @override
  Future<VideoJobSubmission> submitJob({
    required String imageBase64,
    required String prompt,
    int durationSeconds = 5,
    Map<String, dynamic> extraParams = const {},
  }) async {
    final jobId = 'local_${DateTime.now().millisecondsSinceEpoch}';

    // Store job params for pollJob to execute
    _pendingJobs[jobId] = _LocalJob(
      imageBase64: imageBase64,
      prompt: prompt,
      model: extraParams['model'] as String? ?? _selectedModel,
      frames: (durationSeconds * 8).clamp(8, 50), // 8 fps
    );

    return VideoJobSubmission(
      jobId: jobId,
      provider: id,
      submittedAt: DateTime.now(),
    );
  }

  @override
  Future<VideoJobStatus> pollJob(String jobId) async {
    final job = _pendingJobs[jobId];
    if (job == null) {
      return VideoJobStatus(
        state: VideoJobState.failed,
        error: 'Job not found: $jobId',
      );
    }

    // If already completed
    if (job.result != null) {
      _pendingJobs.remove(jobId);
      final result = job.result!;
      if (result.success) {
        // For local, video is already in base64 — we store it as a data URI
        return VideoJobStatus(
          state: VideoJobState.completed,
          videoUrl: 'data:video/mp4;base64,${result.videoBase64}',
          progress: 1.0,
        );
      } else {
        return VideoJobStatus(
          state: VideoJobState.failed,
          error: result.error ?? 'Generation failed',
        );
      }
    }

    // If not started, start it now
    if (!job.started) {
      job.started = true;
      // Run inference asynchronously
      _runInference(jobId, job);

      return VideoJobStatus(
        state: VideoJobState.processing,
        progress: 0.1,
        statusMessage: 'Starting local inference...',
      );
    }

    // In progress
    return VideoJobStatus(
      state: VideoJobState.processing,
      progress: 0.3,
      statusMessage: 'Running local model (${job.model})...',
    );
  }

  @override
  Future<List<int>> downloadVideo(String videoUrl) async {
    // For local provider, video URL may be a data URI
    if (videoUrl.startsWith('data:video/mp4;base64,')) {
      final base64Data = videoUrl.substring('data:video/mp4;base64,'.length);
      return List<int>.from(
        base64Decode(base64Data),
      );
    }
    return super.downloadVideo(videoUrl);
  }

  void _runInference(String jobId, _LocalJob job) async {
    try {
      final result = await _modelManager.generateVideo(
        modelId: job.model,
        prompt: job.prompt,
        imageBase64: job.imageBase64,
        frames: job.frames,
      );
      job.result = result;
    } catch (e) {
      job.result = LocalInferenceResult(
        success: false,
        error: 'Local inference error: $e',
      );
    }
  }

  final Map<String, _LocalJob> _pendingJobs = {};
}

class _LocalJob {
  final String imageBase64;
  final String prompt;
  final String model;
  final int frames;
  bool started = false;
  LocalInferenceResult? result;

  _LocalJob({
    required this.imageBase64,
    required this.prompt,
    required this.model,
    required this.frames,
  });
}
