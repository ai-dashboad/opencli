import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf_router/shelf_router.dart';
import 'episode_script.dart';
import 'episode_store.dart';
import 'script_generator.dart';
import 'episode_generator.dart';

/// REST API for episode CRUD and generation.
///
/// Mounts under /api/v1/episodes on the UnifiedApiServer.
class EpisodeApi {
  final EpisodeStore store;
  final ScriptGenerator scriptGenerator;
  final EpisodeGenerator? episodeGenerator;

  // Track active generation tasks for cancellation
  final Map<String, bool> _cancelFlags = {};
  // Track error messages (in-memory, cleared on new generation)
  final Map<String, String> _errorMessages = {};

  EpisodeApi({
    required this.store,
    required this.scriptGenerator,
    this.episodeGenerator,
  });

  void registerRoutes(Router router) {
    router.get('/api/v1/episodes', _handleList);
    router.post('/api/v1/episodes', _handleCreate);
    router.post('/api/v1/episodes/from-script', _handleCreateFromScript);
    router.get('/api/v1/episodes/<id>', _handleGet);
    router.put('/api/v1/episodes/<id>', _handleUpdate);
    router.delete('/api/v1/episodes/<id>', _handleDelete);
    router.post('/api/v1/episodes/<id>/generate', _handleGenerate);
    router.get('/api/v1/episodes/<id>/progress', _handleProgress);
    router.post('/api/v1/episodes/<id>/cancel', _handleCancel);
    router.get('/api/v1/episodes/<id>/assets', _handleAssets);
    router.post('/api/v1/episodes/batch-generate', _handleBatchGenerate);
  }

  /// GET /api/v1/episodes — list all episodes.
  Future<shelf.Response> _handleList(shelf.Request request) async {
    final episodes = await store.list();
    return _json({'success': true, 'episodes': episodes});
  }

  /// POST /api/v1/episodes — create from narrative text (AI generates script).
  Future<shelf.Response> _handleCreate(shelf.Request request) async {
    try {
      final body = await request.readAsString();
      final json = jsonDecode(body) as Map<String, dynamic>;

      final narrativeText = json['text'] as String? ?? '';
      if (narrativeText.trim().isEmpty) {
        return _json({'success': false, 'error': 'No narrative text provided'}, 400);
      }

      final language = json['language'] as String? ?? 'zh-CN';
      final style = json['style'] as String? ?? 'anime';
      final maxScenes = (json['max_scenes'] as num?)?.toInt() ?? 8;

      final script = await scriptGenerator.generate(
        narrativeText: narrativeText,
        language: language,
        style: style,
        maxScenes: maxScenes,
      );

      await store.upsert(script.id, script);

      return _json({
        'success': true,
        'id': script.id,
        'episode': {
          'id': script.id,
          'title': script.title,
          'synopsis': script.synopsis,
          'script': script.toJson(),
          'status': 'draft',
          'progress': 0,
        },
      }, 201);
    } catch (e) {
      return _json({'success': false, 'error': 'Script generation failed: $e'}, 500);
    }
  }

  /// POST /api/v1/episodes/from-script — create from pre-written JSON script.
  Future<shelf.Response> _handleCreateFromScript(shelf.Request request) async {
    try {
      final body = await request.readAsString();
      final json = jsonDecode(body) as Map<String, dynamic>;

      final scriptJson = json['script'] as Map<String, dynamic>?;
      if (scriptJson == null) {
        return _json({'success': false, 'error': 'No script JSON provided'}, 400);
      }

      // Generate ID if not provided
      if (!scriptJson.containsKey('id') || (scriptJson['id'] as String).isEmpty) {
        scriptJson['id'] = 'ep_${DateTime.now().millisecondsSinceEpoch}';
      }

      final script = EpisodeScript.fromJson(scriptJson);
      await store.upsert(script.id, script);

      return _json({
        'success': true,
        'id': script.id,
        'episode': {
          'id': script.id,
          'title': script.title,
          'synopsis': script.synopsis,
          'script': script.toJson(),
          'status': 'draft',
          'progress': 0,
        },
      }, 201);
    } catch (e) {
      return _json({'success': false, 'error': 'Invalid script: $e'}, 400);
    }
  }

