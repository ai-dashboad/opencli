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

  UnifiedApiServer({
    required RequestRouter requestRouter,
    required MessageHandler messageHandler,
    this.port = 9529,
    PipelineApi? pipelineApi,
  })  : _requestRouter = requestRouter,
        _messageHandler = messageHandler,
        _pipelineApi = pipelineApi;

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

    // Pipeline API routes
    _pipelineApi?.registerRoutes(router);

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

      return shelf.Response.ok(
        jsonEncode({'success': true, 'message': 'Config updated. Restart daemon to apply changes.'}),
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
