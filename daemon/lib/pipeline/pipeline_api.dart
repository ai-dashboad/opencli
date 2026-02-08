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
    router.post('/api/v1/pipelines/<id>/run-from/<nodeId>', _handleRunFromNode);

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

  /// POST /api/v1/pipelines/<id>/run-from/<nodeId> — execute from a specific node.
  Future<shelf.Response> _handleRunFromNode(
      shelf.Request request, String id, String nodeId) async {
    final pipeline = await store.load(id);
    if (pipeline == null) {
      return _jsonResponse(
          {'success': false, 'error': 'Pipeline not found'}, 404);
    }

    Map<String, dynamic> overrideParams = {};
    Map<String, dynamic> previousResults = {};
    try {
      final body = await request.readAsString();
      if (body.isNotEmpty) {
        final json = jsonDecode(body) as Map<String, dynamic>;
        overrideParams = json['parameters'] as Map<String, dynamic>? ?? {};
        previousResults =
            json['previous_results'] as Map<String, dynamic>? ?? {};
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

    final result = await executor.executeFromNode(
      pipeline,
      nodeId,
      overrideParams,
      previousResults,
    );

    executor.onProgress = null;

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
            'inputs': _buildInputPorts(intent, taskType),
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
          {
            'name': 'command',
            'type': 'string',
            'required': true,
            'inputType': 'textarea',
            'description': 'Shell command to execute',
          }
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
          {
            'name': 'model',
            'type': 'string',
            'inputType': 'select',
            'options': ['llama3.2', 'mistral', 'codellama', 'gemma2'],
            'defaultValue': 'llama3.2',
            'description': 'AI model to use',
          },
          {
            'name': 'query',
            'type': 'string',
            'required': true,
            'inputType': 'textarea',
            'description': 'Prompt to send to the AI',
          }
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

  List<Map<String, dynamic>> _buildInputPorts(
      DomainOllamaIntent? intent, String taskType) {
    if (intent == null) return [{'name': 'input', 'type': 'any'}];

    final params = intent.parameters;
    if (params.isEmpty) return [{'name': 'input', 'type': 'any'}];

    return params.entries.map((e) {
      final port = <String, dynamic>{
        'name': e.key,
        'type': 'string',
        'description': e.value,
        'inputType': _inferInputType(e.key, e.value),
      };

      // Add options for select inputs
      final options = _knownOptions[e.key];
      if (options != null) {
        port['inputType'] = 'select';
        port['options'] = options;
      }

      // Add slider config for numeric inputs
      final sliderCfg = _sliderConfig[e.key];
      if (sliderCfg != null) {
        port['inputType'] = 'slider';
        port.addAll(sliderCfg);
      }

      return port;
    }).toList();
  }

  /// Infer input type from parameter name and description.
  String _inferInputType(String name, String description) {
    final lower = name.toLowerCase();
    final descLower = description.toLowerCase();

    // Textarea for long-form text
    if (['prompt', 'query', 'message', 'text', 'content', 'description',
         'body', 'note', 'command'].contains(lower)) {
      return 'textarea';
    }
    if (descLower.contains('prompt') || descLower.contains('message')) {
      return 'textarea';
    }

    // Select for known enums
    if (['model', 'provider', 'style', 'format', 'type', 'mode',
         'language', 'unit', 'category'].contains(lower)) {
      return 'select';
    }

    // Slider for numeric
    if (['count', 'duration', 'temperature', 'limit', 'steps',
         'width', 'height', 'quality', 'volume'].contains(lower)) {
      return 'slider';
    }

    // Toggle for booleans
    if (['enabled', 'verbose', 'recursive', 'force',
         'silent', 'async'].contains(lower)) {
      return 'toggle';
    }

    return 'text';
  }

  /// Known option lists for select inputs.
  static const _knownOptions = <String, List<String>>{
    'model': ['llama3.2', 'mistral', 'codellama', 'gemma2'],
    'provider': ['replicate', 'runway', 'kling', 'luma'],
    'style': [
      'cinematic',
      'adPromo',
      'socialMedia',
      'calmAesthetic',
      'epic',
      'mysterious'
    ],
    'format': ['json', 'text', 'markdown', 'csv'],
    'unit': ['celsius', 'fahrenheit', 'kelvin'],
  };

  /// Slider configurations for numeric inputs.
  static const _sliderConfig = <String, Map<String, dynamic>>{
    'temperature': {'min': 0.0, 'max': 2.0, 'step': 0.1, 'defaultValue': 0.7},
    'count': {'min': 1, 'max': 100, 'step': 1, 'defaultValue': 10},
    'duration': {'min': 1, 'max': 300, 'step': 1, 'defaultValue': 30},
    'steps': {'min': 1, 'max': 150, 'step': 1, 'defaultValue': 30},
    'quality': {'min': 1, 'max': 100, 'step': 1, 'defaultValue': 85},
    'volume': {'min': 0, 'max': 100, 'step': 1, 'defaultValue': 50},
  };

  /// Typed output ports per task type.
  static const _taskOutputPorts = <String, List<Map<String, String>>>{
    'weather_current': [
      {'name': 'temperature', 'type': 'number'},
      {'name': 'conditions', 'type': 'string'},
      {'name': 'display', 'type': 'string'},
    ],
    'weather_forecast': [
      {'name': 'forecast', 'type': 'string'},
      {'name': 'display', 'type': 'string'},
    ],
    'calculator_eval': [
      {'name': 'result', 'type': 'number'},
      {'name': 'display', 'type': 'string'},
    ],
    'calculator_convert': [
      {'name': 'result', 'type': 'number'},
      {'name': 'display', 'type': 'string'},
    ],
    'timer_set': [
      {'name': 'timer_id', 'type': 'string'},
      {'name': 'display', 'type': 'string'},
    ],
    'system_info': [
      {'name': 'info', 'type': 'string'},
      {'name': 'display', 'type': 'string'},
    ],
    'run_command': [
      {'name': 'stdout', 'type': 'string'},
      {'name': 'exit_code', 'type': 'number'},
    ],
    'ai_query': [
      {'name': 'response', 'type': 'string'},
    ],
    'music_play': [
      {'name': 'display', 'type': 'string'},
    ],
    'reminders_add': [
      {'name': 'display', 'type': 'string'},
    ],
    'calendar_today': [
      {'name': 'events', 'type': 'string'},
      {'name': 'display', 'type': 'string'},
    ],
    'media_ai_generate_video': [
      {'name': 'video_path', 'type': 'file'},
      {'name': 'display', 'type': 'string'},
    ],
    'timezone_current': [
      {'name': 'time', 'type': 'string'},
      {'name': 'display', 'type': 'string'},
    ],
    'knowledge_search': [
      {'name': 'answer', 'type': 'string'},
      {'name': 'display', 'type': 'string'},
    ],
  };

  List<Map<String, dynamic>> _buildOutputPorts(String taskType) {
    final ports = _taskOutputPorts[taskType];
    if (ports != null) return ports.map((p) => Map<String, dynamic>.from(p)).toList();
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
