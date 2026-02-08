import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// 跨平台系统托盘服务
/// 支持 macOS (菜单栏)、Windows (系统托盘)、Linux (系统托盘)
class TrayService {
  static const String _daemonStatusUrl = 'http://localhost:9875/status';
  Timer? _statusUpdateTimer;

  // Daemon 状态
  bool _isRunning = false;
  String _version = '0.0.0';
  int _uptimeSeconds = 0;
  double _memoryMb = 0.0;
  int _mobileClients = 0;

  // Getters
  bool get isRunning => _isRunning;
  String get version => _version;
  String get uptimeFormatted => _formatUptime(_uptimeSeconds);
  String get memoryFormatted => '${_memoryMb.toStringAsFixed(1)} MB';
  int get mobileClients => _mobileClients;

  /// 初始化系统托盘（不注册监听器，由外部 State 类处理）
  Future<void> initWithoutListener() async {
    try {
      debugPrint('🚀 Initializing system tray...');

      // 设置托盘图标
      debugPrint('   🎨 Setting tray icon...');
      await _setTrayIcon();

      // 设置工具提示
      await trayManager.setToolTip('OpenCLI - Initializing...');

      // 创建托盘菜单
      debugPrint('   📋 Creating tray menu...');
      await _updateTrayMenu();

      // 开始定期更新状态
      debugPrint('   ⏰ Starting status updates...');
      _startStatusUpdates();

      debugPrint('✅ System tray initialized successfully');
    } catch (e) {
      debugPrint('⚠️  Failed to initialize system tray: $e');
      debugPrint('   Stack trace: ${StackTrace.current}');
    }
  }

  /// 设置托盘图标
  Future<void> _setTrayIcon() async {
    String iconPath;

    if (Platform.isMacOS) {
      // macOS 使用模板图标（自动适配深色模式）
      iconPath = 'assets/tray_icon_macos_template.png';
    } else if (Platform.isWindows) {
      iconPath = 'assets/tray_icon_windows.ico';
    } else {
      // Linux
      iconPath = 'assets/tray_icon_linux.png';
    }

    try {
      await trayManager.setIcon(iconPath);
    } catch (e) {
      debugPrint('⚠️  Failed to set tray icon: $e');
      // 如果图标加载失败，继续运行（使用默认图标）
    }
  }

