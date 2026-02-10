import 'dart:convert';
import 'package:http/http.dart' as http;
import 'video_provider.dart';

/// Runway Gen-4 API provider for AI video generation.
/// Best cinematography control with professional camera term understanding.
class RunwayVideoProvider extends AIVideoProvider {
  String? _apiSecret;
  final _client = http.Client();
  static const _baseUrl = 'https://api.runwayml.com/v1';

  @override
  String get id => 'runway';
  @override
  String get displayName => 'Runway Gen-4';
  @override
  bool get isConfigured => _apiSecret != null && _apiSecret!.isNotEmpty;
  @override
  void configure(String apiKey) => _apiSecret = apiKey;

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $_apiSecret',
        'Content-Type': 'application/json',
        'X-Runway-Version': '2024-11-06',
      };

  @override
  Future<VideoJobSubmission> submitJob({
    required String imageBase64,
    required String prompt,
    int durationSeconds = 5,
    Map<String, dynamic> extraParams = const {},
  }) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl/image_to_video'),
      headers: _headers,
      body: jsonEncode({
        'model': 'gen4_turbo',
        'promptImage': 'data:image/jpeg;base64,$imageBase64',
        'promptText': prompt,
        'duration': durationSeconds.clamp(5, 10),
        'ratio': extraParams['ratio'] as String? ?? '16:9',
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      final body = jsonDecode(response.body);
      throw Exception(
          'Runway submit failed: ${body['error'] ?? response.statusCode}');
    }

    final data = jsonDecode(response.body);
    return VideoJobSubmission(
      jobId: data['id'] as String,
      provider: id,
      submittedAt: DateTime.now(),
    );
  }

  @override
  Future<VideoJobStatus> pollJob(String jobId) async {
    final response = await _client.get(
      Uri.parse('$_baseUrl/tasks/$jobId'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      return VideoJobStatus(
        state: VideoJobState.failed,
        error: 'Poll failed: HTTP ${response.statusCode}',
      );
    }

    final data = jsonDecode(response.body);
    final status = data['status'] as String;

    switch (status) {
      case 'SUCCEEDED':
        final outputs = data['output'] as List?;
        final videoUrl = outputs?.firstOrNull as String?;
        if (videoUrl == null) {
          return VideoJobStatus(
              state: VideoJobState.failed, error: 'No output URL');
        }
        return VideoJobStatus(
          state: VideoJobState.completed,
          videoUrl: videoUrl,
          progress: 1.0,
        );
      case 'FAILED':
        return VideoJobStatus(
          state: VideoJobState.failed,
          error: data['failure'] as String? ?? 'Generation failed',
        );
      case 'RUNNING':
        final progress = (data['progress'] as num?)?.toDouble() ?? 0.4;
        return VideoJobStatus(
          state: VideoJobState.processing,
          progress: progress,
          statusMessage: 'Runway generating...',
        );
      default: // PENDING, THROTTLED
        return VideoJobStatus(
          state: VideoJobState.queued,
          progress: 0.05,
          statusMessage: 'Queued at Runway...',
        );
    }
  }
}
