import 'package:http/http.dart' as http;

/// State of an AI video generation job.
enum VideoJobState { queued, processing, completed, failed }

/// Result of submitting a video generation job.
class VideoJobSubmission {
  final String jobId;
  final String provider;
  final DateTime submittedAt;

  VideoJobSubmission({
    required this.jobId,
    required this.provider,
    required this.submittedAt,
  });
}

/// Status of a video generation job being polled.
class VideoJobStatus {
  final VideoJobState state;
  final double? progress;
  final String? videoUrl;
  final String? error;
  final String? statusMessage;

  VideoJobStatus({
    required this.state,
    this.progress,
    this.videoUrl,
    this.error,
    this.statusMessage,
  });
}

/// Abstract interface for AI video generation providers.
/// Each provider implements async job lifecycle: submit → poll → download.
abstract class AIVideoProvider {
  /// Provider identifier (e.g., 'replicate', 'runway', 'kling', 'luma')
  String get id;

  /// Human-readable display name
  String get displayName;

  /// Whether the provider has a valid API key configured
  bool get isConfigured;

  /// Configure with API key
  void configure(String apiKey);

  /// Submit an image-to-video generation job.
  /// Returns a job submission with an ID for polling.
  Future<VideoJobSubmission> submitJob({
    required String imageBase64,
    required String prompt,
    int durationSeconds = 5,
    Map<String, dynamic> extraParams = const {},
  });

  /// Poll the status of a submitted job.
  Future<VideoJobStatus> pollJob(String jobId);

  /// Download the completed video as bytes.
  Future<List<int>> downloadVideo(String videoUrl) async {
    final response = await http.get(Uri.parse(videoUrl));
    if (response.statusCode == 200) {
      return response.bodyBytes;
    }
    throw Exception('Failed to download video: HTTP ${response.statusCode}');
  }
}
