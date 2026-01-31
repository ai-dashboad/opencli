import 'dart:async';
import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'dart:math';

/// Manages user authentication and session management
class AuthenticationManager {
  final Map<String, User> _users = {};
  final Map<String, Session> _sessions = {};
  final Map<String, String> _refreshTokens = {}; // refreshToken -> userId
  final Duration sessionTimeout;
  final Duration refreshTokenLifetime;
  final String jwtSecret;

  AuthenticationManager({
    this.sessionTimeout = const Duration(hours: 8),
    this.refreshTokenLifetime = const Duration(days: 30),
    required this.jwtSecret,
  }) {
    _initializeDemoUsers();
    _startSessionCleanup();
  }

  /// Initialize demo users
  void _initializeDemoUsers() {
    // Admin user
    _users['admin'] = User(
      id: 'admin',
      username: 'admin',
      email: 'admin@opencli.com',
      passwordHash: _hashPassword('admin123'),
      role: UserRole.admin,
      permissions: Permission.values.toSet(),
      createdAt: DateTime.now(),
    );

    // Regular user
    _users['user1'] = User(
      id: 'user1',
      username: 'user1',
      email: 'user1@opencli.com',
      passwordHash: _hashPassword('user123'),
      role: UserRole.user,
      permissions: {
        Permission.readTasks,
        Permission.createTasks,
        Permission.updateOwnTasks,
      },
      createdAt: DateTime.now(),
    );
  }

  /// Register a new user
  Future<User> registerUser({
    required String username,
    required String email,
    required String password,
    UserRole role = UserRole.user,
    Set<Permission>? permissions,
  }) async {
    // Validate username uniqueness
    if (_users.values.any((u) => u.username == username)) {
      throw Exception('Username already exists');
    }

    // Validate email uniqueness
    if (_users.values.any((u) => u.email == email)) {
      throw Exception('Email already exists');
    }

    // Validate password strength
    _validatePasswordStrength(password);

    final userId = _generateUserId();
    final user = User(
      id: userId,
      username: username,
      email: email,
      passwordHash: _hashPassword(password),
      role: role,
      permissions: permissions ?? _getDefaultPermissions(role),
      createdAt: DateTime.now(),
    );

    _users[userId] = user;
    print('User registered: $username ($userId)');

    return user;
  }

  /// Authenticate user and create session
  Future<AuthResult> login({
    required String username,
    required String password,
  }) async {
    final user = _users.values.firstWhere(
      (u) => u.username == username,
      orElse: () => throw Exception('Invalid credentials'),
    );

    // Verify password
    if (user.passwordHash != _hashPassword(password)) {
      throw Exception('Invalid credentials');
    }

    // Check if user is active
    if (!user.isActive) {
      throw Exception('User account is disabled');
    }

    // Create session
    final sessionId = _generateSessionId();
    final session = Session(
      id: sessionId,
      userId: user.id,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(sessionTimeout),
      ipAddress: null,
      userAgent: null,
    );

    _sessions[sessionId] = session;

    // Create refresh token
    final refreshToken = _generateRefreshToken();
    _refreshTokens[refreshToken] = user.id;

    // Update last login
    user.lastLoginAt = DateTime.now();

    print('User logged in: ${user.username}');

    return AuthResult(
      sessionId: sessionId,
      refreshToken: refreshToken,
      user: user,
      expiresAt: session.expiresAt,
    );
  }

  /// Logout and invalidate session
  Future<void> logout(String sessionId) async {
    final session = _sessions.remove(sessionId);
    if (session != null) {
      // Remove associated refresh tokens
      _refreshTokens.removeWhere((token, userId) => userId == session.userId);
      print('User logged out: ${session.userId}');
    }
  }

