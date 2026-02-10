import 'package:opencli_daemon/ipc/ipc_protocol.dart';

/// Translates between HTTP JSON requests and IPC protocol messages
class ApiTranslator {
  /// Convert HTTP JSON body to IpcRequest
  static IpcRequest httpToIpcRequest(Map<String, dynamic> json) {
    return IpcRequest(
      method: json['method'] as String,
      params: List<String>.from(json['params'] ?? []),
      context: Map<String, String>.from(json['context'] ?? {}),
      requestId: _generateRequestId(),
      timeoutMs: (json['timeout_ms'] as int?) ?? 30000,
    );
  }

  /// Convert IpcResponse to HTTP JSON
  static Map<String, dynamic> ipcResponseToHttp(IpcResponse response) {
    return {
      'success': response.success,
      'result': response.result,
      'duration_ms': response.durationUs / 1000,
      'request_id': response.requestId,
      'cached': response.cached,
      if (!response.success && response.error != null) 'error': response.error,
    };
  }

  /// Format errors for HTTP response
  static Map<String, dynamic> errorToHttp(String error, String? requestId) {
    return {
      'success': false,
      'error': error,
      'request_id': requestId,
    };
  }

  /// Generate unique request ID
  static String _generateRequestId() {
    return DateTime.now().millisecondsSinceEpoch.toRadixString(16);
  }
}
