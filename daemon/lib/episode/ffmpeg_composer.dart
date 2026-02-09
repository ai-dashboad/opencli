import 'dart:convert';
import 'dart:io';
import '../domains/media_creation/local_model_manager.dart';

/// FFmpeg-based audio/video composition toolkit for episode assembly.
///
/// Provides: audio mixing, subtitle overlay, scene transitions,
/// and final episode assembly from individual scene clips.
class FFmpegComposer {
  String? _ffmpegPath;

  Future<String> _ensureFFmpeg() async {
    if (_ffmpegPath != null) return _ffmpegPath!;
    final result = await Process.run('which', ['ffmpeg']);
    if (result.exitCode != 0) {
      throw Exception('FFmpeg not installed. Install via: brew install ffmpeg');
    }
    _ffmpegPath = (result.stdout as String).trim();
    return _ffmpegPath!;
  }

  /// Mix voice audio with background music.
  ///
  /// Voice is kept at full volume, BGM is reduced to [bgmVolume] (0.0-1.0).
  Future<String> mixAudio({
    required String voicePath,
    required String bgmPath,
    required String outputPath,
    double bgmVolume = 0.3,
  }) async {
    final ffmpeg = await _ensureFFmpeg();

    final isMP3 = outputPath.endsWith('.mp3');
    final codec = isMP3 ? 'libmp3lame' : 'aac';

    final result = await Process.run(ffmpeg, [
      '-y',
      '-i', voicePath,
      '-i', bgmPath,
      '-filter_complex',
      '[0:a]volume=1.0[v];[1:a]volume=$bgmVolume,aloop=loop=-1:size=2e+09[b];[v][b]amix=inputs=2:duration=first:dropout_transition=2',
      '-c:a', codec,
      '-b:a', '192k',
      outputPath,
    ]).timeout(const Duration(seconds: 120));

    if (result.exitCode != 0) {
      throw Exception('Audio mix failed: ${_lastLine(result.stderr as String)}');
    }
    return outputPath;
  }

  /// Concatenate multiple voice clips into a single audio file.
  ///
  /// Uses filter_complex concat filter instead of concat demuxer
  /// to handle mp3 files with different sample rates/formats.
  Future<String> concatAudio({
    required List<String> audioPaths,
    required String outputPath,
  }) async {
    if (audioPaths.isEmpty) throw Exception('No audio files to concatenate');
    if (audioPaths.length == 1) {
      await File(audioPaths.first).copy(outputPath);
      return outputPath;
    }

    final ffmpeg = await _ensureFFmpeg();

    // Build filter_complex: normalize all inputs then concat
    final inputs = <String>[];
    final filterParts = <String>[];
    for (int i = 0; i < audioPaths.length; i++) {
      inputs.addAll(['-i', audioPaths[i]]);
      filterParts.add('[$i:a]aresample=44100,aformat=sample_fmts=fltp:channel_layouts=stereo[a$i]');
    }
    final concatInputs = List.generate(audioPaths.length, (i) => '[a$i]').join();
    final filterComplex = '${filterParts.join(';')};${concatInputs}concat=n=${audioPaths.length}:v=0:a=1[out]';

    try {
      // Use libmp3lame for .mp3 output, aac for .m4a/.mp4
      final isMP3 = outputPath.endsWith('.mp3');
      final codec = isMP3 ? 'libmp3lame' : 'aac';

      final result = await Process.run(ffmpeg, [
        '-y',
        ...inputs,
        '-filter_complex', filterComplex,
        '-map', '[out]',
        '-c:a', codec,
        '-b:a', '192k',
        outputPath,
      ]).timeout(const Duration(seconds: 60));

      if (result.exitCode != 0) {
        throw Exception('Audio concat failed: ${_lastLine(result.stderr as String)}');
      }
      return outputPath;
    } catch (e) {
      if (e is Exception && e.toString().contains('Audio concat failed')) rethrow;
      throw Exception('Audio concat error: $e');
    }
  }

