import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;

/// Database manager with support for multiple database backends
class DatabaseManager {
  final DatabaseConfig config;
  late DatabaseAdapter _adapter;
  bool _isInitialized = false;

  DatabaseManager({required this.config}) {
    _adapter = _createAdapter(config);
  }

  /// Initialize database connection
  Future<void> initialize() async {
    if (_isInitialized) return;

    await _adapter.connect();
    await _adapter.createTables();
    _isInitialized = true;

    print('Database initialized: ${config.type}');
  }

  /// Close database connection
  Future<void> close() async {
    await _adapter.disconnect();
    _isInitialized = false;
  }

  /// Save task to database
  Future<String> saveTask(Map<String, dynamic> task) async {
    _ensureInitialized();
    return await _adapter.insertTask(task);
  }

  /// Get task by ID
  Future<Map<String, dynamic>?> getTask(String taskId) async {
    _ensureInitialized();
    return await _adapter.getTask(taskId);
  }

  /// Get all tasks
  Future<List<Map<String, dynamic>>> getAllTasks({
    int? limit,
    int? offset,
    String? status,
  }) async {
    _ensureInitialized();
    return await _adapter.getAllTasks(
      limit: limit,
      offset: offset,
      status: status,
    );
  }

  /// Update task
  Future<void> updateTask(String taskId, Map<String, dynamic> updates) async {
    _ensureInitialized();
    await _adapter.updateTask(taskId, updates);
  }

  /// Delete task
  Future<void> deleteTask(String taskId) async {
    _ensureInitialized();
    await _adapter.deleteTask(taskId);
  }

  /// Save user to database
  Future<String> saveUser(Map<String, dynamic> user) async {
    _ensureInitialized();
    return await _adapter.insertUser(user);
  }

  /// Get user by ID
  Future<Map<String, dynamic>?> getUser(String userId) async {
    _ensureInitialized();
    return await _adapter.getUser(userId);
  }

  /// Get user by username
  Future<Map<String, dynamic>?> getUserByUsername(String username) async {
    _ensureInitialized();
    return await _adapter.getUserByUsername(username);
  }

  /// Update user
  Future<void> updateUser(String userId, Map<String, dynamic> updates) async {
    _ensureInitialized();
    await _adapter.updateUser(userId, updates);
  }

  /// Save worker to database
  Future<String> saveWorker(Map<String, dynamic> worker) async {
    _ensureInitialized();
    return await _adapter.insertWorker(worker);
  }

  /// Get worker by ID
  Future<Map<String, dynamic>?> getWorker(String workerId) async {
    _ensureInitialized();
    return await _adapter.getWorker(workerId);
  }

  /// Get all workers
  Future<List<Map<String, dynamic>>> getAllWorkers() async {
    _ensureInitialized();
    return await _adapter.getAllWorkers();
  }

  /// Save audit log entry
  Future<void> saveAuditLog(Map<String, dynamic> entry) async {
    _ensureInitialized();
    await _adapter.insertAuditLog(entry);
  }

  /// Get audit logs
  Future<List<Map<String, dynamic>>> getAuditLogs({
    String? userId,
    DateTime? startTime,
    DateTime? endTime,
    int? limit,
  }) async {
    _ensureInitialized();
    return await _adapter.getAuditLogs(
      userId: userId,
      startTime: startTime,
      endTime: endTime,
      limit: limit,
    );
  }

  /// Execute raw query (use with caution)
  Future<List<Map<String, dynamic>>> query(String sql,
      [List<dynamic>? params]) async {
    _ensureInitialized();
    return await _adapter.query(sql, params);
  }

  /// Execute raw command (use with caution)
  Future<void> execute(String sql, [List<dynamic>? params]) async {
    _ensureInitialized();
    await _adapter.execute(sql, params);
  }

  /// Ensure database is initialized
  void _ensureInitialized() {
    if (!_isInitialized) {
      throw Exception('Database not initialized. Call initialize() first.');
    }
  }

  /// Create database adapter based on config
  DatabaseAdapter _createAdapter(DatabaseConfig config) {
    switch (config.type) {
      case DatabaseType.sqlite:
        return SQLiteAdapter(config);
      case DatabaseType.postgres:
        return PostgreSQLAdapter(config);
      case DatabaseType.mysql:
        return MySQLAdapter(config);
      case DatabaseType.mongodb:
        return MongoDBAdapter(config);
    }
  }
}

/// Database configuration
class DatabaseConfig {
  final DatabaseType type;
  final String? host;
  final int? port;
  final String? database;
  final String? username;
  final String? password;
  final String? path; // For SQLite
  final Map<String, dynamic>? options;

  DatabaseConfig({
    required this.type,
    this.host,
    this.port,
    this.database,
    this.username,
    this.password,
    this.path,
    this.options,
  });

