import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:yaml/yaml.dart';
import 'package:path/path.dart' as path;
import 'package:opencli_daemon/core/request_router.dart';
import 'package:opencli_daemon/ipc/ipc_protocol.dart';
import 'package:opencli_daemon/api/api_translator.dart';
import 'package:opencli_daemon/api/message_handler.dart';
import 'package:opencli_daemon/pipeline/pipeline_api.dart';
import 'package:opencli_daemon/domains/media_creation/local_model_manager.dart';
import 'package:opencli_daemon/api/storage_api.dart';
import 'package:opencli_daemon/episode/episode_api.dart';
import 'package:opencli_daemon/api/lora_api.dart';

/// Unified API server on port 9529 for Web UI integration
///
/// Provides HTTP REST API that bridges to the existing RequestRouter,
/// allowing Web UI to execute commands and methods via HTTP.
class UnifiedApiServer {
  final RequestRouter _requestRouter;
  final MessageHandler _messageHandler;
  final int port;
  HttpServer? _server;
  PipelineApi? _pipelineApi;
  Future<void> Function()? _onConfigSaved;
  LocalModelManager? _localModelManager;
  StorageApi? _storageApi;
  EpisodeApi? _episodeApi;
  LoRAApi? _loraApi;

  UnifiedApiServer({
    required RequestRouter requestRouter,
    required MessageHandler messageHandler,
    this.port = 9529,
    PipelineApi? pipelineApi,
    Future<void> Function()? onConfigSaved,
    LocalModelManager? localModelManager,
    StorageApi? storageApi,
    EpisodeApi? episodeApi,
    LoRAApi? loraApi,
  })  : _requestRouter = requestRouter,
        _messageHandler = messageHandler,
        _pipelineApi = pipelineApi,
        _onConfigSaved = onConfigSaved,
        _localModelManager = localModelManager,
        _storageApi = storageApi,
        _episodeApi = episodeApi,
        _loraApi = loraApi;

  /// Set pipeline API (can be configured after construction).
  void setPipelineApi(PipelineApi api) {
    _pipelineApi = api;
  }

  Future<void> start() async {
    final router = Router();

    // POST /api/v1/execute - Main execution endpoint
    router.post('/api/v1/execute', _handleExecute);

    // GET /api/v1/status - Status proxy
    router.get('/api/v1/status', _handleStatus);

    // GET /health - Health check
    router.get('/health', _handleHealth);

    // WebSocket /ws - Real-time messaging
    router.get('/ws', _messageHandler.handler);

    // Config API routes
    router.get('/api/v1/config', _handleGetConfig);
    router.post('/api/v1/config', _handleUpdateConfig);

    // Local model API routes
    router.get('/api/v1/local-models', _handleListLocalModels);
    router.get('/api/v1/local-models/environment', _handleLocalEnv);
    router.post('/api/v1/local-models/setup', _handleSetupEnvironment);
    router.post('/api/v1/local-models/<modelId>/download', _handleDownloadModel);
    router.delete('/api/v1/local-models/<modelId>', _handleDeleteModel);

    // Pipeline API routes
    _pipelineApi?.registerRoutes(router);

    // Storage API routes (history, assets, events, chat)
    _storageApi?.registerRoutes(router);

    // Episode API routes (CRUD + generation)
    _episodeApi?.registerRoutes(router);

    // LoRA + Recipe API routes
    _loraApi?.registerRoutes(router);

    final handler = const shelf.Pipeline()
        .addMiddleware(shelf.logRequests())
        .addMiddleware(_corsMiddleware())
        .addMiddleware(_errorHandlingMiddleware())
        .addHandler(router.call);

    try {
      _server = await shelf_io.serve(
        handler,
        InternetAddress.loopbackIPv4,
        port,
      );
      print(
          '✓ Unified API server listening on http://localhost:${_server!.port}');
      print(
          '  - Execute API: POST http://localhost:${_server!.port}/api/v1/execute');
      print('  - WebSocket: ws://localhost:${_server!.port}/ws');
    } catch (e) {
      print('⚠️  Failed to start unified API server: $e');
      rethrow;
    }
  }

  Future<void> stop() async {
    await _server?.close(force: true);
    _server = null;
  }

