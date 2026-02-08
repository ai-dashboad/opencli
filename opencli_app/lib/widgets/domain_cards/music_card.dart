import 'package:flutter/material.dart';

/// Music domain card — shows now playing info, playback controls styling.
class MusicCard extends StatelessWidget {
  final String taskType;
  final Map<String, dynamic> result;

  const MusicCard({Key? key, required this.taskType, required this.result}) : super(key: key);

  static const _color = Color(0xFFE91E63);

  @override
  Widget build(BuildContext context) {
    final success = result['success'] == true;

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_color.withOpacity(0.1), _color.withOpacity(0.05)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(_iconForTask(), color: _color, size: 28),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _titleForTask(success),
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: success ? _color : Colors.red[700]!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (!success)
            Text(result['error'] as String? ?? result['message'] as String? ?? 'Music action failed',
                style: TextStyle(color: Colors.red[700]))
          else if (taskType == 'music_now_playing')
            _buildNowPlaying()
          else if (result['message'] != null)
            Text(result['message'] as String, style: const TextStyle(fontSize: 14))
          else
            Text(result['stdout'] as String? ?? 'Done', style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildNowPlaying() {
    final playing = result['playing'] == true;
    if (!playing) {
      return const Text('Nothing is currently playing', style: TextStyle(fontSize: 14, color: Colors.grey));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          result['track'] as String? ?? 'Unknown Track',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          result['artist'] as String? ?? 'Unknown Artist',
          style: TextStyle(fontSize: 14, color: Colors.grey[700]),
        ),
        if (result['album'] != null && (result['album'] as String).isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            result['album'] as String,
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ],
      ],
    );
  }

  IconData _iconForTask() {
    switch (taskType) {
      case 'music_play': return Icons.play_arrow;
      case 'music_pause': return Icons.pause;
      case 'music_next': return Icons.skip_next;
      case 'music_previous': return Icons.skip_previous;
      case 'music_now_playing': return Icons.music_note;
      case 'music_playlist': return Icons.queue_music;
      default: return Icons.music_note;
    }
  }

  String _titleForTask(bool success) {
    if (!success) return 'Music Error';
    switch (taskType) {
      case 'music_play': return 'Playing';
      case 'music_pause': return 'Paused';
      case 'music_next': return 'Next Track';
      case 'music_previous': return 'Previous Track';
      case 'music_now_playing': return 'Now Playing';
      case 'music_playlist': return 'Playlist';
      default: return 'Music';
    }
  }
}
