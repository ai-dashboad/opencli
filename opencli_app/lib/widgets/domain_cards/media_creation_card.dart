import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:video_player/video_player.dart';

class MediaCreationCard extends StatefulWidget {
  final String taskType;
  final Map<String, dynamic> result;

  const MediaCreationCard({
    super.key,
    required this.taskType,
    required this.result,
  });

  @override
  State<MediaCreationCard> createState() => _MediaCreationCardState();
}

class _MediaCreationCardState extends State<MediaCreationCard> {
  VideoPlayerController? _videoController;
  bool _isPlaying = false;
  bool _isLoading = true;
  String? _initError;
  String? _videoFilePath;
  bool _isSaving = false;
  static const _color = Color(0xFF7C4DFF);

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    final videoBase64 = widget.result['video_base64'] as String?;
    final videoPath = widget.result['video_path'] as String?;

    try {
      if (videoBase64 != null && videoBase64.isNotEmpty) {
        final bytes = base64Decode(videoBase64);
        final tempDir = await getTemporaryDirectory();
        final tempPath = '${tempDir.path}/opencli_video_${DateTime.now().millisecondsSinceEpoch}.mp4';
        final file = File(tempPath);
        await file.writeAsBytes(bytes);

        debugPrint('[MediaCreationCard] Video file: ${bytes.length} bytes → $tempPath');
        _videoFilePath = tempPath;

        _videoController = VideoPlayerController.file(file);
        await _videoController!.initialize();
        _videoController!.setLooping(true);
        // Auto-play so user sees the video immediately
        _videoController!.play();
        _isPlaying = true;

        debugPrint('[MediaCreationCard] Video initialized: '
            '${_videoController!.value.size.width}x${_videoController!.value.size.height} '
            'duration=${_videoController!.value.duration}');
      } else if (videoPath != null) {
        final file = File(videoPath);
        if (await file.exists()) {
          _videoFilePath = videoPath;
          _videoController = VideoPlayerController.file(file);
          await _videoController!.initialize();
          _videoController!.setLooping(true);
          _videoController!.play();
          _isPlaying = true;
        } else {
          _initError = 'Video file not found: $videoPath';
        }
      } else {
        _initError = 'No video data in result';
      }
    } catch (e) {
      debugPrint('[MediaCreationCard] Video init error: $e');
      _initError = 'Video init failed: $e';
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final success = widget.result['success'] == true;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_color.withOpacity(0.08), _color.withOpacity(0.03)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Icon(_iconForTask(), color: success ? _color : Colors.red[700], size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _titleForTask(success),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: success ? _color : Colors.red[700],
                    ),
                  ),
                ),
                if (success && widget.result['generation_type'] == 'ai')
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      color: Colors.amber.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'AI',
                      style: TextStyle(fontSize: 10, color: Colors.amber, fontWeight: FontWeight.bold),
                    ),
                  ),
                if (success && (widget.result['effect'] ?? widget.result['style']) != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _color.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      (widget.result['effect'] ?? widget.result['style']) as String,
                      style: TextStyle(fontSize: 11, color: _color, fontWeight: FontWeight.w500),
                    ),
                  ),
              ],
            ),
          ),

          // Video player or error
          if (success && !_isLoading && _videoController != null && _videoController!.value.isInitialized)
            _buildVideoPlayer()
          else if (success && _isLoading)
            _buildLoadingState()
          else if (success)
            _buildFallbackState()
          else
            _buildErrorState(),

          // Metadata footer
          if (success)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
              child: Row(
                children: [
                  if (widget.result['duration'] != null)
                    _metadataChip(Icons.timer, '${widget.result['duration']}s'),
                  if (widget.result['size_bytes'] != null) ...[
                    const SizedBox(width: 8),
                    _metadataChip(
                      Icons.storage,
                      '${((widget.result['size_bytes'] as num) / 1024 / 1024).toStringAsFixed(1)} MB',
                    ),
                  ],
                  if (widget.result['image_count'] != null) ...[
                    const SizedBox(width: 8),
                    _metadataChip(Icons.photo_library, '${widget.result['image_count']} photos'),
                  ],
                  if (widget.result['provider'] != null) ...[
                    const SizedBox(width: 8),
                    _metadataChip(Icons.cloud, _providerDisplayName(widget.result['provider'] as String)),
                  ],
                ],
              ),
            ),

          // Action buttons (Save / Share)
          if (success && _videoFilePath != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Row(
                children: [
                  _actionButton(
                    icon: _isSaving ? Icons.hourglass_empty : Icons.save_alt,
                    label: _isSaving ? 'Saving...' : 'Save',
                    onTap: _isSaving ? null : _saveToGallery,
                  ),
                  const SizedBox(width: 8),
                  _actionButton(
                    icon: Icons.share,
                    label: 'Share',
                    onTap: _shareVideo,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVideoPlayer() {
    return GestureDetector(
      onTap: () {
        setState(() {
          if (_videoController!.value.isPlaying) {
            _videoController!.pause();
            _isPlaying = false;
          } else {
            _videoController!.play();
            _isPlaying = true;
          }
        });
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          ClipRRect(
            child: AspectRatio(
              aspectRatio: _videoController!.value.aspectRatio,
              child: VideoPlayer(_videoController!),
            ),
          ),
          if (!_isPlaying)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow, color: Colors.white, size: 32),
            ),
          // Progress indicator
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: VideoProgressIndicator(
              _videoController!,
              allowScrubbing: true,
              colors: VideoProgressColors(
                playedColor: _color,
                bufferedColor: _color.withOpacity(0.3),
                backgroundColor: Colors.grey.withOpacity(0.2),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      height: 150,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _color.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Loading video...',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildFallbackState() {
    return Container(
      height: 120,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            _initError != null ? Icons.error_outline : Icons.movie_creation,
            size: 40,
            color: _initError != null ? Colors.orange.withOpacity(0.5) : _color.withOpacity(0.3),
          ),
          const SizedBox(height: 8),
          Text(
            _initError ?? widget.result['message'] as String? ?? 'Video created',
            style: TextStyle(color: _initError != null ? Colors.orange[700] : Colors.grey[600], fontSize: 13),
            textAlign: TextAlign.center,
          ),
          if (widget.result['video_path'] != null) ...[
            const SizedBox(height: 4),
            Text(
              widget.result['video_path'] as String,
              style: TextStyle(color: Colors.grey[400], fontSize: 10),
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red[700], size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.result['error'] as String? ??
                    widget.result['message'] as String? ??
                    'Failed to create video',
                style: TextStyle(color: Colors.red[700], fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveToGallery() async {
    if (_videoFilePath == null) return;
    setState(() => _isSaving = true);
    try {
      await Gal.putVideo(_videoFilePath!);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Video saved to gallery'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Save failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
    if (mounted) setState(() => _isSaving = false);
  }

  Future<void> _shareVideo() async {
    if (_videoFilePath == null) return;
    try {
      await Share.shareXFiles([XFile(_videoFilePath!)]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Share failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _actionButton({required IconData icon, required String label, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: _color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: _color),
            const SizedBox(width: 4),
            Text(label, style: TextStyle(fontSize: 12, color: _color, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _metadataChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 11, color: Colors.grey[600])),
        ],
      ),
    );
  }

  IconData _iconForTask() {
    switch (widget.taskType) {
      case 'media_animate_photo':
        return Icons.animation;
      case 'media_create_slideshow':
        return Icons.slideshow;
      case 'media_ai_generate_video':
        return Icons.auto_awesome;
      default:
        return Icons.movie_creation;
    }
  }

  String _titleForTask(bool success) {
    if (!success) return 'Media Creation Error';
    switch (widget.taskType) {
      case 'media_animate_photo':
        return widget.result['generation_type'] == 'ai' ? 'AI Photo Animation' : 'Photo Animation';
      case 'media_create_slideshow':
        return 'Slideshow Created';
      case 'media_ai_generate_video':
        final provider = widget.result['provider'] as String?;
        return 'AI Video${provider != null ? ' - ${_providerDisplayName(provider)}' : ''}';
      default:
        return 'Media Created';
    }
  }

  String _providerDisplayName(String id) {
    switch (id) {
      case 'replicate': return 'Replicate';
      case 'runway': return 'Runway';
      case 'kling': return 'Kling AI';
      case 'luma': return 'Luma';
      case 'local_ffmpeg': return 'Local';
      default: return id;
    }
  }
}
