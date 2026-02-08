import 'dart:convert';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf_router/shelf_router.dart';
import 'pipeline_definition.dart';
import 'pipeline_store.dart';
import 'pipeline_executor.dart';
import '../domains/domain.dart';
import '../domains/domain_registry.dart';
import '../mobile/mobile_connection_manager.dart';

/// REST API handler for pipeline CRUD and execution.
///
/// Mounts under /api/v1/pipelines on the UnifiedApiServer.
class PipelineApi {
  final PipelineStore store;
  final PipelineExecutor executor;
  final DomainRegistry? domainRegistry;
  final MobileConnectionManager? connectionManager;

  PipelineApi({
    required this.store,
    required this.executor,
    this.domainRegistry,
    this.connectionManager,
  });

  /// Register all pipeline routes on the given router.
  void registerRoutes(Router router) {
    // Pipeline CRUD
    router.get('/api/v1/pipelines', _handleList);
    router.get('/api/v1/pipelines/<id>', _handleGet);
    router.post('/api/v1/pipelines', _handleCreate);
    router.put('/api/v1/pipelines/<id>', _handleUpdate);
    router.delete('/api/v1/pipelines/<id>', _handleDelete);

    // Pipeline execution
    router.post('/api/v1/pipelines/<id>/run', _handleRun);

    // Node catalog
    router.get('/api/v1/nodes/catalog', _handleNodeCatalog);
  }

  /// GET /api/v1/pipelines — list all pipelines.
  Future<shelf.Response> _handleList(shelf.Request request) async {
    final pipelines = await store.list();
    return _jsonResponse({'success': true, 'pipelines': pipelines});
  }

  /// GET /api/v1/pipelines/<id> — get a pipeline definition.
  Future<shelf.Response> _handleGet(
      shelf.Request request, String id) async {
    final pipeline = await store.load(id);
    if (pipeline == null) {
      return _jsonResponse(
          {'success': false, 'error': 'Pipeline not found'}, 404);
    }
    return _jsonResponse({'success': true, 'pipeline': pipeline.toJson()});
  }

  /// POST /api/v1/pipelines — create a new pipeline.
  Future<shelf.Response> _handleCreate(shelf.Request request) async {
    try {
      final body = await request.readAsString();
      final json = jsonDecode(body) as Map<String, dynamic>;

      // Generate ID if not provided
      if (!json.containsKey('id') || (json['id'] as String).isEmpty) {
        json['id'] =
            'pipeline_${DateTime.now().millisecondsSinceEpoch}';
      }

      final pipeline = PipelineDefinition.fromJson(json);
      await store.save(pipeline);

      return _jsonResponse({
        'success': true,
        'id': pipeline.id,
        'pipeline': pipeline.toJson(),
      }, 201);
    } catch (e) {
      return _jsonResponse(
          {'success': false, 'error': 'Invalid pipeline: $e'}, 400);
    }
  }

  /// PUT /api/v1/pipelines/<id> — update a pipeline.
  Future<shelf.Response> _handleUpdate(
      shelf.Request request, String id) async {
    try {
      final existing = await store.load(id);
      if (existing == null) {
        return _jsonResponse(
            {'success': false, 'error': 'Pipeline not found'}, 404);
      }

      final body = await request.readAsString();
      final json = jsonDecode(body) as Map<String, dynamic>;
      json['id'] = id; // Ensure ID matches URL
      json['created_at'] = existing.createdAt.toIso8601String();

      final pipeline = PipelineDefinition.fromJson(json);
      await store.save(pipeline);

      return _jsonResponse({
        'success': true,
        'pipeline': pipeline.toJson(),
      });
    } catch (e) {
      return _jsonResponse(
          {'success': false, 'error': 'Invalid pipeline: $e'}, 400);
    }
  }

  /// DELETE /api/v1/pipelines/<id> — delete a pipeline.
  Future<shelf.Response> _handleDelete(
      shelf.Request request, String id) async {
    final deleted = await store.delete(id);
    if (!deleted) {
      return _jsonResponse(
          {'success': false, 'error': 'Pipeline not found'}, 404);
    }
    return _jsonResponse({'success': true});
  }

