import 'authentication_manager.dart';

/// Manages authorization and permission checking
class AuthorizationManager {
  final AuthenticationManager authManager;

  AuthorizationManager({required this.authManager});

  /// Check if user has permission
  Future<bool> hasPermission(String userId, Permission permission) async {
    final user = authManager.getUser(userId);
    if (user == null || !user.isActive) {
      return false;
    }

    return user.permissions.contains(permission);
  }

  /// Check if user has all permissions
  Future<bool> hasAllPermissions(
    String userId,
    Set<Permission> permissions,
  ) async {
    final user = authManager.getUser(userId);
    if (user == null || !user.isActive) {
      return false;
    }

    return permissions.every((p) => user.permissions.contains(p));
  }

  /// Check if user has any of the permissions
  Future<bool> hasAnyPermission(
    String userId,
    Set<Permission> permissions,
  ) async {
    final user = authManager.getUser(userId);
    if (user == null || !user.isActive) {
      return false;
    }

    return permissions.any((p) => user.permissions.contains(p));
  }

  /// Check if user has role
  Future<bool> hasRole(String userId, UserRole role) async {
    final user = authManager.getUser(userId);
    if (user == null || !user.isActive) {
      return false;
    }

    return user.role == role;
  }

  /// Check if user has minimum role
  Future<bool> hasMinimumRole(String userId, UserRole minimumRole) async {
    final user = authManager.getUser(userId);
    if (user == null || !user.isActive) {
      return false;
    }

    return _getRoleLevel(user.role) >= _getRoleLevel(minimumRole);
  }

  /// Require permission (throws if not authorized)
  Future<void> requirePermission(String userId, Permission permission) async {
    if (!await hasPermission(userId, permission)) {
      throw UnauthorizedException(
        'User does not have permission: ${permission.name}',
      );
    }
  }

  /// Require all permissions (throws if not authorized)
  Future<void> requireAllPermissions(
    String userId,
    Set<Permission> permissions,
  ) async {
    if (!await hasAllPermissions(userId, permissions)) {
      throw UnauthorizedException(
        'User does not have required permissions',
      );
    }
  }

  /// Require role (throws if not authorized)
  Future<void> requireRole(String userId, UserRole role) async {
    if (!await hasRole(userId, role)) {
      throw UnauthorizedException(
        'User does not have required role: ${role.name}',
      );
    }
  }

  /// Require minimum role (throws if not authorized)
  Future<void> requireMinimumRole(String userId, UserRole minimumRole) async {
    if (!await hasMinimumRole(userId, minimumRole)) {
      throw UnauthorizedException(
        'User does not have minimum role: ${minimumRole.name}',
      );
    }
  }

  /// Check if user can access resource
  Future<bool> canAccessResource(
    String userId,
    ResourceType resourceType,
    String resourceId, {
    ResourceAction action = ResourceAction.read,
  }) async {
    final user = authManager.getUser(userId);
    if (user == null || !user.isActive) {
      return false;
    }

    // Admin can access everything
    if (user.role == UserRole.admin) {
      return true;
    }

    switch (resourceType) {
      case ResourceType.task:
        return _canAccessTask(user, resourceId, action);
      case ResourceType.worker:
        return _canAccessWorker(user, resourceId, action);
      case ResourceType.user:
        return _canAccessUser(user, resourceId, action);
      case ResourceType.analytics:
        return _canAccessAnalytics(user, action);
    }
  }

  /// Check task access
  bool _canAccessTask(User user, String taskId, ResourceAction action) {
    switch (action) {
      case ResourceAction.read:
        return user.permissions.contains(Permission.readTasks);
      case ResourceAction.create:
        return user.permissions.contains(Permission.createTasks);
      case ResourceAction.update:
        if (user.permissions.contains(Permission.updateTasks)) {
          return true;
        }
        // Check if user owns the task
        if (user.permissions.contains(Permission.updateOwnTasks)) {
          // TODO: Check task ownership
          return true;
        }
        return false;
      case ResourceAction.delete:
        if (user.permissions.contains(Permission.deleteTasks)) {
          return true;
        }
        // Check if user owns the task
        if (user.permissions.contains(Permission.deleteOwnTasks)) {
          // TODO: Check task ownership
          return true;
        }
        return false;
    }
  }

  /// Check worker access
  bool _canAccessWorker(User user, String workerId, ResourceAction action) {
    switch (action) {
      case ResourceAction.read:
        return user.permissions.contains(Permission.readWorkers);
      case ResourceAction.create:
        return user.permissions.contains(Permission.createWorkers);
      case ResourceAction.update:
        return user.permissions.contains(Permission.updateWorkers);
      case ResourceAction.delete:
        return user.permissions.contains(Permission.deleteWorkers);
    }
  }

  /// Check user access
  bool _canAccessUser(User user, String targetUserId, ResourceAction action) {
    // Users can always read their own profile
    if (action == ResourceAction.read && user.id == targetUserId) {
      return true;
    }

    switch (action) {
      case ResourceAction.read:
        return user.permissions.contains(Permission.readUsers);
      case ResourceAction.create:
        return user.permissions.contains(Permission.createUsers);
      case ResourceAction.update:
        return user.permissions.contains(Permission.updateUsers);
      case ResourceAction.delete:
        return user.permissions.contains(Permission.deleteUsers);
    }
  }

  /// Check analytics access
  bool _canAccessAnalytics(User user, ResourceAction action) {
    return user.permissions.contains(Permission.readAnalytics);
  }

