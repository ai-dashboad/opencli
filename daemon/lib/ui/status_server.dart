import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;
import 'package:opencli_daemon/mobile/mobile_connection_manager.dart';
import 'package:opencli_daemon/core/daemon.dart';

/// HTTP server providing daemon status for UI consumption
class StatusServer {
  final MobileConnectionManager _connectionManager;
  final Daemon _daemon;
  final int port;
  HttpServer? _server;

  StatusServer({
    required MobileConnectionManager connectionManager,
    required Daemon daemon,
    this.port = 9875,
  })  : _connectionManager = connectionManager,
        _daemon = daemon;

  Future<void> start() async {
    final handler = const shelf.Pipeline()
        .addMiddleware(shelf.logRequests())
        .addMiddleware(_cors())
        .addHandler(_router);

    try {
      _server = await shelf_io.serve(handler, InternetAddress.loopbackIPv4, port);
      print('✓ Status server listening on http://localhost:${_server!.port}');
    } catch (e) {
      print('⚠️  Failed to start status server: $e');
    }
  }

  Future<void> stop() async {
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

  Future<shelf.Response> _router(shelf.Request request) async {
    final path = request.url.path;

    switch (path) {
      case 'status':
        return _handleStatus(request);
      case 'health':
        return _handleHealth(request);
      default:
        return shelf.Response.notFound('Not found');
    }
  }

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
