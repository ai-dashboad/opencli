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
    final prompt = '''You are an intent classifier for a macOS automation assistant. Analyze the user's input and return JSON.

User input: $userInput

Return JSON format:
{"intent": "intent_name", "confidence": 0.0-1.0, "parameters": {params}}

Available intents:

1. **open_url** - Open a website (params: url)
   "open twitter" → {"intent": "open_url", "parameters": {"url": "https://twitter.com"}}
   "send message on twitter" → {"intent": "open_url", "parameters": {"url": "https://twitter.com"}}
   "check my email" → {"intent": "open_url", "parameters": {"url": "https://mail.google.com"}}

2. **open_app** - Open a macOS application (params: app_name)
   "open Chrome" → {"intent": "open_app", "parameters": {"app_name": "Google Chrome"}}
   "launch Terminal" → {"intent": "open_app", "parameters": {"app_name": "Terminal"}}

3. **close_app** - Close/quit an application (params: app_name)
   "close Safari" → {"intent": "close_app", "parameters": {"app_name": "Safari"}}
   "kill Chrome" → {"intent": "close_app", "parameters": {"app_name": "Google Chrome"}}

4. **run_command** - Execute a shell command (params: command, args)
   Simple commands:
   "what's my IP" → {"intent": "run_command", "parameters": {"command": "curl", "args": ["-s", "ifconfig.me"]}}
   "check disk space" → {"intent": "run_command", "parameters": {"command": "df", "args": ["-h"]}}
   "git status" → {"intent": "run_command", "parameters": {"command": "git", "args": ["status"]}}

   Multi-step scripts (use bash -c for chained commands):
   "show largest files" → {"intent": "run_command", "parameters": {"command": "bash", "args": ["-c", "du -ah ~ -d 3 2>/dev/null | sort -rh | head -20"]}}
   "kill process on port 3000" → {"intent": "run_command", "parameters": {"command": "bash", "args": ["-c", "lsof -t -i:3000 | xargs kill -9"]}}
   "compress downloads" → {"intent": "run_command", "parameters": {"command": "bash", "args": ["-c", "cd ~/Downloads && zip -r ~/Desktop/archive.zip ."]}}
   "show open ports" → {"intent": "run_command", "parameters": {"command": "bash", "args": ["-c", "lsof -i -P -n | grep LISTEN"]}}
   "backup documents" → {"intent": "run_command", "parameters": {"command": "bash", "args": ["-c", "rsync -av ~/Documents/ ~/Desktop/backup/"]}}

   macOS automation via AppleScript (use osascript -e):
   "create a note about shopping" → {"intent": "run_command", "parameters": {"command": "osascript", "args": ["-e", "tell application \\"Notes\\" to make new note with properties {name:\\"shopping\\"}"]}}
   "set volume to 50" → {"intent": "run_command", "parameters": {"command": "osascript", "args": ["-e", "set volume output volume 50"]}}
   "empty trash" → {"intent": "run_command", "parameters": {"command": "osascript", "args": ["-e", "tell application \\"Finder\\" to empty the trash"]}}
   "toggle dark mode" → {"intent": "run_command", "parameters": {"command": "osascript", "args": ["-e", "tell application \\"System Events\\" to tell appearance preferences to set dark mode to not dark mode"]}}

5. **web_search** - Search the web (params: query)
6. **screenshot** - Take a screenshot (no params)
7. **system_info** - Get system information (no params)
8. **check_process** - Check if a process is running (params: process_name)
9. **list_processes** - List running processes (no params)
10. **file_operation** - Browse/list/search files (params: operation, directory, pattern)
11. **ai_query** - General questions needing AI (params: query)

RULES:
1. Social media actions → open_url with the platform URL
2. Multi-step operations → run_command with command: "bash", args: ["-c", "cmd1 && cmd2"]
3. macOS app automation → run_command with command: "osascript", args: ["-e", "applescript"]
4. args MUST be a JSON array of strings
5. run_command is the UNIVERSAL FALLBACK
6. NEVER return "unknown"
7. confidence >= 0.7

Return ONLY JSON.
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