  /// 开始定期更新状态
  void _startStatusUpdates() {
    // 立即更新一次
    _updateDaemonStatus();

    // 每 3 秒更新一次
    _statusUpdateTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _updateDaemonStatus(),
    );
  }

  /// 更新 Daemon 状态
  Future<void> _updateDaemonStatus() async {
    try {
      debugPrint('📡 Fetching daemon status from $_daemonStatusUrl');
      final response = await http.get(
        Uri.parse(_daemonStatusUrl),
      ).timeout(const Duration(seconds: 2));

      debugPrint('📊 Response status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final daemon = data['daemon'] as Map<String, dynamic>;
        final mobile = data['mobile'] as Map<String, dynamic>;

        final wasRunning = _isRunning;
        _isRunning = true;
        _version = daemon['version'] as String? ?? '0.0.0';
        _uptimeSeconds = daemon['uptime_seconds'] as int? ?? 0;
        _memoryMb = (daemon['memory_mb'] as num?)?.toDouble() ?? 0.0;
        _mobileClients = mobile['connected_clients'] as int? ?? 0;

        debugPrint('✅ Status updated: v$_version, uptime: $_uptimeSeconds s, memory: $_memoryMb MB');

        // 更新托盘工具提示（每次都更新，因为这不影响点击事件）
        await trayManager.setToolTip(
          'OpenCLI - Running\n'
          'Uptime: $uptimeFormatted\n'
          'Memory: $memoryFormatted'
        );

        // ⚠️ 只在状态变化时更新菜单，避免频繁调用 setContextMenu 导致点击事件失效
        if (wasRunning != _isRunning) {
          debugPrint('🔄 Daemon state changed, updating menu...');
          await _updateTrayMenu();
        }
      } else {
        debugPrint('❌ Unexpected status code: ${response.statusCode}');
        _handleDaemonOffline();
      }
    } catch (e) {
      debugPrint('❌ Failed to fetch daemon status: $e');
      _handleDaemonOffline();
    }
  }

  /// 处理 Daemon 离线状态
  void _handleDaemonOffline() {
    final wasRunning = _isRunning;
    _isRunning = false;
    trayManager.setToolTip('OpenCLI - Daemon Offline');

    // 只在状态变化时更新菜单
    if (wasRunning != _isRunning) {
      debugPrint('🔄 Daemon went offline, updating menu...');
      _updateTrayMenu();
    }
  }

  /// 更新托盘菜单
  Future<void> _updateTrayMenu() async {
    final statusIcon = _isRunning ? '●' : '○';
    final statusText = _isRunning ? 'Running' : 'Offline';

    final menu = Menu(items: [
      // 标题 - 更简洁的设计
      MenuItem(
        key: 'header',
        label: 'OpenCLI  $statusIcon $statusText',
        disabled: true,
      ),
      MenuItem.separator(),

      // 状态信息 - 精简布局
      if (_isRunning) ...[
        MenuItem(
          key: 'version',
          label: '  v$_version  ·  ↑ $uptimeFormatted  ·  💾 $memoryFormatted',
          disabled: true,
        ),
        MenuItem(
          key: 'clients',
          label: '  📱 $_mobileClients ${_mobileClients == 1 ? "client" : "clients"} connected',
          disabled: true,
        ),
      ] else ...[
        MenuItem(
          key: 'status_offline',
          label: '  Daemon not responding...',
          disabled: true,
        ),
      ],
      MenuItem.separator(),

      // 操作菜单 - 使用 SF Symbols 风格
      MenuItem(
        key: 'ai_models',
        label: '🧠  AI Models',
      ),
      MenuItem(
        key: 'dashboard',
        label: '📈  Dashboard',
      ),
      MenuItem(
        key: 'webui',
        label: '🌐  Web UI',
      ),
      MenuItem.separator(),
      MenuItem(
        key: 'settings',
        label: '⚙️   Settings',
      ),
      MenuItem(
        key: 'refresh',
        label: '🔄  Refresh Status',
      ),
      MenuItem.separator(),
      MenuItem(
        key: 'quit',
        label: '⏻  Quit',
      ),
    ]);

    await trayManager.setContextMenu(menu);
  }

  /// 格式化运行时间
  String _formatUptime(int seconds) {
    if (seconds < 60) {
      return '${seconds}s';
    } else if (seconds < 3600) {
      final mins = seconds ~/ 60;
      return '${mins}m';
    } else if (seconds < 86400) {
      final hours = seconds ~/ 3600;
      final mins = (seconds % 3600) ~/ 60;
      return '${hours}h ${mins}m';
    } else {
      final days = seconds ~/ 86400;
      final hours = (seconds % 86400) ~/ 3600;
      return '${days}d ${hours}h';
    }
  }

  /// 处理托盘菜单项点击（由外部 State 类调用）
  void handleMenuClick(String menuKey) {
    debugPrint('🔔 [TrayService] Handling menu click: $menuKey');

    switch (menuKey) {
      case 'ai_models':
        debugPrint('   ➜ Executing: AI Models');
        _openAIModels();
        break;
      case 'dashboard':
        debugPrint('   ➜ Executing: Dashboard');
        _openDashboard();
        break;
      case 'webui':
        debugPrint('   ➜ Executing: Web UI');
        _openWebUI();
        break;
      case 'settings':
        debugPrint('   ➜ Executing: Settings');
        _openSettings();
        break;
      case 'refresh':
        debugPrint('   ➜ Executing: Refresh');
        _refresh();
        break;
      case 'quit':
        debugPrint('   ➜ Executing: Quit');
        _quit();
        break;
      default:
        debugPrint('   ⚠️  Unknown menu item: $menuKey');
    }
  }

  /// 打开 AI Models
  void _openAIModels() {
    debugPrint('📍 Opening AI Models...');
    _showMainWindow();
  }

  /// 打开 Dashboard
  void _openDashboard() {
    debugPrint('📍 Opening Dashboard...');
    _openUrl('http://localhost:3000/dashboard');
  }

  /// 打开 Web UI
  void _openWebUI() {
    debugPrint('📍 Opening Web UI...');
    _openUrl('http://localhost:3000');
  }

  /// 打开设置
  void _openSettings() {
    debugPrint('📍 Opening Settings...');
    _showMainWindow();
  }

  /// 刷新状态
  void _refresh() {
    debugPrint('♻️  Refreshing status...');
    _updateDaemonStatus();
  }

  /// 退出应用
  void _quit() {
    debugPrint('👋 Quitting OpenCLI...');
    _cleanup();
    exit(0);
  }

  /// 显示主窗口
  Future<void> _showMainWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  /// 打开 URL
  void _openUrl(String url) {
    debugPrint('🌐 Opening URL: $url');

    if (Platform.isMacOS) {
      Process.run('open', [url]);
    } else if (Platform.isWindows) {
      Process.run('cmd', ['/c', 'start', url]);
    } else {
      Process.run('xdg-open', [url]);
    }
  }

  /// 清理资源
  void _cleanup() {
    _statusUpdateTimer?.cancel();
    trayManager.destroy();
  }

  /// 销毁服务
  void dispose() {
    _cleanup();
  }
}