  /// Add subtitles to video as a soft subtitle stream (mov_text).
  ///
  /// Uses mov_text codec (MP4 timed text) which is supported by most players.
  /// This avoids requiring libass/libfreetype compiled into FFmpeg.
  /// Video and audio streams are copied without re-encoding.
  Future<String> addSubtitles({
    required String videoPath,
    required String assPath,
    required String outputPath,
  }) async {
    final ffmpeg = await _ensureFFmpeg();

    final result = await Process.run(ffmpeg, [
      '-y',
      '-i', videoPath,
      '-i', assPath,
      '-c:v', 'copy',
      '-c:a', 'copy',
      '-c:s', 'mov_text',
      '-movflags', '+faststart',
      outputPath,
    ]).timeout(const Duration(seconds: 120));

    if (result.exitCode != 0) {
      throw Exception('Subtitle overlay failed: ${_lastLine(result.stderr as String)}');
    }
    return outputPath;
  }

  /// Apply a transition between two video clips.
  ///
  /// Supported transitions: fade, dissolve, wipeleft, wiperight, slidedown
  Future<String> applyTransition({
    required String clipAPath,
    required String clipBPath,
    required String outputPath,
    String transition = 'fade',
    double durationSeconds = 1.0,
  }) async {
    final ffmpeg = await _ensureFFmpeg();

    // Get duration of clip A for offset calculation
    final probeResult = await Process.run('ffprobe', [
      '-v', 'error',
      '-show_entries', 'format=duration',
      '-of', 'default=noprint_wrappers=1:nokey=1',
      clipAPath,
    ]);
    final clipADuration = double.tryParse(
        (probeResult.stdout as String).trim()) ?? 5.0;
    final offset = (clipADuration - durationSeconds).clamp(0.0, clipADuration);

    // Check if inputs have audio streams
    final hasAudioA = await _hasAudioStream(clipAPath);
    final hasAudioB = await _hasAudioStream(clipBPath);

    final filterComplex = hasAudioA && hasAudioB
        ? '[0:v][1:v]xfade=transition=$transition:duration=$durationSeconds:offset=$offset[v];'
          '[0:a][1:a]acrossfade=d=$durationSeconds:c1=tri:c2=tri[a]'
        : '[0:v][1:v]xfade=transition=$transition:duration=$durationSeconds:offset=$offset[v]';

    final mapArgs = hasAudioA && hasAudioB
        ? ['-map', '[v]', '-map', '[a]']
        : ['-map', '[v]'];

    final result = await Process.run(ffmpeg, [
      '-y',
      '-i', clipAPath,
      '-i', clipBPath,
      '-filter_complex', filterComplex,
      ...mapArgs,
      '-c:v', 'libx264',
      '-preset', 'medium',
      '-crf', '18',
      '-pix_fmt', 'yuv420p',
      if (hasAudioA && hasAudioB) ...['-c:a', 'aac', '-b:a', '192k'],
      outputPath,
    ]).timeout(const Duration(seconds: 120));

    if (result.exitCode != 0) {
      throw Exception('Transition failed: ${_lastLine(result.stderr as String)}');
    }
    return outputPath;
  }

  /// Concatenate video clips sequentially (no transition).
  Future<String> concatVideos({
    required List<String> videoPaths,
    required String outputPath,
  }) async {
    if (videoPaths.isEmpty) throw Exception('No video files to concatenate');
    if (videoPaths.length == 1) {
      await File(videoPaths.first).copy(outputPath);
      return outputPath;
    }

    final ffmpeg = await _ensureFFmpeg();
    final tempDir = Directory.systemTemp.createTempSync('opencli_video_');
    final concatFile = File('${tempDir.path}/concat.txt');
    final lines = videoPaths.map((p) => "file '$p'").join('\n');
    await concatFile.writeAsString(lines);

    try {
      final result = await Process.run(ffmpeg, [
        '-y',
        '-f', 'concat',
        '-safe', '0',
        '-i', concatFile.path,
        '-c', 'copy',
        '-movflags', '+faststart',
        outputPath,
      ]).timeout(const Duration(seconds: 180));

      if (result.exitCode != 0) {
        throw Exception('Video concat failed: ${_lastLine(result.stderr as String)}');
      }
      return outputPath;
    } finally {
      try { tempDir.deleteSync(recursive: true); } catch (_) {}
    }
  }

