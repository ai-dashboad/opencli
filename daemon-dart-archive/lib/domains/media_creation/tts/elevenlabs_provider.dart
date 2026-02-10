import 'dart:convert';
import 'package:http/http.dart' as http;
import 'tts_provider.dart';

/// TTS provider using ElevenLabs API (paid, premium quality).
class ElevenLabsProvider extends TTSProvider {
  String? _apiKey;
  final _client = http.Client();
  static const _baseUrl = 'https://api.elevenlabs.io/v1';

  @override
  String get id => 'elevenlabs';
  @override
  String get displayName => 'ElevenLabs';
  @override
  bool get isConfigured => _apiKey != null && _apiKey!.isNotEmpty;
  @override
  void configure(String apiKey) => _apiKey = apiKey;

  @override
  Future<TTSResult> synthesize({
    required String text,
    required String voice,
    double rate = 1.0,
    double pitch = 0.0,
    String outputFormat = 'mp3',
  }) async {
    if (!isConfigured) {
      return TTSResult(
        success: false,
        error: 'ElevenLabs API key not configured',
      );
    }

    try {
      final response = await _client.post(
        Uri.parse('$_baseUrl/text-to-speech/$voice'),
        headers: {
          'xi-api-key': _apiKey!,
          'Content-Type': 'application/json',
          'Accept': 'audio/mpeg',
        },
        body: jsonEncode({
          'text': text,
          'model_id': 'eleven_multilingual_v2',
          'voice_settings': {
            'stability': 0.5,
            'similarity_boost': 0.75,
            'style': 0.0,
            'use_speaker_boost': true,
          },
        }),
      );

      if (response.statusCode != 200) {
        final error = jsonDecode(response.body);
        return TTSResult(
          success: false,
          error: 'ElevenLabs error: ${error['detail']?['message'] ?? response.statusCode}',
        );
      }

      final audioBytes = response.bodyBytes;
      final audioBase64 = base64Encode(audioBytes);

      return TTSResult(
        success: true,
        audioBytes: audioBytes,
        audioBase64: audioBase64,
      );
    } catch (e) {
      return TTSResult(
        success: false,
        error: 'ElevenLabs error: $e',
      );
    }
  }

  @override
  Future<List<TTSVoice>> listVoices({String? language}) async {
    if (!isConfigured) return [];

    try {
      final response = await _client.get(
        Uri.parse('$_baseUrl/voices'),
        headers: {'xi-api-key': _apiKey!},
      );

      if (response.statusCode != 200) return [];

      final data = jsonDecode(response.body);
      final voices = (data['voices'] as List)
          .map((v) => TTSVoice(
                id: v['voice_id'] as String,
                name: v['name'] as String,
                language: 'multilingual',
                gender: (v['labels']?['gender'] as String?) ?? 'unknown',
                provider: id,
              ))
          .toList();

      return voices;
    } catch (e) {
      return [];
    }
  }
}
