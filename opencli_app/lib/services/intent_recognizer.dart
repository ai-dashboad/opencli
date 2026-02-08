import 'dart:core';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'daemon_service.dart';

/// Domain intent pattern — injected from daemon's DomainRegistry via config
class DomainIntentPatternLocal {
  final RegExp pattern;
  final String taskType;
  final Map<String, dynamic> Function(RegExpMatch match) extractData;
  final double confidence;

  const DomainIntentPatternLocal({
    required this.pattern,
    required this.taskType,
    required this.extractData,
    this.confidence = 1.0,
  });
}

/// AI 驱动的意图识别引擎
/// 使用 Ollama LLM 理解自然语言，无需硬编码模式
class IntentRecognizer {
  final DaemonService daemonService;

  /// Domain patterns injected from the daemon's DomainRegistry.
  /// Checked FIRST in _tryQuickPath() before hardcoded patterns.
  final List<DomainIntentPatternLocal> _domainPatterns = [];

  /// Set of all domain task types (for _mapIntentToTaskType)
  final Set<String> _domainTaskTypes = {};

  IntentRecognizer(this.daemonService);

  /// Register domain patterns (called after connecting to daemon)
  void registerDomainPatterns(List<DomainIntentPatternLocal> patterns) {
    _domainPatterns.clear();
    _domainPatterns.addAll(patterns);
    _domainTaskTypes.clear();
    for (final p in patterns) {
      _domainTaskTypes.add(p.taskType);
    }
    print('[IntentRecognizer] Registered ${patterns.length} domain patterns');
  }

  /// 识别用户输入的意图（AI 驱动）
  Future<IntentResult> recognize(String input) async {
    final trimmed = input.trim();

    if (trimmed.isEmpty) {
      return IntentResult(
        intent: 'unknown',
        confidence: 0.0,
        taskType: null,
        taskData: {},
      );
    }

    // 可选：超高频命令的快速路径（跳过 AI 调用以提速）
    // 这些是最常用且格式固定的命令，占比约 20%
    final quickResult = _tryQuickPath(trimmed);
    if (quickResult != null) {
      return quickResult;
    }

    // 主流程：使用 AI 识别所有其他命令
    final aiResult = await _recognizeWithAI(trimmed);

    // 最终 fallback：如果 AI 也无法识别，当作 AI 问答处理
    if (!aiResult.isRecognized || aiResult.taskType == null) {
      return IntentResult(
        intent: 'ai_query',
        confidence: 0.5,
        taskType: 'ai_query',
        taskData: {'query': trimmed},
        isAIFallback: true,
      );
    }

    return aiResult;
  }