  /// Refresh session using refresh token
  Future<AuthResult> refreshSession(String refreshToken) async {
    final userId = _refreshTokens[refreshToken];
    if (userId == null) {
      throw Exception('Invalid refresh token');
    }

    final user = _users[userId];
    if (user == null || !user.isActive) {
      throw Exception('User not found or inactive');
    }

    // Create new session
    final sessionId = _generateSessionId();
    final session = Session(
      id: sessionId,
      userId: user.id,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(sessionTimeout),
      ipAddress: null,
      userAgent: null,
    );

    _sessions[sessionId] = session;

    // Generate new refresh token
    final newRefreshToken = _generateRefreshToken();
    _refreshTokens.remove(refreshToken);
    _refreshTokens[newRefreshToken] = user.id;

    return AuthResult(
      sessionId: sessionId,
      refreshToken: newRefreshToken,
      user: user,
      expiresAt: session.expiresAt,
    );
  }

  /// Validate session
  Future<User?> validateSession(String sessionId) async {
    final session = _sessions[sessionId];
    if (session == null) {
      return null;
    }

    // Check if session expired
    if (DateTime.now().isAfter(session.expiresAt)) {
      _sessions.remove(sessionId);
      return null;
    }

    // Update last activity
    session.lastActivityAt = DateTime.now();

    return _users[session.userId];
  }

  /// Change user password
  Future<void> changePassword({
    required String userId,
    required String oldPassword,
    required String newPassword,
  }) async {
    final user = _users[userId];
    if (user == null) {
      throw Exception('User not found');
    }

    // Verify old password
    if (user.passwordHash != _hashPassword(oldPassword)) {
      throw Exception('Invalid old password');
    }

    // Validate new password strength
    _validatePasswordStrength(newPassword);

    // Update password
    user.passwordHash = _hashPassword(newPassword);

    // Invalidate all sessions for this user
    _sessions.removeWhere((_, session) => session.userId == userId);
    _refreshTokens.removeWhere((_, uid) => uid == userId);

    print('Password changed for user: ${user.username}');
  }

  /// Reset password (admin only)
  Future<String> resetPassword(String userId) async {
    final user = _users[userId];
    if (user == null) {
      throw Exception('User not found');
    }

    // Generate temporary password
    final tempPassword = _generateTemporaryPassword();

    // Update password
    user.passwordHash = _hashPassword(tempPassword);

    // Invalidate all sessions
    _sessions.removeWhere((_, session) => session.userId == userId);
    _refreshTokens.removeWhere((_, uid) => uid == userId);

    print('Password reset for user: ${user.username}');

    return tempPassword;
  }

  /// Update user permissions
  Future<void> updatePermissions(String userId, Set<Permission> permissions) async {
    final user = _users[userId];
    if (user == null) {
      throw Exception('User not found');
    }

    user.permissions = permissions;
    print('Permissions updated for user: ${user.username}');
  }

  /// Deactivate user
  Future<void> deactivateUser(String userId) async {
    final user = _users[userId];
    if (user == null) {
      throw Exception('User not found');
    }

    user.isActive = false;

    // Invalidate all sessions
    _sessions.removeWhere((_, session) => session.userId == userId);
    _refreshTokens.removeWhere((_, uid) => uid == userId);

    print('User deactivated: ${user.username}');
  }

  /// Activate user
  Future<void> activateUser(String userId) async {
    final user = _users[userId];
    if (user == null) {
      throw Exception('User not found');
    }

    user.isActive = true;
    print('User activated: ${user.username}');
  }

  /// Get user by ID
  User? getUser(String userId) {
    return _users[userId];
  }

  /// Get all users
  List<User> getAllUsers() {
    return _users.values.toList();
  }

