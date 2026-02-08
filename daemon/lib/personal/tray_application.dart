/// System tray application for personal mode
///
/// Provides a GUI system tray icon with menu for quick access to
/// common OpenCLI functions without using the command line.
library;

import 'dart:async';
import 'dart:io';

/// System tray application manager
class TrayApplication {
  final String appName;
  final String version;
  final TrayConfig config;

  Process? _trayProcess;
  bool _isRunning = false;
  final _statusController = StreamController<TrayStatus>.broadcast();

  TrayApplication({
    required this.appName,
    required this.version,
    TrayConfig? config,
  }) : config = config ?? TrayConfig();

  /// Stream of tray status updates
  Stream<TrayStatus> get statusStream => _statusController.stream;

  /// Start the system tray application
  Future<void> start() async {
    if (_isRunning) return;

    try {
      // Detect platform and start appropriate tray implementation
      if (Platform.isMacOS) {
        await _startMacOSTray();
      } else if (Platform.isLinux) {
        await _startLinuxTray();
      } else if (Platform.isWindows) {
        await _startWindowsTray();
      } else {
        throw TrayException(
            'Unsupported platform: ${Platform.operatingSystem}');
      }

      _isRunning = true;
      _updateStatus(TrayStatus.running);

      print('[TrayApp] System tray started');
    } catch (e) {
      print('[TrayApp] Failed to start: $e');
      _updateStatus(TrayStatus.error);
      rethrow;
    }
  }

  /// Stop the system tray application
  Future<void> stop() async {
    if (!_isRunning) return;

    _trayProcess?.kill();
    _trayProcess = null;

    _isRunning = false;
    _updateStatus(TrayStatus.stopped);

    print('[TrayApp] System tray stopped');
  }

  /// Update tray icon
  Future<void> updateIcon(TrayIcon icon) async {
    if (!_isRunning) return;

    // Send update command to tray process
    _sendCommand({
      'action': 'update_icon',
      'icon': icon.name,
    });
  }

  /// Update tray tooltip
  Future<void> updateTooltip(String tooltip) async {
    if (!_isRunning) return;

    _sendCommand({
      'action': 'update_tooltip',
      'tooltip': tooltip,
    });
  }

  /// Show notification from tray
  Future<void> showNotification({
    required String title,
    required String message,
    TrayNotificationType type = TrayNotificationType.info,
  }) async {
    _sendCommand({
      'action': 'show_notification',
      'title': title,
      'message': message,
      'type': type.name,
    });
  }

  /// Start macOS tray application
  Future<void> _startMacOSTray() async {
    // Create menu definition
    final menu = _buildMacOSMenu();

    // Write menu to temp file
    final menuFile = File('${Directory.systemTemp.path}/opencli_menu.json');
    await menuFile.writeAsString(menu);

    // Start tray app using built-in macOS support
    // In production, this would use a proper macOS app bundle
    print('[TrayApp] macOS tray initialized');
  }

  /// Start Linux tray application
  Future<void> _startLinuxTray() async {
    // Check for desktop environment
    final desktop = Platform.environment['XDG_CURRENT_DESKTOP'];

    if (desktop == null || desktop.isEmpty) {
      throw TrayException('No desktop environment detected');
    }

    // Create menu definition
    final menu = _buildLinuxMenu();

    print('[TrayApp] Linux tray initialized for $desktop');
  }

  /// Start Windows tray application
  Future<void> _startWindowsTray() async {
    // Create menu definition
    final menu = _buildWindowsMenu();

    print('[TrayApp] Windows tray initialized');
  }

