import 'dart:convert';
import 'dart:io';
import 'app_database.dart';

/// One-time migration from legacy JSON files to SQLite.
///
/// Runs on daemon startup. Checks schema_migrations table to determine
/// if migration has already been performed.
class DataMigrator {
  static Future<void> migrateIfNeeded(AppDatabase db) async {
    // v1 is always present (created with schema), check for v2 (data migration)
    final migrated = await db.db.query('schema_migrations',
        where: 'version = ?', whereArgs: [2]);
    if (migrated.isNotEmpty) return;

    print('[DataMigrator] Running one-time JSON → SQLite migration...');
    final home = Platform.environment['HOME'] ?? '.';
    var count = 0;

    // 1. Migrate pipelines
    count += await _migratePipelines(db, '$home/.opencli/pipelines');

    // 2. Migrate paired devices
    count += await _migratePairedDevices(
        db, '$home/.opencli/security/paired_devices.json');

    // 3. Migrate pending issues
    count += await _migratePendingIssues(
        db, '$home/.opencli/data/pending_issues.json');

    // 4. Migrate file metadata
    count += await _migrateFileMetadata(
        db, '$home/.opencli/storage/metadata.json');

    // Record migration
    await db.db.insert('schema_migrations', {
      'version': 2,
      'applied_at': DateTime.now().millisecondsSinceEpoch,
      'description': 'Migrated $count records from JSON files',
    });

    print('[DataMigrator] Migration complete: $count records migrated');
  }

  static Future<int> _migratePipelines(AppDatabase db, String dir) async {
    final directory = Directory(dir);
    if (!await directory.exists()) return 0;

    var count = 0;
    await for (final entity in directory.list()) {
      if (entity is File && entity.path.endsWith('.json')) {
        try {
          final content = await entity.readAsString();
          final json = jsonDecode(content) as Map<String, dynamic>;

          await db.upsertPipeline({
            'id': json['id'] as String,
            'name': json['name'] as String? ?? 'Untitled',
            'description': json['description'] as String? ?? '',
            'nodes': jsonEncode(json['nodes'] ?? []),
            'edges': jsonEncode(json['edges'] ?? []),
            'parameters': jsonEncode(json['parameters'] ?? []),
            'created_at': _parseTimestamp(json['created_at']),
            'updated_at': _parseTimestamp(json['updated_at']),
          });

          // Rename to .bak
          await entity.rename('${entity.path}.bak');
          count++;
        } catch (e) {
          print('[DataMigrator] Warning: could not migrate ${entity.path}: $e');
        }
      }
    }
    if (count > 0) print('[DataMigrator] Migrated $count pipelines');
    return count;
  }

  static Future<int> _migratePairedDevices(
      AppDatabase db, String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return 0;

    try {
      final content = await file.readAsString();
      final List<dynamic> data = jsonDecode(content);
      var count = 0;

      for (final item in data) {
        final device = item as Map<String, dynamic>;
        await db.upsertPairedDevice({
          'device_id': device['deviceId'] as String,
          'device_name': device['deviceName'] as String? ?? 'Unknown',
          'platform': device['platform'] as String? ?? 'unknown',
          'paired_at': _parseTimestamp(device['pairedAt']),
          'last_seen': _parseTimestamp(device['lastSeen']),
          'shared_secret': device['sharedSecret'] as String? ?? '',
          'permissions': jsonEncode(device['permissions'] ?? {}),
        });
        count++;
      }

      await file.rename('$filePath.bak');
      if (count > 0) print('[DataMigrator] Migrated $count paired devices');
      return count;
    } catch (e) {
      print('[DataMigrator] Warning: could not migrate paired devices: $e');
      return 0;
    }
  }

  static Future<int> _migratePendingIssues(
      AppDatabase db, String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return 0;

    try {
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      var count = 0;

      // Migrate pending issues
      final issues = json['pendingIssues'] as List<dynamic>? ?? [];
      for (final item in issues) {
        final issue = item as Map<String, dynamic>;
        await db.insertIssue({
          'id': issue['id'] as String,
          'title': issue['title'] as String? ?? '',
          'body': issue['body'] as String? ?? '',
          'labels': jsonEncode(issue['labels'] ?? []),
          'fingerprint': '${(issue['title'] ?? '').hashCode}',
          'created_at': _parseTimestamp(issue['createdAt']),
          'reported': (issue['reported'] == true) ? 1 : 0,
          'remote_id': issue['remoteId'] as String?,
        });
        count++;
      }

      await file.rename('$filePath.bak');
      if (count > 0) print('[DataMigrator] Migrated $count pending issues');
      return count;
    } catch (e) {
      print('[DataMigrator] Warning: could not migrate pending issues: $e');
      return 0;
    }
  }

  static Future<int> _migrateFileMetadata(
      AppDatabase db, String filePath) async {
    final file = File(filePath);
    if (!await file.exists()) return 0;

    try {
      final content = await file.readAsString();
      final json = jsonDecode(content) as Map<String, dynamic>;
      var count = 0;

      for (final entry in json.entries) {
        final meta = entry.value as Map<String, dynamic>;
        await db.insertFileMetadata({
          'id': meta['id'] as String? ?? entry.key,
          'filename': meta['filename'] as String? ?? 'unknown',
          'size': meta['size'] as int? ?? 0,
          'content_type': meta['content_type'] as String? ?? 'application/octet-stream',
          'checksum': meta['checksum'] as String? ?? '',
          'uploaded_at': _parseTimestamp(meta['uploaded_at']),
          'metadata': jsonEncode(meta['metadata'] ?? {}),
        });
        count++;
      }

      await file.rename('$filePath.bak');
      if (count > 0) print('[DataMigrator] Migrated $count file metadata');
      return count;
    } catch (e) {
      print('[DataMigrator] Warning: could not migrate file metadata: $e');
      return 0;
    }
  }

  /// Parse a timestamp that could be ISO 8601 string or milliseconds int.
  static int _parseTimestamp(dynamic value) {
    if (value == null) return DateTime.now().millisecondsSinceEpoch;
    if (value is int) return value;
    if (value is String) {
      try {
        return DateTime.parse(value).millisecondsSinceEpoch;
      } catch (_) {
        return DateTime.now().millisecondsSinceEpoch;
      }
    }
    return DateTime.now().millisecondsSinceEpoch;
  }
}
