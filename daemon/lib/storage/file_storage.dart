import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as path;
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;

/// File storage system with multiple backend support
class FileStorage {
  final FileStorageConfig config;
  late FileStorageAdapter _adapter;

  FileStorage({required this.config}) {
    _adapter = _createAdapter(config);
  }

  /// Initialize storage
  Future<void> initialize() async {
    await _adapter.initialize();
    print('File storage initialized: ${config.type}');
  }

  /// Upload file
  Future<StoredFile> upload(
    File file, {
    String? filename,
    String? contentType,
    Map<String, String>? metadata,
  }) async {
    final name = filename ?? path.basename(file.path);
    final bytes = await file.readAsBytes();
    final checksum = _calculateChecksum(bytes);

    final storedFile = StoredFile(
      id: _generateFileId(),
      filename: name,
      size: bytes.length,
      contentType: contentType ?? _detectContentType(name),
      checksum: checksum,
      uploadedAt: DateTime.now(),
      metadata: metadata ?? {},
    );

    final storagePath = await _adapter.store(storedFile, bytes);
    storedFile.path = storagePath;

    return storedFile;
  }

  /// Upload from bytes
  Future<StoredFile> uploadBytes(
    List<int> bytes, {
    required String filename,
    String? contentType,
    Map<String, String>? metadata,
  }) async {
    final checksum = _calculateChecksum(bytes);

    final storedFile = StoredFile(
      id: _generateFileId(),
      filename: filename,
      size: bytes.length,
      contentType: contentType ?? _detectContentType(filename),
      checksum: checksum,
      uploadedAt: DateTime.now(),
      metadata: metadata ?? {},
    );

    final storagePath = await _adapter.store(storedFile, bytes);
    storedFile.path = storagePath;

    return storedFile;
  }

  /// Download file
  Future<List<int>> download(String fileId) async {
    return await _adapter.retrieve(fileId);
  }

  /// Download to file
  Future<File> downloadToFile(String fileId, String destinationPath) async {
    final bytes = await download(fileId);
    final file = File(destinationPath);
    await file.writeAsBytes(bytes);
    return file;
  }

  /// Get file metadata
  Future<StoredFile?> getMetadata(String fileId) async {
    return await _adapter.getMetadata(fileId);
  }

  /// Delete file
  Future<void> delete(String fileId) async {
    await _adapter.delete(fileId);
  }

  /// List files
  Future<List<StoredFile>> listFiles({
    int? limit,
    int? offset,
    String? contentType,
  }) async {
    return await _adapter.listFiles(
      limit: limit,
      offset: offset,
      contentType: contentType,
    );
  }

  /// Get storage statistics
  Future<StorageStats> getStats() async {
    return await _adapter.getStats();
  }

  /// Close storage
  Future<void> close() async {
    await _adapter.close();
  }

  /// Create adapter based on config
  FileStorageAdapter _createAdapter(FileStorageConfig config) {
    switch (config.type) {
      case FileStorageType.local:
        return LocalFileStorageAdapter(config);
      case FileStorageType.s3:
        return S3StorageAdapter(config);
      case FileStorageType.gcs:
        return GCSStorageAdapter(config);
      case FileStorageType.azure:
        return AzureStorageAdapter(config);
    }
  }

  String _generateFileId() {
    return 'file_${DateTime.now().millisecondsSinceEpoch}';
  }

  String _calculateChecksum(List<int> bytes) {
    return md5.convert(bytes).toString();
  }

  String _detectContentType(String filename) {
    final ext = path.extension(filename).toLowerCase();
    const contentTypes = {
      '.txt': 'text/plain',
      '.html': 'text/html',
      '.json': 'application/json',
      '.xml': 'application/xml',
      '.pdf': 'application/pdf',
      '.jpg': 'image/jpeg',
      '.jpeg': 'image/jpeg',
      '.png': 'image/png',
      '.gif': 'image/gif',
      '.svg': 'image/svg+xml',
      '.mp4': 'video/mp4',
      '.mp3': 'audio/mpeg',
      '.zip': 'application/zip',
      '.tar': 'application/x-tar',
      '.gz': 'application/gzip',
    };
    return contentTypes[ext] ?? 'application/octet-stream';
  }
}

/// File storage configuration
class FileStorageConfig {
  final FileStorageType type;
  final String? basePath;
  final String? bucket;
  final String? region;
  final String? accessKey;
  final String? secretKey;
  final Map<String, dynamic>? options;

  FileStorageConfig({
    required this.type,
    this.basePath,
    this.bucket,
    this.region,
    this.accessKey,
    this.secretKey,
    this.options,
  });