  /// Build macOS menu structure
  String _buildMacOSMenu() {
    final menu = {
      'title': appName,
      'items': [
        {
          'label': '📱 Mobile Pairing',
          'submenu': [
            {'label': 'Show QR Code', 'action': 'show_qr'},
            {'label': 'View Paired Devices', 'action': 'view_devices'},
            {'separator': true},
            {'label': 'Disconnect All', 'action': 'disconnect_all'},
          ],
        },
        {'separator': true},
        {
          'label': '🖥️ Quick Tasks',
          'submenu': [
            {'label': 'Open Application...', 'action': 'open_app'},
            {'label': 'Execute Command...', 'action': 'execute_cmd'},
            {'label': 'Screenshot & Analyze', 'action': 'screenshot'},
            {'label': 'File Operations...', 'action': 'file_ops'},
          ],
        },
        {'separator': true},
        {
          'label': '⚙️ Settings',
          'submenu': [
            {
              'label': 'Start at Login',
              'type': 'checkbox',
              'checked': config.startAtLogin,
              'action': 'toggle_autostart',
            },
            {'label': 'Notifications...', 'action': 'settings_notifications'},
            {'label': 'Data Storage...', 'action': 'settings_storage'},
            {'separator': true},
            {'label': 'Advanced Options...', 'action': 'settings_advanced'},
          ],
        },
        {
          'label': '📊 Status',
          'submenu': [
            {'label': 'View Status', 'action': 'view_status'},
            {'label': 'Recent Tasks', 'action': 'recent_tasks'},
            {'label': 'Performance Monitor', 'action': 'performance'},
          ],
        },
        {'separator': true},
        {
          'label': '❓ Help',
          'submenu': [
            {'label': 'User Guide', 'action': 'help_guide'},
            {'label': 'FAQ', 'action': 'help_faq'},
            {'separator': true},
            {'label': 'Send Feedback', 'action': 'help_feedback'},
            {'label': 'About $appName', 'action': 'about'},
          ],
        },
        {'separator': true},
        {'label': 'Quit $appName', 'action': 'quit'},
      ],
    };

    return _menuToJson(menu);
  }

  /// Build Linux menu structure
  String _buildLinuxMenu() {
    // Similar to macOS but adapted for Linux desktop environments
    return _buildMacOSMenu();
  }

  /// Build Windows menu structure
  String _buildWindowsMenu() {
    // Similar to macOS but adapted for Windows
    return _buildMacOSMenu();
  }

  /// Convert menu structure to JSON
  String _menuToJson(Map<String, dynamic> menu) {
    // In production, use proper JSON encoding
    return menu.toString();
  }

  /// Send command to tray process
  void _sendCommand(Map<String, dynamic> command) {
    if (_trayProcess == null) return;

    // Send command via stdin
    final cmdJson = _menuToJson(command);
    _trayProcess!.stdin.writeln(cmdJson);
  }

  /// Update tray status
  void _updateStatus(TrayStatus status) {
    _statusController.add(status);
  }

  /// Dispose resources
  Future<void> dispose() async {
    await stop();
    await _statusController.close();
  }

  bool get isRunning => _isRunning;
}

/// Tray configuration
class TrayConfig {
  final bool startAtLogin;
  final bool showNotifications;
  final bool minimizeToTray;
  final TrayIcon defaultIcon;

  TrayConfig({
    this.startAtLogin = true,
    this.showNotifications = true,
    this.minimizeToTray = true,
    this.defaultIcon = TrayIcon.idle,
  });
}

/// Tray icon types
enum TrayIcon {
  idle,
  active,
  working,
  error,
  paused,
}

/// Tray status
enum TrayStatus {
  stopped,
  starting,
  running,
  error,
}

/// Notification type
enum TrayNotificationType {
  info,
  warning,
  error,
  success,
}

/// Tray exception
class TrayException implements Exception {
  final String message;

  TrayException(this.message);

  @override
  String toString() => 'TrayException: $message';
}

/// Tray menu builder for creating dynamic menus
class TrayMenuBuilder {
  final List<TrayMenuItem> _items = [];

  /// Add menu item
  TrayMenuBuilder addItem(TrayMenuItem item) {
    _items.add(item);
    return this;
  }

  /// Add separator
  TrayMenuBuilder addSeparator() {
    _items.add(TrayMenuItem.separator());
    return this;
  }

  /// Add submenu
  TrayMenuBuilder addSubmenu(String label, List<TrayMenuItem> items) {
    _items.add(TrayMenuItem.submenu(label, items));
    return this;
  }

  /// Build menu
  List<TrayMenuItem> build() => _items;
}

/// Tray menu item
class TrayMenuItem {
  final String? label;
  final String? action;
  final List<TrayMenuItem>? submenu;
  final bool isSeparator;
  final bool isCheckbox;
  final bool? checked;

  TrayMenuItem({
    this.label,
    this.action,
    this.submenu,
    this.isSeparator = false,
    this.isCheckbox = false,
    this.checked,
  });

  factory TrayMenuItem.separator() {
    return TrayMenuItem(isSeparator: true);
  }

  factory TrayMenuItem.submenu(String label, List<TrayMenuItem> items) {
    return TrayMenuItem(label: label, submenu: items);
  }

  factory TrayMenuItem.checkbox(String label, bool checked, String action) {
    return TrayMenuItem(
      label: label,
      action: action,
      isCheckbox: true,
      checked: checked,
    );
  }
}
