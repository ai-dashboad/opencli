import 'dart:io';
import 'dart:convert';
import 'dart:async';
import '../core/plugin.dart';

/// 语音识别插件 - 使用 Whisper 或 macOS 原生 API
class SpeechRecognitionPlugin extends Plugin {
  @override
  String get name => 'speech_recognition';

  @override
  String get version => '1.0.0';

  @override
  String get description => 'Speech to text using Whisper or native APIs';

  String _whisperModel = 'base'; // tiny, base, small, medium, large
  bool _useWhisper = true;

  @override
  Future<void> initialize() async {
    print('🎤 Initializing Speech Recognition Plugin...');

    // 检查 Whisper 是否可用
    try {
      final result = await Process.run('which', ['whisper']);
      if (result.exitCode == 0) {
        print('✓ Whisper found: ${result.stdout.toString().trim()}');
        _useWhisper = true;
      } else {
        print('⚠️  Whisper not found, will use macOS native API');
        _useWhisper = false;
      }
    } catch (e) {
      print('⚠️  Could not check for Whisper: $e');
      _useWhisper = false;
    }

    print('✓ Speech Recognition Plugin initialized');
  }

  @override
  Future<Map<String, dynamic>> handleTask(
    String taskType,
    Map<String, dynamic> taskData,
  ) async {
    if (taskType == 'speech_to_text') {
      return await _transcribeAudio(taskData);
    }

    throw UnimplementedError('Task type $taskType not supported');
  }

  /// 转换音频为文字
  Future<Map<String, dynamic>> _transcribeAudio(
    Map<String, dynamic> data,
  ) async {
    final audioData = data['audio'] as String?; // base64 encoded
    final audioPath = data['audio_path'] as String?;
    final language = data['language'] as String? ?? 'Chinese';

    String tempAudioFile;

    if (audioPath != null) {
      tempAudioFile = audioPath;
    } else if (audioData != null) {
      // 保存 base64 音频到临时文件
      tempAudioFile = await _saveAudioData(audioData);
    } else {
      throw ArgumentError('Either audio or audio_path must be provided');
    }

    try {
      String transcription;

      if (_useWhisper) {
        transcription = await _transcribeWithWhisper(tempAudioFile, language);
      } else {
        transcription = await _transcribeWithMacOS(tempAudioFile);
      }

      return {
        'success': true,
        'text': transcription,
        'method': _useWhisper ? 'whisper' : 'macos_native',
        'language': language,
      };
    } catch (e) {
      return {
        'success': false,
        'error': e.toString(),
      };
    } finally {
      // 清理临时文件
      if (audioPath == null && audioData != null) {
        await File(tempAudioFile).delete();
      }
    }
  }

  /// 使用 Whisper 转录
  Future<String> _transcribeWithWhisper(
    String audioPath,
    String language,
  ) async {
    print('🎤 Transcribing with Whisper (model: $_whisperModel)...');

    final result = await Process.run('whisper', [
      audioPath,
      '--model',
      _whisperModel,
      '--language',
      language,
      '--output_format',
      'txt',
      '--output_dir',
      '/tmp',
    ]);

    if (result.exitCode != 0) {
      throw Exception('Whisper failed: ${result.stderr}');
    }

    // 读取输出文件
    final audioFileName = audioPath.split('/').last.split('.').first;
    final outputFile = File('/tmp/$audioFileName.txt');

    if (await outputFile.exists()) {
      final text = await outputFile.readAsString();
      await outputFile.delete();
      return text.trim();
    }

    throw Exception('Whisper output file not found');
  }

  /// 使用 macOS 原生 API 转录
  Future<String> _transcribeWithMacOS(String audioPath) async {
    print('🎤 Transcribing with macOS native API...');

    // 使用 AppleScript 调用 macOS 语音识别
    final script = '''
on run argv
    set audioFile to item 1 of argv
    tell application "System Events"
        -- macOS doesn't have direct command-line speech recognition
        -- This is a placeholder for native implementation
        return "macOS native recognition not implemented yet"
    end tell
end run
''';

    final tempScript = await File('/tmp/speech_recognition.scpt').create();
    await tempScript.writeAsString(script);

    final result = await Process.run('osascript', [
      tempScript.path,
      audioPath,
    ]);

    await tempScript.delete();

    if (result.exitCode != 0) {
      throw Exception('macOS recognition failed: ${result.stderr}');
    }

    return result.stdout.toString().trim();
  }

  /// 保存 base64 音频数据到临时文件
  Future<String> _saveAudioData(String base64Audio) async {
    final bytes = base64Decode(base64Audio);
    final tempFile =
        File('/tmp/audio_${DateTime.now().millisecondsSinceEpoch}.m4a');
    await tempFile.writeAsBytes(bytes);
    return tempFile.path;
  }

  @override
  Future<void> dispose() async {
    print('🎤 Speech Recognition Plugin disposed');
  }

  @override
  List<String> get supportedTaskTypes => ['speech_to_text'];
}