  factory DatabaseConfig.sqlite(String path) {
    return DatabaseConfig(
      type: DatabaseType.sqlite,
      path: path,
    );
  }

  factory DatabaseConfig.postgres({
    required String host,
    required int port,
    required String database,
    required String username,
    required String password,
  }) {
    return DatabaseConfig(
      type: DatabaseType.postgres,
      host: host,
      port: port,
      database: database,
      username: username,
      password: password,
    );
  }
}

enum DatabaseType { sqlite, postgres, mysql, mongodb }

/// Base database adapter interface
abstract class DatabaseAdapter {
  Future<void> connect();
  Future<void> disconnect();
  Future<void> createTables();

  // Task operations
  Future<String> insertTask(Map<String, dynamic> task);
  Future<Map<String, dynamic>?> getTask(String taskId);
  Future<List<Map<String, dynamic>>> getAllTasks({
    int? limit,
    int? offset,
    String? status,
  });
  Future<void> updateTask(String taskId, Map<String, dynamic> updates);
  Future<void> deleteTask(String taskId);

  // User operations
  Future<String> insertUser(Map<String, dynamic> user);
  Future<Map<String, dynamic>?> getUser(String userId);
  Future<Map<String, dynamic>?> getUserByUsername(String username);
  Future<void> updateUser(String userId, Map<String, dynamic> updates);

  // Worker operations
  Future<String> insertWorker(Map<String, dynamic> worker);
  Future<Map<String, dynamic>?> getWorker(String workerId);
  Future<List<Map<String, dynamic>>> getAllWorkers();

  // Audit log operations
  Future<void> insertAuditLog(Map<String, dynamic> entry);
  Future<List<Map<String, dynamic>>> getAuditLogs({
    String? userId,
    DateTime? startTime,
    DateTime? endTime,
    int? limit,
  });

  // Raw queries
  Future<List<Map<String, dynamic>>> query(String sql, [List<dynamic>? params]);
  Future<void> execute(String sql, [List<dynamic>? params]);
}

/// SQLite adapter implementation
class SQLiteAdapter implements DatabaseAdapter {
  final DatabaseConfig config;
  final Map<String, Map<String, dynamic>> _storage = {
    'tasks': {},
    'users': {},
    'workers': {},
    'audit_logs': {},
  };
  String? _dbPath;

  SQLiteAdapter(this.config);

  @override
  Future<void> connect() async {
    _dbPath = config.path ?? path.join(Directory.systemTemp.path, 'opencli.db');
    final file = File(_dbPath!);

    if (await file.exists()) {
      // Load existing data
      final content = await file.readAsString();
      if (content.isNotEmpty) {
        final data = jsonDecode(content) as Map<String, dynamic>;
        _storage['tasks'] = Map<String, Map<String, dynamic>>.from(
          data['tasks'] as Map<dynamic, dynamic>? ?? {},
        );
        _storage['users'] = Map<String, Map<String, dynamic>>.from(
          data['users'] as Map<dynamic, dynamic>? ?? {},
        );
        _storage['workers'] = Map<String, Map<String, dynamic>>.from(
          data['workers'] as Map<dynamic, dynamic>? ?? {},
        );
        _storage['audit_logs'] = Map<String, Map<String, dynamic>>.from(
          data['audit_logs'] as Map<dynamic, dynamic>? ?? {},
        );
      }
    }
  }

  @override
  Future<void> disconnect() async {
    await _persist();
  }

  @override
  Future<void> createTables() async {
    // Tables are created implicitly in the storage structure
  }

  Future<void> _persist() async {
    if (_dbPath == null) return;

    final file = File(_dbPath!);
    await file.writeAsString(jsonEncode(_storage));
  }

  @override
  Future<String> insertTask(Map<String, dynamic> task) async {
    final id = task['id'] as String;
    _storage['tasks']![id] = task;
    await _persist();
    return id;
  }

  @override
  Future<Map<String, dynamic>?> getTask(String taskId) async {
    return _storage['tasks']![taskId];
  }

  @override
  Future<List<Map<String, dynamic>>> getAllTasks({
    int? limit,
    int? offset,
    String? status,
  }) async {
    var tasks = _storage['tasks']!.values.toList();

    if (status != null) {
      tasks = tasks.where((t) => t['status'] == status).toList();
    }

    if (offset != null) {
      tasks = tasks.skip(offset).toList();
    }

    if (limit != null) {
      tasks = tasks.take(limit).toList();
    }

    return tasks;
  }

  @override
  Future<void> updateTask(String taskId, Map<String, dynamic> updates) async {
    final task = _storage['tasks']![taskId];
    if (task != null) {
      task.addAll(updates);
      await _persist();
    }
  }

