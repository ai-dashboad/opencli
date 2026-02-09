import 'dart:io';
import 'episode_script.dart';

/// Generates ASS (Advanced SubStation Alpha) subtitle files from dialogue lines.
///
/// ASS format is used over SRT because it supports:
/// - Styled text with fonts, colors, borders
/// - Positioning (top/bottom/center)
/// - Fade in/out effects
/// - Character name colors
class SubtitleGenerator {
  /// Default ASS style settings for anime subtitles.
  static const _defaultStyle = 'Style: Default,'
      'Microsoft YaHei,28,'
      '&H00FFFFFF,&H000000FF,&H00000000,&H64000000,'
      '-1,0,0,0,100,100,0,0,1,2,1,2,10,10,25,1';

  /// Style for character names (slightly smaller, colored).
  static const _nameStyle = 'Style: Name,'
      'Microsoft YaHei,22,'
      '&H0000FFFF,&H000000FF,&H00000000,&H64000000,'
      '-1,0,0,0,100,100,0,0,1,1,0,2,10,10,25,1';

  /// Generate an ASS subtitle file for a single scene.
  Future<String> generateForScene({
    required EpisodeScene scene,
    required List<CharacterDefinition> characters,
    required String outputPath,
  }) async {
    final buffer = StringBuffer();
    _writeHeader(buffer);
    _writeStyles(buffer, characters);
    buffer.writeln('[Events]');
    buffer.writeln('Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text');

    double currentTime = 0;
    for (final line in scene.dialogue) {
      final character = characters
          .where((c) => c.id == line.characterId)
          .firstOrNull;
      final charName = character?.name ?? line.characterId;
      final duration = line.estimatedDurationSeconds;
      final start = _formatTime(currentTime);
      final end = _formatTime(currentTime + duration);

      // Add character name line (top, smaller)
      if (line.characterId != 'narrator') {
        buffer.writeln('Dialogue: 0,$start,$end,Name,,0,0,0,,{\\pos(320,420)}$charName');
      }

      // Add dialogue text (bottom, main style)
      buffer.writeln('Dialogue: 1,$start,$end,Default,,0,0,0,,${ _escapeAss(line.text)}');

      currentTime += duration + 0.3; // Small gap between lines
    }

    await File(outputPath).writeAsString(buffer.toString());
    return outputPath;
  }

  /// Generate ASS for the entire episode (all scenes concatenated).
  Future<String> generateForEpisode({
    required EpisodeScript script,
    required String outputPath,
    required List<double> sceneStartTimes,
  }) async {
    final buffer = StringBuffer();
    _writeHeader(buffer);
    _writeStyles(buffer, script.characters);
    buffer.writeln('[Events]');
    buffer.writeln('Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text');

    for (int i = 0; i < script.scenes.length; i++) {
      final scene = script.scenes[i];
      final sceneStart = i < sceneStartTimes.length ? sceneStartTimes[i] : 0.0;
      double lineStart = sceneStart;

      for (final line in scene.dialogue) {
        final character = script.characters
            .where((c) => c.id == line.characterId)
            .firstOrNull;
        final charName = character?.name ?? line.characterId;
        final duration = line.estimatedDurationSeconds;
        final start = _formatTime(lineStart);
        final end = _formatTime(lineStart + duration);

        if (line.characterId != 'narrator') {
          buffer.writeln('Dialogue: 0,$start,$end,Name,,0,0,0,,{\\pos(320,420)}$charName');
        }
        buffer.writeln('Dialogue: 1,$start,$end,Default,,0,0,0,,${_escapeAss(line.text)}');

        lineStart += duration + 0.3;
      }
    }

    await File(outputPath).writeAsString(buffer.toString());
    return outputPath;
  }

  void _writeHeader(StringBuffer buf) {
    buf.writeln('[Script Info]');
    buf.writeln('Title: OpenCLI Episode');
    buf.writeln('ScriptType: v4.00+');
    buf.writeln('WrapStyle: 0');
    buf.writeln('ScaledBorderAndShadow: yes');
    buf.writeln('PlayResX: 1920');
    buf.writeln('PlayResY: 1080');
    buf.writeln('');
  }

  void _writeStyles(StringBuffer buf, List<CharacterDefinition> characters) {
    buf.writeln('[V4+ Styles]');
    buf.writeln('Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding');
    buf.writeln(_defaultStyle);
    buf.writeln(_nameStyle);
    buf.writeln('');
  }

  /// Format seconds to ASS time: H:MM:SS.CC
  String _formatTime(double seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    final cs = ((s - s.floor()) * 100).round();
    return '${h}:${m.toString().padLeft(2, '0')}:${s.floor().toString().padLeft(2, '0')}.${cs.toString().padLeft(2, '0')}';
  }

  /// Escape text for ASS format.
  String _escapeAss(String text) {
    return text
        .replaceAll(r'\', r'\\')
        .replaceAll('{', r'\{')
        .replaceAll('}', r'\}')
        .replaceAll('\n', r'\N');
  }
}