  /// Combine a video and audio track into a single file.
  Future<String> muxVideoAudio({
    required String videoPath,
    required String audioPath,
    required String outputPath,
  }) async {
    final ffmpeg = await _ensureFFmpeg();

    // Pad audio to match video length (or vice versa) to avoid clipping.
    // Use -shortest only if audio is longer than video — pad audio with silence otherwise.
    final videoDuration = await getVideoDuration(videoPath);
    final audioDuration = await getVideoDuration(audioPath);
    final useAudioPad = audioDuration < videoDuration;

    final args = <String>[
      '-y',
      '-i', videoPath,
      '-i', audioPath,
    ];

    if (useAudioPad) {
      // Pad short audio with silence to match video length
      args.addAll([
        '-filter_complex', '[1:a]apad=whole_dur=$videoDuration[a]',
        '-map', '0:v',
        '-map', '[a]',
        '-c:v', 'copy',
        '-c:a', 'aac',
        '-b:a', '192k',
      ]);
    } else {
      args.addAll([
        '-c:v', 'copy',
        '-c:a', 'aac',
        '-b:a', '192k',
        '-shortest', // Trim audio to video length
      ]);
    }

    args.addAll(['-movflags', '+faststart', outputPath]);

    final result = await Process.run(ffmpeg, args)
        .timeout(const Duration(seconds: 120));

    if (result.exitCode != 0) {
      throw Exception('Mux failed: ${_lastLine(result.stderr as String)}');
    }
    return outputPath;
  }

  /// Full episode assembly: video + audio + soft subtitles in one step.
  ///
  /// Muxes all streams together: video (copy), audio (aac), subtitles (mov_text).
  /// If subtitles fail, falls back to video+audio without subtitles.
  Future<String> assembleEpisode({
    required String videoPath,
    required String audioPath,
    required String? assSubtitlePath,
    required String outputPath,
  }) async {
    final ffmpeg = await _ensureFFmpeg();
    final hasSubs = assSubtitlePath != null &&
        await File(assSubtitlePath).exists();

    // Try single-step mux with all streams (video + audio + subs)
    if (hasSubs) {
      try {
        // Pad audio with silence if shorter than video
        final videoDuration = await getVideoDuration(videoPath);
        final audioDuration = await getVideoDuration(audioPath);

        final args = <String>['-y', '-i', videoPath, '-i', audioPath, '-i', assSubtitlePath];
        if (audioDuration < videoDuration) {
          args.addAll([
            '-filter_complex', '[1:a]apad=whole_dur=$videoDuration[a]',
            '-map', '0:v', '-map', '[a]', '-map', '2',
            '-c:v', 'copy', '-c:a', 'aac', '-b:a', '192k', '-c:s', 'mov_text',
          ]);
        } else {
          args.addAll([
            '-c:v', 'copy', '-c:a', 'aac', '-b:a', '192k', '-c:s', 'mov_text', '-shortest',
          ]);
        }
        args.addAll(['-movflags', '+faststart', outputPath]);

        final result = await Process.run(ffmpeg, args)
            .timeout(const Duration(seconds: 120));

        if (result.exitCode == 0) return outputPath;
        print('[FFmpegComposer] 3-stream mux failed, falling back to video+audio: '
            '${_lastLine(result.stderr as String)}');
      } catch (e) {
        print('[FFmpegComposer] 3-stream mux error: $e');
      }
    }

    // Fallback: video + audio only
    await muxVideoAudio(
      videoPath: videoPath,
      audioPath: audioPath,
      outputPath: outputPath,
    );
    return outputPath;
  }

