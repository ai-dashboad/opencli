import 'dart:io';
import 'package:path/path.dart' as path;

/// 文件操作执行器
/// 支持列出、搜索、创建、移动、删除文件
class FileOperationExecutor {
  /// 执行文件操作
  Future<Map<String, dynamic>> execute(Map<String, dynamic> taskData) async {
    final operation = taskData['operation'] as String? ?? 'list';

    switch (operation) {
      case 'list':
        return await _listFiles(taskData);
      case 'search':
        return await _searchFiles(taskData);
      case 'create':
        return await _createFile(taskData);
      case 'move':
        return await _moveFile(taskData);
      case 'delete':
        return await _deleteFile(taskData);
      case 'organize':
        return await _organizeFiles(taskData);
      default:
        throw Exception('Unknown operation: $operation');
    }
  }

  /// 列出文件 - 返回丰富的元数据
  Future<Map<String, dynamic>> _listFiles(Map<String, dynamic> data) async {
    final directory = data['directory'] as String? ??
        '${Platform.environment['HOME']}/Desktop';
    final showHidden = data['show_hidden'] as bool? ?? false;

    final dir = Directory(directory);

    if (!await dir.exists()) {
      return {
        'success': false,
        'error': 'Directory not found: $directory',
      };
    }

    final files = <Map<String, dynamic>>[];

    await for (var entity in dir.list()) {
      final name = path.basename(entity.path);

      // 跳过隐藏文件（除非明确要求）
      if (!showHidden && name.startsWith('.')) {
        continue;
      }

      final stat = await entity.stat();
      final isDirectory = entity is Directory;
      final extension = isDirectory ? '' : path.extension(name).toLowerCase();

      files.add({
        'name': name,
        'path': entity.path,
        'type': isDirectory ? 'directory' : _getFileType(extension),
        'icon': isDirectory ? 'folder' : _getFileIcon(extension),
        'size': isDirectory ? null : stat.size,
        'size_formatted': isDirectory ? '-' : _formatFileSize(stat.size),
        'modified': stat.modified.toIso8601String(),
        'modified_relative': _formatRelativeTime(stat.modified),
        'extension': extension,
        'is_directory': isDirectory,
      });
    }

    // 按类型和名称排序（文件夹优先）
    files.sort((a, b) {
      if (a['is_directory'] != b['is_directory']) {
        return a['is_directory'] ? -1 : 1;
      }
      return (a['name'] as String).toLowerCase().compareTo(
        (b['name'] as String).toLowerCase()
      );
    });

    return {
      'success': true,
      'directory': directory,
      'files': files,
      'count': files.length,
      'total_size': _calculateTotalSize(files),
    };
  }

  /// 搜索文件
  Future<Map<String, dynamic>> _searchFiles(Map<String, dynamic> data) async {
    final directory = data['directory'] as String? ??
        '${Platform.environment['HOME']}/Desktop';
    final pattern = data['pattern'] as String;
    final recursive = data['recursive'] as bool? ?? false;

    final dir = Directory(directory);
    final results = <Map<String, dynamic>>[];

    await for (var entity in dir.list(recursive: recursive)) {
      final name = path.basename(entity.path);

      if (name.toLowerCase().contains(pattern.toLowerCase())) {
        final stat = await entity.stat();
        final isDirectory = entity is Directory;
        final extension = isDirectory ? '' : path.extension(name).toLowerCase();

        results.add({
          'name': name,
          'path': entity.path,
          'type': isDirectory ? 'directory' : _getFileType(extension),
          'icon': isDirectory ? 'folder' : _getFileIcon(extension),
          'size': isDirectory ? null : stat.size,
          'size_formatted': isDirectory ? '-' : _formatFileSize(stat.size),
          'modified': stat.modified.toIso8601String(),
          'modified_relative': _formatRelativeTime(stat.modified),
          'is_directory': isDirectory,
        });
      }
    }

    return {
      'success': true,
      'pattern': pattern,
      'directory': directory,
      'results': results,
      'count': results.length,
    };
  }

  /// 创建文件
  Future<Map<String, dynamic>> _createFile(Map<String, dynamic> data) async {
    final filePath = data['path'] as String;
    final content = data['content'] as String? ?? '';

    final file = File(filePath);
    await file.create(recursive: true);
    await file.writeAsString(content);

    return {
      'success': true,
      'path': filePath,
      'size': content.length,
    };
  }

  /// 移动文件
  Future<Map<String, dynamic>> _moveFile(Map<String, dynamic> data) async {
    final from = data['from'] as String;
    final to = data['to'] as String;

    final file = File(from);

    if (!await file.exists()) {
      return {
        'success': false,
        'error': 'Source file not found: $from',
      };
    }

    await file.rename(to);

    return {
      'success': true,
      'from': from,
      'to': to,
    };
  }

  /// 删除文件
  Future<Map<String, dynamic>> _deleteFile(Map<String, dynamic> data) async {
    final filePath = data['path'] as String;
    final file = File(filePath);

    if (!await file.exists()) {
      return {
        'success': false,
        'error': 'File not found: $filePath',
      };
    }

    await file.delete();

    return {
      'success': true,
      'deleted': filePath,
    };
  }

