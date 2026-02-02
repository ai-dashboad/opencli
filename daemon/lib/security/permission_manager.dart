import 'dart:async';
import 'device_pairing.dart';

/// Permission level for operations
enum PermissionLevel {
  /// Auto-execute without notification
  auto,

  /// Execute with notification
  notify,

  /// Require confirmation before execution
  confirm,

  /// Never allow (must be done locally)
  deny,
}

/// Operation category for permission classification
enum OperationCategory {
  /// Read-only queries (system info, file listing)
  query,

  /// Opening applications or URLs
  open,

  /// Taking screenshots or recordings
  capture,

  /// Reading file contents
  fileRead,

  /// Writing or creating files
  fileWrite,

  /// Deleting files
  fileDelete,

  /// Running shell commands
  command,

  /// Closing applications
  close,

  /// Modifying system settings
  system,

  /// Unknown/other operations
  other,
}

/// Pending confirmation request
class ConfirmationRequest {
  final String id;
  final String deviceId;
  final String operation;
  final Map<String, dynamic> details;
  final DateTime createdAt;
  final Duration timeout;
  final Completer<bool> completer;

  ConfirmationRequest({
    required this.id,
    required this.deviceId,
    required this.operation,
    required this.details,
    required this.createdAt,
    this.timeout = const Duration(seconds: 30),
  }) : completer = Completer<bool>();

  bool get isExpired =>
      DateTime.now().difference(createdAt) > timeout;

  void approve() {
    if (!completer.isCompleted) {
      completer.complete(true);
    }
  }

  void deny() {
    if (!completer.isCompleted) {
      completer.complete(false);
    }
  }

  void expire() {
    if (!completer.isCompleted) {
      completer.complete(false);
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'deviceId': deviceId,
    'operation': operation,
    'details': details,
    'createdAt': createdAt.toIso8601String(),
    'timeoutSeconds': timeout.inSeconds,
  };
}

/// Manages operation permissions and confirmation flows
class PermissionManager {
  final DevicePairingManager _pairingManager;

  /// Operation to permission level mapping
  final Map<String, PermissionLevel> _defaultPermissions = {};

  /// Operation to category mapping
  final Map<String, OperationCategory> _operationCategories = {};

  /// Pending confirmation requests
  final Map<String, ConfirmationRequest> _pendingConfirmations = {};

  /// Confirmation listeners
  final List<void Function(ConfirmationRequest)> _confirmationListeners = [];

  /// Timer for cleanup
  Timer? _cleanupTimer;

  PermissionManager({
    required DevicePairingManager pairingManager,
  }) : _pairingManager = pairingManager {
    _initializeDefaultPermissions();
    _startCleanupTimer();
  }

  /// Initialize default permission levels
  void _initializeDefaultPermissions() {
    // Query operations - auto-execute
    _setPermission('system_info', PermissionLevel.auto, OperationCategory.query);
    _setPermission('list_apps', PermissionLevel.auto, OperationCategory.query);
    _setPermission('list_processes', PermissionLevel.auto, OperationCategory.query);
    _setPermission('check_process', PermissionLevel.auto, OperationCategory.query);

    // Open operations - notify
    _setPermission('open_app', PermissionLevel.notify, OperationCategory.open);
    _setPermission('open_url', PermissionLevel.notify, OperationCategory.open);
    _setPermission('web_search', PermissionLevel.notify, OperationCategory.open);
    _setPermission('open_file', PermissionLevel.notify, OperationCategory.open);

    // Capture operations - notify
    _setPermission('screenshot', PermissionLevel.notify, OperationCategory.capture);

    // File read operations - auto
    _setPermission('read_file', PermissionLevel.auto, OperationCategory.fileRead);
    _setPermission('file_operation:list', PermissionLevel.auto, OperationCategory.fileRead);
    _setPermission('file_operation:search', PermissionLevel.auto, OperationCategory.fileRead);

    // File write operations - confirm
    _setPermission('create_file', PermissionLevel.confirm, OperationCategory.fileWrite);
    _setPermission('file_operation:create', PermissionLevel.confirm, OperationCategory.fileWrite);
    _setPermission('file_operation:move', PermissionLevel.confirm, OperationCategory.fileWrite);
    _setPermission('file_operation:organize', PermissionLevel.confirm, OperationCategory.fileWrite);

    // File delete operations - confirm
    _setPermission('delete_file', PermissionLevel.confirm, OperationCategory.fileDelete);
    _setPermission('file_operation:delete', PermissionLevel.confirm, OperationCategory.fileDelete);

    // Command operations - confirm
    _setPermission('run_command', PermissionLevel.confirm, OperationCategory.command);

    // Close operations - confirm
    _setPermission('close_app', PermissionLevel.confirm, OperationCategory.close);

    // AI operations - notify
    _setPermission('ai_query', PermissionLevel.notify, OperationCategory.other);
    _setPermission('ai_analyze_image', PermissionLevel.notify, OperationCategory.other);
  }