  /// 快速路径：高频命令直接返回，无需 AI 调用
  IntentResult? _tryQuickPath(String input) {
    final lower = input.toLowerCase().trim();

    // === Domain patterns (calendar, music, timer, weather, etc.) ===
    // Checked FIRST — these come from the daemon's DomainRegistry
    for (final dp in _domainPatterns) {
      final match = dp.pattern.firstMatch(input.trim());
      if (match != null) {
        return IntentResult(
          intent: dp.taskType,
          confidence: dp.confidence,
          taskType: dp.taskType,
          taskData: dp.extractData(match),
        );
      }
    }

    // === 截图 ===
    if (lower == '截图' || lower == '截屏' || lower == 'screenshot' || lower == 'take screenshot') {
      return IntentResult(intent: 'screenshot', confidence: 1.0, taskType: 'screenshot', taskData: {});
    }

    // === 系统信息 ===
    if (lower == '系统信息' || lower == 'system info' || lower == 'sysinfo') {
      return IntentResult(intent: 'system_info', confidence: 1.0, taskType: 'system_info', taskData: {});
    }

    // === 打开网站 (open <website>) ===
    final websites = <String, String>{
      'youtube': 'https://www.youtube.com',
      'twitter': 'https://twitter.com',
      'x': 'https://x.com',
      'github': 'https://github.com',
      'gmail': 'https://mail.google.com',
      'google': 'https://www.google.com',
      'facebook': 'https://www.facebook.com',
      'instagram': 'https://www.instagram.com',
      'reddit': 'https://www.reddit.com',
      'linkedin': 'https://www.linkedin.com',
      'whatsapp': 'https://web.whatsapp.com',
      'slack': 'https://app.slack.com',
      'notion': 'https://www.notion.so',
      'chatgpt': 'https://chat.openai.com',
      'claude': 'https://claude.ai',
      'stackoverflow': 'https://stackoverflow.com',
      'amazon': 'https://www.amazon.com',
      'netflix': 'https://www.netflix.com',
      'spotify': 'https://open.spotify.com',
    };

    // Pattern: "open youtube", "打开 youtube", "go to youtube"
    final openWebMatch = RegExp(r'^(?:open|打开|go to|visit|launch)\s+(.+)$', caseSensitive: false).firstMatch(lower);
    if (openWebMatch != null) {
      final target = openWebMatch.group(1)!.trim();

      // Check if it's a known website
      if (websites.containsKey(target)) {
        return IntentResult(intent: 'open_url', confidence: 1.0, taskType: 'open_url', taskData: {'url': websites[target]!});
      }

      // Check if it looks like a URL (contains dot)
      if (target.contains('.')) {
        final url = target.startsWith('http') ? target : 'https://$target';
        return IntentResult(intent: 'open_url', confidence: 1.0, taskType: 'open_url', taskData: {'url': url});
      }

      // Check if it's a known app name
      final knownApps = {'safari', 'chrome', 'firefox', 'terminal', 'iterm', 'vscode', 'code',
        'finder', 'notes', 'calendar', 'maps', 'music', 'photos', 'messages', 'mail',
        'wechat', 'telegram', 'discord', 'zoom', 'teams', 'word', 'excel', 'powerpoint',
        'xcode', 'simulator', 'activity monitor', 'system preferences', 'settings'};
      if (knownApps.contains(target)) {
        return IntentResult(intent: 'open_app', confidence: 1.0, taskType: 'open_app', taskData: {'app_name': target});
      }

      // Default: try as app name
      return IntentResult(intent: 'open_app', confidence: 0.8, taskType: 'open_app', taskData: {'app_name': target});
    }

    // === 系统命令快速路径 ===
    final systemCommands = <String, Map<String, dynamic>>{
      'ip address': {'command': 'curl -s ifconfig.me', 'args': []},
      'my ip': {'command': 'curl -s ifconfig.me', 'args': []},
      'wifi status': {'command': 'networksetup', 'args': ['-getairportnetwork', 'en0']},
      'battery': {'command': 'pmset', 'args': ['-g', 'batt']},
      'disk space': {'command': 'df', 'args': ['-h']},
      'disk usage': {'command': 'df', 'args': ['-h']},
      'uptime': {'command': 'uptime', 'args': []},
      'whoami': {'command': 'whoami', 'args': []},
      'date': {'command': 'date', 'args': []},
      'hostname': {'command': 'hostname', 'args': []},
      'pwd': {'command': 'pwd', 'args': []},
      'top processes': {'command': 'ps', 'args': ['aux', '--sort=-%mem']},
    };

    if (systemCommands.containsKey(lower)) {
      final cmd = systemCommands[lower]!;
      return IntentResult(intent: 'run_command', confidence: 1.0, taskType: 'run_command', taskData: cmd);
    }

    // === 搜索 ===
    final searchMatch = RegExp(r'^(?:search|搜索|google|查一下|look up)\s+(.+)$', caseSensitive: false).firstMatch(lower);
    if (searchMatch != null) {
      return IntentResult(intent: 'web_search', confidence: 1.0, taskType: 'web_search', taskData: {'query': searchMatch.group(1)!.trim()});
    }

    // === 关闭/杀死应用 ===
    final killMatch = RegExp(r'^(?:close|kill|quit|关闭|退出|杀死)\s+(.+)$', caseSensitive: false).firstMatch(lower);
    if (killMatch != null) {
      return IntentResult(intent: 'close_app', confidence: 1.0, taskType: 'close_app', taskData: {'app_name': killMatch.group(1)!.trim()});
    }

    // === 直接 shell 命令 (git, npm, ls, etc.) ===
    final shellPrefixes = ['git ', 'npm ', 'yarn ', 'brew ', 'pip ', 'python ', 'node ', 'ls ', 'cat ', 'echo ', 'mkdir ', 'rm ', 'cp ', 'mv ', 'curl ', 'wget ', 'docker ', 'flutter ', 'dart '];
    for (final prefix in shellPrefixes) {
      if (lower.startsWith(prefix)) {
        final parts = input.trim().split(' ');
        return IntentResult(
          intent: 'run_command',
          confidence: 1.0,
          taskType: 'run_command',
          taskData: {'command': parts[0], 'args': parts.sublist(1)},
        );
      }
    }

    // === 列出进程 ===
    if (lower == 'list processes' || lower == '列出进程' || lower == 'ps') {
      return IntentResult(intent: 'list_processes', confidence: 1.0, taskType: 'list_processes', taskData: {});
    }

    // === 查看文件夹 ===
    final folderMatch = RegExp(r'^(?:show|list|查看|打开)\s+(?:my\s+)?(?:desktop|downloads|documents|桌面|下载|文档)$', caseSensitive: false).firstMatch(lower);
    if (folderMatch != null) {
      String dir;
      if (lower.contains('desktop') || lower.contains('桌面')) {
        dir = '~/Desktop';
      } else if (lower.contains('download') || lower.contains('下载')) {
        dir = '~/Downloads';
      } else {
        dir = '~/Documents';
      }
      return IntentResult(intent: 'file_operation', confidence: 1.0, taskType: 'file_operation', taskData: {'operation': 'list', 'directory': dir});
    }

    // ============================================================
    // === COMPLEX DAILY TASKS (bash -c, osascript) ===
    // ============================================================

    // --- macOS App Automation via AppleScript ---

    // "send email to X about Y" / "email X about Y"
    final emailMatch = RegExp(r'^(?:send\s+)?(?:email|mail)\s+(?:to\s+)?(\S+@\S+)\s+(?:about|subject|re)\s+(.+)$', caseSensitive: false).firstMatch(input.trim());
    if (emailMatch != null) {
      final to = emailMatch.group(1)!;
      final subject = emailMatch.group(2)!;
      return IntentResult(intent: 'run_command', confidence: 1.0, taskType: 'run_command', taskData: {
        'command': 'osascript',
        'args': ['-e', 'tell application "Mail"\nset newMsg to make new outgoing message with properties {subject:"$subject", visible:true}\ntell newMsg\nmake new to recipient at end of to recipients with properties {address:"$to"}\nend tell\nactivate\nend tell'],
      });
    }

    // "create note about X" / "new note X"
    final noteMatch = RegExp(r'^(?:create|new|add|make)\s+(?:a\s+)?note\s+(?:about\s+|titled?\s+)?(.+)$', caseSensitive: false).firstMatch(input.trim());
    if (noteMatch != null) {
      final content = noteMatch.group(1)!;
      return IntentResult(intent: 'run_command', confidence: 1.0, taskType: 'run_command', taskData: {
        'command': 'osascript',
        'args': ['-e', 'tell application "Notes"\nactivate\nmake new note at folder "Notes" with properties {name:"$content", body:"$content"}\nend tell'],
      });
    }

    // "add reminder X" / "remind me to X"
    final reminderMatch = RegExp(r'^(?:add\s+(?:a\s+)?reminder|remind\s+me)\s+(?:to\s+)?(.+)$', caseSensitive: false).firstMatch(input.trim());
    if (reminderMatch != null) {
      final task = reminderMatch.group(1)!;
      return IntentResult(intent: 'run_command', confidence: 1.0, taskType: 'run_command', taskData: {
        'command': 'osascript',
        'args': ['-e', 'tell application "Reminders"\nset mylist to list "Reminders"\ntell mylist\nmake new reminder with properties {name:"$task"}\nend tell\nactivate\nend tell'],
      });
    }

    // "set volume to X" / "volume X%"
    final volumeMatch = RegExp(r'^(?:set\s+)?volume\s+(?:to\s+)?(\d+)%?$', caseSensitive: false).firstMatch(lower);
    if (volumeMatch != null) {
      final level = volumeMatch.group(1)!;
      return IntentResult(intent: 'run_command', confidence: 1.0, taskType: 'run_command', taskData: {
        'command': 'osascript',
        'args': ['-e', 'set volume output volume $level'],
      });
    }

    // "mute" / "unmute"
    if (lower == 'mute' || lower == 'mute volume') {
      return IntentResult(intent: 'run_command', confidence: 1.0, taskType: 'run_command', taskData: {
        'command': 'osascript',
        'args': ['-e', 'set volume output muted true'],
      });
    }
    if (lower == 'unmute' || lower == 'unmute volume') {
      return IntentResult(intent: 'run_command', confidence: 1.0, taskType: 'run_command', taskData: {
        'command': 'osascript',
        'args': ['-e', 'set volume output muted false'],
      });
    }

    // "empty trash"
    if (lower == 'empty trash' || lower == '清空垃圾桶') {
      return IntentResult(intent: 'run_command', confidence: 1.0, taskType: 'run_command', taskData: {
        'command': 'osascript',
        'args': ['-e', 'tell application "Finder" to empty the trash'],
      });
    }

    // "toggle dark mode" / "dark mode" / "light mode"
    if (lower == 'dark mode' || lower == 'toggle dark mode' || lower == 'switch to dark mode') {
      return IntentResult(intent: 'run_command', confidence: 1.0, taskType: 'run_command', taskData: {
        'command': 'osascript',
        'args': ['-e', 'tell application "System Events" to tell appearance preferences to set dark mode to not dark mode'],
      });
    }

    // "do not disturb" / "focus mode"
    if (lower == 'do not disturb' || lower == 'dnd' || lower == 'focus mode') {
      return IntentResult(intent: 'run_command', confidence: 1.0, taskType: 'run_command', taskData: {
        'command': 'shortcuts',
        'args': ['run', 'Toggle Focus'],
      });
    }

    // "lock screen"
    if (lower == 'lock screen' || lower == 'lock' || lower == '锁屏') {
      return IntentResult(intent: 'run_command', confidence: 1.0, taskType: 'run_command', taskData: {
        'command': 'osascript',
        'args': ['-e', 'tell application "System Events" to keystroke "q" using {command down, control down}'],
      });
    }

    // "sleep" / "put to sleep"
    if (lower == 'sleep' || lower == 'put to sleep' || lower == '睡眠') {
      return IntentResult(intent: 'run_command', confidence: 1.0, taskType: 'run_command', taskData: {
        'command': 'pmset',
        'args': ['sleepnow'],
      });
    }

    // --- Multi-step scripts via bash -c ---

    // "compress/zip X in Y" / "zip downloads"
    final compressMatch = RegExp(r'^(?:compress|zip)\s+(?:all\s+)?(?:files?\s+)?(?:in\s+)?(.+)$', caseSensitive: false).firstMatch(input.trim());
    if (compressMatch != null) {
      final target = compressMatch.group(1)!;
      final dir = _resolveDirectory(target);
      return IntentResult(intent: 'run_command', confidence: 0.95, taskType: 'run_command', taskData: {
        'command': 'bash',
        'args': ['-c', 'cd $dir && zip -r ~/Desktop/archive_\$(date +%Y%m%d_%H%M%S).zip . && echo "Compressed to ~/Desktop/archive_*.zip"'],
      });
    }

    // "kill process on port X" / "free port X"
    final portKillMatch = RegExp(r'^(?:kill|free|stop)\s+(?:process\s+)?(?:on\s+)?port\s+(\d+)$', caseSensitive: false).firstMatch(lower);
    if (portKillMatch != null) {
      final port = portKillMatch.group(1)!;
      return IntentResult(intent: 'run_command', confidence: 1.0, taskType: 'run_command', taskData: {
        'command': 'bash',
        'args': ['-c', 'PID=\$(lsof -t -i:$port 2>/dev/null); if [ -n "\$PID" ]; then kill -9 \$PID && echo "Killed process \$PID on port $port"; else echo "No process found on port $port"; fi'],
      });
    }

    // "show largest files" / "biggest files"
    final largestFilesMatch = RegExp(r'^(?:show|find|list)\s+(?:the\s+)?(?:largest|biggest|top)\s+(?:\d+\s+)?files?', caseSensitive: false).firstMatch(lower);
    if (largestFilesMatch != null) {
      return IntentResult(intent: 'run_command', confidence: 1.0, taskType: 'run_command', taskData: {
        'command': 'bash',
        'args': ['-c', 'du -sh ~/Desktop ~/Downloads ~/Documents ~/Pictures ~/Music ~/Movies 2>/dev/null | sort -rh'],
      });
    }

    // "commit all with message X" / "git commit all X"
    final commitMatch = RegExp(r'^(?:commit\s+all|git\s+commit\s+all)\s+(?:with\s+message\s+|message\s+)?(.+)$', caseSensitive: false).firstMatch(input.trim());
    if (commitMatch != null) {
      final message = commitMatch.group(1)!;
      return IntentResult(intent: 'run_command', confidence: 1.0, taskType: 'run_command', taskData: {
        'command': 'bash',
        'args': ['-c', 'git add -A && git commit -m "$message"'],
      });
    }

    // "backup X to Y" / "backup downloads"
    final backupMatch = RegExp(r'^backup\s+(.+?)(?:\s+to\s+(.+))?$', caseSensitive: false).firstMatch(input.trim());
    if (backupMatch != null) {
      final source = _resolveDirectory(backupMatch.group(1)!);
      final dest = backupMatch.group(2) != null ? _resolveDirectory(backupMatch.group(2)!) : '~/Desktop/backup_\$(date +%Y%m%d)';
      return IntentResult(intent: 'run_command', confidence: 0.9, taskType: 'run_command', taskData: {
        'command': 'bash',
        'args': ['-c', 'rsync -av --progress $source/ $dest/ && echo "Backup complete"'],
      });
    }

    // "flush dns"
    if (lower == 'flush dns' || lower == 'clear dns' || lower == 'reset dns') {
      return IntentResult(intent: 'run_command', confidence: 1.0, taskType: 'run_command', taskData: {
        'command': 'bash',
        'args': ['-c', 'sudo dscacheutil -flushcache && sudo killall -HUP mDNSResponder && echo "DNS cache flushed"'],
      });
    }

    // "show listening ports" / "show open ports"
    if (lower == 'show listening ports' || lower == 'show open ports' || lower == 'listening ports') {
      return IntentResult(intent: 'run_command', confidence: 1.0, taskType: 'run_command', taskData: {
        'command': 'bash',
        'args': ['-c', 'lsof -i -P -n | grep LISTEN | awk \'{print \$1, \$2, \$9}\' | sort -u'],
      });
    }

    // "check if X is up" / "is X up" / "ping X"
    final checkUpMatch = RegExp(r'^(?:check\s+if|is)\s+(\S+)\s+(?:up|running|alive|reachable)$', caseSensitive: false).firstMatch(lower);
    if (checkUpMatch != null) {
      final host = checkUpMatch.group(1)!;
      final url = host.contains('.') ? (host.startsWith('http') ? host : 'https://$host') : 'https://$host.com';
      return IntentResult(intent: 'run_command', confidence: 1.0, taskType: 'run_command', taskData: {
        'command': 'bash',
        'args': ['-c', 'STATUS=\$(curl -sI -o /dev/null -w "%{http_code}" --max-time 10 "$url"); if [ "\$STATUS" -ge 200 ] && [ "\$STATUS" -lt 400 ]; then echo "$url is UP (HTTP \$STATUS)"; else echo "$url is DOWN (HTTP \$STATUS)"; fi'],
      });
    }

    // "monitor cpu" / "cpu usage"
    if (lower == 'monitor cpu' || lower == 'cpu usage' || lower == 'cpu') {
      return IntentResult(intent: 'run_command', confidence: 1.0, taskType: 'run_command', taskData: {
        'command': 'bash',
        'args': ['-c', 'top -l 1 -n 10 | head -25'],
      });
    }

    // "memory usage" / "ram usage"
    if (lower == 'memory usage' || lower == 'ram usage' || lower == 'ram' || lower == 'memory') {
      return IntentResult(intent: 'run_command', confidence: 1.0, taskType: 'run_command', taskData: {
        'command': 'bash',
        'args': ['-c', 'vm_stat | head -15 && echo "---" && sysctl hw.memsize | awk \'{print "Total RAM: " \$2/1073741824 " GB"}\''],
      });
    }

    // "clean up docker" / "docker cleanup"
    if (lower.contains('docker') && (lower.contains('clean') || lower.contains('prune'))) {
      return IntentResult(intent: 'run_command', confidence: 1.0, taskType: 'run_command', taskData: {
        'command': 'bash',
        'args': ['-c', 'docker system prune -af --volumes 2>/dev/null && echo "Docker cleanup complete" || echo "Docker not running"'],
      });
    }

    // "create flutter project X"
    final flutterCreateMatch = RegExp(r'^create\s+flutter\s+(?:project\s+)?(\w+)$', caseSensitive: false).firstMatch(lower);
    if (flutterCreateMatch != null) {
      final name = flutterCreateMatch.group(1)!;
      return IntentResult(intent: 'run_command', confidence: 1.0, taskType: 'run_command', taskData: {
        'command': 'bash',
        'args': ['-c', 'cd ~/Desktop && flutter create $name && echo "Created Flutter project: ~/Desktop/$name"'],
      });
    }

    // "run tests" / "flutter test"
    if (lower == 'run tests' || lower == 'flutter test' || lower == 'run test') {
      return IntentResult(intent: 'run_command', confidence: 1.0, taskType: 'run_command', taskData: {
        'command': 'bash',
        'args': ['-c', 'flutter test 2>&1 | tail -50'],
      });
    }

    // "build apk" / "build release"
    if (lower == 'build apk' || lower == 'build release apk' || lower == 'build release') {
      return IntentResult(intent: 'run_command', confidence: 1.0, taskType: 'run_command', taskData: {
        'command': 'bash',
        'args': ['-c', 'flutter build apk --release 2>&1 | tail -30'],
      });
    }

    // "count lines of code" / "loc" / "cloc"
    if (lower == 'count lines of code' || lower == 'loc' || lower == 'lines of code') {
      return IntentResult(intent: 'run_command', confidence: 1.0, taskType: 'run_command', taskData: {
        'command': 'bash',
        'args': ['-c', 'find . -name "*.dart" -o -name "*.js" -o -name "*.ts" -o -name "*.py" -o -name "*.swift" | xargs wc -l 2>/dev/null | sort -rn | head -20'],
      });
    }

    // "show git log" / "recent commits"
    if (lower == 'git log' || lower == 'show git log' || lower == 'recent commits' || lower == 'show commits') {
      return IntentResult(intent: 'run_command', confidence: 1.0, taskType: 'run_command', taskData: {
        'command': 'bash',
        'args': ['-c', 'git log --oneline --graph --decorate -20 2>/dev/null || echo "Not a git repository"'],
      });
    }

    // "show git diff" / "what changed"
    if (lower == 'git diff' || lower == 'show changes' || lower == 'what changed') {
      return IntentResult(intent: 'run_command', confidence: 1.0, taskType: 'run_command', taskData: {
        'command': 'bash',
        'args': ['-c', 'git diff --stat 2>/dev/null && echo "---" && git diff --shortstat 2>/dev/null || echo "Not a git repository"'],
      });
    }

    // "find duplicate files" / "duplicates in X"
    final dupeMatch = RegExp(r'^find\s+duplicate(?:s|\s+files?)(?:\s+in\s+(.+))?$', caseSensitive: false).firstMatch(lower);
    if (dupeMatch != null) {
      final dir = dupeMatch.group(1) != null ? _resolveDirectory(dupeMatch.group(1)!) : '~/Downloads';
      return IntentResult(intent: 'run_command', confidence: 0.9, taskType: 'run_command', taskData: {
        'command': 'bash',
        'args': ['-c', 'find $dir -type f -exec md5 -r {} \\; 2>/dev/null | sort | uniq -d -w 32 | head -20'],
      });
    }

    // "clean downloads older than X days"
    final cleanOldMatch = RegExp(r'^clean\s+(?:up\s+)?(?:old\s+)?(?:files?\s+)?(?:in\s+)?(\w+)(?:\s+older\s+than\s+(\d+)\s+days?)?$', caseSensitive: false).firstMatch(input.trim());
    if (cleanOldMatch != null) {
      final dir = _resolveDirectory(cleanOldMatch.group(1)!);
      final days = cleanOldMatch.group(2) ?? '30';
      return IntentResult(intent: 'run_command', confidence: 0.9, taskType: 'run_command', taskData: {
        'command': 'bash',
        'args': ['-c', 'echo "Files older than $days days in $dir:" && find $dir -maxdepth 1 -mtime +$days -type f 2>/dev/null | head -30 && echo "---" && echo "Use: find $dir -maxdepth 1 -mtime +$days -delete  to remove"'],
      });
    }

    // "what's using disk space" / "disk hogs"
    if (lower == "what's using disk space" || lower == 'disk hogs' || lower == 'disk usage details') {
      return IntentResult(intent: 'run_command', confidence: 1.0, taskType: 'run_command', taskData: {
        'command': 'bash',
        'args': ['-c', 'echo "=== Top folders by size ===" && du -sh ~/Desktop ~/Documents ~/Downloads ~/Movies ~/Music ~/Pictures ~/Library 2>/dev/null | sort -rh && echo "---" && echo "=== Largest files ===" && find ~ -maxdepth 3 -type f -size +100M 2>/dev/null | head -10'],
      });
    }

    // "show wifi password" / "wifi password"
    if (lower == 'wifi password' || lower == 'show wifi password') {
      return IntentResult(intent: 'run_command', confidence: 1.0, taskType: 'run_command', taskData: {
        'command': 'bash',
        'args': ['-c', 'SSID=\$(networksetup -getairportnetwork en0 | awk -F\': \' \'{print \$2}\') && echo "Network: \$SSID" && security find-generic-password -wa "\$SSID" 2>/dev/null || echo "Could not retrieve password (may need admin privileges)"'],
      });
    }

    // "speed test" / "internet speed"
    if (lower == 'speed test' || lower == 'internet speed' || lower == 'test internet') {
      return IntentResult(intent: 'run_command', confidence: 1.0, taskType: 'run_command', taskData: {
        'command': 'bash',
        'args': ['-c', 'echo "Testing download speed..." && curl -s -o /dev/null -w "Download speed: %{speed_download} bytes/sec (%{time_total}s)\\n" https://speed.cloudflare.com/__down?bytes=10000000 && echo "Testing upload..." && curl -s -o /dev/null -w "Upload speed: %{speed_upload} bytes/sec\\n" -X POST -d @/dev/zero --max-time 5 https://speed.cloudflare.com/__up 2>/dev/null || echo "Upload test skipped"'],
      });
    }

    return null; // 其他都交给 AI
  }

