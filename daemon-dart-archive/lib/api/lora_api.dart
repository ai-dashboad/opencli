import 'dart:convert';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf_router/shelf_router.dart';
import '../database/app_database.dart';

/// REST API for LoRA registry and generation recipe management.
class LoRAApi {
  final AppDatabase _db;

  LoRAApi(this._db);

  void registerRoutes(Router router) {
    // LoRA registry
    router.get('/api/v1/loras', _handleListLoRAs);
    router.get('/api/v1/loras/<id>', _handleGetLoRA);
    router.post('/api/v1/loras', _handleCreateLoRA);
    router.put('/api/v1/loras/<id>', _handleUpdateLoRA);
    router.delete('/api/v1/loras/<id>', _handleDeleteLoRA);

    // Generation recipes
    router.get('/api/v1/recipes', _handleListRecipes);
    router.get('/api/v1/recipes/<id>', _handleGetRecipe);
    router.post('/api/v1/recipes', _handleCreateRecipe);
    router.put('/api/v1/recipes/<id>', _handleUpdateRecipe);
    router.delete('/api/v1/recipes/<id>', _handleDeleteRecipe);
  }

  // ── LoRA endpoints ──

  Future<shelf.Response> _handleListLoRAs(shelf.Request request) async {
    final type = request.url.queryParameters['type'];
    final loras = await _db.listLoRAs(type: type);
    return _json({'success': true, 'loras': loras});
  }

  Future<shelf.Response> _handleGetLoRA(shelf.Request request, String id) async {
    final lora = await _db.getLoRA(id);
    if (lora == null) {
      return _json({'success': false, 'error': 'LoRA not found'}, 404);
    }
    return _json({'success': true, 'lora': lora});
  }

  Future<shelf.Response> _handleCreateLoRA(shelf.Request request) async {
    try {
      final body = await request.readAsString();
      final json = jsonDecode(body) as Map<String, dynamic>;

      final now = DateTime.now().millisecondsSinceEpoch;
      final id = json['id'] as String? ?? 'lora_$now';

      await _db.upsertLoRA({
        'id': id,
        'name': json['name'] ?? id,
        'type': json['type'] ?? 'style',
        'path': json['path'] ?? '',
        'trigger_word': json['trigger_word'] ?? '',
        'weight': (json['weight'] as num?)?.toDouble() ?? 0.7,
        'preview_base64': json['preview_base64'],
        'tags': jsonEncode(json['tags'] ?? []),
        'created_at': now,
      });

      return _json({'success': true, 'id': id}, 201);
    } catch (e) {
      return _json({'success': false, 'error': 'Failed to create LoRA: $e'}, 400);
    }
  }

  Future<shelf.Response> _handleUpdateLoRA(shelf.Request request, String id) async {
    try {
      final existing = await _db.getLoRA(id);
      if (existing == null) {
        return _json({'success': false, 'error': 'LoRA not found'}, 404);
      }

      final body = await request.readAsString();
      final json = jsonDecode(body) as Map<String, dynamic>;

      final updated = Map<String, dynamic>.from(existing);
      if (json.containsKey('name')) updated['name'] = json['name'];
      if (json.containsKey('type')) updated['type'] = json['type'];
      if (json.containsKey('path')) updated['path'] = json['path'];
      if (json.containsKey('trigger_word')) updated['trigger_word'] = json['trigger_word'];
      if (json.containsKey('weight')) updated['weight'] = (json['weight'] as num).toDouble();
      if (json.containsKey('tags')) updated['tags'] = jsonEncode(json['tags']);
      if (json.containsKey('preview_base64')) updated['preview_base64'] = json['preview_base64'];

      await _db.upsertLoRA(updated);
      return _json({'success': true, 'lora': updated});
    } catch (e) {
      return _json({'success': false, 'error': 'Update failed: $e'}, 400);
    }
  }

