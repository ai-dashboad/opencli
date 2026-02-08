import 'dart:io';

/// 终端 UI 美化工具
/// 提供颜色、格式化和视觉元素支持
class TerminalUI {
  // ANSI 颜色代码
  static const String _reset = '\x1B[0m';
  static const String _bold = '\x1B[1m';
  static const String _dim = '\x1B[2m';

  // 前景色
  static const String _black = '\x1B[30m';
  static const String _red = '\x1B[31m';
  static const String _green = '\x1B[32m';
  static const String _yellow = '\x1B[33m';
  static const String _blue = '\x1B[34m';
  static const String _magenta = '\x1B[35m';
  static const String _cyan = '\x1B[36m';
  static const String _white = '\x1B[37m';

  // 亮色
  static const String _brightBlack = '\x1B[90m';
  static const String _brightRed = '\x1B[91m';
  static const String _brightGreen = '\x1B[92m';
  static const String _brightYellow = '\x1B[93m';
  static const String _brightBlue = '\x1B[94m';
  static const String _brightMagenta = '\x1B[95m';
  static const String _brightCyan = '\x1B[96m';
  static const String _brightWhite = '\x1B[97m';

  // 背景色
  static const String _bgBlue = '\x1B[44m';
  static const String _bgGreen = '\x1B[42m';
  static const String _bgRed = '\x1B[41m';
  static const String _bgYellow = '\x1B[43m';

  /// 检测终端是否支持颜色
  static bool get supportsColor {
    return stdout.supportsAnsiEscapes;
  }

  /// 应用颜色（如果终端支持）
  static String _color(String text, String colorCode) {
    return supportsColor ? '$colorCode$text$_reset' : text;
  }

  // 公共颜色方法
  static String red(String text) => _color(text, _red);
  static String green(String text) => _color(text, _green);
  static String yellow(String text) => _color(text, _yellow);
  static String blue(String text) => _color(text, _blue);
  static String magenta(String text) => _color(text, _magenta);
  static String cyan(String text) => _color(text, _cyan);
  static String white(String text) => _color(text, _white);
  static String bold(String text) => _color(text, _bold);
  static String dim(String text) => _color(text, _dim);

  static String brightRed(String text) => _color(text, _brightRed);
  static String brightGreen(String text) => _color(text, _brightGreen);
  static String brightYellow(String text) => _color(text, _brightYellow);
  static String brightBlue(String text) => _color(text, _brightBlue);
  static String brightMagenta(String text) => _color(text, _brightMagenta);
  static String brightCyan(String text) => _color(text, _brightCyan);

  /// 打印带颜色的横幅
  static void printBanner(String appName, String version) {
    final width = 60;
    final padding = (width - appName.length - version.length - 3) ~/ 2;

    print('');
    print(cyan('┏' + '━' * (width - 2) + '┓'));
    print(cyan('┃') +
        ' ' * padding +
        bold(brightCyan(appName)) +
        ' ' +
        dim(version) +
        ' ' * padding +
        cyan('┃'));
    print(cyan('┗' + '━' * (width - 2) + '┛'));
    print('');
  }

  /// 打印分隔线
  static void printDivider({String char = '─', int width = 60, String? color}) {
    final line = char * width;
    if (color != null) {
      print(_color(line, color));
    } else {
      print(dim(line));
    }
  }

  /// 打印粗分隔线
  static void printThickDivider({int width = 60}) {
    print(cyan('━' * width));
  }

  /// 打印节标题
  static void printSection(String title, {String emoji = '▶'}) {
    print('');
    print(bold(brightCyan('$emoji $title')));
    printDivider(char: '─', width: 40);
  }

  /// 打印成功消息
  static void success(String message, {String prefix = '✓'}) {
    print(brightGreen('$prefix ') + message);
  }

  /// 打印错误消息
  static void error(String message, {String prefix = '✗'}) {
    print(brightRed('$prefix ') + message);
  }

  /// 打印警告消息
  static void warning(String message, {String prefix = '⚠'}) {
    print(brightYellow('$prefix ') + message);
  }