  /// 智能整理文件（按类型分类）
  Future<Map<String, dynamic>> _organizeFiles(Map<String, dynamic> data) async {
    final directory = data['directory'] as String;
    final strategy = data['strategy'] as String? ?? 'by_type';

    final dir = Directory(directory);
    final moved = <String, String>{};

    await for (var entity in dir.list()) {
      if (entity is File) {
        final name = path.basename(entity.path);
        final extension = path.extension(name).toLowerCase();
        final category = _getCategoryForExtension(extension);

        final targetDir = path.join(directory, category);
        await Directory(targetDir).create(recursive: true);

        final newPath = path.join(targetDir, name);
        await entity.rename(newPath);

        moved[entity.path] = newPath;
      }
    }

    return {
      'success': true,
      'directory': directory,
      'files_organized': moved.length,
      'moves': moved,
    };
  }

  /// 获取文件类型
  String _getFileType(String extension) {
    const typeMap = {
      // 文档
      '.pdf': 'document',
      '.doc': 'document',
      '.docx': 'document',
      '.txt': 'document',
      '.rtf': 'document',
      '.odt': 'document',

      // 图片
      '.jpg': 'image',
      '.jpeg': 'image',
      '.png': 'image',
      '.gif': 'image',
      '.bmp': 'image',
      '.svg': 'image',
      '.webp': 'image',

      // 视频
      '.mp4': 'video',
      '.mov': 'video',
      '.avi': 'video',
      '.mkv': 'video',
      '.flv': 'video',
      '.wmv': 'video',

      // 音频
      '.mp3': 'audio',
      '.wav': 'audio',
      '.flac': 'audio',
      '.aac': 'audio',
      '.m4a': 'audio',
      '.ogg': 'audio',

      // 压缩包
      '.zip': 'archive',
      '.rar': 'archive',
      '.7z': 'archive',
      '.tar': 'archive',
      '.gz': 'archive',

      // 代码
      '.dart': 'code',
      '.js': 'code',
      '.ts': 'code',
      '.py': 'code',
      '.java': 'code',
      '.cpp': 'code',
      '.c': 'code',
      '.swift': 'code',
      '.go': 'code',
      '.rs': 'code',

      // 其他
      '.dmg': 'installer',
      '.pkg': 'installer',
      '.app': 'application',
      '.exe': 'application',
    };

    return typeMap[extension] ?? 'file';
  }

  /// 获取文件图标名称
  String _getFileIcon(String extension) {
    const iconMap = {
      // 文档
      '.pdf': '📄',
      '.doc': '📝',
      '.docx': '📝',
      '.txt': '📃',

      // 图片
      '.jpg': '🖼️',
      '.jpeg': '🖼️',
      '.png': '🖼️',
      '.gif': '🎞️',

      // 视频
      '.mp4': '🎬',
      '.mov': '🎬',
      '.avi': '🎬',

      // 音频
      '.mp3': '🎵',
      '.wav': '🎵',
      '.flac': '🎵',

      // 压缩包
      '.zip': '📦',
      '.rar': '📦',
      '.7z': '📦',

      // 代码
      '.dart': '💻',
      '.js': '💻',
      '.py': '💻',
      '.java': '💻',

      // 其他
      '.dmg': '💿',
      '.app': '📱',
    };

    return iconMap[extension] ?? '📄';
  }

  /// 获取文件分类目录名
  String _getCategoryForExtension(String extension) {
    const categories = {
      '.jpg': 'Images',
      '.jpeg': 'Images',
      '.png': 'Images',
      '.gif': 'Images',

      '.pdf': 'Documents',
      '.doc': 'Documents',
      '.docx': 'Documents',
      '.txt': 'Documents',

      '.mp4': 'Videos',
      '.mov': 'Videos',
      '.avi': 'Videos',

      '.mp3': 'Music',
      '.wav': 'Music',
      '.flac': 'Music',

      '.zip': 'Archives',
      '.rar': 'Archives',
      '.7z': 'Archives',

      '.dart': 'Code',
      '.js': 'Code',
      '.py': 'Code',
      '.java': 'Code',
    };

    return categories[extension] ?? 'Other';
  }

  /// 格式化文件大小
  String _formatFileSize(int bytes) {
    if (bytes < 1024) {
      return '$bytes B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    } else if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    } else {
      return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
    }
  }

  /// 格式化相对时间
  String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return '刚刚';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}分钟前';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}小时前';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}天前';
    } else if (difference.inDays < 30) {
      return '${(difference.inDays / 7).floor()}周前';
    } else if (difference.inDays < 365) {
      return '${(difference.inDays / 30).floor()}个月前';
    } else {
      return '${(difference.inDays / 365).floor()}年前';
    }
  }

  /// 计算总大小
  int _calculateTotalSize(List<Map<String, dynamic>> files) {
    return files
        .where((f) => f['size'] != null)
        .fold(0, (sum, f) => sum + (f['size'] as int));
  }
}