  /// Get role level (higher is more privileged)
  int _getRoleLevel(UserRole role) {
    switch (role) {
      case UserRole.viewer:
        return 1;
      case UserRole.user:
        return 2;
      case UserRole.manager:
        return 3;
      case UserRole.admin:
        return 4;
    }
  }

  /// Create access control list
  Map<String, dynamic> createACL({
    required String resourceType,
    required String resourceId,
    required String ownerId,
    Set<String>? readers,
    Set<String>? writers,
    Set<String>? admins,
  }) {
    return {
      'resource_type': resourceType,
      'resource_id': resourceId,
      'owner_id': ownerId,
      'readers': readers?.toList() ?? [],
      'writers': writers?.toList() ?? [],
      'admins': admins?.toList() ?? [],
      'created_at': DateTime.now().toIso8601String(),
    };
  }

  /// Check ACL access
  bool checkACL(
    Map<String, dynamic> acl,
    String userId,
    ResourceAction action,
  ) {
    // Owner has full access
    if (acl['owner_id'] == userId) {
      return true;
    }

    final readers = (acl['readers'] as List<dynamic>?)?.cast<String>() ?? [];
    final writers = (acl['writers'] as List<dynamic>?)?.cast<String>() ?? [];
    final admins = (acl['admins'] as List<dynamic>?)?.cast<String>() ?? [];

    switch (action) {
      case ResourceAction.read:
        return readers.contains(userId) ||
            writers.contains(userId) ||
            admins.contains(userId);
      case ResourceAction.create:
      case ResourceAction.update:
        return writers.contains(userId) || admins.contains(userId);
      case ResourceAction.delete:
        return admins.contains(userId);
    }
  }
}

/// Resource types
enum ResourceType {
  task,
  worker,
  user,
  analytics,
}

/// Resource actions
enum ResourceAction {
  read,
  create,
  update,
  delete,
}

/// Unauthorized exception
class UnauthorizedException implements Exception {
  final String message;

  UnauthorizedException(this.message);

  @override
  String toString() => 'UnauthorizedException: $message';
}

/// Rate limiter for API endpoints
class RateLimiter {
  final Map<String, List<DateTime>> _requestHistory = {};
  final Duration window;
  final int maxRequests;

  RateLimiter({
    this.window = const Duration(minutes: 1),
    this.maxRequests = 60,
  });

  /// Check if request is allowed
  bool isAllowed(String identifier) {
    final now = DateTime.now();
    final windowStart = now.subtract(window);

    // Get request history for this identifier
    final history = _requestHistory.putIfAbsent(identifier, () => []);

    // Remove requests outside the window
    history.removeWhere((timestamp) => timestamp.isBefore(windowStart));

    // Check if limit exceeded
    if (history.length >= maxRequests) {
      return false;
    }

    // Add current request
    history.add(now);

    return true;
  }

  /// Get remaining requests
  int getRemainingRequests(String identifier) {
    final now = DateTime.now();
    final windowStart = now.subtract(window);

    final history = _requestHistory[identifier] ?? [];
    final recentRequests = history.where((t) => t.isAfter(windowStart)).length;

    return maxRequests - recentRequests;
  }

  /// Get reset time
  DateTime? getResetTime(String identifier) {
    final history = _requestHistory[identifier];
    if (history == null || history.isEmpty) {
      return null;
    }

    final oldestRequest = history.first;
    return oldestRequest.add(window);
  }
}

/// Audit logger for security events
class AuditLogger {
  final List<AuditEvent> _events = [];
  final int maxEvents;

  AuditLogger({this.maxEvents = 10000});

  /// Log event
  void log({
    required String userId,
    required AuditEventType type,
    required String resource,
    String? action,
    bool success = true,
    String? details,
    String? ipAddress,
  }) {
    final event = AuditEvent(
      timestamp: DateTime.now(),
      userId: userId,
      type: type,
      resource: resource,
      action: action,
      success: success,
      details: details,
      ipAddress: ipAddress,
    );

    _events.add(event);

    // Limit events size
    if (_events.length > maxEvents) {
      _events.removeAt(0);
    }

    print('AUDIT: ${event.toString()}');
  }

  /// Get events for user
  List<AuditEvent> getEventsForUser(String userId) {
    return _events.where((e) => e.userId == userId).toList();
  }

  /// Get events by type
  List<AuditEvent> getEventsByType(AuditEventType type) {
    return _events.where((e) => e.type == type).toList();
  }

  /// Get recent events
  List<AuditEvent> getRecentEvents(int count) {
    return _events.reversed.take(count).toList();
  }
}

/// Audit event
class AuditEvent {
  final DateTime timestamp;
  final String userId;
  final AuditEventType type;
  final String resource;
  final String? action;
  final bool success;
  final String? details;
  final String? ipAddress;

  AuditEvent({
    required this.timestamp,
    required this.userId,
    required this.type,
    required this.resource,
    this.action,
    required this.success,
    this.details,
    this.ipAddress,
  });

  @override
  String toString() {
    return '[${timestamp.toIso8601String()}] $type: User $userId ${action ?? 'accessed'} $resource - ${success ? 'SUCCESS' : 'FAILED'}';
  }

  Map<String, dynamic> toJson() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'user_id': userId,
      'type': type.name,
      'resource': resource,
      if (action != null) 'action': action,
      'success': success,
      if (details != null) 'details': details,
      if (ipAddress != null) 'ip_address': ipAddress,
    };
  }
}

enum AuditEventType {
  authentication,
  authorization,
  dataAccess,
  dataModification,
  systemChange,
  securityEvent,
}
