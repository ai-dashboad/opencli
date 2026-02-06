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

      case 'run_command':
        return _buildRunCommandResult();

      case 'open_url':
        return _buildOpenUrlResult();

      case 'open_app':
      case 'close_app':
        return _buildAppActionResult();

      case 'web_search':
        return _buildWebSearchResult();

      case 'ai_query':
        return _buildAIQueryResult();

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

  /// Shell 命令結果 — 终端风格（支持 bash -c, osascript, blocked）
  Widget _buildRunCommandResult() {
    final success = result['success'] == true;
    final blocked = result['blocked'] == true;
    final timedOut = result['timed_out'] == true;
    final rawCommand = result['command'] as String? ?? '';
    final stdout = result['stdout'] as String? ?? result['output'] as String? ?? '';
    final stderr = result['stderr'] as String? ?? '';
    final error = result['error'] as String? ?? '';
    final exitCode = result['exit_code'] as int? ?? result['exitCode'] as int?;

    // Smart display: strip "bash -c " prefix, show script content
    String displayCommand = rawCommand;
    IconData commandIcon = Icons.terminal;
    String commandLabel = 'Terminal';

    if (rawCommand.startsWith('bash -c ')) {
      displayCommand = rawCommand.substring(8);
      commandIcon = Icons.code;
      commandLabel = 'Script';
    } else if (rawCommand.startsWith('osascript ')) {
      displayCommand = rawCommand.substring(10);
      commandIcon = Icons.auto_fix_high;
      commandLabel = 'AppleScript';
    }

    // Blocked command — amber warning card
    if (blocked) {
      return Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.amber[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.amber[300]!, width: 1),
        ),
        child: Row(
          children: [
            Icon(Icons.shield, color: Colors.amber[800], size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Command Blocked', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.amber[900])),
                  const SizedBox(height: 4),
                  Text(error.isNotEmpty ? error : 'Dangerous command pattern detected', style: TextStyle(fontSize: 13, color: Colors.amber[800])),
                  if (rawCommand.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(rawCommand, style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.amber[700]), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    // Timed out — red timeout card
    if (timedOut) {
      return Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.red[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red[300]!, width: 1),
        ),
        child: Row(
          children: [
            Icon(Icons.timer_off, color: Colors.red[700], size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Command Timed Out', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.red[900])),
                  const SizedBox(height: 4),
                  Text('The command took longer than 120 seconds', style: TextStyle(fontSize: 13, color: Colors.red[700])),
                  if (rawCommand.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(displayCommand, style: TextStyle(fontSize: 11, fontFamily: 'monospace', color: Colors.red[600]), maxLines: 2, overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF333333), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title bar with command type label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF2D2D2D),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Icon(commandIcon, size: 16, color: success ? Colors.green[400] : Colors.red[400]),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: const Color(0xFF444444),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(commandLabel, style: const TextStyle(fontSize: 10, color: Color(0xFFAAAAAA), fontFamily: 'monospace')),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    displayCommand.isNotEmpty ? displayCommand : 'Command',
                    style: const TextStyle(
                      fontSize: 13,
                      fontFamily: 'monospace',
                      color: Color(0xFFCCCCCC),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (exitCode != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: exitCode == 0 ? Colors.green.withValues(alpha: 0.2) : Colors.red.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'exit $exitCode',
                      style: TextStyle(
                        fontSize: 10,
                        fontFamily: 'monospace',
                        color: exitCode == 0 ? Colors.green[400] : Colors.red[400],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          // Output content
          if (stdout.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                stdout.length > 2000 ? '${stdout.substring(0, 2000)}\n... (truncated)' : stdout,
                style: const TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: Color(0xFFD4D4D4),
                  height: 1.4,
                ),
              ),
            ),
          if (stderr.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                stderr,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: Colors.red[300],
                  height: 1.4,
                ),
              ),
            ),
          if (error.isNotEmpty && !blocked && !timedOut)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Text(
                error,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: Colors.red[300],
                  height: 1.4,
                ),
              ),
            ),
          if (stdout.isEmpty && stderr.isEmpty && error.isEmpty)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text(
                '(no output)',
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: Color(0xFF888888),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 打开 URL 结果
  Widget _buildOpenUrlResult() {
    final success = result['success'] == true;
    final url = result['url'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: success ? Colors.blue[50] : Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: success ? Colors.blue[200]! : Colors.red[200]!, width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.open_in_browser, color: success ? Colors.blue[700] : Colors.red[700], size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  success ? 'Opened in browser' : 'Failed to open',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: success ? Colors.blue[900] : Colors.red[900]),
                ),
                if (url.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(url, style: TextStyle(fontSize: 12, color: Colors.blue[600], fontFamily: 'monospace'), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 应用操作结果 (open/close)
  Widget _buildAppActionResult() {
    final success = result['success'] == true;
    final appName = result['app_name'] as String? ?? result['name'] as String? ?? '';
    final isOpen = taskType == 'open_app';

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: success ? Colors.green[50] : Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: success ? Colors.green[200]! : Colors.red[200]!, width: 1),
      ),
      child: Row(
        children: [
          Icon(
            isOpen ? Icons.launch : Icons.close,
            color: success ? Colors.green[700] : Colors.red[700],
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              success
                  ? (isOpen ? 'Opened $appName' : 'Closed $appName')
                  : 'Failed: ${result['error'] ?? 'unknown error'}',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: success ? Colors.green[900] : Colors.red[900],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// 网络搜索结果
  Widget _buildWebSearchResult() {
    final success = result['success'] == true;
    final query = result['query'] as String? ?? '';
    final url = result['url'] as String? ?? '';

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange[200]!, width: 1),
      ),
      child: Row(
        children: [
          Icon(Icons.search, color: Colors.orange[700], size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  success ? 'Searching: $query' : 'Search failed',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.orange[900]),
                ),
                if (url.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(url, style: TextStyle(fontSize: 11, color: Colors.orange[600], fontFamily: 'monospace'), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// AI 问答结果
  Widget _buildAIQueryResult() {
    final response = result['response'] as String? ?? result['answer'] as String? ?? result['result'] as String? ?? '';

    if (response.isNotEmpty) {
      return Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.purple[50],
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.purple[200]!, width: 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.purple[700], size: 20),
                const SizedBox(width: 8),
                Text('AI Response', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.purple[900])),
              ],
            ),
            const SizedBox(height: 12),
            Text(response, style: const TextStyle(fontSize: 14, color: Colors.black87, height: 1.5)),
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
