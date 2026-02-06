import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:opencli_daemon/core/request_router.dart';
import 'package:opencli_daemon/ipc/ipc_protocol.dart';
import 'package:opencli_daemon/api/api_translator.dart';
import 'package:opencli_daemon/api/message_handler.dart';

/// Unified API server on port 9529 for Web UI integration
///
/// Provides HTTP REST API that bridges to the existing RequestRouter,
/// allowing Web UI to execute commands and methods via HTTP.
class UnifiedApiServer {
  final RequestRouter _requestRouter;
  final MessageHandler _messageHandler;
  final int port;
  HttpServer? _server;

  UnifiedApiServer({
    required RequestRouter requestRouter,
    required MessageHandler messageHandler,
    this.port = 9529,
  })  : _requestRouter = requestRouter,
        _messageHandler = messageHandler;

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
      final duration =
          DateTime.now().difference(startTime).inMicroseconds;

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
        'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
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