  /// 打印信息消息
  static void info(String message, {String prefix = 'ℹ'}) {
    print(brightBlue('$prefix ') + message);
  }

  /// 打印进行中的操作
  static void progress(String message, {String prefix = '⋯'}) {
    stdout.write(dim('$prefix ') + message + dim('...'));
  }

  /// 完成进度行
  static void progressDone({bool success = true}) {
    if (success) {
      print(' ' + brightGreen('✓'));
    } else {
      print(' ' + brightRed('✗'));
    }
  }

  /// 打印键值对
  static void printKeyValue(String key, dynamic value, {int indent = 2}) {
    final spaces = ' ' * indent;
    final formattedKey = dim('$key:');
    print('$spaces$formattedKey $value');
  }

  /// 打印状态表
  static void printStatusTable(List<Map<String, String>> rows) {
    if (rows.isEmpty) return;

    // 计算列宽
    final labelWidth = rows
        .map((r) => r['label']?.length ?? 0)
        .reduce((a, b) => a > b ? a : b);
    final statusWidth = rows
        .map((r) => r['status']?.length ?? 0)
        .reduce((a, b) => a > b ? a : b);

    print('');
    for (final row in rows) {
      final label = row['label'] ?? '';
      final status = row['status'] ?? '';
      final state = row['state'] ?? 'info'; // success, error, warning, info

      final paddedLabel = label.padRight(labelWidth + 2);
      String coloredStatus;

      switch (state) {
        case 'success':
          coloredStatus = brightGreen(status);
          break;
        case 'error':
          coloredStatus = brightRed(status);
          break;
        case 'warning':
          coloredStatus = brightYellow(status);
          break;
        default:
          coloredStatus = brightBlue(status);
      }

      print('  ${dim(paddedLabel)} $coloredStatus');
    }
    print('');
  }

  /// 打印加载动画帧（需要在循环中调用）
  static const List<String> _spinnerFrames = [
    '⠋',
    '⠙',
    '⠹',
    '⠸',
    '⠼',
    '⠴',
    '⠦',
    '⠧',
    '⠇',
    '⠏'
  ];
  static int _spinnerIndex = 0;

  static void printSpinner(String message) {
    final frame = _spinnerFrames[_spinnerIndex % _spinnerFrames.length];
    stdout.write('\r${brightCyan(frame)} $message');
    _spinnerIndex++;
  }

  /// 清除当前行
  static void clearLine() {
    stdout.write('\r\x1B[K');
  }

  /// 打印服务列表
  static void printServices(List<Map<String, dynamic>> services) {
    print('');
    print(bold(brightCyan('📊 Available Services')));
    printDivider(char: '─', width: 60);

    for (final service in services) {
      final name = service['name'] as String;
      final url = service['url'] as String;
      final icon = service['icon'] as String? ?? '•';
      final enabled = service['enabled'] as bool? ?? true;

      if (enabled) {
        print('  ${brightCyan(icon)} ${bold(name.padRight(16))} ${dim(url)}');
      } else {
        print('  ${dim('$icon ${name.padRight(16)} $url (disabled)')}');
      }
    }

    printDivider(char: '─', width: 60);
    print('');
  }

  /// 打印欢迎消息
  static void printWelcome() {
    print(brightCyan('🚀 Daemon is ready!'));
    print(dim('   Press Ctrl+C to stop'));
    print('');
  }

  /// 打印关闭消息
  static void printShutdown() {
    print('');
    print(yellow('👋 Shutting down gracefully...'));
  }

  /// 打印插件加载信息
  static void printPluginLoaded(String name, {String? version}) {
    final versionStr = version != null ? dim(' v$version') : '';
    print('  ${brightGreen('✓')} $name$versionStr');
  }

  /// 打印统计信息
  static void printStats(Map<String, dynamic> stats) {
    print('');
    print(bold(brightCyan('📈 Statistics')));
    printDivider(char: '─', width: 40);

    stats.forEach((key, value) {
      printKeyValue(key, value);
    });

    print('');
  }

  /// 打印初始化步骤
  static void printInitStep(String step, {bool last = false}) {
    final prefix = last ? '└─' : '├─';
    print(dim('  $prefix ') + step);
  }
}
