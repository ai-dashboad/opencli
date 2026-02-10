import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// L3 Cache - SQLite persistent disk cache
class L3Cache {
  final String? directory;
  late Database _db;

  L3Cache({this.directory});

  Future<void> initialize() async {
    // Initialize FFI
    sqfliteFfiInit();

    final dbPath = _getDatabasePath();
    final dbDir = path.dirname(dbPath);

    // Create directory if needed
    await Directory(dbDir).create(recursive: true);

    // Open database
    _db = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: _createTables,
      ),
    );
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE cache (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        accessed_at INTEGER NOT NULL,
        hit_count INTEGER DEFAULT 0,
        size_bytes INTEGER,
        ttl_seconds INTEGER DEFAULT 604800
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_accessed_at ON cache(accessed_at)
    ''');

    await db.execute('''
      CREATE INDEX idx_created_at ON cache(created_at)
    ''');
  }

  Future<String?> get(String key) async {
    final results = await _db.query(
      'cache',
      where: 'key = ?',
      whereArgs: [key],
      limit: 1,
    );

    if (results.isEmpty) return null;

    final row = results.first;

    // Check TTL
    final createdAt = row['created_at'] as int;
    final ttl = row['ttl_seconds'] as int;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (now - createdAt > ttl * 1000) {
      // Expired
      await _db.delete('cache', where: 'key = ?', whereArgs: [key]);
      return null;
    }

    // Update access time
    await _db.update(
      'cache',
      {
        'accessed_at': now,
        'hit_count': (row['hit_count'] as int) + 1,
      },
      where: 'key = ?',
      whereArgs: [key],
    );

    return row['value'] as String;
  }

  Future<void> put(String key, String value, {int ttlSeconds = 604800}) async {
    final now = DateTime.now().millisecondsSinceEpoch;

    await _db.insert(
      'cache',
      {
        'key': key,
        'value': value,
        'created_at': now,
        'accessed_at': now,
        'hit_count': 0,
        'size_bytes': key.length + value.length,
        'ttl_seconds': ttlSeconds,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> clear() async {
    await _db.delete('cache');
  }

  Future<Map<String, dynamic>> getStats() async {
    final count = Sqflite.firstIntValue(
      await _db.rawQuery('SELECT COUNT(*) FROM cache'),
    );

    final totalSize = Sqflite.firstIntValue(
      await _db.rawQuery('SELECT SUM(size_bytes) FROM cache'),
    );

    return {
      'entries': count ?? 0,
      'size_bytes': totalSize ?? 0,
      'size_mb': (totalSize ?? 0) / 1024 / 1024,
    };
  }

  String _getDatabasePath() {
    if (directory != null) {
      return path.join(directory!, 'cache.db');
    }

    final home = Platform.environment['HOME'] ?? '.';
    return path.join(home, '.opencli', 'cache', 'cache.db');
  }

  Future<void> close() async {
    await _db.close();
  }
}
