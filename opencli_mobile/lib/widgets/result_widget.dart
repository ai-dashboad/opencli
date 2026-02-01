import 'package:flutter/material.dart';
import 'file_list_widget.dart';

/// 通用结果展示组件
/// 根据任务类型智能选择展示方式
class ResultWidget extends StatelessWidget {
  final String taskType;
  final Map<String, dynamic> result;

  const ResultWidget({
    Key? key,
    required this.taskType,
    required this.result,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 根据任务类型选择展示方式
    switch (taskType) {
      case 'file_operation':
        return _buildFileOperationResult();

      case 'system_info':
        return _buildSystemInfoResult();

      case 'check_process':
        return _buildProcessCheckResult();

      case 'list_processes':
        return _buildProcessListResult();

      case 'screenshot':
        return _buildScreenshotResult();

      default:
        return _buildDefaultResult();
    }
  }

  /// 文件操作结果
  Widget _buildFileOperationResult() {
    if (result['success'] == true && result['files'] != null) {
      final files = result['files'] as List<dynamic>;
      final directory = result['directory'] as String? ?? '';

      return FileListWidget(
        files: files,
        directory: directory,
      );
    } else {
      return _buildErrorResult(result['error'] as String? ?? '操作失败');
    }
  }

  /// 系统信息结果
  Widget _buildSystemInfoResult() {
    if (result['success'] == true) {
      return Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue[50]!, Colors.blue[100]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.blue[200]!, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.computer, color: Colors.blue[700]),
                const SizedBox(width: 8),
                Text(
                  '系统信息',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[900],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow('平台', result['platform'] ?? '-', Icons.desktop_mac),
            _buildInfoRow('版本', result['version'] ?? '-', Icons.info_outline),
            _buildInfoRow('主机名', result['hostname'] ?? '-', Icons.dns),
            _buildInfoRow('处理器', '${result['processors'] ?? '-'} 核', Icons.memory),
          ],
        ),
      );
    }
    return _buildDefaultResult();
  }

  /// 进程检查结果
  Widget _buildProcessCheckResult() {
    if (result['success'] == true) {
      final isRunning = result['is_running'] as bool? ?? false;
      final processName = result['process_name'] as String? ?? '';

      return Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isRunning ? Colors.green[50] : Colors.red[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isRunning ? Colors.green[200]! : Colors.red[200]!,
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isRunning ? Icons.check_circle : Icons.cancel,
              color: isRunning ? Colors.green[700] : Colors.red[700],
              size: 32,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    processName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: isRunning ? Colors.green[900] : Colors.red[900],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isRunning ? '✓ 正在运行' : '✗ 未运行',
                    style: TextStyle(
                      fontSize: 14,
                      color: isRunning ? Colors.green[700] : Colors.red[700],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return _buildDefaultResult();
  }

  /// 进程列表结果
  Widget _buildProcessListResult() {
    if (result['success'] == true && result['processes'] != null) {
      final processes = result['processes'] as List<dynamic>;

      return Container(
        margin: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.list_alt, size: 20, color: Colors.blue),
                  const SizedBox(width: 8),
                  Text(
                    '运行中的进程 (${processes.length})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            ...processes.take(10).map((process) {
              final processStr = process.toString();
              return Container(
                margin: const EdgeInsets.only(bottom: 4),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  processStr,
                  style: const TextStyle(
                    fontSize: 11,
                    fontFamily: 'monospace',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            if (processes.length > 10)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '... 还有 ${processes.length - 10} 个进程',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
              ),
          ],
        ),
      );
    }
    return _buildDefaultResult();
  }

  /// 截图结果
  Widget _buildScreenshotResult() {
    if (result['success'] == true && result['path'] != null) {
      return Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.green[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.green[200]!, width: 1),
        ),
        child: Row(
          children: [
            Icon(Icons.screenshot, color: Colors.green[700], size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '✓ 截图成功',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.green[900],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    result['path'] as String,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.green[700],
                      fontFamily: 'monospace',
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }
    return _buildDefaultResult();
  }

  /// 默认结果展示（JSON 格式）
  Widget _buildDefaultResult() {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.data_object, size: 16, color: Colors.grey),
              SizedBox(width: 6),
              Text(
                '结果：',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...result.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: RichText(
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: '${entry.key}: ',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                        fontSize: 13,
                      ),
                    ),
                    TextSpan(
                      text: '${entry.value}',
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  /// 错误结果
  Widget _buildErrorResult(String error) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red[200]!, width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red[700], size: 32),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error,
              style: TextStyle(
                fontSize: 14,
                color: Colors.red[900],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 构建信息行
  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.blue[600]),
          const SizedBox(width: 8),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.blue[800],
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
