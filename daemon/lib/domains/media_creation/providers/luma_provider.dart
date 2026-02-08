import 'dart:convert';
import 'package:http/http.dart' as http;
import 'video_provider.dart';

/// Luma Dream Machine API provider for AI video generation.
/// Most realistic physics for water, smoke, fabric motion.
class LumaVideoProvider extends AIVideoProvider {
  String? _apiKey;
  final _client = http.Client();
  static const _baseUrl = 'https://api.lumalabs.ai/dream-machine/v1';

  @override
  String get id => 'luma';
  @override
  String get displayName => 'Luma Dream';
  @override
  bool get isConfigured => _apiKey != null && _apiKey!.isNotEmpty;
  @override
  void configure(String apiKey) => _apiKey = apiKey;

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $_apiKey',
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
      Uri.parse('$_baseUrl/generations'),
      headers: _headers,
      body: jsonEncode({
        'prompt': prompt,
        'keyframes': {
          'frame0': {
            'type': 'image',
            'url': 'data:image/jpeg;base64,$imageBase64',
          },
        },
      }),
    );

    if (response.statusCode != 200 && response.statusCode != 201) {
      final body = jsonDecode(response.body);
      throw Exception(
          'Luma submit failed: ${body['detail'] ?? response.statusCode}');
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
      Uri.parse('$_baseUrl/generations/$jobId'),
      headers: _headers,
    );

    if (response.statusCode != 200) {
      return VideoJobStatus(
        state: VideoJobState.failed,
        error: 'Poll failed: HTTP ${response.statusCode}',
      );
    }

    final data = jsonDecode(response.body);
    final state = data['state'] as String;

    switch (state) {
      case 'completed':
        final videoUrl = data['assets']?['video'] as String?;
        if (videoUrl == null) {
          return VideoJobStatus(
              state: VideoJobState.failed, error: 'No video asset');
        }
        return VideoJobStatus(
          state: VideoJobState.completed,
          videoUrl: videoUrl,
          progress: 1.0,
        );
      case 'failed':
        return VideoJobStatus(
          state: VideoJobState.failed,
          error: data['failure_reason'] as String? ?? 'Generation failed',
        );
      case 'dreaming':
        return VideoJobStatus(
          state: VideoJobState.processing,
          progress: 0.5,
          statusMessage: 'Luma dreaming...',
        );
      default: // queued
        return VideoJobStatus(
          state: VideoJobState.queued,
          progress: 0.05,
          statusMessage: 'Queued at Luma...',
        );
    }
  }
}