  /// Handle POST /api/v1/execute
  ///
  /// Expected request body: {"method": "...", "params": [...], "context": {...}}
  /// Returns: {"success": true/false, "result": "...", ...}
  Future<shelf.Response> _handleExecute(shelf.Request request) async {
    final startTime = DateTime.now();

    try {
      // Parse JSON body
      final body = await request.readAsString();

      if (body.isEmpty) {
        return shelf.Response.badRequest(
          body: jsonEncode(
            ApiTranslator.errorToHttp('Empty request body', null),
          ),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final json = jsonDecode(body) as Map<String, dynamic>;

      // Validate required fields
      if (!json.containsKey('method')) {
        return shelf.Response.badRequest(
          body: jsonEncode(
            ApiTranslator.errorToHttp('Missing required field: method', null),
          ),
          headers: {'Content-Type': 'application/json'},
        );
      }

      // Convert to IpcRequest
      final ipcRequest = ApiTranslator.httpToIpcRequest(json);

      // Route through RequestRouter
      final result = await _requestRouter.route(ipcRequest);

      // Calculate duration
      final duration = DateTime.now().difference(startTime).inMicroseconds;

      // Build response
      final ipcResponse = IpcResponse(
        success: true,
        result: result,
        durationUs: duration,
        cached: false,
        requestId: ipcRequest.requestId,
      );

      // Convert back to HTTP JSON
      final responseJson = ApiTranslator.ipcResponseToHttp(ipcResponse);

      return shelf.Response.ok(
        jsonEncode(responseJson),
        headers: {'Content-Type': 'application/json'},
      );
    } on FormatException catch (e) {
      return shelf.Response.badRequest(
        body: jsonEncode(
          ApiTranslator.errorToHttp('Invalid JSON: ${e.message}', null),
        ),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e, stack) {
      print('Execute error: $e\n$stack');
      final errorJson = ApiTranslator.errorToHttp(e.toString(), null);
      return shelf.Response.internalServerError(
        body: jsonEncode(errorJson),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// Handle GET /api/v1/status
  Future<shelf.Response> _handleStatus(shelf.Request request) async {
    final status = {
      'status': 'running',
      'version': '0.1.0',
      'timestamp': DateTime.now().toIso8601String(),
    };

    return shelf.Response.ok(
      jsonEncode(status),
      headers: {'Content-Type': 'application/json'},
    );
  }

  /// Handle GET /health
  Future<shelf.Response> _handleHealth(shelf.Request request) async {
    return shelf.Response.ok('OK');
  }

  /// Handle GET /api/v1/config
  Future<shelf.Response> _handleGetConfig(shelf.Request request) async {
    try {
      final home = Platform.environment['HOME'] ?? '.';
      final configPath = path.join(home, '.opencli', 'config.yaml');
      final file = File(configPath);

      if (!await file.exists()) {
        return shelf.Response.ok(
          jsonEncode({'config': {}}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final content = await file.readAsString();
      final yaml = loadYaml(content);
      final config = _yamlToJson(yaml);

      // Mask API key values for security (show last 4 chars)
      final masked = _maskApiKeys(Map<String, dynamic>.from(config as Map));

      return shelf.Response.ok(
        jsonEncode({'config': masked}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return shelf.Response.internalServerError(
        body: jsonEncode({'error': 'Failed to read config: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// Handle POST /api/v1/config
  Future<shelf.Response> _handleUpdateConfig(shelf.Request request) async {
    try {
      final body = await request.readAsString();
      final updates = jsonDecode(body) as Map<String, dynamic>;

      final home = Platform.environment['HOME'] ?? '.';
      final configPath = path.join(home, '.opencli', 'config.yaml');
      final file = File(configPath);

      // Read current config
      Map<String, dynamic> current = {};
      if (await file.exists()) {
        final content = await file.readAsString();
        final yaml = loadYaml(content);
        current = Map<String, dynamic>.from(_yamlToJson(yaml) as Map);
      }

      // Deep merge updates
      _deepMerge(current, updates);

      // Write back as YAML
      final yamlStr = _toYamlString(current, 0);
      await file.writeAsString('# OpenCLI Configuration\n# Updated by web UI\n\n$yamlStr');

      // Hot-reload providers immediately
      if (_onConfigSaved != null) {
        try {
          await _onConfigSaved!();
        } catch (e) {
          print('[UnifiedApi] Config reload warning: $e');
        }
      }

      return shelf.Response.ok(
        jsonEncode({'success': true, 'message': 'Config saved and applied.'}),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return shelf.Response.internalServerError(
        body: jsonEncode({'error': 'Failed to update config: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  dynamic _yamlToJson(dynamic yaml) {
    if (yaml is YamlMap) {
      return Map<String, dynamic>.fromEntries(
        yaml.entries.map((e) => MapEntry(e.key.toString(), _yamlToJson(e.value))),
      );
    } else if (yaml is YamlList) {
      return yaml.map((e) => _yamlToJson(e)).toList();
    }
    return yaml;
  }

  Map<String, dynamic> _maskApiKeys(Map<String, dynamic> config) {
    final result = Map<String, dynamic>.from(config);
    // Mask ai_video.api_keys
    if (result['ai_video'] is Map) {
      final aiVideo = Map<String, dynamic>.from(result['ai_video'] as Map);
      if (aiVideo['api_keys'] is Map) {
        final keys = Map<String, dynamic>.from(aiVideo['api_keys'] as Map);
        for (final entry in keys.entries) {
          final val = entry.value?.toString() ?? '';
          if (val.length > 8 && !val.startsWith('\${')) {
            keys[entry.key] = '****${val.substring(val.length - 4)}';
          }
        }
        aiVideo['api_keys'] = keys;
      }
      result['ai_video'] = aiVideo;
    }
    // Mask models.*.api_key
    if (result['models'] is Map) {
      final models = Map<String, dynamic>.from(result['models'] as Map);
      for (final key in models.keys) {
        if (models[key] is Map) {
          final model = Map<String, dynamic>.from(models[key] as Map);
          if (model['api_key'] is String) {
            final val = model['api_key'] as String;
            if (val.length > 8 && !val.startsWith('\${')) {
              model['api_key'] = '****${val.substring(val.length - 4)}';
            }
          }
          models[key] = model;
        }
      }
      result['models'] = models;
    }
    return result;
  }

  void _deepMerge(Map<String, dynamic> target, Map<String, dynamic> source) {
    for (final key in source.keys) {
      if (source[key] is Map && target[key] is Map) {
        _deepMerge(
          target[key] as Map<String, dynamic>,
          Map<String, dynamic>.from(source[key] as Map),
        );
      } else {
        target[key] = source[key];
      }
    }
  }

  String _toYamlString(dynamic value, int indent) {
    final prefix = '  ' * indent;
    if (value is Map) {
      if (value.isEmpty) return '{}\n';
      final buf = StringBuffer();
      for (final entry in value.entries) {
        final v = entry.value;
        if (v is Map || v is List) {
          buf.writeln('$prefix${entry.key}:');
          buf.write(_toYamlString(v, indent + 1));
        } else {
          buf.writeln('$prefix${entry.key}: ${_yamlScalar(v)}');
        }
      }
      return buf.toString();
    } else if (value is List) {
      if (value.isEmpty) return '$prefix[]\n';
      final buf = StringBuffer();
      for (final item in value) {
        if (item is Map) {
          buf.writeln('$prefix-');
          buf.write(_toYamlString(item, indent + 1));
        } else {
          buf.writeln('$prefix- ${_yamlScalar(item)}');
        }
      }
      return buf.toString();
    }
    return '$prefix${_yamlScalar(value)}\n';
  }

  String _yamlScalar(dynamic value) {
    if (value == null) return 'null';
    if (value is bool) return value.toString();
    if (value is num) return value.toString();
    final s = value.toString();
    if (s.contains(':') || s.contains('#') || s.contains("'") ||
        s.startsWith('{') || s.startsWith('[') || s.startsWith('"') ||
        s == 'true' || s == 'false' || s == 'null' || s.isEmpty) {
      return "'${s.replaceAll("'", "''")}'";
    }
    return s;
  }

  /// Handle GET /api/v1/local-models
  Future<shelf.Response> _handleListLocalModels(shelf.Request request) async {
    try {
      if (_localModelManager == null) {
        return shelf.Response.ok(
          jsonEncode({'models': [], 'available': false}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final models = await _localModelManager!.listModels();
      return shelf.Response.ok(
        jsonEncode({
          'models': models.map((m) => m.toJson()).toList(),
          'available': _localModelManager!.isAvailable,
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return shelf.Response.internalServerError(
        body: jsonEncode({'error': 'Failed to list models: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// Handle GET /api/v1/local-models/environment
  Future<shelf.Response> _handleLocalEnv(shelf.Request request) async {
    try {
      if (_localModelManager == null) {
        return shelf.Response.ok(
          jsonEncode({
            'ok': false,
            'python_version': 'not configured',
            'device': 'unknown',
            'missing_packages': ['local-inference not initialized'],
            'venv_exists': false,
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final env = await _localModelManager!.checkEnvironment();
      return shelf.Response.ok(
        jsonEncode(env.toJson()),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return shelf.Response.internalServerError(
        body: jsonEncode({'error': 'Failed to check environment: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// Handle POST /api/v1/local-models/setup
  /// Runs local-inference/setup.sh to create venv and install dependencies
  Future<shelf.Response> _handleSetupEnvironment(shelf.Request request) async {
    try {
      // Find setup.sh relative to the daemon's working directory
      final scriptPath = path.join(
        Directory.current.path, '..', 'local-inference', 'setup.sh',
      );
      final scriptFile = File(path.normalize(scriptPath));

      if (!await scriptFile.exists()) {
        // Try from home dir
        final home = Platform.environment['HOME'] ?? '.';
        final altPath = path.join(home, 'development', 'opencli', 'local-inference', 'setup.sh');
        final altFile = File(altPath);
        if (!await altFile.exists()) {
          return shelf.Response.notFound(
            jsonEncode({'error': 'setup.sh not found. Expected at local-inference/setup.sh'}),
            headers: {'Content-Type': 'application/json'},
          );
        }
        return _runSetupScript(altPath);
      }
      return _runSetupScript(path.normalize(scriptPath));
    } catch (e) {
      return shelf.Response.internalServerError(
        body: jsonEncode({'error': 'Setup failed: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  Future<shelf.Response> _runSetupScript(String scriptPath) async {
    try {
      final result = await Process.run(
        'bash',
        [scriptPath],
        environment: Platform.environment,
        workingDirectory: path.dirname(scriptPath),
      ).timeout(const Duration(minutes: 10));

      final success = result.exitCode == 0;
      return shelf.Response.ok(
        jsonEncode({
          'success': success,
          'exit_code': result.exitCode,
          'stdout': result.stdout.toString(),
          'stderr': result.stderr.toString(),
          'message': success
              ? 'Environment setup complete!'
              : 'Setup failed with exit code ${result.exitCode}',
        }),
        headers: {'Content-Type': 'application/json'},
      );
    } on TimeoutException {
      return shelf.Response.internalServerError(
        body: jsonEncode({'error': 'Setup timed out after 10 minutes'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// Handle POST /api/v1/local-models/:modelId/download
  Future<shelf.Response> _handleDownloadModel(
      shelf.Request request, String modelId) async {
    try {
      if (_localModelManager == null || !_localModelManager!.isAvailable) {
        return shelf.Response.internalServerError(
          body: jsonEncode({
            'error': 'Local inference not available. Run local-inference/setup.sh first.'
          }),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final result = await _localModelManager!.downloadModel(modelId);
      return shelf.Response.ok(
        jsonEncode(result),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return shelf.Response.internalServerError(
        body: jsonEncode({'error': 'Download failed: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// Handle DELETE /api/v1/local-models/:modelId
  Future<shelf.Response> _handleDeleteModel(
      shelf.Request request, String modelId) async {
    try {
      if (_localModelManager == null) {
        return shelf.Response.notFound(
          jsonEncode({'error': 'Local model manager not available'}),
          headers: {'Content-Type': 'application/json'},
        );
      }

      final result = await _localModelManager!.deleteModel(modelId);
      return shelf.Response.ok(
        jsonEncode(result),
        headers: {'Content-Type': 'application/json'},
      );
    } catch (e) {
      return shelf.Response.internalServerError(
        body: jsonEncode({'error': 'Delete failed: $e'}),
        headers: {'Content-Type': 'application/json'},
      );
    }
  }

  /// CORS middleware for Web UI access
  shelf.Middleware _corsMiddleware() {
    return (shelf.Handler handler) {
      return (shelf.Request request) async {
        if (request.method == 'OPTIONS') {
          return shelf.Response.ok('', headers: _corsHeaders);
        }

        final response = await handler(request);
        return response.change(headers: _corsHeaders);
      };
    };
  }

  Map<String, String> get _corsHeaders => {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type',
      };

  /// Error handling middleware
  shelf.Middleware _errorHandlingMiddleware() {
    return (shelf.Handler handler) {
      return (shelf.Request request) async {
        try {
          return await handler(request);
        } catch (e, stack) {
          print('API Error: $e\n$stack');
          return shelf.Response.internalServerError(
            body: jsonEncode({'error': e.toString()}),
            headers: {'Content-Type': 'application/json'},
          );
        }
      };
    };
  }
}
