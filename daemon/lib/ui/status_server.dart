import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:shelf_router/shelf_router.dart';
import 'package:opencli_daemon/mobile/mobile_connection_manager.dart';
import 'package:opencli_daemon/core/daemon.dart';
import 'package:opencli_daemon/api/message_handler.dart';

/// HTTP server providing daemon status for UI consumption
class StatusServer {
  final MobileConnectionManager _connectionManager;
  final Daemon _daemon;
  final int port;
  HttpServer? _server;
  late final MessageHandler _messageHandler;

  StatusServer({
    required MobileConnectionManager connectionManager,
    required Daemon daemon,
    this.port = 9875,
  })  : _connectionManager = connectionManager,
        _daemon = daemon {
    _messageHandler = MessageHandler();
  }

  Future<void> start() async {
    final router = Router();

    // REST endpoints
    router.get('/status', _handleStatus);
    router.get('/health', _handleHealth);

    // WebSocket endpoint for unified protocol
    router.get('/ws', _messageHandler.handler);

    final handler = const shelf.Pipeline()
        .addMiddleware(shelf.logRequests())
        .addMiddleware(_cors())
        .addHandler(router.call);

    try {
      _server = await shelf_io.serve(handler, InternetAddress.loopbackIPv4, port);
      print('✓ Status server listening on http://localhost:${_server!.port}');
      print('  - REST API: http://localhost:${_server!.port}/status');
      print('  - WebSocket: ws://localhost:${_server!.port}/ws');
    } catch (e) {
      print('⚠️  Failed to start status server: $e');
    }
  }

  Future<void> stop() async {
    _messageHandler.dispose();
    await _server?.close(force: true);
    _server = null;
  }

  shelf.Middleware _cors() {
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

  Future<shelf.Response> _handleStatus(shelf.Request request) async {
    final stats = _daemon.getStats();
    final clients = _connectionManager.connectedClients;

    final status = {
      'daemon': {
        'version': '0.1.0',
        'uptime_seconds': stats['uptime_seconds'],
        'memory_mb': stats['memory_mb'],
        'plugins_loaded': stats['plugins_loaded'],
        'total_requests': stats['total_requests'],
      },
      'mobile': {
        'connected_clients': clients.length,
        'client_ids': clients.map((id) => id.substring(0, 12)).toList(),
      },
      'timestamp': DateTime.now().toIso8601String(),
    };

    return shelf.Response.ok(
      jsonEncode(status),
      headers: {'Content-Type': 'application/json'},
    );
  }

  Future<shelf.Response> _handleHealth(shelf.Request request) async {
    final health = {
      'status': 'healthy',
      'timestamp': DateTime.now().toIso8601String(),
    };

    return shelf.Response.ok(
      jsonEncode(health),
      headers: {'Content-Type': 'application/json'},
    );
  }
}