  /// Hash password
  String _hashPassword(String password) {
    final bytes = utf8.encode(password + jwtSecret);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Validate password strength
  void _validatePasswordStrength(String password) {
    if (password.length < 8) {
      throw Exception('Password must be at least 8 characters');
    }

    if (!RegExp(r'[A-Z]').hasMatch(password)) {
      throw Exception('Password must contain at least one uppercase letter');
    }

    if (!RegExp(r'[a-z]').hasMatch(password)) {
      throw Exception('Password must contain at least one lowercase letter');
    }

    if (!RegExp(r'[0-9]').hasMatch(password)) {
      throw Exception('Password must contain at least one digit');
    }
  }

  /// Get default permissions for role
  Set<Permission> _getDefaultPermissions(UserRole role) {
    switch (role) {
      case UserRole.admin:
        return Permission.values.toSet();
      case UserRole.manager:
        return {
          Permission.readTasks,
          Permission.createTasks,
          Permission.updateTasks,
          Permission.deleteTasks,
          Permission.readWorkers,
          Permission.assignTasks,
          Permission.readAnalytics,
        };
      case UserRole.user:
        return {
          Permission.readTasks,
          Permission.createTasks,
          Permission.updateOwnTasks,
          Permission.readWorkers,
        };
      case UserRole.viewer:
        return {
          Permission.readTasks,
          Permission.readWorkers,
          Permission.readAnalytics,
        };
    }
  }

  /// Generate user ID
  String _generateUserId() {
    return 'user_${DateTime.now().millisecondsSinceEpoch}';
  }

  /// Generate session ID
  String _generateSessionId() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  /// Generate refresh token
  String _generateRefreshToken() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  /// Generate temporary password
  String _generateTemporaryPassword() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return List.generate(12, (_) => chars[random.nextInt(chars.length)]).join();
  }

  /// Start periodic session cleanup
  void _startSessionCleanup() {
    Timer.periodic(Duration(minutes: 5), (_) {
      _cleanupExpiredSessions();
    });
  }

  /// Cleanup expired sessions
  void _cleanupExpiredSessions() {
    final now = DateTime.now();
    final expiredSessions = _sessions.entries
        .where((entry) => now.isAfter(entry.value.expiresAt))
        .map((entry) => entry.key)
        .toList();

    for (final sessionId in expiredSessions) {
      _sessions.remove(sessionId);
    }

    if (expiredSessions.isNotEmpty) {
      print('Cleaned up ${expiredSessions.length} expired sessions');
    }
  }
}

/// User model
class User {
  final String id;
  final String username;
  final String email;
  String passwordHash;
  final UserRole role;
  Set<Permission> permissions;
  final DateTime createdAt;
  DateTime? lastLoginAt;
  bool isActive;

  User({
    required this.id,
    required this.username,
    required this.email,
    required this.passwordHash,
    required this.role,
    required this.permissions,
    required this.createdAt,
    this.lastLoginAt,
    this.isActive = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'email': email,
      'role': role.name,
      'permissions': permissions.map((p) => p.name).toList(),
      'created_at': createdAt.toIso8601String(),
      if (lastLoginAt != null) 'last_login_at': lastLoginAt!.toIso8601String(),
      'is_active': isActive,
    };
  }
}

enum UserRole { admin, manager, user, viewer }

enum Permission {
  // Task permissions
  readTasks,
  createTasks,
  updateTasks,
  updateOwnTasks,
  deleteTasks,
  deleteOwnTasks,
  assignTasks,

  // Worker permissions
  readWorkers,
  createWorkers,
  updateWorkers,
  deleteWorkers,

  // User management
  readUsers,
  createUsers,
  updateUsers,
  deleteUsers,

  // System permissions
  readAnalytics,
  manageSystem,
  managePermissions,
}

/// Session model
class Session {
  final String id;
  final String userId;
  final DateTime createdAt;
  final DateTime expiresAt;
  DateTime lastActivityAt;
  final String? ipAddress;
  final String? userAgent;

  Session({
    required this.id,
    required this.userId,
    required this.createdAt,
    required this.expiresAt,
    DateTime? lastActivityAt,
    this.ipAddress,
    this.userAgent,
  }) : lastActivityAt = lastActivityAt ?? createdAt;
}

/// Authentication result
class AuthResult {
  final String sessionId;
  final String refreshToken;
  final User user;
  final DateTime expiresAt;

  AuthResult({
    required this.sessionId,
    required this.refreshToken,
    required this.user,
    required this.expiresAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'session_id': sessionId,
      'refresh_token': refreshToken,
      'user': user.toJson(),
      'expires_at': expiresAt.toIso8601String(),
    };
  }
}
