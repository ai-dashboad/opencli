import 'dart:convert';
import 'package:http/http.dart' as http;
import 'video_provider.dart';

/// Kling AI provider via PiAPI third-party API.
/// Advanced motion control with up to 3-minute videos.
class KlingVideoProvider extends AIVideoProvider {
  String? _apiKey;
  final _client = http.Client();
  static const _baseUrl =
      'https://api.piapi.ai/api/platform/generation/kling-ai';

  @override
  String get id => 'kling';
  @override
  String get displayName => 'Kling AI';
  @override
  bool get isConfigured => _apiKey != null && _apiKey!.isNotEmpty;
  @override
  void configure(String apiKey) => _apiKey = apiKey;

  Map<String, String> get _headers => {
        'X-API-Key': _apiKey!,
        'Content-Type': 'application/json',
      };

  @override
  Future<VideoJobSubmission> submitJob({
    required String imageBase64,
    required String prompt,
    int durationSeconds = 5,
    Map<String, dynamic> extraParams = const {},
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/create-task'),
      headers: _headers,
      body: jsonEncode({
        'model': extraParams['model'] as String? ?? 'kling-v2.6',
        'task_type': 'image2video',
        'input': {
          'image_url': 'data:image/jpeg;base64,$imageBase64',
          'prompt': prompt,
          'duration': '$durationSeconds',
          'mode': extraParams['mode'] as String? ?? 'std',
        },
      }),
    );

    if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(
          'Kling submit failed: ${body['message'] ?? response.statusCode}');
    }

    final data = jsonDecode(response.body);
    final taskId = data['data']?['task_id'] as String?;
    if (taskId == null) {
      throw Exception('Kling: no task_id in response');
    }

    return VideoJobSubmission(
      jobId: taskId,
      provider: id,
      submittedAt: DateTime.now(),
    );
  }

  @override
  Future<VideoJobStatus> pollJob(String jobId) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/query-task'),
      headers: _headers,
      body: jsonEncode({'task_id': jobId}),
    );

    if (response.statusCode != 200) {
      return VideoJobStatus(
        state: VideoJobState.failed,
        error: 'Poll failed: HTTP ${response.statusCode}',
      );
    }

    final data = jsonDecode(response.body);
    final taskData = data['data'] as Map<String, dynamic>?;
    final status = taskData?['status'] as String? ?? 'unknown';

    switch (status) {
      case 'completed':
        final videoUrl = taskData?['output']?['video_url'] as String?;
        if (videoUrl == null) {
          return VideoJobStatus(
              state: VideoJobState.failed, error: 'No video URL');
        }
        return VideoJobStatus(
          state: VideoJobState.completed,
          videoUrl: videoUrl,
          progress: 1.0,
        );
      case 'failed':
        return VideoJobStatus(
          state: VideoJobState.failed,
          error: taskData?['error'] as String? ?? 'Generation failed',
        );
      case 'processing':
        final progress = (taskData?['progress'] as num?)?.toDouble() ?? 0.3;
        return VideoJobStatus(
          state: VideoJobState.processing,
          progress: progress,
          statusMessage: 'Kling generating...',
        );
      default: // queued, pending
        return VideoJobStatus(
          state: VideoJobState.queued,
          progress: 0.05,
          statusMessage: 'Queued at Kling...',
        );
    }
  }
}