  Future<shelf.Response> _handleDeleteLoRA(shelf.Request request, String id) async {
    final deleted = await _db.deleteLoRA(id);
    if (!deleted) {
      return _json({'success': false, 'error': 'LoRA not found'}, 404);
    }
    return _json({'success': true});
  }

  // ── Recipe endpoints ──

  Future<shelf.Response> _handleListRecipes(shelf.Request request) async {
    final recipes = await _db.listRecipes();
    return _json({'success': true, 'recipes': recipes});
  }

  Future<shelf.Response> _handleGetRecipe(shelf.Request request, String id) async {
    final recipe = await _db.getRecipe(id);
    if (recipe == null) {
      return _json({'success': false, 'error': 'Recipe not found'}, 404);
    }
    return _json({'success': true, 'recipe': recipe});
  }

  Future<shelf.Response> _handleCreateRecipe(shelf.Request request) async {
    try {
      final body = await request.readAsString();
      final json = jsonDecode(body) as Map<String, dynamic>;

      final now = DateTime.now().millisecondsSinceEpoch;
      final id = json['id'] as String? ?? 'recipe_$now';

      await _db.upsertRecipe({
        'id': id,
        'name': json['name'] ?? 'Untitled Recipe',
        'description': json['description'] ?? '',
        'image_model': json['image_model'] ?? 'animagine_xl',
        'video_model': json['video_model'] ?? 'local_v3',
        'quality': json['quality'] ?? 'standard',
        'lora_ids': jsonEncode(json['lora_ids'] ?? []),
        'controlnet_type': json['controlnet_type'] ?? 'lineart_anime',
        'controlnet_scale': (json['controlnet_scale'] as num?)?.toDouble() ?? 0.7,
        'ip_adapter_scale': (json['ip_adapter_scale'] as num?)?.toDouble() ?? 0.6,
        'color_grade': json['color_grade'] ?? '',
        'export_platform': json['export_platform'] ?? '',
        'created_at': now,
        'updated_at': now,
      });

      return _json({'success': true, 'id': id}, 201);
    } catch (e) {
      return _json({'success': false, 'error': 'Failed to create recipe: $e'}, 400);
    }
  }

  Future<shelf.Response> _handleUpdateRecipe(shelf.Request request, String id) async {
    try {
      final existing = await _db.getRecipe(id);
      if (existing == null) {
        return _json({'success': false, 'error': 'Recipe not found'}, 404);
      }

      final body = await request.readAsString();
      final json = jsonDecode(body) as Map<String, dynamic>;

      final updated = Map<String, dynamic>.from(existing);
      for (final key in ['name', 'description', 'image_model', 'video_model',
          'quality', 'controlnet_type', 'color_grade', 'export_platform']) {
        if (json.containsKey(key)) updated[key] = json[key];
      }
      if (json.containsKey('lora_ids')) updated['lora_ids'] = jsonEncode(json['lora_ids']);
      if (json.containsKey('controlnet_scale')) {
        updated['controlnet_scale'] = (json['controlnet_scale'] as num).toDouble();
      }
      if (json.containsKey('ip_adapter_scale')) {
        updated['ip_adapter_scale'] = (json['ip_adapter_scale'] as num).toDouble();
      }
      updated['updated_at'] = DateTime.now().millisecondsSinceEpoch;

      await _db.upsertRecipe(updated);
      return _json({'success': true, 'recipe': updated});
    } catch (e) {
      return _json({'success': false, 'error': 'Update failed: $e'}, 400);
    }
  }

  Future<shelf.Response> _handleDeleteRecipe(shelf.Request request, String id) async {
    final deleted = await _db.deleteRecipe(id);
    if (!deleted) {
      return _json({'success': false, 'error': 'Recipe not found'}, 404);
    }
    return _json({'success': true});
  }

  shelf.Response _json(Map<String, dynamic> data, [int status = 200]) {
    return shelf.Response(status,
        body: jsonEncode(data),
        headers: {'Content-Type': 'application/json'});
  }
}