  /// Set permission for an operation
  void _setPermission(
    String operation,
    PermissionLevel level,
    OperationCategory category,
  ) {
    _defaultPermissions[operation] = level;
    _operationCategories[operation] = category;
  }

  /// Get permission level for an operation
  PermissionLevel getPermissionLevel(String operation) {
    // Check for specific operation
    if (_defaultPermissions.containsKey(operation)) {
      return _defaultPermissions[operation]!;
    }

    // Check for operation with subtype (e.g., file_operation:list)
    if (operation.contains(':')) {
      final fullOp = operation;
      if (_defaultPermissions.containsKey(fullOp)) {
        return _defaultPermissions[fullOp]!;
      }
    }

    // Default to confirm for unknown operations
    return PermissionLevel.confirm;
  }

  /// Get category for an operation
  OperationCategory getCategory(String operation) {
    return _operationCategories[operation] ?? OperationCategory.other;
  }

  /// Check if operation can execute
  Future<PermissionCheckResult> checkPermission({
    required String deviceId,
    required String operation,
    required Map<String, dynamic> params,
  }) async {
    // Check if device is paired
    if (!_pairingManager.isPaired(deviceId)) {
      return PermissionCheckResult(
        allowed: false,
        reason: 'Device not paired',
        requiresConfirmation: false,
      );
    }

    // Get permission level
    final level = getPermissionLevel(operation);

    switch (level) {
      case PermissionLevel.auto:
        return PermissionCheckResult(
          allowed: true,
          reason: 'Auto-approved',
          requiresConfirmation: false,
        );

      case PermissionLevel.notify:
        // Check device-specific permission
        final category = getCategory(operation);
        final categoryPermission = _categoryToPermissionKey(category);

        if (_pairingManager.hasPermission(deviceId, categoryPermission)) {
          return PermissionCheckResult(
            allowed: true,
            reason: 'Device has permission',
            requiresConfirmation: false,
            shouldNotify: true,
          );
        }

        return PermissionCheckResult(
          allowed: false,
          reason: 'Permission not granted for $categoryPermission',
          requiresConfirmation: true,
        );

      case PermissionLevel.confirm:
        return PermissionCheckResult(
          allowed: false,
          reason: 'Requires confirmation',
          requiresConfirmation: true,
        );

      case PermissionLevel.deny:
        return PermissionCheckResult(
          allowed: false,
          reason: 'Operation not allowed remotely',
          requiresConfirmation: false,
        );
    }
  }

  /// Convert category to permission key
  String _categoryToPermissionKey(OperationCategory category) {
    switch (category) {
      case OperationCategory.query:
        return 'query';
      case OperationCategory.open:
        return 'open_app';
      case OperationCategory.capture:
        return 'screenshot';
      case OperationCategory.fileRead:
        return 'file_read';
      case OperationCategory.fileWrite:
        return 'file_write';
      case OperationCategory.fileDelete:
        return 'file_delete';
      case OperationCategory.command:
        return 'run_command';
      case OperationCategory.close:
        return 'close_app';
      case OperationCategory.system:
        return 'system_settings';
      case OperationCategory.other:
        return 'other';
    }
  }

