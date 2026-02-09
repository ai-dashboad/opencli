import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Centralized SQLite database for all OpenCLI persistent storage.
///
/// Replaces scattered JSON files, localStorage, and SharedPreferences
/// with a single real SQLite database at ~/.opencli/opencli.db.
class AppDatabase {
  static final AppDatabase instance = AppDatabase._();
  AppDatabase._();

  late Database _db;
  bool _initialized = false;

  bool get isInitialized => _initialized;
  Database get db => _db;

  /// Initialize the database. Must be called once at daemon startup.
  Future<void> initialize(String dbPath) async {
    if (_initialized) return;

    sqfliteFfiInit();

    final dbDir = path.dirname(dbPath);
    await Directory(dbDir).create(recursive: true);

    _db = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: _createTables,
      ),
    );

    _initialized = true;
    print('[AppDatabase] Initialized at $dbPath');
  }

  Future<void> _createTables(Database db, int version) async {
    // Pipelines (replaces ~/.opencli/pipelines/*.json)
    await db.execute('''
      CREATE TABLE pipelines (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        description TEXT DEFAULT '',
        nodes TEXT NOT NULL,
        edges TEXT NOT NULL,
        parameters TEXT DEFAULT '[]',
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');

    // Paired Devices (replaces ~/.opencli/security/paired_devices.json)
    await db.execute('''
      CREATE TABLE paired_devices (
        device_id TEXT PRIMARY KEY,
        device_name TEXT NOT NULL,
        platform TEXT NOT NULL,
        paired_at INTEGER NOT NULL,
        last_seen INTEGER NOT NULL,
        shared_secret TEXT NOT NULL,
        permissions TEXT NOT NULL
      )
    ''');

    // Pending Issues (replaces ~/.opencli/data/pending_issues.json)
    await db.execute('''
      CREATE TABLE pending_issues (
        id TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        body TEXT NOT NULL,
        labels TEXT DEFAULT '[]',
        fingerprint TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        reported INTEGER DEFAULT 0,
        remote_id TEXT
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_issues_fingerprint ON pending_issues(fingerprint)');

    // File Metadata (replaces ~/.opencli/storage/metadata.json)
    await db.execute('''
      CREATE TABLE file_metadata (
        id TEXT PRIMARY KEY,
        filename TEXT NOT NULL,
        size INTEGER NOT NULL,
        content_type TEXT NOT NULL,
        checksum TEXT NOT NULL,
        uploaded_at INTEGER NOT NULL,
        metadata TEXT DEFAULT '{}'
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_files_content_type ON file_metadata(content_type)');

    // Generation History (replaces web-ui localStorage opencli_gen_history)
    await db.execute('''
      CREATE TABLE generation_history (
        id TEXT PRIMARY KEY,
        mode TEXT NOT NULL,
        prompt TEXT NOT NULL,
        provider TEXT NOT NULL,
        style TEXT DEFAULT '',
        result_type TEXT NOT NULL,
        thumbnail TEXT,
        created_at INTEGER NOT NULL
      )
    ''');

    // Assets (replaces web-ui localStorage opencli_assets)
    await db.execute('''
      CREATE TABLE assets (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        title TEXT NOT NULL,
        url TEXT NOT NULL,
        thumbnail TEXT,
        provider TEXT,
        style TEXT,
        created_at INTEGER NOT NULL
      )
    ''');

    // Status Events (replaces web-ui in-memory event log)
    await db.execute('''
      CREATE TABLE status_events (
        id TEXT PRIMARY KEY,
        type TEXT NOT NULL,
        source TEXT DEFAULT '',
        content TEXT NOT NULL,
        task_type TEXT,
        status TEXT,
        result TEXT,
        created_at INTEGER NOT NULL
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_events_created ON status_events(created_at)');

    // Chat Messages (replaces Flutter SharedPreferences chat_messages)
    await db.execute('''
      CREATE TABLE chat_messages (
        id TEXT PRIMARY KEY,
        content TEXT NOT NULL,
        is_user INTEGER NOT NULL,
        timestamp INTEGER NOT NULL,
        status TEXT DEFAULT 'completed',
        task_type TEXT,
        result TEXT
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_chat_timestamp ON chat_messages(timestamp)');

    // Schema version tracking
    await db.execute('''
      CREATE TABLE schema_migrations (
        version INTEGER PRIMARY KEY,
        applied_at INTEGER NOT NULL,
        description TEXT
      )
    ''');

    // Record initial migration
    await db.insert('schema_migrations', {
      'version': 1,
      'applied_at': DateTime.now().millisecondsSinceEpoch,
      'description': 'Initial schema with 9 tables',
    });
  }

  // ── Pipeline CRUD ──

  Future<List<Map<String, dynamic>>> listPipelines() async {
    return await _db.query('pipelines', orderBy: 'updated_at DESC');
  }

  Future<Map<String, dynamic>?> getPipeline(String id) async {
    final rows =
        await _db.query('pipelines', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> upsertPipeline(Map<String, dynamic> data) async {
    await _db.insert('pipelines', data,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<bool> deletePipeline(String id) async {
    final count =
        await _db.delete('pipelines', where: 'id = ?', whereArgs: [id]);
    return count > 0;
  }

  Future<bool> pipelineExists(String id) async {
    final rows = await _db.query('pipelines',
        columns: ['id'], where: 'id = ?', whereArgs: [id]);
    return rows.isNotEmpty;
  }

  // ── Paired Devices CRUD ──

  Future<List<Map<String, dynamic>>> listPairedDevices() async {
    return await _db.query('paired_devices');
  }

  Future<Map<String, dynamic>?> getPairedDevice(String deviceId) async {
    final rows = await _db.query('paired_devices',
        where: 'device_id = ?', whereArgs: [deviceId]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> upsertPairedDevice(Map<String, dynamic> data) async {
    await _db.insert('paired_devices', data,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> deletePairedDevice(String deviceId) async {
    await _db.delete('paired_devices',
        where: 'device_id = ?', whereArgs: [deviceId]);
  }

  Future<void> updateDeviceLastSeen(String deviceId) async {
    await _db.update(
      'paired_devices',
      {'last_seen': DateTime.now().millisecondsSinceEpoch},
      where: 'device_id = ?',
      whereArgs: [deviceId],
    );
  }

  // ── Pending Issues CRUD ──

  Future<void> insertIssue(Map<String, dynamic> data) async {
    await _db.insert('pending_issues', data,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<Map<String, dynamic>>> listPendingIssues() async {
    return await _db
        .query('pending_issues', where: 'reported = 0', orderBy: 'created_at');
  }

  Future<Set<String>> getReportedFingerprints() async {
    final rows = await _db.query('pending_issues',
        columns: ['fingerprint'], where: 'reported = 1');
    return rows.map((r) => r['fingerprint'] as String).toSet();
  }

  Future<void> markIssueReported(String id, String? remoteId) async {
    await _db.update(
      'pending_issues',
      {'reported': 1, 'remote_id': remoteId},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ── File Metadata CRUD ──

  Future<void> insertFileMetadata(Map<String, dynamic> data) async {
    await _db.insert('file_metadata', data,
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<Map<String, dynamic>?> getFileMetadata(String id) async {
    final rows =
        await _db.query('file_metadata', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, dynamic>>> listFileMetadata(
      {String? contentType, int? limit, int? offset}) async {
    return await _db.query(
      'file_metadata',
      where: contentType != null ? 'content_type = ?' : null,
      whereArgs: contentType != null ? [contentType] : null,
      orderBy: 'uploaded_at DESC',
      limit: limit,
      offset: offset,
    );
  }

  Future<void> deleteFileMetadata(String id) async {
    await _db.delete('file_metadata', where: 'id = ?', whereArgs: [id]);
  }

  // ── Generation History CRUD ──

  Future<void> insertHistory(Map<String, dynamic> data) async {
    await _db.insert('generation_history', data,
        conflictAlgorithm: ConflictAlgorithm.replace);
    // Keep max 50 entries
    await _db.execute('''
      DELETE FROM generation_history WHERE id NOT IN (
        SELECT id FROM generation_history ORDER BY created_at DESC LIMIT 50
      )
    ''');
  }

  Future<List<Map<String, dynamic>>> listHistory({int limit = 50}) async {
    return await _db.query('generation_history',
        orderBy: 'created_at DESC', limit: limit);
  }

  Future<void> deleteHistory(String id) async {
    await _db
        .delete('generation_history', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clearHistory() async {
    await _db.delete('generation_history');
  }

  // ── Assets CRUD ──

  Future<void> insertAsset(Map<String, dynamic> data) async {
    await _db.insert('assets', data,
        conflictAlgorithm: ConflictAlgorithm.replace);
    // Keep max 100 entries
    await _db.execute('''
      DELETE FROM assets WHERE id NOT IN (
        SELECT id FROM assets ORDER BY created_at DESC LIMIT 100
      )
    ''');
  }

  Future<List<Map<String, dynamic>>> listAssets({int limit = 100}) async {
    return await _db.query('assets',
        orderBy: 'created_at DESC', limit: limit);
  }

  Future<void> deleteAsset(String id) async {
    await _db.delete('assets', where: 'id = ?', whereArgs: [id]);
  }

  // ── Status Events CRUD ──

  Future<void> insertEvent(Map<String, dynamic> data) async {
    await _db.insert('status_events', data,
        conflictAlgorithm: ConflictAlgorithm.replace);
    // Keep max 500 events
    await _db.execute('''
      DELETE FROM status_events WHERE id NOT IN (
        SELECT id FROM status_events ORDER BY created_at DESC LIMIT 500
      )
    ''');
  }

  Future<List<Map<String, dynamic>>> listEvents({int limit = 100}) async {
    return await _db.query('status_events',
        orderBy: 'created_at DESC', limit: limit);
  }

  Future<Map<String, dynamic>> getEventStats() async {
    final totalRow =
        await _db.rawQuery('SELECT COUNT(*) as c FROM status_events');
    final total = (totalRow.first['c'] as int?) ?? 0;

    final compRow = await _db.rawQuery(
        "SELECT COUNT(*) as c FROM status_events WHERE status = 'completed'");
    final completed = (compRow.first['c'] as int?) ?? 0;

    final failRow = await _db.rawQuery(
        "SELECT COUNT(*) as c FROM status_events WHERE status = 'failed'");
    final failed = (failRow.first['c'] as int?) ?? 0;

    // Tasks in last minute
    final oneMinAgo =
        DateTime.now().subtract(const Duration(minutes: 1)).millisecondsSinceEpoch;
    final recentRow = await _db.rawQuery(
        'SELECT COUNT(*) as c FROM status_events WHERE created_at > ?',
        [oneMinAgo]);
    final recentCount = (recentRow.first['c'] as int?) ?? 0;

    final successRate =
        (completed + failed) > 0 ? completed / (completed + failed) : 1.0;

    return {
      'total': total,
      'completed': completed,
      'failed': failed,
      'success_rate': successRate,
      'tasks_per_min': recentCount,
    };
  }

  // ── Chat Messages CRUD ──

  Future<void> insertChatMessage(Map<String, dynamic> data) async {
    await _db.insert('chat_messages', data,
        conflictAlgorithm: ConflictAlgorithm.replace);
    // Keep max 100 messages
    await _db.execute('''
      DELETE FROM chat_messages WHERE id NOT IN (
        SELECT id FROM chat_messages ORDER BY timestamp DESC LIMIT 100
      )
    ''');
  }

  Future<List<Map<String, dynamic>>> listChatMessages(
      {int limit = 100}) async {
    return await _db.query('chat_messages',
        orderBy: 'timestamp DESC', limit: limit);
  }

  Future<void> clearChatMessages() async {
    await _db.delete('chat_messages');
  }

  // ── Utilities ──

  Future<void> close() async {
    await _db.close();
    _initialized = false;
  }

  Future<List<String>> getTableNames() async {
    final rows = await _db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name");
    return rows.map((r) => r['name'] as String).toList();
  }
}
