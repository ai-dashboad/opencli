import 'package:flutter/material.dart';

/// 文件列表 Widget
/// 友好地展示文件信息，包括图标、名称、大小、时间
class FileListWidget extends StatelessWidget {
  final List<dynamic> files;
  final String directory;

  const FileListWidget({
    Key? key,
    required this.files,
    required this.directory,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 目录路径
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              const Icon(Icons.folder_open, size: 20, color: Colors.blue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  directory,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),

        // 文件列表
        ...files.map((file) => _buildFileItem(file)).toList(),

        // 统计信息
        if (files.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text(
              '共 ${files.length} 项',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildFileItem(Map<String, dynamic> file) {
    final name = file['name'] as String;
    final icon = file['icon'] as String? ?? '📄';
    final sizeFormatted = file['size_formatted'] as String? ?? '-';
    final modifiedRelative = file['modified_relative'] as String? ?? '';
    final isDirectory = file['is_directory'] as bool? ?? false;
    final fileType = file['type'] as String? ?? 'file';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: ListTile(
        dense: true,
        leading: _buildFileIcon(icon, fileType, isDirectory),
        title: Text(
          name,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '$sizeFormatted · $modifiedRelative',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        trailing: isDirectory
            ? const Icon(Icons.chevron_right, size: 20, color: Colors.grey)
            : null,
      ),
    );
  }

  Widget _buildFileIcon(String emoji, String fileType, bool isDirectory) {
    // 根据文件类型返回不同颜色的背景
    Color backgroundColor;
    if (isDirectory) {
      backgroundColor = Colors.blue[50]!;
    } else {
      switch (fileType) {
        case 'image':
          backgroundColor = Colors.green[50]!;
          break;
        case 'video':
          backgroundColor = Colors.purple[50]!;
          break;
        case 'audio':
          backgroundColor = Colors.orange[50]!;
          break;
        case 'document':
          backgroundColor = Colors.red[50]!;
          break;
        case 'code':
          backgroundColor = Colors.indigo[50]!;
          break;
        case 'archive':
          backgroundColor = Colors.amber[50]!;
          break;
        default:
          backgroundColor = Colors.grey[50]!;
      }
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          emoji,
          style: const TextStyle(fontSize: 20),
        ),
      ),
    );
  }
}