  /// Request confirmation for an operation
  Future<bool> requestConfirmation({
    required String deviceId,
    required String operation,
    required Map<String, dynamic> details,
  }) async {
    final requestId = '${deviceId}_${DateTime.now().millisecondsSinceEpoch}';

    final request = ConfirmationRequest(
      id: requestId,
      deviceId: deviceId,
      operation: operation,
      details: details,
      createdAt: DateTime.now(),
    );

    _pendingConfirmations[requestId] = request;

    // Notify listeners
    for (final listener in _confirmationListeners) {
      listener(request);
    }

    print('[PermissionManager] Waiting for confirmation: $operation');

    try {
      // Wait for confirmation with timeout
      final result = await request.completer.future.timeout(
        request.timeout,
        onTimeout: () {
          request.expire();
          return false;
        },
      );

      _pendingConfirmations.remove(requestId);
      return result;
    } catch (e) {
      _pendingConfirmations.remove(requestId);
      return false;
    }
  }

  /// Approve a confirmation request
  void approveRequest(String requestId) {
    final request = _pendingConfirmations[requestId];
    if (request != null) {
      request.approve();
      print('[PermissionManager] Request approved: ${request.operation}');
    }
  }

  /// Deny a confirmation request
  void denyRequest(String requestId) {
    final request = _pendingConfirmations[requestId];
    if (request != null) {
      request.deny();
      print('[PermissionManager] Request denied: ${request.operation}');
    }
  }

  /// Get pending confirmation requests
  List<ConfirmationRequest> getPendingRequests() {
    _cleanupExpired();
    return _pendingConfirmations.values.toList();
  }

  /// Add confirmation listener
  void addConfirmationListener(void Function(ConfirmationRequest) listener) {
    _confirmationListeners.add(listener);
  }

  /// Remove confirmation listener
  void removeConfirmationListener(void Function(ConfirmationRequest) listener) {
    _confirmationListeners.remove(listener);
  }

  /// Start cleanup timer
  void _startCleanupTimer() {
    _cleanupTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _cleanupExpired();
    });
  }

  /// Cleanup expired requests
  void _cleanupExpired() {
    final expired = _pendingConfirmations.entries
        .where((e) => e.value.isExpired)
        .map((e) => e.key)
        .toList();

    for (final id in expired) {
      final request = _pendingConfirmations.remove(id);
      request?.expire();
    }
  }

  /// Update default permission level
  void setDefaultPermission(String operation, PermissionLevel level) {
    _defaultPermissions[operation] = level;
  }

  /// Get statistics
  Map<String, dynamic> getStats() {
    return {
      'defaultPermissions': _defaultPermissions.length,
      'pendingConfirmations': _pendingConfirmations.length,
      'permissionsByLevel': {
        'auto': _defaultPermissions.values.where((l) => l == PermissionLevel.auto).length,
        'notify': _defaultPermissions.values.where((l) => l == PermissionLevel.notify).length,
        'confirm': _defaultPermissions.values.where((l) => l == PermissionLevel.confirm).length,
        'deny': _defaultPermissions.values.where((l) => l == PermissionLevel.deny).length,
      },
    };
  }

  /// Dispose resources
  void dispose() {
    _cleanupTimer?.cancel();

    // Expire all pending requests
    for (final request in _pendingConfirmations.values) {
      request.expire();
    }
    _pendingConfirmations.clear();
  }
}

/// Result of permission check
class PermissionCheckResult {
  final bool allowed;
  final String reason;
  final bool requiresConfirmation;
  final bool shouldNotify;

  const PermissionCheckResult({
    required this.allowed,
    required this.reason,
    required this.requiresConfirmation,
    this.shouldNotify = false,
  });

  Map<String, dynamic> toJson() => {
    'allowed': allowed,
    'reason': reason,
    'requiresConfirmation': requiresConfirmation,
    'shouldNotify': shouldNotify,
  };
}
