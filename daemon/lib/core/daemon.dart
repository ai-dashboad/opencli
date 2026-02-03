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
import 'package:opencli_daemon/ui/terminal_ui.dart';
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
    TerminalUI.printSection('Initialization', emoji: '🚀');

    // Initialize telemetry first (for error tracking)
    TerminalUI.printInitStep('Initializing telemetry');
    _telemetry = TelemetryManager(
      appVersion: version,
      deviceId: _deviceId,
    );
    await _telemetry.initialize();
    TerminalUI.success('Telemetry initialized (consent: ${_telemetry.config.consent.name})', prefix: '  ✓');

    // Initialize plugin manager
    TerminalUI.printInitStep('Loading plugins');
    _pluginManager = PluginManager(config);
    await _pluginManager.loadAll();

    // Initialize request router
    TerminalUI.printInitStep('Setting up request router');
    _router = RequestRouter(_pluginManager);

    // Start IPC server
    TerminalUI.printInitStep('Starting IPC server');
    _ipcServer = IpcServer(
      socketPath: config.socketPath,
      router: _router,
    );
    await _ipcServer.start();
    TerminalUI.success('IPC server listening on ${config.socketPath}', prefix: '  ✓');

    // Start mobile WebSocket server
    TerminalUI.printInitStep('Starting mobile WebSocket server');
    _mobileManager = MobileConnectionManager(
      port: 9876,
      authSecret: 'opencli-dev-secret',
    );
    await _mobileManager.start();
    TerminalUI.success('Mobile connection server listening on port 9876', prefix: '  ✓');

    // Initialize mobile task handler
    TerminalUI.printInitStep('Setting up mobile task handler');
    _mobileTaskHandler = MobileTaskHandler(
      connectionManager: _mobileManager,
    );

    // Initialize capability system for hot-updatable executors
    TerminalUI.printInitStep('Initializing capability system');
    try {
      await _mobileTaskHandler.initializeCapabilities(
        autoUpdate: true,
      );
      TerminalUI.success('Capability system initialized', prefix: '  ✓');
    } catch (e) {
      TerminalUI.warning('Capability system initialization failed: $e', prefix: '  ⚠');
      // Continue without capabilities - fall back to built-in executors
    }

    // Initialize permission system for secure remote control
    TerminalUI.printInitStep('Initializing permission system');
    try {
      await _mobileTaskHandler.initializePermissions(
        pairingManager: _mobileManager.pairingManager,
      );
      TerminalUI.success('Permission system initialized', prefix: '  ✓');
    } catch (e) {
      TerminalUI.warning('Permission system initialization failed: $e', prefix: '  ⚠');
      // Continue without permission checks
    }

    // Start config watcher for hot-reload
    TerminalUI.printInitStep('Starting config watcher');
    _configWatcher = ConfigWatcher(
      configPath: config.configPath,
      onConfigChanged: _handleConfigChanged,
    );
    await _configWatcher.start();

    // Start health monitor
    TerminalUI.printInitStep('Starting health monitor');
    _healthMonitor = HealthMonitor(
      daemon: this,
      checkInterval: Duration(seconds: 30),
    );
    _healthMonitor.start();

    // Start status HTTP server for UI consumption
    TerminalUI.printInitStep('Starting status HTTP server', last: true);
    _statusServer = StatusServer(
      connectionManager: _mobileManager,
      daemon: this,
      port: 9875,
    );
    await _statusServer.start();
    TerminalUI.success('Status server listening on port 9875', prefix: '  ✓');

    // Auto-start Web UI (optional, can be disabled via config)
    final autoStartWebUI = Platform.environment['OPENCLI_AUTO_START_WEB_UI'] != 'false';
    if (autoStartWebUI) {
      TerminalUI.printSection('Optional Services', emoji: '🌟');
      TerminalUI.info('Auto-starting Web UI...', prefix: '🌐');
      final projectRoot = _findProjectRoot();
      if (projectRoot != null) {
        _webUILauncher = WebUILauncher(
          projectRoot: projectRoot,
          port: 3000,
        );
        await _webUILauncher!.start();
      }
    }

    // Print summary of all services
    final services = [
      {
        'name': 'Status API',
        'url': 'http://localhost:9875/status',
        'icon': '📊',
        'enabled': true,
      },
      {
        'name': 'Web UI',
        'url': 'http://localhost:3000',
        'icon': '🌐',
        'enabled': _webUILauncher?.isRunning ?? false,
      },
      {
        'name': 'Mobile',
        'url': 'ws://localhost:9876',
        'icon': '📱',
        'enabled': true,
      },
      {
        'name': 'IPC Socket',
        'url': config.socketPath,
        'icon': '🔌',
        'enabled': true,
      },
    ];

    TerminalUI.printServices(services);
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
      TerminalUI.warning('Could not find project root: $e', prefix: '  ⚠');
    }
    return null;
  }

  Future<void> stop() async {
    TerminalUI.printSection('Shutdown', emoji: '🛑');

    TerminalUI.printInitStep('Stopping Web UI');
    await _webUILauncher?.stop();

    TerminalUI.printInitStep('Stopping status server');
    await _statusServer.stop();

    TerminalUI.printInitStep('Stopping health monitor');
    await _healthMonitor.stop();

    TerminalUI.printInitStep('Stopping config watcher');
    await _configWatcher.stop();

    TerminalUI.printInitStep('Stopping mobile connection manager');
    await _mobileManager.stop();

    TerminalUI.printInitStep('Stopping IPC server');
    await _ipcServer.stop();

    TerminalUI.printInitStep('Unloading plugins');
    await _pluginManager.unloadAll();

    TerminalUI.printInitStep('Disposing task handler');
    _mobileTaskHandler.dispose();

    TerminalUI.printInitStep('Disposing telemetry', last: true);
    _telemetry.dispose();

    _exitSignal.complete();

    print('');
    TerminalUI.success('Daemon stopped gracefully', prefix: '👋');
    print('');
  }

  /// Get telemetry manager for error reporting
  TelemetryManager get telemetry => _telemetry;

  Future<void> wait() => _exitSignal.future;

  Future<void> _handleConfigChanged(Config newConfig) async {
    TerminalUI.info('Configuration changed, reloading...', prefix: '🔄');
    await _pluginManager.reload(newConfig);
    TerminalUI.success('Configuration reloaded', prefix: '✓');
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
