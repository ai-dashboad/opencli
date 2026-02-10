import 'dart:io';
import '../domain.dart';

class MusicDomain extends TaskDomain {
  @override
  String get id => 'music';
  @override
  String get name => 'Music';
  @override
  String get description =>
      'Control Music.app playback, playlists, and now playing info';
  @override
  String get icon => 'music_note';
  @override
  int get colorHex => 0xFFE91E63;

  @override
  List<String> get taskTypes => [
        'music_play',
        'music_pause',
        'music_next',
        'music_previous',
        'music_now_playing',
        'music_playlist',
      ];

  @override
  List<DomainIntentPattern> get intentPatterns => [
        DomainIntentPattern(
          pattern: RegExp(r'^play\s+(?:playlist\s+)?(.+?)(?:\s+playlist)?$',
              caseSensitive: false),
          taskType: 'music_playlist',
          extractData: (m) => {'playlist': m.group(1)!.trim()},
          confidence: 0.8, // Lower confidence — "play X" could be music or app
        ),
        DomainIntentPattern(
          pattern: RegExp(r'^play\s+music$', caseSensitive: false),
          taskType: 'music_play',
          extractData: (_) => {},
        ),
        DomainIntentPattern(
          pattern: RegExp(r'^(?:pause|stop)\s*(?:music|playback)?$',
              caseSensitive: false),
          taskType: 'music_pause',
          extractData: (_) => {},
        ),
        DomainIntentPattern(
          pattern: RegExp(r'^(?:resume)\s*(?:music|playback)?$',
              caseSensitive: false),
          taskType: 'music_play',
          extractData: (_) => {},
        ),
        DomainIntentPattern(
          pattern:
              RegExp(r'^(?:next\s+(?:song|track)|skip)$', caseSensitive: false),
          taskType: 'music_next',
          extractData: (_) => {},
        ),
        DomainIntentPattern(
          pattern: RegExp(r'^(?:previous\s+(?:song|track)|prev|go\s+back)$',
              caseSensitive: false),
          taskType: 'music_previous',
          extractData: (_) => {},
        ),
        DomainIntentPattern(
          pattern: RegExp(
              r"^(?:what'?s?\s+playing|now\s+playing|current\s+(?:song|track))$",
              caseSensitive: false),
          taskType: 'music_now_playing',
          extractData: (_) => {},
        ),
      ];

  @override
  List<DomainOllamaIntent> get ollamaIntents => [
        DomainOllamaIntent(
          intentName: 'music_play',
          description: 'Play or resume music in Music.app',
          examples: [
            OllamaExample(
                input: 'play music',
                intentJson:
                    '{"intent": "music_play", "confidence": 0.95, "parameters": {}}'),
            OllamaExample(
                input: 'resume playback',
                intentJson:
                    '{"intent": "music_play", "confidence": 0.95, "parameters": {}}'),
          ],
        ),
        DomainOllamaIntent(
          intentName: 'music_pause',
          description: 'Pause music playback',
          examples: [
            OllamaExample(
                input: 'pause music',
                intentJson:
                    '{"intent": "music_pause", "confidence": 0.95, "parameters": {}}'),
          ],
        ),
        DomainOllamaIntent(
          intentName: 'music_playlist',
          description: 'Play a specific playlist by name',
          parameters: {'playlist': 'playlist name'},
          examples: [
            OllamaExample(
                input: 'play focus playlist',
                intentJson:
                    '{"intent": "music_playlist", "confidence": 0.95, "parameters": {"playlist": "Focus"}}'),
            OllamaExample(
                input: 'play lo-fi',
                intentJson:
                    '{"intent": "music_playlist", "confidence": 0.95, "parameters": {"playlist": "lo-fi"}}'),
          ],
        ),
        DomainOllamaIntent(
          intentName: 'music_now_playing',
          description: 'Show the currently playing song',
          examples: [
            OllamaExample(
                input: "what's playing",
                intentJson:
                    '{"intent": "music_now_playing", "confidence": 0.95, "parameters": {}}'),
          ],
        ),
      ];

