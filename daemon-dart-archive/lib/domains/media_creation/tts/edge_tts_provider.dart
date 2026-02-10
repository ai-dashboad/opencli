import 'dart:convert';
import 'dart:io';
import 'tts_provider.dart';

/// TTS provider using Microsoft Edge TTS (free, high quality).
///
/// Calls the Python `edge-tts` CLI via subprocess.
/// Supports Chinese, Japanese, English, and 300+ voices.
class EdgeTTSProvider extends TTSProvider {
  String? _pythonPath;

  @override
  String get id => 'edge_tts';
  @override
  String get displayName => 'Edge TTS';
  @override
  bool get isConfigured => true; // Free, no API key needed
  @override
  void configure(String apiKey) {} // No-op — free provider

  /// Set the Python path for subprocess calls.
  void setPythonPath(String path) => _pythonPath = path;

  Future<String> _findPython() async {
    if (_pythonPath != null) return _pythonPath!;

    // Check local-inference venv first
    final home = Platform.environment['HOME'] ?? '/tmp';
    final venvPython = '$home/development/opencli/local-inference/.venv/bin/python';
    if (await File(venvPython).exists()) {
      _pythonPath = venvPython;
      return venvPython;
    }

    // Try system Python
    for (final cmd in ['python3', 'python']) {
      final result = await Process.run('which', [cmd]);
      if (result.exitCode == 0) {
        _pythonPath = (result.stdout as String).trim();
        return _pythonPath!;
      }
    }
    throw Exception('Python not found');
  }

  @override
  Future<TTSResult> synthesize({
    required String text,
    required String voice,
    double rate = 1.0,
    double pitch = 0.0,
    String outputFormat = 'mp3',
  }) async {
    final home = Platform.environment['HOME'] ?? '/tmp';
    final tempDir = '$home/.opencli/media_temp';
    await Directory(tempDir).create(recursive: true);

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final outputPath = '$tempDir/tts_$timestamp.$outputFormat';

    try {
      final pythonPath = await _findPython();
      final ttsScript = '$home/development/opencli/local-inference/tts.py';

      // Build rate string: +0% or -10% or +20%
      final ratePercent = ((rate - 1.0) * 100).round();
      final rateStr =
          ratePercent >= 0 ? '+${ratePercent}%' : '${ratePercent}%';

      // Build pitch string: +0Hz or -5Hz
      final pitchHz = (pitch * 10).round();
      final pitchStr = pitchHz >= 0 ? '+${pitchHz}Hz' : '${pitchHz}Hz';

      final input = jsonEncode({
        'text': text,
        'voice': voice,
        'rate': rateStr,
        'pitch': pitchStr,
        'output_path': outputPath,
      });

      // Use Process.start so we can pipe JSON to stdin
      final process = await Process.start(
        pythonPath,
        [ttsScript],
        environment: Platform.environment,
      );

      process.stdin.write(input);
      await process.stdin.close();

      final stdout = await process.stdout.transform(utf8.decoder).join();
      final stderr = await process.stderr.transform(utf8.decoder).join();
      final exitCode = await process.exitCode;

      if (exitCode != 0) {
        return TTSResult(
          success: false,
          error: 'Edge TTS failed: $stderr',
        );
      }

      // Parse output JSON
      final output = jsonDecode(stdout.trim()) as Map<String, dynamic>;
      if (output['success'] != true) {
        return TTSResult(
          success: false,
          error: output['error'] as String? ?? 'TTS failed',
        );
      }

      // Read the generated audio file
      final audioFile = File(outputPath);
      if (!await audioFile.exists()) {
        return TTSResult(
          success: false,
          error: 'Output audio file not created',
        );
      }

      final audioBytes = await audioFile.readAsBytes();
      final audioBase64 = base64Encode(audioBytes);

      return TTSResult(
        success: true,
        audioBytes: audioBytes,
        audioBase64: audioBase64,
        durationMs: output['duration_ms'] as int?,
        filePath: outputPath,
      );
    } catch (e) {
      return TTSResult(
        success: false,
        error: 'Edge TTS error: $e',
      );
    }
  }

  @override
  Future<List<TTSVoice>> listVoices({String? language}) async {
    // Built-in voice list — Edge TTS has 300+ voices but we list key ones
    final voices = <TTSVoice>[
      // Chinese
      TTSVoice(id: 'zh-CN-XiaoxiaoNeural', name: 'Xiaoxiao (Female)', language: 'zh-CN', gender: 'female', provider: id),
      TTSVoice(id: 'zh-CN-YunxiNeural', name: 'Yunxi (Male)', language: 'zh-CN', gender: 'male', provider: id),
      TTSVoice(id: 'zh-CN-YunjianNeural', name: 'Yunjian (Narrator)', language: 'zh-CN', gender: 'male', provider: id),
      TTSVoice(id: 'zh-CN-XiaoyiNeural', name: 'Xiaoyi (Female)', language: 'zh-CN', gender: 'female', provider: id),
      TTSVoice(id: 'zh-TW-HsiaoChenNeural', name: 'HsiaoChen (TW Female)', language: 'zh-TW', gender: 'female', provider: id),
      // Japanese
      TTSVoice(id: 'ja-JP-NanamiNeural', name: 'Nanami (Female)', language: 'ja-JP', gender: 'female', provider: id),
      TTSVoice(id: 'ja-JP-KeitaNeural', name: 'Keita (Male)', language: 'ja-JP', gender: 'male', provider: id),
      // English
      TTSVoice(id: 'en-US-JennyNeural', name: 'Jenny (Female)', language: 'en-US', gender: 'female', provider: id),
      TTSVoice(id: 'en-US-GuyNeural', name: 'Guy (Male)', language: 'en-US', gender: 'male', provider: id),
      TTSVoice(id: 'en-US-AriaNeural', name: 'Aria (Female)', language: 'en-US', gender: 'female', provider: id),
      TTSVoice(id: 'en-GB-SoniaNeural', name: 'Sonia (UK Female)', language: 'en-GB', gender: 'female', provider: id),
      // Korean
      TTSVoice(id: 'ko-KR-SunHiNeural', name: 'SunHi (Female)', language: 'ko-KR', gender: 'female', provider: id),
      TTSVoice(id: 'ko-KR-InJoonNeural', name: 'InJoon (Male)', language: 'ko-KR', gender: 'male', provider: id),
    ];

    if (language != null) {
      return voices.where((v) => v.language.startsWith(language)).toList();
    }
    return voices;
  }
}
