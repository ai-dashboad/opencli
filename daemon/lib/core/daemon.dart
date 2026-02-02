import 'dart:async';
import 'dart:io';
import 'package:opencli_daemon/core/config.dart';
import 'package:opencli_daemon/ipc/ipc_server.dart';
import 'package:opencli_daemon/core/request_router.dart';
import 'package:opencli_daemon/plugins/plugin_manager.dart';
import 'package:opencli_daemon/core/config_watcher.dart';
import 'package:opencli_daemon/core/health_monitor.dart';
import 'package:opencli_daemon/mobile/mobile_connection_manager.dart';
import 'package:opencli_daemon/mobile/mobile_task_handler.dart';
import 'package:opencli_daemon/ui/status_server.dart';
import 'package:opencli_daemon/ui/web_ui_launcher.dart';
import 'package:opencli_daemon/ui/menubar_app_launcher.dart';
import 'package:opencli_daemon/telemetry/telemetry.dart';

class Daemon {
  static const String version = '0.2.0';

  final Config config;
  late final IpcServer _ipcServer;
  late final RequestRouter _router;
  late final PluginManager _pluginManager;
  late final ConfigWatcher _configWatcher;
  late final HealthMonitor _healthMonitor;
  late final MobileConnectionManager _mobileManager;
  late final MobileTaskHandler _mobileTaskHandler;
  late final StatusServer _statusServer;
  late final TelemetryManager _telemetry;
  WebUILauncher? _webUILauncher;
  MenubarAppLauncher? _menubarLauncher;

  final Completer<void> _exitSignal = Completer<void>();
  late final String _deviceId;

  Daemon(this.config) {
    _deviceId = _loadOrCreateDeviceId();
  }

  /// Load or create device ID
  String _loadOrCreateDeviceId() {
    final home = Platform.environment['HOME'] ?? '.';
    final deviceIdFile = File('$home/.opencli/device_id');

    try {
      if (deviceIdFile.existsSync()) {
        return deviceIdFile.readAsStringSync().trim();
      }
    } catch (_) {}

    // Generate new device ID
    final deviceId = '${Platform.localHostname}-${DateTime.now().millisecondsSinceEpoch}';
    try {
      deviceIdFile.parent.createSync(recursive: true);
      deviceIdFile.writeAsStringSync(deviceId);
    } catch (_) {}

    return deviceId;
  }

  Future<void> start() async {
    // Initialize telemetry first (for error tracking)
    _telemetry = TelemetryManager(
      appVersion: version,
      deviceId: _deviceId,
    );
    await _telemetry.initialize();
    print('📊 Telemetry initialized (consent: ${_telemetry.config.consent.name})');

    // Initialize plugin manager
    _pluginManager = PluginManager(config);
    await _pluginManager.loadAll();

    // Initialize request router
    _router = RequestRouter(_pluginManager);

    // Start IPC server
    _ipcServer = IpcServer(
      socketPath: config.socketPath,
      router: _router,
    );
    await _ipcServer.start();

    // Start mobile WebSocket server
    _mobileManager = MobileConnectionManager(
      port: 9876,
      authSecret: 'opencli-dev-secret',
    );
    await _mobileManager.start();

    // Initialize mobile task handler
    _mobileTaskHandler = MobileTaskHandler(
      connectionManager: _mobileManager,
    );

    // Initialize capability system for hot-updatable executors
    try {
      await _mobileTaskHandler.initializeCapabilities(
        autoUpdate: true,
      );
      print('📦 Capability system initialized');
    } catch (e) {
      print('⚠️  Capability system initialization failed: $e');
      // Continue without capabilities - fall back to built-in executors
    }

    // Start config watcher for hot-reload
    _configWatcher = ConfigWatcher(
      configPath: config.configPath,
      onConfigChanged: _handleConfigChanged,
    );
    await _configWatcher.start();

    // Start health monitor
    _healthMonitor = HealthMonitor(
      daemon: this,
      checkInterval: Duration(seconds: 30),
    );
    _healthMonitor.start();

    // Start status HTTP server for UI consumption
    _statusServer = StatusServer(
      connectionManager: _mobileManager,
      daemon: this,
      port: 9875,
    );
    await _statusServer.start();

    // Auto-start Web UI (optional, can be disabled via config)
    final autoStartWebUI = Platform.environment['OPENCLI_AUTO_START_WEB_UI'] != 'false';
    if (autoStartWebUI) {
      print('');
      print('🌐 Auto-starting Web UI...');
      final projectRoot = _findProjectRoot();
      if (projectRoot != null) {
        _webUILauncher = WebUILauncher(
          projectRoot: projectRoot,
          port: 3000,
        );
        await _webUILauncher!.start();
      }
    }

    // Auto-start menubar app on macOS (optional)
    final autoStartMenubar = Platform.environment['OPENCLI_AUTO_START_MENUBAR'] != 'false';
    if (autoStartMenubar && Platform.isMacOS) {
      print('');
      print('📍 Starting menubar app...');
      _menubarLauncher = MenubarAppLauncher(
        statusUrl: 'http://localhost:9875/status',
      );
      await _menubarLauncher!.start();
    }

    print('');
    print('✓ All services started!');
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('📊 Available Interfaces:');
    print('  • Status API:  http://localhost:9875/status');
    if (_webUILauncher?.isRunning ?? false) {
      print('  • Web UI:      http://localhost:3000');
    }
    print('  • Mobile:      ws://localhost:9876');
    print('  • IPC Socket:  ${config.socketPath}');
    if (_menubarLauncher?.isRunning ?? false) {
      print('  • Menubar:     Running in macOS taskbar');
    }
    print('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    print('');
  }

  String? _findProjectRoot() {
    try {
      // Try to find project root by looking for web-ui directory
      var dir = Directory.current;
      for (var i = 0; i < 5; i++) {
        final webUiDir = Directory('${dir.path}/web-ui');
        if (webUiDir.existsSync()) {
          return dir.path;
        }
        dir = dir.parent;
      }
    } catch (e) {
      print('⚠️  Could not find project root: $e');
    }
    return null;
  }

  Future<void> stop() async {
    print('Stopping daemon...');

    await _webUILauncher?.stop();
    await _menubarLauncher?.stop();
    await _statusServer.stop();
    await _healthMonitor.stop();
    await _configWatcher.stop();
    await _mobileManager.stop();
    await _ipcServer.stop();
    await _pluginManager.unloadAll();
    _mobileTaskHandler.dispose();
    _telemetry.dispose();

    _exitSignal.complete();
    print('✓ Daemon stopped');
  }

  /// Get telemetry manager for error reporting
  TelemetryManager get telemetry => _telemetry;

  Future<void> wait() => _exitSignal.future;

  Future<void> _handleConfigChanged(Config newConfig) async {
    print('Configuration changed, reloading...');
    await _pluginManager.reload(newConfig);
  }

  Map<String, dynamic> getStats() {
    return {
      'version': version,
      'device_id': _deviceId,
      'uptime_seconds': _healthMonitor.uptimeSeconds,
      'total_requests': _router.totalRequests,
      'plugins_loaded': _pluginManager.loadedCount,
      'memory_mb': _healthMonitor.memoryUsageMb,
      'telemetry': _telemetry.getStats(),
      'taskHandler': _mobileTaskHandler.getStats(),
    };
  }

  /// Get mobile task handler for capability management
  MobileTaskHandler get taskHandler => _mobileTaskHandler;
}
