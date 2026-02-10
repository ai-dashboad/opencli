import 'dart:convert';
import 'package:http/http.dart' as http;
import 'video_provider.dart';

/// Replicate API provider for AI video generation.
/// Uses minimax/video-01 (Hailuo) by default — supports both txt2vid and img2vid.
class ReplicateVideoProvider extends AIVideoProvider {
  String? _apiToken;
  final _client = http.Client();
  static const _baseUrl = 'https://api.replicate.com/v1';
  static const _defaultModel = 'minimax/video-01';

  @override
  String get id => 'replicate';
  @override
  String get displayName => 'Replicate';
  @override
  bool get isConfigured => _apiToken != null && _apiToken!.isNotEmpty;
  @override
  void configure(String apiKey) => _apiToken = apiKey;

  Map<String, String> get _headers => {
        'Authorization': 'Bearer $_apiToken',
        'Content-Type': 'application/json',
      };

  @override
  Future<VideoJobSubmission> submitJob({
    required String imageBase64,
    required String prompt,
    int durationSeconds = 5,
    Map<String, dynamic> extraParams = const {},
  }) async {
    final model = extraParams['model'] as String? ?? _defaultModel;

    // Build model-specific input
    final input = <String, dynamic>{
      'prompt': prompt,
    };

    // Add image if provided (img2vid mode)
    if (imageBase64.isNotEmpty) {
      if (model.startsWith('minimax/')) {
        input['first_frame_image'] = 'data:image/jpeg;base64,$imageBase64';
      } else if (model.startsWith('stability-ai/')) {
        input['input_image'] = 'data:image/jpeg;base64,$imageBase64';
      } else {
        input['image'] = 'data:image/jpeg;base64,$imageBase64';
      }
    }

    // Add extra params (excluding our internal keys)
    for (final entry in extraParams.entries) {
      if (entry.key != 'model' && entry.key != 'prompt') {
        input[entry.key] = entry.value;
      }
    }

    final response = await _client.post(
      Uri.parse('$_baseUrl/models/$model/predictions'),
      headers: _headers,
      body: jsonEncode({'input': input}),
    );

    if (response.statusCode != 201 && response.statusCode != 200) {
      final body = jsonDecode(response.body);
      throw Exception(
          'Replicate submit failed: ${body['detail'] ?? response.statusCode}');
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
      Uri.parse('$_baseUrl/predictions/$jobId'),
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
      case 'succeeded':
        final output = data['output'];
        final videoUrl =
            output is List ? output.first as String : output as String;
        return VideoJobStatus(
          state: VideoJobState.completed,
          videoUrl: videoUrl,
          progress: 1.0,
        );
      case 'failed':
      case 'canceled':
        return VideoJobStatus(
          state: VideoJobState.failed,
          error: data['error']?['message'] as String? ?? 'Generation failed',
        );
      case 'processing':
        return VideoJobStatus(
          state: VideoJobState.processing,
          progress: _estimateProgress(data['logs'] as String?),
          statusMessage: 'Generating video...',
        );
      default: // starting, queued
        return VideoJobStatus(
          state: VideoJobState.queued,
          progress: 0.05,
          statusMessage: 'Queued...',
        );
    }
  }

  double _estimateProgress(String? logs) {
    if (logs == null || logs.isEmpty) return 0.2;
    // Replicate logs often contain percentage indicators
    final percentMatch = RegExp(r'(\d+)%').allMatches(logs);
    if (percentMatch.isNotEmpty) {
      final pct = int.tryParse(percentMatch.last.group(1)!) ?? 20;
      return (pct / 100.0).clamp(0.1, 0.95);
    }
    return 0.3;
  }
}
