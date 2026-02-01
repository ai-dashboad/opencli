import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Ollama 本地 AI 服务
/// 需要先安装 Ollama: brew install ollama
class OllamaService {
  final String host;
  final int port;
  final String model;

  OllamaService({
    this.host = 'localhost',
    this.port = 11434,
    this.model = 'qwen2.5:latest', // 使用通义千问，中文支持好
  });

  /// 检查 Ollama 是否运行
  Future<bool> isAvailable() async {
    try {
      final response = await http.get(Uri.parse('http://$host:$port/api/tags'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  /// 识别用户意图
  Future<Map<String, dynamic>> recognizeIntent(String userInput) async {
    final prompt = '''
你是一个智能助手，负责识别用户的指令意图。

用户输入：$userInput

请分析用户的意图，并返回 JSON 格式的结果：
{
  "intent": "意图名称",
  "confidence": 0.0-1.0,
  "parameters": {参数}
}

可用的意图类型：
- screenshot: 截屏、截图
- open_app: 打开应用（参数：app_name）
  示例："打开 Chrome" → {"intent": "open_app", "parameters": {"app_name": "Chrome"}}
- close_app: 关闭应用（参数：app_name）
- open_url: 打开网址（参数：url）
- web_search: 网络搜索（参数：query）
- system_info: 获取系统信息
- open_file: 打开文件（参数：path）
- run_command: 运行 shell 命令（参数：command, args）
- check_process: 检查进程是否运行（参数：process_name）
  示例："检查 chrome 是否运行" → {"intent": "check_process", "parameters": {"process_name": "chrome"}}
- list_processes: 列出运行中的进程
- file_operation: 文件操作（参数：operation, directory）
  示例："查看桌面的文件" → {"intent": "file_operation", "parameters": {"operation": "list", "directory": "~/Desktop"}}
  示例："搜索文档文件夹的PDF" → {"intent": "file_operation", "parameters": {"operation": "search", "directory": "~/Documents", "pattern": "pdf"}}
- ai_query: AI 问答（参数：query）

重要识别规则：
1. 检查进程/程序是否运行 → check_process（不是 system_info）
2. 列出运行中的程序 → list_processes（不是 file_operation）
3. 查看/列出/浏览文件 → file_operation（不是 list_processes）
4. 搜索文件 → file_operation（operation: search）
5. 需要执行 shell 命令 → run_command
6. 获取系统信息（版本、CPU等）→ system_info

只返回 JSON，不要其他内容。
''';

    try {
      final response = await http.post(
        Uri.parse('http://$host:$port/api/generate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': model,
          'prompt': prompt,
          'stream': false,
          'format': 'json', // 要求返回 JSON
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final responseText = data['response'] as String;

        // 解析 AI 返回的 JSON
        try {
          final result = jsonDecode(responseText);
          return {
            'success': true,
            'intent': result['intent'] ?? 'unknown',
            'confidence': result['confidence'] ?? 0.5,
            'parameters': result['parameters'] ?? {},
          };
        } catch (e) {
          // JSON 解析失败，返回失败
          return {
            'success': false,
            'error': '无法解析 AI 响应',
            'raw_response': responseText,
          };
        }
      }

      return {
        'success': false,
        'error': 'Ollama 请求失败: ${response.statusCode}',
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Ollama 连接失败: $e',
      };
    }
  }

  /// 通用 AI 查询
  Future<String> query(String prompt) async {
    try {
      final response = await http.post(
        Uri.parse('http://$host:$port/api/generate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': model,
          'prompt': prompt,
          'stream': false,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['response'] as String;
      }

      return 'Ollama 请求失败: ${response.statusCode}';
    } catch (e) {
      return 'Ollama 连接失败: $e';
    }
  }
}