  /// Apply a 3D LUT color grade to a video file.
  Future<String?> applyLUT({
    required String inputPath,
    required String outputPath,
    required String lutPath,
    String interpolation = 'tetrahedral',
  }) async {
    final ffmpeg = await _ensureFFmpeg();

    final result = await Process.run(ffmpeg, [
      '-y',
      '-i', inputPath,
      '-vf', "lut3d='$lutPath':interp=$interpolation",
      '-c:v', 'libx264',
      '-preset', 'medium',
      '-crf', '18',
      '-pix_fmt', 'yuv420p',
      '-c:a', 'copy',
      '-movflags', '+faststart',
      outputPath,
    ]).timeout(const Duration(seconds: 180));

    return result.exitCode == 0 ? outputPath : null;
  }

  /// Encode a video for a specific platform (YouTube, TikTok, e-commerce).
  Future<String> encodeForPlatform({
    required String inputPath,
    required String outputPath,
    required String platform,
  }) async {
    final ffmpeg = await _ensureFFmpeg();

    final (scale, bitrate, fps, preset) = switch (platform) {
      'youtube' => ('1920:1080', '12M', '24', 'slow'),
      'tiktok' => ('1080:1920', '8M', '30', 'medium'),
      'ecommerce' => ('720:1280', '6M', '30', 'faster'),
      _ => ('1920:1080', '10M', '24', 'medium'),
    };

    final result = await Process.run(ffmpeg, [
      '-y',
      '-i', inputPath,
      '-vf', 'scale=$scale:flags=lanczos',
      '-c:v', 'libx264',
      '-b:v', bitrate,
      '-r', fps,
      '-preset', preset,
      '-pix_fmt', 'yuv420p',
      '-c:a', 'aac',
      '-b:a', '192k',
      '-movflags', '+faststart',
      outputPath,
    ]).timeout(const Duration(minutes: 5));

    if (result.exitCode != 0) {
      throw Exception('Platform encode failed: ${_lastLine(result.stderr as String)}');
    }
    return outputPath;
  }

  /// Get video duration in seconds.
  Future<double> getVideoDuration(String videoPath) async {
    final result = await Process.run('ffprobe', [
      '-v', 'error',
      '-show_entries', 'format=duration',
      '-of', 'default=noprint_wrappers=1:nokey=1',
      videoPath,
    ]);
    return double.tryParse((result.stdout as String).trim()) ?? 0;
  }

  /// Check if a media file contains an audio stream.
  Future<bool> _hasAudioStream(String path) async {
    final result = await Process.run('ffprobe', [
      '-v', 'error',
      '-select_streams', 'a',
      '-show_entries', 'stream=codec_type',
      '-of', 'csv=p=0',
      path,
    ]);
    return (result.stdout as String).trim().isNotEmpty;
  }

  String _lastLine(String text) {
    final lines = text.trim().split('\n').where((l) => l.isNotEmpty).toList();
    return lines.isNotEmpty ? lines.last : 'Unknown FFmpeg error';
  }
}