  /// Resolve human-friendly directory names to paths
  String _resolveDirectory(String name) {
    final lower = name.toLowerCase().trim();
    const dirs = {
      'desktop': '~/Desktop',
      'downloads': '~/Downloads',
      'download': '~/Downloads',
      'documents': '~/Documents',
      'document': '~/Documents',
      'docs': '~/Documents',
      'home': '~',
      'pictures': '~/Pictures',
      'photos': '~/Pictures',
      'music': '~/Music',
      'movies': '~/Movies',
      'videos': '~/Movies',
      'applications': '/Applications',
      'apps': '/Applications',
      'library': '~/Library',
      'tmp': '/tmp',
      'temp': '/tmp',
    };
    return dirs[lower] ?? (lower.startsWith('/') || lower.startsWith('~') ? lower : '~/$lower');
  }

  /// 使用 AI (Ollama) 识别意图
  Future<IntentResult> _recognizeWithAI(String input) async {
    try {
      // 提交到 daemon 的 AI 意图识别服务
      final response = await daemonService.submitTaskAndWait(
        'ai_query',
        {
          'query': input,
          'mode': 'intent_recognition',
        },
        timeout: Duration(seconds: 30), // 增加到30秒，给 Ollama 足够时间
      );

      // 解析 AI 返回的结果
      if (response['success'] == true) {
        final intent = response['intent'] as String? ?? 'unknown';
        final confidence = (response['confidence'] as num?)?.toDouble() ?? 0.0;
        final parameters = response['parameters'] as Map<String, dynamic>? ?? {};

        // 映射 AI 识别的 intent 到 taskType
        final taskType = _mapIntentToTaskType(intent);

        return IntentResult(
          intent: intent,
          confidence: confidence,
          taskType: taskType,
          taskData: parameters,
          isAIFallback: true,
        );
      } else {
        // AI 识别失败，返回未知
        return IntentResult(
          intent: 'unknown',
          confidence: 0.0,
          taskType: null,
          taskData: {},
          error: response['error'] as String?,
        );
      }
    } catch (e) {
      print('AI intent recognition failed: $e');

      // 降级：直接调用本地 Ollama（绕过 daemon）
      return await _fallbackRecognition(input);
    }
  }