  factory FileStorageConfig.local(String basePath) {
    return FileStorageConfig(
      type: FileStorageType.local,
      basePath: basePath,
    );
  }

  factory FileStorageConfig.s3({
    required String bucket,
    required String region,
    required String accessKey,
    required String secretKey,
  }) {
    return FileStorageConfig(
      type: FileStorageType.s3,
      bucket: bucket,
      region: region,
      accessKey: accessKey,
      secretKey: secretKey,
    );
  }
}

enum FileStorageType { local, s3, gcs, azure }

/// Stored file metadata
class StoredFile {
  final String id;
  final String filename;
  final int size;
  final String contentType;
  final String checksum;
  final DateTime uploadedAt;
  final Map<String, String> metadata;
  String? path;

  StoredFile({
    required this.id,
    required this.filename,
    required this.size,
    required this.contentType,
    required this.checksum,
    required this.uploadedAt,
    required this.metadata,
    this.path,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'filename': filename,
      'size': size,
      'content_type': contentType,
      'checksum': checksum,
      'uploaded_at': uploadedAt.toIso8601String(),
      'metadata': metadata,
      if (path != null) 'path': path,
    };
  }

  factory StoredFile.fromJson(Map<String, dynamic> json) {
    return StoredFile(
      id: json['id'] as String,
      filename: json['filename'] as String,
      size: json['size'] as int,
      contentType: json['content_type'] as String,
      checksum: json['checksum'] as String,
      uploadedAt: DateTime.parse(json['uploaded_at'] as String),
      metadata: Map<String, String>.from(json['metadata'] as Map),
      path: json['path'] as String?,
    );
  }