/// Generate built-in .cube LUT files for color grading presets.
///
/// Each LUT is a 17x17x17 3D lookup table in Adobe .cube format.
/// These are programmatically generated — no external files needed.
Future<void> ensureBuiltinLUTs() async {
  final home = Platform.environment['HOME'] ?? '/tmp';
  final lutDir = Directory('$home/.opencli/luts');
  await lutDir.create(recursive: true);

  final luts = <String, String Function(double r, double g, double b)>{
    'anime_cinematic': (r, g, b) {
      // Warm highlights + cool shadows + high contrast
      final lum = 0.299 * r + 0.587 * g + 0.114 * b;
      final contrast = 1.15;
      final rr = ((r - 0.5) * contrast + 0.5 + 0.02).clamp(0.0, 1.0);
      final gg = ((g - 0.5) * contrast + 0.5 - 0.01).clamp(0.0, 1.0);
      final bb = ((b - 0.5) * contrast + 0.5 + 0.05).clamp(0.0, 1.0);
      // Warm highlights
      final warmR = lum > 0.5 ? rr + 0.03 : rr;
      final warmB = lum < 0.5 ? bb + 0.02 : bb;
      return '${warmR.clamp(0.0, 1.0)} ${gg.clamp(0.0, 1.0)} ${warmB.clamp(0.0, 1.0)}';
    },
    'golden_hour': (r, g, b) {
      // Golden warm tone
      final rr = (r * 1.08 + 0.03).clamp(0.0, 1.0);
      final gg = (g * 1.02 + 0.02).clamp(0.0, 1.0);
      final bb = (b * 0.85).clamp(0.0, 1.0);
      return '$rr $gg $bb';
    },
    'moonlit': (r, g, b) {
      // Cool blue desaturated
      final lum = 0.299 * r + 0.587 * g + 0.114 * b;
      final desat = 0.7;
      final rr = (lum + (r - lum) * desat - 0.02).clamp(0.0, 1.0);
      final gg = (lum + (g - lum) * desat - 0.01).clamp(0.0, 1.0);
      final bb = (lum + (b - lum) * desat + 0.06).clamp(0.0, 1.0);
      return '$rr $gg $bb';
    },
    'neon_city': (r, g, b) {
      // High saturation cyan-purple
      final sat = 1.3;
      final lum = 0.299 * r + 0.587 * g + 0.114 * b;
      final rr = (lum + (r - lum) * sat + 0.02).clamp(0.0, 1.0);
      final gg = (lum + (g - lum) * sat + 0.03).clamp(0.0, 1.0);
      final bb = (lum + (b - lum) * sat + 0.05).clamp(0.0, 1.0);
      return '$rr $gg $bb';
    },
    'sakura': (r, g, b) {
      // Soft pink highlights
      final lum = 0.299 * r + 0.587 * g + 0.114 * b;
      final rr = (r * 1.05 + (lum > 0.6 ? 0.04 : 0.0)).clamp(0.0, 1.0);
      final gg = (g * 0.98).clamp(0.0, 1.0);
      final bb = (b * 1.02 + (lum > 0.6 ? 0.02 : 0.0)).clamp(0.0, 1.0);
      return '$rr $gg $bb';
    },
    'film_noir': (r, g, b) {
      // Desaturated high contrast
      final lum = 0.299 * r + 0.587 * g + 0.114 * b;
      final desat = 0.4;
      final contrast = 1.25;
      final ll = ((lum - 0.5) * contrast + 0.5).clamp(0.0, 1.0);
      final rr = (ll + (r - lum) * desat).clamp(0.0, 1.0);
      final gg = (ll + (g - lum) * desat).clamp(0.0, 1.0);
      final bb = (ll + (b - lum) * desat).clamp(0.0, 1.0);
      return '$rr $gg $bb';
    },
  };

  for (final entry in luts.entries) {
    final file = File('${lutDir.path}/${entry.key}.cube');
    if (await file.exists()) continue; // Don't regenerate

    final buf = StringBuffer();
    buf.writeln('# OpenCLI ${entry.key} LUT');
    buf.writeln('TITLE "${entry.key}"');
    buf.writeln('LUT_3D_SIZE 17');
    buf.writeln('');

    const size = 17;
    for (int bi = 0; bi < size; bi++) {
      for (int gi = 0; gi < size; gi++) {
        for (int ri = 0; ri < size; ri++) {
          final r = ri / (size - 1);
          final g = gi / (size - 1);
          final b = bi / (size - 1);
          buf.writeln(entry.value(r, g, b));
        }
      }
    }

    await file.writeAsString(buf.toString());
    print('[LUT] Generated ${entry.key}.cube');
  }
}

/// Quality tier for episode generation.
enum QualityTier { draft, standard, cinematic }

/// Color grading profile for cinematic post-processing.
enum ColorProfile { animeCinematic, warmGolden, coolNoir }