  /// 映射 AI 返回的 intent 到实际的 taskType
  /// 永远不返回 null — 未知意图 fallback 到 run_command
  String _mapIntentToTaskType(String intent) {
    switch (intent) {
      case 'screenshot':
      case 'open_app':
      case 'close_app':
      case 'open_url':
      case 'web_search':
      case 'system_info':
      case 'open_file':
      case 'run_command':
      case 'ai_query':
      case 'check_process':
      case 'list_processes':
      case 'file_operation':
      case 'create_file':
      case 'delete_file':
      case 'read_file':
      case 'list_apps':
      case 'ai_analyze_image':
        return intent;
      default:
        // Check if it's a domain task type
        if (_domainTaskTypes.contains(intent)) {
          return intent;
        }
        // 未知意图 fallback 到 run_command，让 shell 处理
        return 'run_command';
    }
  }

  /// 降级方案：直接调用本地 Ollama（绕过 daemon）
  /// 用于 daemon WebSocket 连接失败但 Ollama 仍在运行的情况
  Future<IntentResult> _fallbackRecognition(String input) async {
    try {
      // 直接通过 HTTP 调用本地 Ollama
      final result = await _callOllamaDirectly(input);
      if (result != null) {
        return result;
      }
    } catch (e) {
      print('Direct Ollama call failed: $e');
    }

    // 如果所有 AI 服务都不可用，fallback 到 ai_query
    return IntentResult(
      intent: 'ai_query',
      confidence: 0.5,
      taskType: 'ai_query',
      taskData: {'query': input},
      isAIFallback: true,
      error: 'AI service unavailable, forwarding as query',
    );
  }

