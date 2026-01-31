import 'dart:io';
import 'dart:async';
import 'package:opencli_daemon/core/config.dart';

class ConfigWatcher {
  final String configPath;
  final Future<void> Function(Config) onConfigChanged;

  Timer? _timer;
  DateTime? _lastModified;

  ConfigWatcher({
    required this.configPath,
    required this.onConfigChanged,
  });

  Future<void> start() async {
    _lastModified = await _getLastModified();

    // Poll for changes every 5 seconds
    _timer = Timer.periodic(Duration(seconds: 5), (_) => _checkForChanges());

    print('Config watcher started');
  }

  Future<void> stop() async {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _checkForChanges() async {
    final currentModified = await _getLastModified();

    if (currentModified != null &&
        _lastModified != null &&
        currentModified.isAfter(_lastModified!)) {
      _lastModified = currentModified;

      try {
        final newConfig = await Config.load();
        await onConfigChanged(newConfig);
      } catch (e) {
        print('Error reloading config: $e');
      }
    }
  }

  Future<DateTime?> _getLastModified() async {
    try {
      final file = File(configPath);
      if (await file.exists()) {
        final stat = await file.stat();
        return stat.modified;
      }
    } catch (e) {
      // Ignore
    }
    return null;
  }
}