  /// GET /api/v1/episodes/:id — get episode with full script.
  Future<shelf.Response> _handleGet(shelf.Request request, String id) async {
    final episode = await store.get(id);
    if (episode == null) {
      return _json({'success': false, 'error': 'Episode not found'}, 404);
    }
    return _json({'success': true, 'episode': episode});
  }

  /// PUT /api/v1/episodes/:id — update script.
  Future<shelf.Response> _handleUpdate(shelf.Request request, String id) async {
    try {
      final existing = await store.get(id);
      if (existing == null) {
        return _json({'success': false, 'error': 'Episode not found'}, 404);
      }

      final body = await request.readAsString();
      final json = jsonDecode(body) as Map<String, dynamic>;

      final scriptJson = json['script'] as Map<String, dynamic>?;
      if (scriptJson == null) {
        return _json({'success': false, 'error': 'No script provided'}, 400);
      }

      scriptJson['id'] = id;
      final script = EpisodeScript.fromJson(scriptJson);
      await store.updateScript(id, script);

      return _json({'success': true, 'episode': {'id': id, 'script': script.toJson()}});
    } catch (e) {
      return _json({'success': false, 'error': 'Update failed: $e'}, 400);
    }
  }

  /// DELETE /api/v1/episodes/:id
  Future<shelf.Response> _handleDelete(shelf.Request request, String id) async {
    final deleted = await store.delete(id);
    if (!deleted) {
      return _json({'success': false, 'error': 'Episode not found'}, 404);
    }
    return _json({'success': true});
  }

  /// POST /api/v1/episodes/:id/generate — trigger full generation.
  Future<shelf.Response> _handleGenerate(shelf.Request request, String id) async {
    if (episodeGenerator == null) {
      return _json({'success': false, 'error': 'Episode generator not configured'}, 500);
    }

    final episodeRow = await store.get(id);
    if (episodeRow == null) {
      return _json({'success': false, 'error': 'Episode not found'}, 404);
    }

    final scriptJson = episodeRow['script'] as Map<String, dynamic>?;
    if (scriptJson == null) {
      return _json({'success': false, 'error': 'No script in episode'}, 400);
    }

    // Parse optional parameters
    Map<String, dynamic> params = {};
    try {
      final body = await request.readAsString();
      if (body.isNotEmpty) {
        params = jsonDecode(body) as Map<String, dynamic>;
      }
    } catch (_) {}

    final script = EpisodeScript.fromJson(scriptJson);

    // Mark as generating
    await store.updateStatus(id, 'generating', 0);
    _cancelFlags[id] = false;
    _errorMessages.remove(id);

    // Start generation asynchronously
    _runGeneration(id, script, params);

    return _json({
      'success': true,
      'message': 'Generation started',
      'episode_id': id,
      'estimated_scenes': script.scenes.length,
    });
  }

  /// Background generation runner.
  Future<void> _runGeneration(
      String id, EpisodeScript script, Map<String, dynamic> params) async {
    try {
      final result = await episodeGenerator!.generate(
        script: script,
        imageProvider: params['image_provider'] as String?,
        videoProvider: params['video_provider'] as String?,
        quality: params['quality'] as String? ?? 'draft',
        colorGradeLut: params['color_grade_lut'] as String?,
        exportPlatform: params['export_platform'] as String?,
        onProgress: (progress, phase, message) async {
          await store.updateStatus(id, 'generating', progress);
          // Cancel check
          if (_cancelFlags[id] == true) {
            throw Exception('Generation cancelled by user');
          }
        },
      );

      if (result['success'] == true) {
        await store.updateStatus(
            id, 'completed', 1.0, outputPath: result['output_path'] as String?);
      } else {
        final error = result['error'] as String? ?? 'Unknown error';
        _errorMessages[id] = error;
        print('[EpisodeApi] Generation failed for $id: $error');
        await store.updateStatus(id, 'failed', 0);
      }
    } catch (e) {
      final isCancelled = e.toString().contains('cancelled');
      final status = isCancelled ? 'draft' : 'failed';
      if (!isCancelled) {
        _errorMessages[id] = e.toString();
        print('[EpisodeApi] Generation exception for $id: $e');
      }
      await store.updateStatus(id, status, 0);
    } finally {
      _cancelFlags.remove(id);
    }
  }