/// 4-step cinematic post-processing pipeline per shot.
///
/// Step 1: Real-ESRGAN 4x upscale (image or video frames)
/// Step 2: RIFE 2x frame interpolation (12fps -> 24fps)
/// Step 3: FFmpeg color grading (eq + curves + colorbalance)
/// Step 4: FFmpeg film effects (noise grain + vignette)
class CinematicPostProcessor {
  final LocalModelManager localModelManager;
  final FFmpegComposer ffmpegComposer;

  CinematicPostProcessor({
    required this.localModelManager,
    required this.ffmpegComposer,
  });

  /// Apply the full post-processing pipeline to a video clip.
  ///
  /// Returns the path to the post-processed video.
  /// Steps are skipped based on [tier].
  Future<String> processShot({
    required String videoPath,
    required String workDir,
    required String shotId,
    QualityTier tier = QualityTier.standard,
    ColorProfile colorProfile = ColorProfile.animeCinematic,
    String? lutFile,
  }) async {
    var currentPath = videoPath;

    if (tier == QualityTier.draft) {
      return currentPath; // No post-processing for draft
    }

    // Step 1: Real-ESRGAN video upscale (standard + cinematic)
    // Try per-frame Real-ESRGAN first (best quality), fallback to Lanczos
    try {
      final upscaledPath = '$workDir/${shotId}_upscaled.mp4';
      final upscaled = await _upscaleVideoRealESRGAN(currentPath, upscaledPath);
      if (upscaled != null) {
        currentPath = upscaled;
        print('[PostProcessor] Real-ESRGAN upscaled: $shotId');
      } else {
        // Fallback: Lanczos
        final lanczosPath = '$workDir/${shotId}_upscaled_lanczos.mp4';
        final lanczos = await _upscaleVideoLanczos(currentPath, lanczosPath);
        if (lanczos != null) {
          currentPath = lanczos;
          print('[PostProcessor] Lanczos upscaled: $shotId');
        }
      }
    } catch (e) {
      print('[PostProcessor] Upscale skipped for $shotId: $e');
    }

    // Step 2: RIFE interpolation (standard + cinematic)
    try {
      final result = await localModelManager.interpolateVideo(
        videoPath: currentPath,
        multiplier: 2,
      );
      if (result['success'] == true && result['video_path'] != null) {
        currentPath = result['video_path'] as String;
        print('[PostProcessor] RIFE interpolated: $shotId');
      }
    } catch (e) {
      print('[PostProcessor] RIFE skipped for $shotId: $e');
    }

    // Step 3: Color grade — LUT if provided, otherwise eq+colorbalance
    try {
      final gradedPath = '$workDir/${shotId}_graded.mp4';
      final graded = await _colorGrade(
        currentPath, gradedPath, colorProfile, lutFile: lutFile);
      if (graded != null) {
        currentPath = graded;
        print('[PostProcessor] Color graded: $shotId');
      }
    } catch (e) {
      print('[PostProcessor] Color grade skipped for $shotId: $e');
    }

    // Step 4: Film effects (cinematic only)
    if (tier == QualityTier.cinematic) {
      try {
        final filmPath = '$workDir/${shotId}_film.mp4';
        final film = await _applyFilmEffects(currentPath, filmPath);
        if (film != null) {
          currentPath = film;
          print('[PostProcessor] Film effects applied: $shotId');
        }
      } catch (e) {
        print('[PostProcessor] Film effects skipped for $shotId: $e');
      }
    }

    return currentPath;
  }

  /// Upscale video per-frame using Real-ESRGAN via Python subprocess.
  Future<String?> _upscaleVideoRealESRGAN(
    String inputPath, String outputPath,
  ) async {
    try {
      final result = await localModelManager.upscaleVideoPath(
        videoPath: inputPath,
        scale: 4,
      );
      if (result['success'] == true && result['video_path'] != null) {
        final srcPath = result['video_path'] as String;
        if (srcPath != outputPath) {
          await File(srcPath).copy(outputPath);
        }
        return outputPath;
      }
    } catch (e) {
      print('[PostProcessor] Real-ESRGAN video upscale failed: $e');
    }
    return null;
  }

