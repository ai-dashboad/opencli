import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:msgpack_dart/msgpack_dart.dart';
import 'package:opencli_daemon/core/request_router.dart';
import 'package:opencli_daemon/ipc/ipc_protocol.dart';

class IpcServer {
  final String socketPath;
  final RequestRouter router;
  ServerSocket? _server;
  final List<Socket> _clients = [];

  IpcServer({
    required this.socketPath,
    required this.router,
  });

  Future<void> start() async {
    // Remove old socket file if exists
    final socketFile = File(socketPath);
    if (await socketFile.exists()) {
      await socketFile.delete();
    }

    // Start Unix socket server
    _server = await ServerSocket.bind(
      InternetAddress(socketPath, type: InternetAddressType.unix),
      0,
    );

    // Set socket permissions (Unix only)
    if (Platform.isLinux || Platform.isMacOS) {
      await Process.run('chmod', ['600', socketPath]);
    }

    print('IPC Server listening on: $socketPath');

    // Handle incoming connections
    _server!.listen(_handleConnection);
  }

  Future<void> stop() async {
    for (final client in _clients) {
      await client.close();
    }
    _clients.clear();

    await _server?.close();

    // Clean up socket file
    final socketFile = File(socketPath);
    if (await socketFile.exists()) {
      await socketFile.delete();
    }
  }

  void _handleConnection(Socket socket) {
    _clients.add(socket);
    print('Client connected: ${socket.remoteAddress}');

    socket.listen(
      (Uint8List data) => _handleData(socket, data),
      onDone: () {
        _clients.remove(socket);
        print('Client disconnected');
      },
      onError: (error) {
        print('Client error: $error');
        _clients.remove(socket);
      },
    );
  }

  Future<void> _handleData(Socket socket, Uint8List data) async {
    try {
      // Read length prefix (4 bytes LE)
      if (data.length < 4) return;

      final length = ByteData.sublistView(data, 0, 4).getUint32(0, Endian.little);

      if (data.length < 4 + length) return;

      // Deserialize MessagePack payload
      final payload = data.sublist(4, 4 + length);
      final decoded = deserialize(payload) as Map;

      final request = IpcRequest.fromMap(decoded);

      // Route and handle request
      final startTime = DateTime.now();
      final result = await router.route(request);
      final duration = DateTime.now().difference(startTime);

      // Build response
      final response = IpcResponse(
        success: true,
        result: result,
        durationUs: duration.inMicroseconds,
        cached: false,
        requestId: request.requestId,
        error: null,
      );

      // Send response
      await _sendResponse(socket, response);

    } catch (e) {
      // Send error response
      final errorResponse = IpcResponse(
        success: false,
        result: '',
        durationUs: 0,
        cached: false,
        requestId: null,
        error: e.toString(),
      );

      await _sendResponse(socket, errorResponse);
    }
  }

  Future<void> _sendResponse(Socket socket, IpcResponse response) async {
    // Serialize to MessagePack
    final payload = serialize(response.toMap());

    // Add length prefix
    final length = ByteData(4)..setUint32(0, payload.length, Endian.little);

    // Send length + payload
    socket.add(length.buffer.asUint8List());
    socket.add(payload);
    await socket.flush();
  }
}
