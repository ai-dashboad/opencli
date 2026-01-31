class IpcRequest {
  final String method;
  final List<dynamic> params;
  final Map<String, dynamic> context;
  final String? requestId;
  final int? timeoutMs;

  IpcRequest({
    required this.method,
    this.params = const [],
    this.context = const {},
    this.requestId,
    this.timeoutMs,
  });

  Map<String, dynamic> toMap() {
    return {
      'method': method,
      'params': params,
      'context': context,
      if (requestId != null) 'request_id': requestId,
      if (timeoutMs != null) 'timeout_ms': timeoutMs,
    };
  }

  factory IpcRequest.fromMap(Map<dynamic, dynamic> map) {
    return IpcRequest(
      method: map['method'] as String,
      params: List<dynamic>.from(map['params'] ?? []),
      context: Map<String, dynamic>.from(map['context'] ?? {}),
      requestId: map['request_id'] as String?,
      timeoutMs: map['timeout_ms'] as int?,
    );
  }
}

class IpcResponse {
  final bool success;
  final String result;
  final int durationUs;
  final bool cached;
  final String? requestId;
  final String? error;

  IpcResponse({
    required this.success,
    required this.result,
    required this.durationUs,
    this.cached = false,
    this.requestId,
    this.error,
  });

  Map<String, dynamic> toMap() {
    return {
      'success': success,
      'result': result,
      'duration_us': durationUs,
      'cached': cached,
      if (requestId != null) 'request_id': requestId,
      if (error != null) 'error': error,
    };
  }

  factory IpcResponse.fromMap(Map<dynamic, dynamic> map) {
    return IpcResponse(
      success: map['success'] as bool,
      result: map['result'] as String,
      durationUs: map['duration_us'] as int,
      cached: map['cached'] as bool? ?? false,
      requestId: map['request_id'] as String?,
      error: map['error'] as String?,
    );
  }
}
