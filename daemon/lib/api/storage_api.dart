import 'dart:convert';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf_router/shelf_router.dart';
import 'package:opencli_daemon/database/app_database.dart';

/// REST API endpoints for client-side storage (web UI, Flutter app).
///
/// Provides CRUD for generation history, assets, status events, and chat messages.
/// All data is persisted in the centralized SQLite database.
class StorageApi {
  final AppDatabase _db;

  StorageApi({AppDatabase? db}) : _db = db ?? AppDatabase.instance;

  /// Register all storage routes on the given router.
  void registerRoutes(Router router) {
    // Generation History
    router.get('/api/v1/history', _listHistory);
    router.post('/api/v1/history', _createHistory);
    router.delete('/api/v1/history/<id>', _deleteHistory);
    router.delete('/api/v1/history', _clearHistory);

    // Assets
    router.get('/api/v1/assets', _listAssets);
    router.post('/api/v1/assets', _createAsset);
    router.delete('/api/v1/assets/<id>', _deleteAsset);

    // Status Events
    router.get('/api/v1/events', _listEvents);
    router.post('/api/v1/events', _createEvent);
    router.get('/api/v1/events/stats', _getEventStats);

    // Chat Messages
    router.get('/api/v1/chat/messages', _listChatMessages);
    router.post('/api/v1/chat/messages', _createChatMessage);
    router.delete('/api/v1/chat/messages', _clearChatMessages);
  }

  // ── Generation History ──

  Future<shelf.Response> _listHistory(shelf.Request request) async {
    try {
      final limit =
          int.tryParse(request.url.queryParameters['limit'] ?? '') ?? 50;
      final rows = await _db.listHistory(limit: limit);
      return _json({'history': rows});
    } catch (e) {
      return _error('Failed to list history: $e');
    }
  }

  Future<shelf.Response> _createHistory(shelf.Request request) async {
    try {
      final body = jsonDecode(await request.readAsString());
      final now = DateTime.now().millisecondsSinceEpoch;
      await _db.insertHistory({
        'id': body['id'] ?? 'h_$now',
        'mode': body['mode'] ?? '',
        'prompt': body['prompt'] ?? '',
        'provider': body['provider'] ?? '',
        'style': body['style'] ?? '',
        'result_type': body['result_type'] ?? body['resultType'] ?? '',
        'thumbnail': body['thumbnail'],
        'created_at': body['created_at'] ?? body['timestamp'] ?? now,
      });
      return _json({'success': true});
    } catch (e) {
      return _error('Failed to create history: $e');
    }
  }

  Future<shelf.Response> _deleteHistory(
      shelf.Request request, String id) async {
    try {
      await _db.deleteHistory(id);
      return _json({'success': true});
    } catch (e) {
      return _error('Failed to delete history: $e');
    }
  }

  Future<shelf.Response> _clearHistory(shelf.Request request) async {
    try {
      await _db.clearHistory();
      return _json({'success': true});
    } catch (e) {
      return _error('Failed to clear history: $e');
    }
  }

  // ── Assets ──

  Future<shelf.Response> _listAssets(shelf.Request request) async {
    try {
      final limit =
          int.tryParse(request.url.queryParameters['limit'] ?? '') ?? 100;
      final rows = await _db.listAssets(limit: limit);
      return _json({'assets': rows});
    } catch (e) {
      return _error('Failed to list assets: $e');
    }
  }

  Future<shelf.Response> _createAsset(shelf.Request request) async {
    try {
      final body = jsonDecode(await request.readAsString());
      final now = DateTime.now().millisecondsSinceEpoch;
      await _db.insertAsset({
        'id': body['id'] ?? 'asset_$now',
        'type': body['type'] ?? 'image',
        'title': body['title'] ?? '',
        'url': body['url'] ?? '',
        'thumbnail': body['thumbnail'],
        'provider': body['provider'],
        'style': body['style'],
        'created_at': body['created_at'] ?? body['createdAt'] ?? now,
      });
      return _json({'success': true});
    } catch (e) {
      return _error('Failed to create asset: $e');
    }
  }

  Future<shelf.Response> _deleteAsset(
      shelf.Request request, String id) async {
    try {
      await _db.deleteAsset(id);
      return _json({'success': true});
    } catch (e) {
      return _error('Failed to delete asset: $e');
    }
  }

  // ── Status Events ──

  Future<shelf.Response> _listEvents(shelf.Request request) async {
    try {
      final limit =
          int.tryParse(request.url.queryParameters['limit'] ?? '') ?? 100;
      final rows = await _db.listEvents(limit: limit);
      return _json({'events': rows});
    } catch (e) {
      return _error('Failed to list events: $e');
    }
  }

  Future<shelf.Response> _createEvent(shelf.Request request) async {
    try {
      final body = jsonDecode(await request.readAsString());
      final now = DateTime.now().millisecondsSinceEpoch;
      await _db.insertEvent({
        'id': body['id'] ?? 'evt_$now',
        'type': body['type'] ?? 'system',
        'source': body['source'] ?? '',
        'content': body['content'] ?? '',
        'task_type': body['task_type'] ?? body['taskType'],
        'status': body['status'],
        'result': body['result'] is String
            ? body['result']
            : (body['result'] != null ? jsonEncode(body['result']) : null),
        'created_at': body['created_at'] ?? body['timestamp'] ?? now,
      });
      return _json({'success': true});
    } catch (e) {
      return _error('Failed to create event: $e');
    }
  }

  Future<shelf.Response> _getEventStats(shelf.Request request) async {
    try {
      final stats = await _db.getEventStats();
      return _json(stats);
    } catch (e) {
      return _error('Failed to get event stats: $e');
    }
  }

  // ── Chat Messages ──

  Future<shelf.Response> _listChatMessages(shelf.Request request) async {
    try {
      final limit =
          int.tryParse(request.url.queryParameters['limit'] ?? '') ?? 100;
      final rows = await _db.listChatMessages(limit: limit);
      return _json({'messages': rows});
    } catch (e) {
      return _error('Failed to list chat messages: $e');
    }
  }

  Future<shelf.Response> _createChatMessage(shelf.Request request) async {
    try {
      final body = jsonDecode(await request.readAsString());
      final now = DateTime.now().millisecondsSinceEpoch;
      await _db.insertChatMessage({
        'id': body['id'] ?? 'msg_$now',
        'content': body['content'] ?? '',
        'is_user': (body['is_user'] ?? body['isUser'] ?? false) ? 1 : 0,
        'timestamp': body['timestamp'] ?? now,
        'status': body['status'] ?? 'completed',
        'task_type': body['task_type'] ?? body['taskType'],
        'result': body['result'] is String
            ? body['result']
            : (body['result'] != null ? jsonEncode(body['result']) : null),
      });
      return _json({'success': true});
    } catch (e) {
      return _error('Failed to create chat message: $e');
    }
  }

  Future<shelf.Response> _clearChatMessages(shelf.Request request) async {
    try {
      await _db.clearChatMessages();
      return _json({'success': true});
    } catch (e) {
      return _error('Failed to clear chat messages: $e');
    }
  }

  // ── Helpers ──

  shelf.Response _json(Map<String, dynamic> data) {
    return shelf.Response.ok(
      jsonEncode(data),
      headers: {'Content-Type': 'application/json'},
    );
  }

  shelf.Response _error(String message) {
    return shelf.Response.internalServerError(
      body: jsonEncode({'error': message}),
      headers: {'Content-Type': 'application/json'},
    );
  }
}
