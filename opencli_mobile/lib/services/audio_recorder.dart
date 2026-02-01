import 'dart:io';
import 'dart:convert';
import 'package:record/record.dart';

/// 音频录制服务 - 录制音频并发送到 Mac 进行识别
class AudioRecorder {
  final AudioRecorder _recorder = AudioRecorder();
  String? _currentRecordingPath;

  /// 开始录音
  Future<void> startRecording() async {
    if (await _recorder.hasPermission()) {
      final tempDir = Directory.systemTemp;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _currentRecordingPath = '${tempDir.path}/recording_$timestamp.m4a';

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          sampleRate: 16000,
          numChannels: 1,
        ),
        path: _currentRecordingPath!,
      );
    } else {
      throw Exception('No permission to record audio');
    }
  }

  /// 停止录音并返回音频数据
  Future<Map<String, dynamic>> stopRecording() async {
    final path = await _recorder.stop();

    if (path == null) {
      throw Exception('Recording failed');
    }

    // 读取音频文件
    final audioFile = File(path);
    final audioBytes = await audioFile.readAsBytes();

    // 转换为 base64
    final base64Audio = base64Encode(audioBytes);

    // 清理临时文件
    await audioFile.delete();

    return {
      'audio': base64Audio,
      'format': 'm4a',
      'sample_rate': 16000,
      'duration_ms': await _getAudioDuration(path),
    };
  }

  /// 取消录音
  Future<void> cancelRecording() async {
    await _recorder.stop();
    if (_currentRecordingPath != null) {
      final file = File(_currentRecordingPath!);
      if (await file.exists()) {
        await file.delete();
      }
    }
  }

  /// 获取音频时长（毫秒）
  Future<int> _getAudioDuration(String path) async {
    // 简化实现，实际应该解析音频文件获取时长
    return 0;
  }

  /// 检查是否正在录音
  Future<bool> isRecording() async {
    return await _recorder.isRecording();
  }

  void dispose() {
    _recorder.dispose();
  }
}
