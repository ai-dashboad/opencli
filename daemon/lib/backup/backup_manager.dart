import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:archive/archive.dart';

/// Manages backup and recovery of system state
class BackupManager {
  final String backupDirectory;
  final int maxBackups;
  final Duration retentionPeriod;

  BackupManager({
    required this.backupDirectory,
    this.maxBackups = 10,
    this.retentionPeriod = const Duration(days: 30),
  }) {
    _ensureBackupDirectory();
  }

  /// Create full system backup
  Future<BackupResult> createBackup({
    String? name,
    BackupType type = BackupType.full,
    List<String>? includePaths,
    List<String>? excludePaths,
  }) async {
    final backupName = name ?? _generateBackupName(type);
    final backupPath = path.join(backupDirectory, backupName);

    try {
      final startTime = DateTime.now();

      // Create backup directory
      final backupDir = Directory(backupPath);
      await backupDir.create(recursive: true);

      // Collect files to backup
      final filesToBackup = await _collectFiles(
        includePaths: includePaths,
        excludePaths: excludePaths,
      );

      // Create backup manifest
      final manifest = BackupManifest(
        name: backupName,
        type: type,
        createdAt: startTime,
        files: filesToBackup.keys.toList(),
        metadata: {
          'hostname': Platform.localHostname,
          'platform': Platform.operatingSystem,
          'version': Platform.version,
        },
      );

      // Copy files
      for (final entry in filesToBackup.entries) {
        final sourcePath = entry.key;
        final destinationPath = path.join(backupPath, entry.value);

        final destFile = File(destinationPath);
        await destFile.parent.create(recursive: true);
        await File(sourcePath).copy(destinationPath);
      }

      // Save manifest
      await _saveManifest(backupPath, manifest);

      // Compress backup if full backup
      if (type == BackupType.full) {
        await _compressBackup(backupPath);
      }

      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);

      // Cleanup old backups
      await _cleanupOldBackups();

      return BackupResult(
        name: backupName,
        path: backupPath,
        success: true,
        duration: duration,
        filesCount: filesToBackup.length,
        size: await _getBackupSize(backupPath),
      );
    } catch (e) {
      return BackupResult(
        name: backupName,
        path: backupPath,
        success: false,
        error: e.toString(),
        duration: Duration.zero,
        filesCount: 0,
        size: 0,
      );
    }
  }

  /// Restore from backup
  Future<RestoreResult> restore(
    String backupName, {
    String? targetDirectory,
    bool overwrite = false,
  }) async {
    final backupPath = path.join(backupDirectory, backupName);
    final backupDir = Directory(backupPath);

    if (!await backupDir.exists()) {
      // Check if compressed backup exists
      final compressedPath = '$backupPath.tar.gz';
      if (await File(compressedPath).exists()) {
        await _decompressBackup(compressedPath);
      } else {
        throw Exception('Backup not found: $backupName');
      }
    }

    try {
      final startTime = DateTime.now();

      // Load manifest
      final manifest = await _loadManifest(backupPath);

      // Restore files
      final target = targetDirectory ?? Directory.current.path;
      int restoredCount = 0;

      for (final relativePath in manifest.files) {
        final sourcePath = path.join(backupPath, relativePath);
        final destPath = path.join(target, relativePath);

        final source = File(sourcePath);
        if (!await source.exists()) continue;

        final dest = File(destPath);

        if (await dest.exists() && !overwrite) {
          continue; // Skip existing files
        }

        await dest.parent.create(recursive: true);
        await source.copy(destPath);
        restoredCount++;
      }

      final endTime = DateTime.now();
      final duration = endTime.difference(startTime);

      return RestoreResult(
        backupName: backupName,
        success: true,
        duration: duration,
        filesRestored: restoredCount,
        targetDirectory: target,
      );
    } catch (e) {
      return RestoreResult(
        backupName: backupName,
        success: false,
        error: e.toString(),
        duration: Duration.zero,
        filesRestored: 0,
        targetDirectory: targetDirectory ?? '',
      );
    }
  }

  /// List all available backups
  Future<List<BackupInfo>> listBackups() async {
    final backups = <BackupInfo>[];
    final dir = Directory(backupDirectory);

    if (!await dir.exists()) return backups;

    await for (final entity in dir.list()) {
      if (entity is Directory) {
        try {
          final manifest = await _loadManifest(entity.path);
          final size = await _getBackupSize(entity.path);

          backups.add(BackupInfo(
            name: path.basename(entity.path),
            path: entity.path,
            type: manifest.type,
            createdAt: manifest.createdAt,
            filesCount: manifest.files.length,
            size: size,
          ));
        } catch (e) {
          // Skip invalid backups
        }
      } else if (entity is File && entity.path.endsWith('.tar.gz')) {
        // Compressed backup
        final stats = await entity.stat();
        backups.add(BackupInfo(
          name: path.basenameWithoutExtension(
              path.basenameWithoutExtension(entity.path)),
          path: entity.path,
          type: BackupType.full,
          createdAt: stats.modified,
          filesCount: 0,
          size: stats.size,
          compressed: true,
        ));
      }
    }

    backups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return backups;
  }

  /// Delete backup
  Future<void> deleteBackup(String backupName) async {
    final backupPath = path.join(backupDirectory, backupName);
    final backupDir = Directory(backupPath);

    if (await backupDir.exists()) {
      await backupDir.delete(recursive: true);
    }

    final compressedPath = '$backupPath.tar.gz';
    if (await File(compressedPath).exists()) {
      await File(compressedPath).delete();
    }
  }

  /// Create incremental backup (only changed files)
  Future<BackupResult> createIncrementalBackup(String baseBackupName) async {
    final baseBackupPath = path.join(backupDirectory, baseBackupName);
    final baseManifest = await _loadManifest(baseBackupPath);

    // Get current file checksums
    final currentFiles = <String, String>{};
    for (final file in baseManifest.files) {
      // Calculate checksum (simplified)
      currentFiles[file] = await _calculateChecksum(file);
    }

    // Find changed files
    final changedFiles = <String>[];
    for (final entry in currentFiles.entries) {
      // Compare with base backup
      // This is simplified - would need actual comparison
      changedFiles.add(entry.key);
    }

    return await createBackup(
      type: BackupType.incremental,
      includePaths: changedFiles,
    );
  }

  /// Verify backup integrity
  Future<bool> verifyBackup(String backupName) async {
    try {
      final backupPath = path.join(backupDirectory, backupName);
      final manifest = await _loadManifest(backupPath);

      for (final relativePath in manifest.files) {
        final filePath = path.join(backupPath, relativePath);
        if (!await File(filePath).exists()) {
          return false;
        }
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Collect files to backup
  Future<Map<String, String>> _collectFiles({
    List<String>? includePaths,
    List<String>? excludePaths,
  }) async {
    final files = <String, String>{};

    final includes = includePaths ??
        [
          'config',
          'data',
          'logs',
        ];

    for (final includePath in includes) {
      final dir = Directory(includePath);
      if (!await dir.exists()) continue;

      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) {
          final relativePath = path.relative(entity.path);

          // Check exclude paths
          if (excludePaths != null &&
              excludePaths.any((ex) => relativePath.startsWith(ex))) {
            continue;
          }

          files[entity.path] = relativePath;
        }
      }
    }

    return files;
  }

  /// Save backup manifest
  Future<void> _saveManifest(String backupPath, BackupManifest manifest) async {
    final manifestFile = File(path.join(backupPath, 'manifest.json'));
    await manifestFile.writeAsString(jsonEncode(manifest.toJson()));
  }

  /// Load backup manifest
  Future<BackupManifest> _loadManifest(String backupPath) async {
    final manifestFile = File(path.join(backupPath, 'manifest.json'));
    final content = await manifestFile.readAsString();
    final data = jsonDecode(content) as Map<String, dynamic>;
    return BackupManifest.fromJson(data);
  }

  /// Compress backup
  Future<void> _compressBackup(String backupPath) async {
    final archive = Archive();
    final dir = Directory(backupPath);

    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        final relativePath = path.relative(entity.path, from: backupPath);
        final bytes = await entity.readAsBytes();
        archive.addFile(ArchiveFile(relativePath, bytes.length, bytes));
      }
    }

    final tarGz = TarEncoder().encode(archive);
    final compressed = GZipEncoder().encode(tarGz!);

    final outputFile = File('$backupPath.tar.gz');
    await outputFile.writeAsBytes(compressed!);

    // Remove uncompressed directory
    await dir.delete(recursive: true);
  }

  /// Decompress backup
  Future<void> _decompressBackup(String compressedPath) async {
    final bytes = await File(compressedPath).readAsBytes();
    final decompressed = GZipDecoder().decodeBytes(bytes);
    final archive = TarDecoder().decodeBytes(decompressed);

    final outputPath = compressedPath.replaceAll('.tar.gz', '');
    final outputDir = Directory(outputPath);
    await outputDir.create(recursive: true);

    for (final file in archive) {
      final filePath = path.join(outputPath, file.name);
      final destFile = File(filePath);
      await destFile.parent.create(recursive: true);
      await destFile.writeAsBytes(file.content as List<int>);
    }
  }

  /// Get backup size
  Future<int> _getBackupSize(String backupPath) async {
    int size = 0;
    final dir = Directory(backupPath);

    if (!await dir.exists()) {
      final compressedFile = File('$backupPath.tar.gz');
      if (await compressedFile.exists()) {
        return await compressedFile.length();
      }
      return 0;
    }

    await for (final entity in dir.list(recursive: true)) {
      if (entity is File) {
        size += await entity.length();
      }
    }

    return size;
  }

  /// Calculate file checksum
  Future<String> _calculateChecksum(String filePath) async {
    // Simplified checksum - would use proper hash in production
    final file = File(filePath);
    if (!await file.exists()) return '';

    final stats = await file.stat();
    return '${stats.size}_${stats.modified.millisecondsSinceEpoch}';
  }

  /// Cleanup old backups
  Future<void> _cleanupOldBackups() async {
    final backups = await listBackups();

    // Remove backups exceeding retention period
    final cutoffDate = DateTime.now().subtract(retentionPeriod);
    for (final backup in backups) {
      if (backup.createdAt.isBefore(cutoffDate)) {
        await deleteBackup(backup.name);
      }
    }

    // Remove excess backups
    if (backups.length > maxBackups) {
      final toRemove = backups.skip(maxBackups);
      for (final backup in toRemove) {
        await deleteBackup(backup.name);
      }
    }
  }

  /// Ensure backup directory exists
  void _ensureBackupDirectory() {
    Directory(backupDirectory).createSync(recursive: true);
  }

  /// Generate backup name
  String _generateBackupName(BackupType type) {
    final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    return 'backup_${type.name}_$timestamp';
  }
}

