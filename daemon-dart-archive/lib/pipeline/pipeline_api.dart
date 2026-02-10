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
    router.get('/api/v1/nodes/video-catalog', _handleVideoNodeCatalog);
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

  /// GET /api/v1/nodes/video-catalog — video editing node types for the editor.
  Future<shelf.Response> _handleVideoNodeCatalog(shelf.Request request) async {
    final catalog = <Map<String, dynamic>>[
      // ── Input category ──────────────────────────────────────────────
      {
        'type': 'load_model',
        'category': 'input',
        'name': 'Load Model',
        'description': 'Select an AI video generation provider and model',
        'icon': '⊕',
        'color': 0xFF4CAF50,
        'inputs': [
          {
            'name': 'provider',
            'type': 'string',
            'inputType': 'select',
            'options': ['Flux', 'Runway', 'Kling', 'Luma'],
            'defaultValue': 'Flux',
            'description': 'AI video generation provider',
          },
          {
            'name': 'model',
            'type': 'string',
            'inputType': 'select',
            'options': ['Flux Dev', 'Flux Pro', 'Flux Schnell'],
            'defaultValue': 'Flux Dev',
            'description': 'Model variant to load',
          },
        ],
        'outputs': [
          {'name': 'model', 'type': 'model'},
        ],
      },
      {
        'type': 'prompt',
        'category': 'input',
        'name': 'Prompt',
        'description': 'Text prompt describing the desired video content',
        'icon': '✎',
        'color': 0xFF4CAF50,
        'inputs': [
          {
            'name': 'prompt',
            'type': 'string',
            'inputType': 'textarea',
            'description': 'Descriptive prompt for video generation',
          },
        ],
        'outputs': [
          {'name': 'text', 'type': 'string'},
        ],
      },
      {
        'type': 'load_image',
        'category': 'input',
        'name': 'Load Image',
        'description': 'Load a reference image from a file path or URL',
        'icon': '⬒',
        'color': 0xFF4CAF50,
        'inputs': [
          {
            'name': 'path',
            'type': 'string',
            'inputType': 'text',
            'description': 'Image file path or URL',
          },
        ],
        'outputs': [
          {'name': 'image', 'type': 'image'},
        ],
      },
      {
        'type': 'number',
        'category': 'input',
        'name': 'Number',
        'description': 'A numeric constant value',
        'icon': '#',
        'color': 0xFF4CAF50,
        'inputs': [
          {
            'name': 'value',
            'type': 'number',
            'inputType': 'text',
            'description': 'Numeric value',
          },
          {
            'name': 'label',
            'type': 'string',
            'inputType': 'text',
            'description': 'Display label for this value',
          },
        ],
        'outputs': [
          {'name': 'value', 'type': 'number'},
        ],
      },

      // ── Process category ────────────────────────────────────────────
      {
        'type': 'generate',
        'category': 'process',
        'name': 'Generate',
        'description': 'Generate a video from a model, prompt, and optional reference image',
        'icon': '✱',
        'color': 0xFF2196F3,
        'inputs': [
          {'name': 'model', 'type': 'model', 'description': 'Loaded model'},
          {'name': 'prompt', 'type': 'string', 'description': 'Generation prompt'},
          {
            'name': 'image',
            'type': 'image',
            'description': 'Optional reference image for image-to-video',
            'required': false,
          },
          {
            'name': 'steps',
            'type': 'number',
            'inputType': 'slider',
            'min': 1,
            'max': 150,
            'step': 1,
            'defaultValue': 30,
            'description': 'Number of inference steps',
          },
          {
            'name': 'duration',
            'type': 'number',
            'inputType': 'slider',
            'min': 1,
            'max': 30,
            'step': 1,
            'defaultValue': 5,
            'description': 'Video duration in seconds',
          },
          {
            'name': 'seed',
            'type': 'number',
            'inputType': 'text',
            'description': 'Random seed for reproducibility',
          },
        ],
        'outputs': [
          {'name': 'video', 'type': 'video'},
        ],
      },
      {
        'type': 'concat',
        'category': 'process',
        'name': 'Concatenate',
        'description': 'Join two video clips sequentially with an optional transition',
        'icon': '⊞',
        'color': 0xFF2196F3,
        'inputs': [
          {'name': 'video_a', 'type': 'video', 'description': 'First video clip'},
          {'name': 'video_b', 'type': 'video', 'description': 'Second video clip'},
          {
            'name': 'transition',
            'type': 'string',
            'inputType': 'select',
            'options': ['none', 'fade', 'wipe', 'dissolve'],
            'defaultValue': 'none',
            'description': 'Transition effect between clips',
          },
        ],
        'outputs': [
          {'name': 'video', 'type': 'video'},
        ],
      },
      {
        'type': 'blend',
        'category': 'process',
        'name': 'Blend',
        'description': 'Blend two video clips together using a compositing mode',
        'icon': '◑',
        'color': 0xFF2196F3,
        'inputs': [
          {'name': 'video_a', 'type': 'video', 'description': 'Base video layer'},
          {'name': 'video_b', 'type': 'video', 'description': 'Overlay video layer'},
          {
            'name': 'ratio',
            'type': 'number',
            'inputType': 'slider',
            'min': 0.0,
            'max': 1.0,
            'step': 0.05,
            'defaultValue': 0.5,
            'description': 'Blend ratio (0 = all A, 1 = all B)',
          },
          {
            'name': 'mode',
            'type': 'string',
            'inputType': 'select',
            'options': ['overlay', 'multiply', 'screen', 'add'],
            'defaultValue': 'overlay',
            'description': 'Blending mode',
          },
        ],
        'outputs': [
          {'name': 'video', 'type': 'video'},
        ],
      },
      {
        'type': 'adjust',
        'category': 'process',
        'name': 'Adjust',
        'description': 'Adjust brightness, contrast, and saturation of a video',
        'icon': '◐',
        'color': 0xFF2196F3,
        'inputs': [
          {'name': 'video', 'type': 'video', 'description': 'Input video'},
          {
            'name': 'brightness',
            'type': 'number',
            'inputType': 'slider',
            'min': -1.0,
            'max': 1.0,
            'step': 0.05,
            'defaultValue': 0.0,
            'description': 'Brightness adjustment',
          },
          {
            'name': 'contrast',
            'type': 'number',
            'inputType': 'slider',
            'min': 0.0,
            'max': 3.0,
            'step': 0.1,
            'defaultValue': 1.0,
            'description': 'Contrast multiplier',
          },
          {
            'name': 'saturation',
            'type': 'number',
            'inputType': 'slider',
            'min': 0.0,
            'max': 3.0,
            'step': 0.1,
            'defaultValue': 1.0,
            'description': 'Saturation multiplier',
          },
        ],
        'outputs': [
          {'name': 'video', 'type': 'video'},
        ],
      },
      {
        'type': 'upscale',
        'category': 'process',
        'name': 'Upscale',
        'description': 'Upscale video resolution using a selected interpolation method',
        'icon': '⇱',
        'color': 0xFF2196F3,
        'inputs': [
          {'name': 'video', 'type': 'video', 'description': 'Input video'},
          {
            'name': 'scale',
            'type': 'string',
            'inputType': 'select',
            'options': ['2x', '4x'],
            'defaultValue': '2x',
            'description': 'Upscale factor',
          },
          {
            'name': 'method',
            'type': 'string',
            'inputType': 'select',
            'options': ['lanczos', 'bicubic', 'bilinear'],
            'defaultValue': 'lanczos',
            'description': 'Interpolation method',
          },
        ],
        'outputs': [
          {'name': 'video', 'type': 'video'},
        ],
      },
      {
        'type': 'style_transfer',
        'category': 'process',
        'name': 'Style Transfer',
        'description': 'Apply a cinematic style preset to a video',
        'icon': '❖',
        'color': 0xFF2196F3,
        'inputs': [
          {'name': 'video', 'type': 'video', 'description': 'Input video'},
          {
            'name': 'preset',
            'type': 'string',
            'inputType': 'select',
            'options': [
              'cinematic',
              'adPromo',
              'socialMedia',
              'calmAesthetic',
              'epic',
              'mysterious',
            ],
            'defaultValue': 'cinematic',
            'description': 'Style preset to apply',
          },
        ],
        'outputs': [
          {'name': 'video', 'type': 'video'},
        ],
      },
      {
        'type': 'controlnet',
        'category': 'process',
        'name': 'ControlNet',
        'description':
            'Extract control signals from a reference image (placeholder — not yet implemented)',
        'icon': '⌖',
        'color': 0xFF9E9E9E,
        'placeholder': true,
        'inputs': [
          {'name': 'image', 'type': 'image', 'description': 'Reference image'},
          {
            'name': 'type',
            'type': 'string',
            'inputType': 'select',
            'options': ['pose', 'depth', 'edge', 'canny'],
            'defaultValue': 'pose',
            'description': 'Control signal type',
          },
        ],
        'outputs': [
          {'name': 'control', 'type': 'control'},
        ],
      },
      {
        'type': 'ip_adapter',
        'category': 'process',
        'name': 'IP-Adapter',
        'description':
            'Generate an image embedding from a reference image (placeholder — not yet implemented)',
        'icon': '⊛',
        'color': 0xFF9E9E9E,
        'placeholder': true,
        'inputs': [
          {
            'name': 'ref_image',
            'type': 'image',
            'description': 'Reference image for style/content embedding',
          },
          {
            'name': 'strength',
            'type': 'number',
            'inputType': 'slider',
            'min': 0.0,
            'max': 1.0,
            'step': 0.05,
            'defaultValue': 0.75,
            'description': 'Adapter influence strength',
          },
        ],
        'outputs': [
          {'name': 'embedding', 'type': 'embedding'},
        ],
      },

      // ── Audio category ──────────────────────────────────────────────
      {
        'type': 'tts_synthesize',
        'category': 'audio',
        'name': 'Text-to-Speech',
        'description': 'Generate spoken audio from text using Edge TTS or ElevenLabs',
        'icon': '🗣',
        'color': 0xFF4CAF50,
        'inputs': [
          {
            'name': 'text',
            'type': 'string',
            'inputType': 'textarea',
            'required': true,
            'description': 'Text to convert to speech',
          },
          {
            'name': 'voice',
            'type': 'string',
            'inputType': 'select',
            'options': [
              'zh-CN-XiaoxiaoNeural', 'zh-CN-YunxiNeural', 'zh-CN-YunjianNeural',
              'ja-JP-NanamiNeural', 'ja-JP-KeitaNeural',
              'en-US-JennyNeural', 'en-US-GuyNeural',
            ],
            'defaultValue': 'zh-CN-XiaoxiaoNeural',
            'description': 'TTS voice',
          },
          {
            'name': 'rate',
            'type': 'number',
            'inputType': 'slider',
            'min': 0.5,
            'max': 2.0,
            'step': 0.1,
            'defaultValue': 1.0,
            'description': 'Speech rate',
          },
        ],
        'outputs': [
          {'name': 'audio', 'type': 'audio'},
          {'name': 'file_path', 'type': 'string'},
        ],
      },
      {
        'type': 'audio_mix',
        'category': 'audio',
        'name': 'Audio Mix',
        'description': 'Mix voice audio with background music',
        'icon': '🎵',
        'color': 0xFF4CAF50,
        'inputs': [
          {'name': 'voice', 'type': 'audio', 'description': 'Voice audio input'},
          {'name': 'bgm', 'type': 'audio', 'description': 'Background music input'},
          {
            'name': 'bgm_volume',
            'type': 'number',
            'inputType': 'slider',
            'min': 0.0,
            'max': 1.0,
            'step': 0.05,
            'defaultValue': 0.3,
            'description': 'BGM volume level',
          },
        ],
        'outputs': [
          {'name': 'audio', 'type': 'audio'},
        ],
      },
      {
        'type': 'subtitle_overlay',
        'category': 'process',
        'name': 'Subtitles',
        'description': 'Burn ASS/SRT subtitles onto a video',
        'icon': '🔤',
        'color': 0xFF2196F3,
        'inputs': [
          {'name': 'video', 'type': 'video', 'description': 'Input video'},
          {'name': 'subtitles', 'type': 'string', 'inputType': 'text', 'description': 'Path to ASS/SRT subtitle file'},
        ],
        'outputs': [
          {'name': 'video', 'type': 'video'},
        ],
      },
      {
        'type': 'video_assembly',
        'category': 'output',
        'name': 'Assemble Video',
        'description': 'Concatenate video clips and mux with audio into final output',
        'icon': '🎬',
        'color': 0xFFFF9800,
        'inputs': [
          {'name': 'videos', 'type': 'video', 'description': 'Video clips to concatenate'},
          {'name': 'audio', 'type': 'audio', 'description': 'Audio track (optional)', 'required': false},
          {'name': 'subtitles', 'type': 'string', 'description': 'Subtitle file path (optional)', 'required': false},
        ],
        'outputs': [
          {'name': 'video', 'type': 'video'},
        ],
      },

      // ── Output category ─────────────────────────────────────────────
      {
        'type': 'output',
        'category': 'output',
        'name': 'Output',
        'description': 'Save the final video to disk in the chosen format',
        'icon': '≡',
        'color': 0xFFFF9800,
        'inputs': [
          {'name': 'video', 'type': 'video', 'description': 'Video to save'},
          {
            'name': 'format',
            'type': 'string',
            'inputType': 'select',
            'options': ['mp4', 'webm', 'gif'],
            'defaultValue': 'mp4',
            'description': 'Output file format',
          },
          {
            'name': 'save_path',
            'type': 'string',
            'inputType': 'text',
            'description': 'File path to save the output video',
          },
        ],
        'outputs': <Map<String, dynamic>>[],
      },
    ];

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
    'provider': ['pollinations', 'replicate', 'runway', 'kling', 'luma'],
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
      {'name': 'video_base64', 'type': 'video'},
      {'name': 'display', 'type': 'string'},
    ],
    'media_ai_generate_image': [
      {'name': 'image_base64', 'type': 'image'},
      {'name': 'prompt', 'type': 'string'},
      {'name': 'display', 'type': 'string'},
    ],
    'media_animate_photo': [
      {'name': 'video_base64', 'type': 'video'},
      {'name': 'display', 'type': 'string'},
    ],
    'media_tts_synthesize': [
      {'name': 'audio_base64', 'type': 'audio'},
      {'name': 'file_path', 'type': 'string'},
      {'name': 'duration_ms', 'type': 'number'},
      {'name': 'display', 'type': 'string'},
    ],
    'media_tts_list_voices': [
      {'name': 'voices', 'type': 'string'},
      {'name': 'display', 'type': 'string'},
    ],
    'media_audio_mix': [
      {'name': 'output_path', 'type': 'string'},
      {'name': 'display', 'type': 'string'},
    ],
    'media_subtitle_overlay': [
      {'name': 'output_path', 'type': 'string'},
      {'name': 'display', 'type': 'string'},
    ],
    'media_scene_transition': [
      {'name': 'output_path', 'type': 'string'},
      {'name': 'display', 'type': 'string'},
    ],
    'media_video_assembly': [
      {'name': 'output_path', 'type': 'string'},
      {'name': 'video_base64', 'type': 'video'},
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