  @override
  Future<void> deleteTask(String taskId) async {
    _storage['tasks']!.remove(taskId);
    await _persist();
  }

  @override
  Future<String> insertUser(Map<String, dynamic> user) async {
    final id = user['id'] as String;
    _storage['users']![id] = user;
    await _persist();
    return id;
  }

  @override
  Future<Map<String, dynamic>?> getUser(String userId) async {
    return _storage['users']![userId];
  }

  @override
  Future<Map<String, dynamic>?> getUserByUsername(String username) async {
    return _storage['users']!.values.firstWhere(
          (u) => u['username'] == username,
          orElse: () => <String, dynamic>{},
        );
  }

  @override
  Future<void> updateUser(String userId, Map<String, dynamic> updates) async {
    final user = _storage['users']![userId];
    if (user != null) {
      user.addAll(updates);
      await _persist();
    }
  }

  @override
  Future<String> insertWorker(Map<String, dynamic> worker) async {
    final id = worker['id'] as String;
    _storage['workers']![id] = worker;
    await _persist();
    return id;
  }

  @override
  Future<Map<String, dynamic>?> getWorker(String workerId) async {
    return _storage['workers']![workerId];
  }

  @override
  Future<List<Map<String, dynamic>>> getAllWorkers() async {
    return _storage['workers']!.values.toList();
  }

  @override
  Future<void> insertAuditLog(Map<String, dynamic> entry) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    _storage['audit_logs']![id] = entry;
    await _persist();
  }

  @override
  Future<List<Map<String, dynamic>>> getAuditLogs({
    String? userId,
    DateTime? startTime,
    DateTime? endTime,
    int? limit,
  }) async {
    var logs = _storage['audit_logs']!.values.toList();

    if (userId != null) {
      logs = logs.where((l) => l['user_id'] == userId).toList();
    }

    if (limit != null) {
      logs = logs.take(limit).toList();
    }

    return logs;
  }

  @override
  Future<List<Map<String, dynamic>>> query(String sql,
      [List<dynamic>? params]) async {
    // Simple implementation - would need proper SQL parsing
    return [];
  }

  @override
  Future<void> execute(String sql, [List<dynamic>? params]) async {
    // Simple implementation - would need proper SQL parsing
  }
}

/// PostgreSQL adapter (placeholder - would need actual postgres package)
class PostgreSQLAdapter implements DatabaseAdapter {
  final DatabaseConfig config;

  PostgreSQLAdapter(this.config);

  @override
  Future<void> connect() async {
    throw UnimplementedError('PostgreSQL adapter requires postgres package');
  }

  @override
  Future<void> disconnect() async {}

  @override
  Future<void> createTables() async {}

  @override
  Future<String> insertTask(Map<String, dynamic> task) async {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>?> getTask(String taskId) async {
    throw UnimplementedError();
  }

  @override
  Future<List<Map<String, dynamic>>> getAllTasks({
    int? limit,
    int? offset,
    String? status,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> updateTask(String taskId, Map<String, dynamic> updates) async {
    throw UnimplementedError();
  }

  @override
  Future<void> deleteTask(String taskId) async {
    throw UnimplementedError();
  }

  @override
  Future<String> insertUser(Map<String, dynamic> user) async {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>?> getUser(String userId) async {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>?> getUserByUsername(String username) async {
    throw UnimplementedError();
  }

  @override
  Future<void> updateUser(String userId, Map<String, dynamic> updates) async {
    throw UnimplementedError();
  }

  @override
  Future<String> insertWorker(Map<String, dynamic> worker) async {
    throw UnimplementedError();
  }

  @override
  Future<Map<String, dynamic>?> getWorker(String workerId) async {
    throw UnimplementedError();
  }

  @override
  Future<List<Map<String, dynamic>>> getAllWorkers() async {
    throw UnimplementedError();
  }

  @override
  Future<void> insertAuditLog(Map<String, dynamic> entry) async {
    throw UnimplementedError();
  }

  @override
  Future<List<Map<String, dynamic>>> getAuditLogs({
    String? userId,
    DateTime? startTime,
    DateTime? endTime,
    int? limit,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<List<Map<String, dynamic>>> query(String sql,
      [List<dynamic>? params]) async {
    throw UnimplementedError();
  }

  @override
  Future<void> execute(String sql, [List<dynamic>? params]) async {
    throw UnimplementedError();
  }
}

/// MySQL adapter (placeholder)
class MySQLAdapter extends PostgreSQLAdapter {
  MySQLAdapter(super.config);
}

/// MongoDB adapter (placeholder)
class MongoDBAdapter extends PostgreSQLAdapter {
  MongoDBAdapter(super.config);
}