  /// POST /api/v1/pipelines/<id>/run — execute a pipeline.
  Future<shelf.Response> _handleRun(
      shelf.Request request, String id) async {
    final pipeline = await store.load(id);
    if (pipeline == null) {
      return _jsonResponse(
          {'success': false, 'error': 'Pipeline not found'}, 404);
    }

    // Parse optional override parameters
    Map<String, dynamic> overrideParams = {};
    try {
      final body = await request.readAsString();
      if (body.isNotEmpty) {
        final json = jsonDecode(body) as Map<String, dynamic>;
        overrideParams = json['parameters'] as Map<String, dynamic>? ?? {};
      }
    } catch (_) {}

    // Set up progress broadcasting via WebSocket
    executor.onProgress = (update) {
      connectionManager?.broadcastMessage({
        'type': 'task_update',
        'task_type': 'pipeline_execute',
        'status': 'running',
        'result': update,
      });
    };

    // Execute the pipeline
    final result = await executor.execute({
      'pipeline_id': id,
      'parameters': overrideParams,
    });

    // Clear progress callback
    executor.onProgress = null;

    // Broadcast completion
    connectionManager?.broadcastMessage({
      'type': 'task_update',
      'task_type': 'pipeline_execute',
      'status': result['success'] == true ? 'completed' : 'failed',
      'result': result,
    });

    return _jsonResponse(result);
  }

  /// GET /api/v1/nodes/catalog — available node types for the editor.
  Future<shelf.Response> _handleNodeCatalog(shelf.Request request) async {
    final catalog = <Map<String, dynamic>>[];

    // Add domain task nodes
    if (domainRegistry != null) {
      for (final domain in domainRegistry!.domains) {
        for (final taskType in domain.taskTypes) {
          final intent = domain.ollamaIntents
              .where((i) => i.intentName == taskType)
              .firstOrNull;

          catalog.add({
            'type': taskType,
            'domain': domain.id,
            'domain_name': domain.name,
            'name': _taskTypeToName(taskType),
            'description': intent?.description ?? taskType,
            'icon': domain.icon,
            'color': domain.colorHex,
            'inputs': _buildInputPorts(intent),
            'outputs': _buildOutputPorts(taskType),
          });
        }
      }
    }

    // Add built-in executor nodes
    final builtinNodes = [
      {
        'type': 'run_command',
        'domain': 'system',
        'domain_name': 'System',
        'name': 'Run Command',
        'description': 'Execute a shell command',
        'icon': 'terminal',
        'color': '0xFF607D8B',
        'inputs': [
          {'name': 'command', 'type': 'string', 'required': true}
        ],
        'outputs': [
          {'name': 'stdout', 'type': 'string'},
          {'name': 'exit_code', 'type': 'number'}
        ],
      },
      {
        'type': 'ai_query',
        'domain': 'ai',
        'domain_name': 'AI',
        'name': 'AI Query',
        'description': 'Send a prompt to an AI model',
        'icon': 'smart_toy',
        'color': '0xFF9C27B0',
        'inputs': [
          {'name': 'query', 'type': 'string', 'required': true}
        ],
        'outputs': [
          {'name': 'response', 'type': 'string'}
        ],
      },
    ];

    // Only add built-in nodes not already covered by domains
    final domainTypes = catalog.map((n) => n['type']).toSet();
    for (final node in builtinNodes) {
      if (!domainTypes.contains(node['type'])) {
        catalog.add(node);
      }
    }

    return _jsonResponse({
      'success': true,
      'nodes': catalog,
      'total': catalog.length,
    });
  }

  List<Map<String, dynamic>> _buildInputPorts(DomainOllamaIntent? intent) {
    if (intent == null) return [{'name': 'input', 'type': 'any'}];

    final params = intent.parameters;
    if (params.isEmpty) return [{'name': 'input', 'type': 'any'}];

    return params.entries.map((e) => {
          'name': e.key,
          'type': 'string',
          'description': e.value,
        }).toList();
  }

  List<Map<String, dynamic>> _buildOutputPorts(String taskType) {
    // Default output port — specific domains can override
    return [{'name': 'output', 'type': 'any'}];
  }

  String _taskTypeToName(String taskType) {
    return taskType
        .replaceAll('_', ' ')
        .split(' ')
        .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
        .join(' ');
  }

  shelf.Response _jsonResponse(Map<String, dynamic> data,
      [int statusCode = 200]) {
    return shelf.Response(statusCode,
        body: jsonEncode(data),
        headers: {'Content-Type': 'application/json'});
  }
}