  String get sizeFormatted {
    if (size < 1024) return '$size B';
    if (size < 1024 * 1024) return '${(size / 1024).toStringAsFixed(2)} KB';
    if (size < 1024 * 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(size / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

/// Storage statistics
class StorageStats {
  final int totalFiles;
  final int totalSize;
  final Map<String, int> filesByType;

  StorageStats({
    required this.totalFiles,
    required this.totalSize,
    required this.filesByType,
  });

  String get totalSizeFormatted {
    if (totalSize < 1024) return '$totalSize B';
    if (totalSize < 1024 * 1024) {
      return '${(totalSize / 1024).toStringAsFixed(2)} KB';
    }
    if (totalSize < 1024 * 1024 * 1024) {
      return '${(totalSize / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(totalSize / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }
}

/// Base file storage adapter
abstract class FileStorageAdapter {
  Future<void> initialize();
  Future<String> store(StoredFile metadata, List<int> data);
  Future<List<int>> retrieve(String fileId);
  Future<StoredFile?> getMetadata(String fileId);
  Future<void> delete(String fileId);
  Future<List<StoredFile>> listFiles({
    int? limit,
    int? offset,
    String? contentType,
  });
  Future<StorageStats> getStats();
  Future<void> close();
}

/// Local file storage adapter
class LocalFileStorageAdapter implements FileStorageAdapter {
  final FileStorageConfig config;
  final Map<String, StoredFile> _metadata = {};
  late String _basePath;

  LocalFileStorageAdapter(this.config);

  @override
  Future<void> initialize() async {
    _basePath = config.basePath ?? path.join(Directory.systemTemp.path, 'opencli_storage');
    final dir = Directory(_basePath);
    await dir.create(recursive: true);

    // Load metadata
    final metadataFile = File(path.join(_basePath, 'metadata.json'));
    if (await metadataFile.exists()) {
      final content = await metadataFile.readAsString();
      final data = jsonDecode(content) as Map<String, dynamic>;
      data.forEach((key, value) {
        _metadata[key] = StoredFile.fromJson(value as Map<String, dynamic>);
      });
    }
  }

  @override
  Future<String> store(StoredFile metadata, List<int> data) async {
    final filePath = path.join(_basePath, metadata.id);
    final file = File(filePath);
    await file.writeAsBytes(data);

    _metadata[metadata.id] = metadata;
    await _saveMetadata();

    return filePath;
  }

  @override
  Future<List<int>> retrieve(String fileId) async {
    final filePath = path.join(_basePath, fileId);
    final file = File(filePath);

    if (!await file.exists()) {
      throw Exception('File not found: $fileId');
    }

    return await file.readAsBytes();
  }

  @override
  Future<StoredFile?> getMetadata(String fileId) async {
    return _metadata[fileId];
  }

  @override
  Future<void> delete(String fileId) async {
    final filePath = path.join(_basePath, fileId);
    final file = File(filePath);

    if (await file.exists()) {
      await file.delete();
    }

    _metadata.remove(fileId);
    await _saveMetadata();
  }

  @override
  Future<List<StoredFile>> listFiles({
    int? limit,
    int? offset,
    String? contentType,
  }) async {
    var files = _metadata.values.toList();

    if (contentType != null) {
      files = files.where((f) => f.contentType == contentType).toList();
    }

    files.sort((a, b) => b.uploadedAt.compareTo(a.uploadedAt));

    if (offset != null) {
      files = files.skip(offset).toList();
    }

    if (limit != null) {
      files = files.take(limit).toList();
    }

    return files;
  }

  @override
  Future<StorageStats> getStats() async {
    final filesByType = <String, int>{};
    var totalSize = 0;

    for (final file in _metadata.values) {
      totalSize += file.size;
      filesByType[file.contentType] = (filesByType[file.contentType] ?? 0) + 1;
    }

    return StorageStats(
      totalFiles: _metadata.length,
      totalSize: totalSize,
      filesByType: filesByType,
    );
  }

  @override
  Future<void> close() async {
    await _saveMetadata();
  }

  Future<void> _saveMetadata() async {
    final metadataFile = File(path.join(_basePath, 'metadata.json'));
    final data = _metadata.map((key, value) => MapEntry(key, value.toJson()));
    await metadataFile.writeAsString(jsonEncode(data));
  }
}

/// S3 storage adapter (placeholder)
class S3StorageAdapter implements FileStorageAdapter {
  final FileStorageConfig config;

  S3StorageAdapter(this.config);

  @override
  Future<void> initialize() async {
    throw UnimplementedError('S3 adapter requires AWS SDK');
  }

  @override
  Future<String> store(StoredFile metadata, List<int> data) async {
    throw UnimplementedError();
  }

  @override
  Future<List<int>> retrieve(String fileId) async {
    throw UnimplementedError();
  }

  @override
  Future<StoredFile?> getMetadata(String fileId) async {
    throw UnimplementedError();
  }

  @override
  Future<void> delete(String fileId) async {
    throw UnimplementedError();
  }

  @override
  Future<List<StoredFile>> listFiles({
    int? limit,
    int? offset,
    String? contentType,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<StorageStats> getStats() async {
    throw UnimplementedError();
  }

  @override
  Future<void> close() async {}
}

/// Google Cloud Storage adapter (placeholder)
class GCSStorageAdapter extends S3StorageAdapter {
  GCSStorageAdapter(super.config);
}

/// Azure Blob Storage adapter (placeholder)
class AzureStorageAdapter extends S3StorageAdapter {
  AzureStorageAdapter(super.config);
}

/// File upload manager with chunking support
class FileUploadManager {
  final FileStorage storage;
  final int chunkSize;

  FileUploadManager({
    required this.storage,
    this.chunkSize = 5 * 1024 * 1024, // 5MB
  });

  /// Upload large file with progress tracking
  Future<StoredFile> uploadWithProgress(
    File file, {
    String? filename,
    String? contentType,
    Map<String, String>? metadata,
    void Function(double progress)? onProgress,
  }) async {
    final fileSize = await file.length();
    final chunks = (fileSize / chunkSize).ceil();

    if (chunks == 1) {
      // Small file, upload directly
      return await storage.upload(
        file,
        filename: filename,
        contentType: contentType,
        metadata: metadata,
      );
    }

    // Large file, upload in chunks
    final tempFiles = <File>[];
    var uploadedBytes = 0;

    for (var i = 0; i < chunks; i++) {
      final start = i * chunkSize;
      final end = ((i + 1) * chunkSize).clamp(0, fileSize);

      final chunk = await file.openRead(start, end).toList();
      final chunkBytes = chunk.expand((e) => e).toList();

      final tempFile = File('${file.path}.chunk$i');
      await tempFile.writeAsBytes(chunkBytes);
      tempFiles.add(tempFile);

      uploadedBytes += chunkBytes.length;
      onProgress?.call(uploadedBytes / fileSize);
    }

    // Combine chunks
    final combinedFile = File('${file.path}.combined');
    final sink = combinedFile.openWrite();

    for (final tempFile in tempFiles) {
      final bytes = await tempFile.readAsBytes();
      sink.add(bytes);
      await tempFile.delete();
    }

    await sink.close();

    // Upload combined file
    final result = await storage.upload(
      combinedFile,
      filename: filename,
      contentType: contentType,
      metadata: metadata,
    );

    await combinedFile.delete();

    return result;
  }
}