  @override
  Map<String, DomainDisplayConfig> get displayConfigs => {
        'music_play': const DomainDisplayConfig(
            cardType: 'music',
            titleTemplate: 'Music',
            icon: 'play_arrow',
            colorHex: 0xFFE91E63),
        'music_pause': const DomainDisplayConfig(
            cardType: 'music',
            titleTemplate: 'Music Paused',
            icon: 'pause',
            colorHex: 0xFFE91E63),
        'music_next': const DomainDisplayConfig(
            cardType: 'music',
            titleTemplate: 'Next Track',
            icon: 'skip_next',
            colorHex: 0xFFE91E63),
        'music_previous': const DomainDisplayConfig(
            cardType: 'music',
            titleTemplate: 'Previous Track',
            icon: 'skip_previous',
            colorHex: 0xFFE91E63),
        'music_now_playing': const DomainDisplayConfig(
            cardType: 'music',
            titleTemplate: 'Now Playing',
            icon: 'music_note',
            colorHex: 0xFFE91E63),
        'music_playlist': const DomainDisplayConfig(
            cardType: 'music',
            titleTemplate: 'Playlist',
            icon: 'queue_music',
            colorHex: 0xFFE91E63),
      };

  @override
  Future<Map<String, dynamic>> executeTask(
      String taskType, Map<String, dynamic> data) async {
    switch (taskType) {
      case 'music_play':
        return _runAppleScript('tell application "Music" to play');
      case 'music_pause':
        return _runAppleScript('tell application "Music" to pause');
      case 'music_next':
        return _runAppleScript('tell application "Music" to next track');
      case 'music_previous':
        return _runAppleScript('tell application "Music" to previous track');
      case 'music_now_playing':
        return _nowPlaying();
      case 'music_playlist':
        return _playPlaylist(data);
      default:
        return {'success': false, 'error': 'Unknown music task: $taskType'};
    }
  }

  Future<Map<String, dynamic>> _runAppleScript(String script) async {
    try {
      final result = await Process.run('osascript', ['-e', script]);
      return {
        'success': result.exitCode == 0,
        'stdout': (result.stdout as String).trim(),
        'stderr': (result.stderr as String).trim(),
        'exit_code': result.exitCode,
        'domain': 'music',
        'card_type': 'music',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'AppleScript error: $e',
        'domain': 'music'
      };
    }
  }

  Future<Map<String, dynamic>> _nowPlaying() async {
    try {
      final script = '''
tell application "Music"
  if player state is playing then
    set trackName to name of current track
    set trackArtist to artist of current track
    set trackAlbum to album of current track
    set trackDuration to duration of current track
    set playerPos to player position
    return trackName & "|||" & trackArtist & "|||" & trackAlbum & "|||" & (trackDuration as string) & "|||" & (playerPos as string)
  else
    return "NOT_PLAYING"
  end if
end tell''';
      final result = await Process.run('osascript', ['-e', script]);
      final output = (result.stdout as String).trim();

      if (output == 'NOT_PLAYING' || result.exitCode != 0) {
        return {
          'success': true,
          'playing': false,
          'message': 'Nothing is playing',
          'domain': 'music',
          'card_type': 'music',
        };
      }

      final parts = output.split('|||');
      return {
        'success': true,
        'playing': true,
        'track': parts.isNotEmpty ? parts[0] : 'Unknown',
        'artist': parts.length > 1 ? parts[1] : 'Unknown',
        'album': parts.length > 2 ? parts[2] : '',
        'domain': 'music',
        'card_type': 'music',
      };
    } catch (e) {
      return {'success': false, 'error': 'Error: $e', 'domain': 'music'};
    }
  }

  Future<Map<String, dynamic>> _playPlaylist(Map<String, dynamic> data) async {
    final playlist = data['playlist'] as String? ?? '';
    return _runAppleScript(
        'tell application "Music" to play playlist "$playlist"');
  }
}