  /// GET /api/v1/episodes/:id/progress
  Future<shelf.Response> _handleProgress(shelf.Request request, String id) async {
    final episode = await store.get(id);
    if (episode == null) {
      return _json({'success': false, 'error': 'Episode not found'}, 404);
    }
    final result = <String, dynamic>{
      'success': true,
      'status': episode['status'],
      'progress': episode['progress'],
      'output_path': episode['output_path'],
    };
    if (_errorMessages.containsKey(id)) {
      result['error'] = _errorMessages[id];
    }
    return _json(result);
  }

  /// POST /api/v1/episodes/:id/cancel
  Future<shelf.Response> _handleCancel(shelf.Request request, String id) async {
    _cancelFlags[id] = true;
    return _json({'success': true, 'message': 'Cancel requested'});
  }

  /// GET /api/v1/episodes/:id/assets — browse intermediate assets.
  Future<shelf.Response> _handleAssets(shelf.Request request, String id) async {
    final episodeRow = await store.get(id);
    if (episodeRow == null) {
      return _json({'success': false, 'error': 'Episode not found'}, 404);
    }

    final home = Platform.environment['HOME'] ?? '/tmp';
    final workDir = Directory('$home/.opencli/episodes/$id');
    if (!await workDir.exists()) {
      return _json({'success': true, 'assets': []});
    }

    final assets = <Map<String, dynamic>>[];
    await for (final entity in workDir.list()) {
      if (entity is File) {
        final name = entity.uri.pathSegments.last;
        final ext = name.split('.').last.toLowerCase();
        final stat = await entity.stat();

        String type;
        if (['png', 'jpg', 'jpeg', 'webp'].contains(ext)) {
          type = 'image';
        } else if (['mp4', 'webm', 'mov'].contains(ext)) {
          type = 'video';
        } else if (['mp3', 'wav', 'm4a', 'aac'].contains(ext)) {
          type = 'audio';
        } else if (['ass', 'srt', 'vtt'].contains(ext)) {
          type = 'subtitle';
        } else {
          type = 'other';
        }

        assets.add({
          'name': name,
          'type': type,
          'path': entity.path,
          'size_bytes': stat.size,
          'modified_at': stat.modified.millisecondsSinceEpoch,
        });
      }
    }

    // Sort by name for consistent ordering
    assets.sort((a, b) => (a['name'] as String).compareTo(b['name'] as String));

    return _json({'success': true, 'assets': assets, 'work_dir': workDir.path});
  }

  /// POST /api/v1/episodes/batch-generate — batch generate multiple episodes.
  Future<shelf.Response> _handleBatchGenerate(shelf.Request request) async {
    if (episodeGenerator == null) {
      return _json({'success': false, 'error': 'Episode generator not configured'}, 500);
    }

    try {
      final body = await request.readAsString();
      final json = jsonDecode(body) as Map<String, dynamic>;
      final ids = (json['ids'] as List?)?.cast<String>() ?? [];

      if (ids.isEmpty) {
        return _json({'success': false, 'error': 'No episode IDs provided'}, 400);
      }

      // Start batch processing asynchronously (sequential, one at a time)
      _runBatchGeneration(ids, json);

      return _json({
        'success': true,
        'message': 'Batch generation started for ${ids.length} episodes',
        'episode_ids': ids,
      });
    } catch (e) {
      return _json({'success': false, 'error': 'Batch generation failed: $e'}, 500);
    }
  }

  Future<void> _runBatchGeneration(List<String> ids, Map<String, dynamic> params) async {
    for (final id in ids) {
      final episodeRow = await store.get(id);
      if (episodeRow == null) continue;

      final scriptJson = episodeRow['script'] as Map<String, dynamic>?;
      if (scriptJson == null) continue;

      final script = EpisodeScript.fromJson(scriptJson);
      await store.updateStatus(id, 'generating', 0);
      _cancelFlags[id] = false;
      _errorMessages.remove(id);

      await _runGeneration(id, script, params);
    }
  }

  shelf.Response _json(Map<String, dynamic> data, [int status = 200]) {
    return shelf.Response(status,
        body: jsonEncode(data),
        headers: {'Content-Type': 'application/json'});
  }
}