/// Backup type
enum BackupType { full, incremental, differential }

/// Backup manifest
class BackupManifest {
  final String name;
  final BackupType type;
  final DateTime createdAt;
  final List<String> files;
  final Map<String, dynamic> metadata;

  BackupManifest({
    required this.name,
    required this.type,
    required this.createdAt,
    required this.files,
    required this.metadata,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'type': type.name,
      'created_at': createdAt.toIso8601String(),
      'files': files,
      'metadata': metadata,
    };
  }

  factory BackupManifest.fromJson(Map<String, dynamic> json) {
    return BackupManifest(
      name: json['name'] as String,
      type: BackupType.values.byName(json['type'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
      files: (json['files'] as List<dynamic>).cast<String>(),
      metadata: json['metadata'] as Map<String, dynamic>,
    );
  }
}

/// Backup result
class BackupResult {
  final String name;
  final String path;
  final bool success;
  final Duration duration;
  final int filesCount;
  final int size;
  final String? error;

  BackupResult({
    required this.name,
    required this.path,
    required this.success,
    required this.duration,
    required this.filesCount,
    required this.size,
    this.error,
  });
}

/// Restore result
class RestoreResult {
  final String backupName;
  final bool success;
  final Duration duration;
  final int filesRestored;
  final String targetDirectory;
  final String? error;

  RestoreResult({
    required this.backupName,
    required this.success,
    required this.duration,
    required this.filesRestored,
    required this.targetDirectory,
    this.error,
  });
}

/// Backup info
class BackupInfo {
  final String name;
  final String path;
  final BackupType type;
  final DateTime createdAt;
  final int filesCount;
  final int size;
  final bool compressed;

  BackupInfo({
    required this.name,
    required this.path,
    required this.type,
    required this.createdAt,
    required this.filesCount,
    required this.size,
    this.compressed = false,
  });

  String get sizeFormatted {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(2)} KB';
    if (size < 1024 * 1024 * 1024)
      return '${(size / (1024 * 1024)).toStringAsFixed(2)} MB';
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}
