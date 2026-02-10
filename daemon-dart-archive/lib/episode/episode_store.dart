import 'dart:convert';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import '../database/app_database.dart';
import 'episode_script.dart';

/// SQLite CRUD for episodes, using the centralized AppDatabase.
class EpisodeStore {
  final AppDatabase _db;

  EpisodeStore(this._db);

  /// List all episodes (summary only — no full script JSON).
  Future<List<Map<String, dynamic>>> list() async {
    final rows = await _db.db.query(
      'episodes',
      columns: ['id', 'title', 'synopsis', 'status', 'progress', 'output_path', 'created_at', 'updated_at'],
      orderBy: 'updated_at DESC',
    );
    return rows;
  }

  /// Get a single episode with full script.
  Future<Map<String, dynamic>?> get(String id) async {
    final rows = await _db.db.query(
      'episodes',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;

    final row = Map<String, dynamic>.from(rows.first);
    // Parse the script JSON
    if (row['script'] is String) {
      try {
        row['script'] = jsonDecode(row['script'] as String);
      } catch (_) {}
    }
    return row;
  }

  /// Create or update an episode.
  Future<void> upsert(String id, EpisodeScript script, {
    String status = 'draft',
    double progress = 0,
    String? outputPath,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.db.insert(
      'episodes',
      {
        'id': id,
        'title': script.title,
        'synopsis': script.synopsis,
        'script': jsonEncode(script.toJson()),
        'status': status,
        'progress': progress,
        'output_path': outputPath,
        'created_at': script.createdAt.millisecondsSinceEpoch,
        'updated_at': now,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Update episode status and progress.
  Future<void> updateStatus(String id, String status, double progress, {String? outputPath}) async {
    final updates = <String, dynamic>{
      'status': status,
      'progress': progress,
      'updated_at': DateTime.now().millisecondsSinceEpoch,
    };
    if (outputPath != null) {
      updates['output_path'] = outputPath;
    }
    await _db.db.update('episodes', updates, where: 'id = ?', whereArgs: [id]);
  }

  /// Update the script JSON.
  Future<void> updateScript(String id, EpisodeScript script) async {
    await _db.db.update(
      'episodes',
      {
        'title': script.title,
        'synopsis': script.synopsis,
        'script': jsonEncode(script.toJson()),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete an episode.
  Future<bool> delete(String id) async {
    final count = await _db.db.delete('episodes', where: 'id = ?', whereArgs: [id]);
    return count > 0;
  }
}
