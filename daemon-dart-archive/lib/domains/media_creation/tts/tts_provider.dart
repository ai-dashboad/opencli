/// Abstract TTS provider interface for text-to-speech synthesis.
///
/// Mirrors the AIVideoProvider pattern — each provider implements
/// synthesize() and listVoices() for a specific backend.
abstract class TTSProvider {
  String get id;
  String get displayName;
  bool get isConfigured;
  void configure(String apiKey);

  /// Synthesize speech from text, returning audio bytes (mp3).
  Future<TTSResult> synthesize({
    required String text,
    required String voice,
    double rate = 1.0,
    double pitch = 0.0,
    String outputFormat = 'mp3',
  });

  /// List available voices for this provider.
  Future<List<TTSVoice>> listVoices({String? language});
}

class TTSResult {
  final bool success;
  final List<int>? audioBytes;
  final String? audioBase64;
  final int? durationMs;
  final String? error;
  final String? filePath;

  TTSResult({
    required this.success,
    this.audioBytes,
    this.audioBase64,
    this.durationMs,
    this.error,
    this.filePath,
  });

  Map<String, dynamic> toJson() => {
        'success': success,
        if (audioBase64 != null) 'audio_base64': audioBase64,
        if (durationMs != null) 'duration_ms': durationMs,
        if (error != null) 'error': error,
        if (filePath != null) 'file_path': filePath,
      };
}

class TTSVoice {
  final String id;
  final String name;
  final String language;
  final String gender;
  final String provider;

  TTSVoice({
    required this.id,
    required this.name,
    required this.language,
    required this.gender,
    required this.provider,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'language': language,
        'gender': gender,
        'provider': provider,
      };
}