  /// Fallback: Upscale video using FFmpeg Lanczos (fast but lower quality).
  Future<String?> _upscaleVideoLanczos(
    String inputPath, String outputPath,
  ) async {
    final ffmpeg = await ffmpegComposer._ensureFFmpeg();

    final result = await Process.run(ffmpeg, [
      '-y',
      '-i', inputPath,
      '-vf', 'scale=1920:1080:flags=lanczos',
      '-c:v', 'libx264',
      '-preset', 'medium',
      '-crf', '18',
      '-pix_fmt', 'yuv420p',
      '-c:a', 'copy',
      '-movflags', '+faststart',
      outputPath,
    ]).timeout(const Duration(seconds: 120));

    return result.exitCode == 0 ? outputPath : null;
  }

  /// Apply color grading — LUT-based if a .cube file is provided,
  /// otherwise fallback to eq + colorbalance filters.
  Future<String?> _colorGrade(
    String inputPath,
    String outputPath,
    ColorProfile profile, {
    String? lutFile,
  }) async {
    final ffmpeg = await ffmpegComposer._ensureFFmpeg();

    String filter;

    if (lutFile != null && await File(lutFile).exists()) {
      // LUT-based color grading (tetrahedral interpolation for best quality)
      filter = "lut3d='$lutFile':interp=tetrahedral";
    } else {
      // Fallback: eq + colorbalance filters
      filter = switch (profile) {
        ColorProfile.animeCinematic =>
          'eq=contrast=1.1:brightness=0.02:saturation=1.15,'
          'colorbalance=rs=0.02:gs=-0.01:bs=0.05:rh=0.03:bh=0.02',
        ColorProfile.warmGolden =>
          'eq=contrast=1.05:brightness=0.03:saturation=1.2,'
          'colorbalance=rs=0.05:gs=0.02:bs=-0.03:rh=0.04:gh=0.02',
        ColorProfile.coolNoir =>
          'eq=contrast=1.15:brightness=-0.02:saturation=0.85,'
          'colorbalance=rs=-0.02:gs=-0.01:bs=0.06:rh=-0.02:bh=0.05',
      };
    }

    final result = await Process.run(ffmpeg, [
      '-y',
      '-i', inputPath,
      '-vf', filter,
      '-c:v', 'libx264',
      '-preset', 'medium',
      '-crf', '18',
      '-pix_fmt', 'yuv420p',
      '-c:a', 'copy',
      outputPath,
    ]).timeout(const Duration(seconds: 120));

    return result.exitCode == 0 ? outputPath : null;
  }

  /// Apply film grain and vignette for cinematic look.
  Future<String?> _applyFilmEffects(String inputPath, String outputPath) async {
    final ffmpeg = await ffmpegComposer._ensureFFmpeg();

    // Light film grain + vignette
    final filter = 'noise=alls=4:allf=t+u,vignette=angle=PI/5';

    final result = await Process.run(ffmpeg, [
      '-y',
      '-i', inputPath,
      '-vf', filter,
      '-c:v', 'libx264',
      '-preset', 'medium',
      '-crf', '18',
      '-pix_fmt', 'yuv420p',
      '-c:a', 'copy',
      outputPath,
    ]).timeout(const Duration(seconds: 120));

    return result.exitCode == 0 ? outputPath : null;
  }

  /// Upscale a single image using Real-ESRGAN (for keyframe enhancement).
  Future<String?> upscaleKeyframe(String imagePath, String outputPath) async {
    try {
      final imageBytes = await File(imagePath).readAsBytes();
      final imageBase64 = base64Encode(imageBytes);

      final result = await localModelManager.upscaleImage(
        imageBase64: imageBase64,
        scale: 4,
      );

      if (result.success && result.imageBase64 != null) {
        final outBytes = base64Decode(result.imageBase64!);
        await File(outputPath).writeAsBytes(outBytes);
        return outputPath;
      }
    } catch (e) {
      print('[PostProcessor] Keyframe upscale failed: $e');
    }
    return null;
  }
}
