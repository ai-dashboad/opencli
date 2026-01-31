import 'dart:async';
import 'package:opencli_daemon/core/config.dart';
import 'package:opencli_daemon/ipc/ipc_server.dart';
import 'package:opencli_daemon/core/request_router.dart';
import 'package:opencli_daemon/plugins/plugin_manager.dart';
import 'package:opencli_daemon/core/config_watcher.dart';
import 'package:opencli_daemon/core/health_monitor.dart';

class Daemon {
  final Config config;
  late final IpcServer _ipcServer;
  late final RequestRouter _router;
  late final PluginManager _pluginManager;
  late final ConfigWatcher _configWatcher;
  late final HealthMonitor _healthMonitor;

  final Completer<void> _exitSignal = Completer<void>();

  Daemon(this.config);

  Future<void> start() async {
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
  }

  Future<void> stop() async {
    print('Stopping daemon...');

    await _healthMonitor.stop();
    await _configWatcher.stop();
    await _ipcServer.stop();
    await _pluginManager.unloadAll();

    _exitSignal.complete();
    print('✓ Daemon stopped');
  }

  Future<void> wait() => _exitSignal.future;

  Future<void> _handleConfigChanged(Config newConfig) async {
    print('Configuration changed, reloading...');
    await _pluginManager.reload(newConfig);
  }

  Map<String, dynamic> getStats() {
    return {
      'uptime_seconds': _healthMonitor.uptimeSeconds,
      'total_requests': _router.totalRequests,
      'plugins_loaded': _pluginManager.loadedCount,
      'memory_mb': _healthMonitor.memoryUsageMb,
    };
  }
}