  /// 直接调用本地 Ollama API
  Future<IntentResult?> _callOllamaDirectly(String input) async {
    try {
      // 构建 Ollama 提示词 — 全面的意图识别
      final prompt = '''You are an intent classifier for a macOS automation assistant. Analyze the user's input and return JSON.

User input: $input

Return JSON format:
{"intent": "intent_name", "confidence": 0.0-1.0, "parameters": {params}}

Available intents (with examples):

1. **open_url** - Open a website (params: url)
   "open twitter" → {"intent": "open_url", "parameters": {"url": "https://twitter.com"}}
   "go to github" → {"intent": "open_url", "parameters": {"url": "https://github.com"}}
   "send message on twitter" → {"intent": "open_url", "parameters": {"url": "https://twitter.com"}}
   "check my email" → {"intent": "open_url", "parameters": {"url": "https://mail.google.com"}}
   "watch youtube" → {"intent": "open_url", "parameters": {"url": "https://www.youtube.com"}}

2. **open_app** - Open a macOS application (params: app_name)
   "open Chrome" → {"intent": "open_app", "parameters": {"app_name": "Google Chrome"}}
   "launch Terminal" → {"intent": "open_app", "parameters": {"app_name": "Terminal"}}
   "open VSCode" → {"intent": "open_app", "parameters": {"app_name": "Visual Studio Code"}}
   "start Slack" → {"intent": "open_app", "parameters": {"app_name": "Slack"}}

3. **close_app** - Close/quit an application (params: app_name)
   "close Safari" → {"intent": "close_app", "parameters": {"app_name": "Safari"}}
   "kill Chrome" → {"intent": "close_app", "parameters": {"app_name": "Google Chrome"}}
   "quit Xcode" → {"intent": "close_app", "parameters": {"app_name": "Xcode"}}

4. **run_command** - Execute a shell command (params: command, args)
   Simple commands:
   "what's my IP address" → {"intent": "run_command", "parameters": {"command": "curl", "args": ["-s", "ifconfig.me"]}}
   "check disk space" → {"intent": "run_command", "parameters": {"command": "df", "args": ["-h"]}}
   "git status" → {"intent": "run_command", "parameters": {"command": "git", "args": ["status"]}}
   "show battery status" → {"intent": "run_command", "parameters": {"command": "pmset", "args": ["-g", "batt"]}}

   Multi-step scripts (use bash -c for chained commands):
   "show largest files" → {"intent": "run_command", "parameters": {"command": "bash", "args": ["-c", "du -ah ~ -d 3 2>/dev/null | sort -rh | head -20"]}}
   "kill process on port 3000" → {"intent": "run_command", "parameters": {"command": "bash", "args": ["-c", "lsof -t -i:3000 | xargs kill -9"]}}
   "compress my downloads" → {"intent": "run_command", "parameters": {"command": "bash", "args": ["-c", "cd ~/Downloads && zip -r ~/Desktop/archive.zip ."]}}
   "commit all changes" → {"intent": "run_command", "parameters": {"command": "bash", "args": ["-c", "git add -A && git commit -m 'update'"]}}
   "show open ports" → {"intent": "run_command", "parameters": {"command": "bash", "args": ["-c", "lsof -i -P -n | grep LISTEN"]}}
   "monitor cpu" → {"intent": "run_command", "parameters": {"command": "bash", "args": ["-c", "top -l 1 -n 10 | head -25"]}}
   "backup documents" → {"intent": "run_command", "parameters": {"command": "bash", "args": ["-c", "rsync -av ~/Documents/ ~/Desktop/backup/"]}}
   "clean docker" → {"intent": "run_command", "parameters": {"command": "bash", "args": ["-c", "docker system prune -af"]}}

   macOS automation via AppleScript (use osascript -e):
   "create a note about shopping" → {"intent": "run_command", "parameters": {"command": "osascript", "args": ["-e", "tell application \\"Notes\\" to make new note with properties {name:\\"shopping\\"}"]}}
   "set volume to 50" → {"intent": "run_command", "parameters": {"command": "osascript", "args": ["-e", "set volume output volume 50"]}}
   "empty trash" → {"intent": "run_command", "parameters": {"command": "osascript", "args": ["-e", "tell application \\"Finder\\" to empty the trash"]}}
   "toggle dark mode" → {"intent": "run_command", "parameters": {"command": "osascript", "args": ["-e", "tell application \\"System Events\\" to tell appearance preferences to set dark mode to not dark mode"]}}
   "add reminder buy milk" → {"intent": "run_command", "parameters": {"command": "osascript", "args": ["-e", "tell application \\"Reminders\\" to make new reminder with properties {name:\\"buy milk\\"}"]}}

5. **web_search** - Search the web (params: query)
   "search for Flutter tutorial" → {"intent": "web_search", "parameters": {"query": "Flutter tutorial"}}
6. **screenshot** - Take a screenshot (no params)
7. **system_info** - Get system information (no params)
8. **check_process** - Check if a process is running (params: process_name)
9. **list_processes** - List running processes (no params)
10. **file_operation** - Browse/list/search files (params: operation, directory, pattern)
11. **ai_query** - General questions that need AI to answer (params: query)

CRITICAL RULES:
1. For social media actions → open_url with the platform URL
2. For multi-step operations → run_command with command: "bash", args: ["-c", "cmd1 && cmd2"]
3. For macOS app automation → run_command with command: "osascript", args: ["-e", "applescript"]
4. args MUST be a JSON array of strings
5. run_command is the UNIVERSAL FALLBACK — if unsure, use it
6. NEVER return "unknown"
7. confidence >= 0.7

Return ONLY JSON, nothing else.''';

      final response = await http.Client().post(
        Uri.parse('http://localhost:11434/api/generate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'model': 'qwen2.5:latest',
          'prompt': prompt,
          'stream': false,
          'format': 'json',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final responseText = data['response'] as String;
        final result = jsonDecode(responseText);

        final intent = result['intent'] as String? ?? 'unknown';
        final confidence = (result['confidence'] as num?)?.toDouble() ?? 0.0;
        final parameters = result['parameters'] as Map<String, dynamic>? ?? {};

        return IntentResult(
          intent: intent,
          confidence: confidence,
          taskType: _mapIntentToTaskType(intent),
          taskData: parameters,
          isAIFallback: true,
        );
      }
    } catch (e) {
      print('Failed to call Ollama directly: $e');
    }

    return null;
  }
}

/// 意图识别结果
class IntentResult {
  final String intent; // 意图名称
  final double confidence; // 置信度 0-1
  final String? taskType; // 对应的任务类型
  final Map<String, dynamic> taskData; // 任务数据
  final bool needsConfirmation; // 是否需要用户确认
  final bool isAIFallback; // 是否使用 AI 识别
  final String? error; // 错误信息

  IntentResult({
    required this.intent,
    required this.confidence,
    this.taskType,
    required this.taskData,
    this.needsConfirmation = false,
    this.isAIFallback = false,
    this.error,
  });

  bool get isRecognized => confidence > 0.3 || isAIFallback;
  bool get hasError => error != null;
}
